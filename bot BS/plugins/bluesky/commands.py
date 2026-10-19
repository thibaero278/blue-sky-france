"""Plugin Blue Sky : le bot fait circuler les infos entre le serveur DCS, Discord et le site web.

    DCS ──(Scores.lua, positions)──▶ bot ──▶ site (stats, carte live, joueurs en ligne)
     ▲                                │  └──▶ Discord (promotions, bilans de vol, /pilote, /classement)
     └──(annonces, événements)────────┘
    Discord ──(activité, événements planifiés)──▶ bot ──▶ site (page Discord, planning)

Réglages : config/dcssb/plugins/bluesky.yaml (modèle : config/templates/plugins/bluesky.yaml.template).
Le site est statique (GitHub Pages) : le bot pousse ses données vers le relais Apps Script
(circuit_site/Code.gs) et/ou les écrit en JSON dans un dossier (export_dir).
"""

import asyncio
import json
import os
import re
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import aiohttp
import discord
from discord import app_commands
from discord.ext import commands, tasks

from core import Coalition, Plugin, Server, Status, command, utils
from services.bot import DCSServerBot

from . import scores as sc
from .listener import BlueSkyEventListener

PARIS = ZoneInfo('Europe/Paris')
DEFAULTS = {
    'scores_file': 'Scores.lua',   # relatif au dossier Saved Games de l'instance DCS
    'stats_interval': 60,          # s entre deux lectures de Scores.lua
    'live_interval': 30,           # s entre deux relevés de positions (0 = carte live coupée)
    'discord_interval': 15,        # min entre deux envois de l'activité Discord / du planning
    'feed_channel': -1,            # salon Discord du fil DCS (promotions, bilans), -1 = coupé
    'announce_events_ingame': True,
    'site_url': 'https://thibaero278.github.io/blue-sky-france/',
    'discord_invite': 'https://discord.gg/zVEsRbm8h2',
    'relay': {'url': '', 'token': ''},
    'export_dir': '',
}
METRICS = {
    'points': 'Points', 'totalFlightTime': 'Heures de vol', 'airair': 'Kills air-air', 'airsol': 'Kills air-sol',
    'airmer': 'Kills air-mer', 'traps': 'Appontages', 'refuelTime': 'Ravitaillement',
}


class BlueSky(Plugin[BlueSkyEventListener]):
    """Pivot DCS ↔ Discord ↔ site."""

    def __init__(self, bot: DCSServerBot, listener):
        super().__init__(bot, listener)
        self._session: aiohttp.ClientSession | None = None
        self._last: dict[str, dict] = {}       # dernier Scores.lua lu, par serveur
        self._mtime: dict[str, datetime] = {}
        self._live_ok: dict[str, bool] = {}

    # ---------- réglages ----------
    def cfg(self, server: Server | None = None) -> dict:
        return utils.deep_merge(DEFAULTS, self.get_config(server) or {})

    def scores_path(self, server: Server) -> str:
        path = os.path.expandvars(self.cfg(server)['scores_file'])
        return path if os.path.isabs(path) else os.path.join(server.instance.home, path)

    def local_servers(self) -> list[Server]:
        return [s for s in self.bus.servers.values() if not s.is_remote]

    def scores_of(self, server: Server) -> dict[str, dict]:
        if server.name not in self._last:
            self._last[server.name] = sc.read_scores(self.scores_path(server)) or {}
        return self._last[server.name]

    def all_scores(self) -> dict[str, dict]:
        out = {}
        for server in self.local_servers():
            out |= self.scores_of(server)
        return out

    async def cog_load(self) -> None:
        await super().cog_load()
        self._session = aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=30))
        self.stats_loop.change_interval(seconds=max(10, int(self.cfg()['stats_interval'])))
        self.discord_loop.change_interval(minutes=max(1, int(self.cfg()['discord_interval'])))
        self.stats_loop.start()
        self.discord_loop.start()
        if int(self.cfg()['live_interval']) > 0:
            self.live_loop.change_interval(seconds=max(5, int(self.cfg()['live_interval'])))
            self.live_loop.start()

    async def cog_unload(self) -> None:
        self.stats_loop.cancel()
        self.live_loop.cancel()
        self.discord_loop.cancel()
        if self._session:
            await self._session.close()
        await super().cog_unload()

    # ---------- envoi vers le site ----------
    async def publish(self, kind: str, data: dict) -> None:
        """kind = stats | live | discord. Relais Apps Script et/ou fichier <export_dir>/<kind>.json."""
        cfg = self.cfg()
        export_dir = os.path.expandvars(cfg['export_dir'] or '')
        if export_dir:
            os.makedirs(export_dir, exist_ok=True)
            path = os.path.join(export_dir, f'{kind}.json')
            with open(path + '.tmp', 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=1, default=str)
            os.replace(path + '.tmp', path)
        relay = cfg['relay']
        if relay.get('url') and relay.get('token'):
            body = {'token': relay['token'], 'type': kind, **data}
            try:
                async with self._session.post(relay['url'], json=body) as r:
                    answer = (await r.text()).strip()
                    if r.status != 200 or answer != 'ok':
                        self.log.warning(f'BlueSky: relais {kind} → HTTP {r.status} « {answer[:80]} »')
            except (aiohttp.ClientError, asyncio.TimeoutError) as ex:
                self.log.warning(f'BlueSky: relais {kind} injoignable ({ex!r})')

    # ---------- DCS → site + Discord : Scores.lua ----------
    @tasks.loop(seconds=60)
    async def stats_loop(self):
        for server in self.local_servers():
            try:
                await self.check_scores(server)
            except Exception as ex:
                self.log.exception(ex)

    @stats_loop.before_loop
    async def before_stats(self):
        await self.bot.wait_until_ready()

    async def check_scores(self, server: Server, force: bool = False) -> None:
        path = self.scores_path(server)
        mt = sc.mtime(path)
        if mt is None or (not force and self._mtime.get(server.name) == mt):
            return
        new = sc.read_scores(path)
        if new is None:
            return
        old = self._last.get(server.name)
        self._last[server.name], self._mtime[server.name] = new, mt
        if old:  # pas de fil au premier chargement (sinon tout le monde serait « nouveau »)
            await self.post_feed(server, old, new)
        await self.publish_stats(server)

    async def publish_stats(self, server: Server) -> None:
        pilots = [{'name': n, **p} for n, p in self.scores_of(server).items()]
        mission = server.current_mission
        await self.publish('stats', {
            'source': 'bot', 'updated': datetime.now(timezone.utc).isoformat(),
            'server': server.display_name, 'mission': mission.name if mission else '',
            'map': mission.map if mission else '',
            'online': [{'name': p.name, 'side': p.side.value} for p in server.get_active_players()],
            'pilots': pilots,
        })

    async def post_feed(self, server: Server, old: dict, new: dict) -> None:
        channel = self.bot.get_channel(int(self.cfg(server)['feed_channel']))
        if not channel:
            return
        for name, p in new.items():
            o = old.get(name, {})
            gain = (p.get('points', 0) or 0) - (o.get('points', 0) or 0)
            new_flight = (p.get('flights', 0) or 0) > (o.get('flights', 0) or 0)
            new_death = (p.get('deaths', 0) or 0) > (o.get('deaths', 0) or 0)
            if gain <= 0 and not new_flight and not new_death:
                continue
            rank, nxt = sc.rank_for(p.get('points', 0))
            old_rank, _ = sc.rank_for(o.get('points', 0))
            if rank != old_rank:
                embed = discord.Embed(title='🎖️ PROMOTION', color=0xd9b45a,
                                      description=f'**{name}** est promu **{rank}** ({p.get("points", 0)} pts) !')
            elif new_death:
                embed = discord.Embed(title='💥 Vol perdu', color=0xd0342c,
                                      description=f'**{name}** n\'est pas rentré : kills du vol non validés.')
            else:
                lines = [f'+{gain} pts → **{p.get("points", 0)} pts** ({rank})'] if gain > 0 else []
                for key, one, many in (('airair', 'kill air-air', 'kills air-air'), ('airsol', 'kill air-sol', 'kills air-sol'),
                                       ('airmer', 'kill air-mer', 'kills air-mer'), ('traps', 'appontage', 'appontages')):
                    d = (p.get(key, 0) or 0) - (o.get(key, 0) or 0)
                    if d > 0:
                        lines.append(f'{d} {one if d == 1 else many}')
                if nxt:
                    lines.append(f'Prochain grade : {nxt[1]} à {nxt[0]} pts')
                embed = discord.Embed(title=f'✈️ Bilan de {name}', color=0x2a5ca8, description='\n'.join(lines))
            embed.set_footer(text=server.display_name)
            await channel.send(embed=embed)

    # ---------- DCS → site : carte live ----------
    @tasks.loop(seconds=30)
    async def live_loop(self):
        for server in self.local_servers():
            if server.status not in (Status.RUNNING, Status.PAUSED):
                if self._live_ok.pop(server.name, None):
                    await self.publish('live', {'server': server.display_name, 'time': None, 'players': []})
                continue
            try:
                data = await server.send_to_dcs_sync({'command': 'bsGetLive'}, timeout=10)
            except (asyncio.TimeoutError, TimeoutError):
                continue  # mission en cours de chargement, ou mission.lua pas encore chargé
            players = (data or {}).get('players') or []
            if isinstance(players, dict):  # table Lua vide → {} en JSON
                players = list(players.values())
            self._live_ok[server.name] = True
            await self.publish('live', {
                'server': server.display_name, 'time': datetime.now(timezone.utc).isoformat(),
                'missionTime': (data or {}).get('time'),  # secondes depuis minuit, heure de la mission
                'map': server.current_mission.map if server.current_mission else '', 'players': players,
            })

    @live_loop.before_loop
    async def before_live(self):
        await self.bot.wait_until_ready()

    # ---------- Discord → site : activité + planning ----------
    @commands.Cog.listener()
    async def on_message(self, message: discord.Message):
        if message.author.bot or not message.guild:
            return
        async with self.apool.connection() as conn:
            await conn.execute("""
                INSERT INTO bluesky_activity (day, messages) VALUES (%s, 1)
                ON CONFLICT (day) DO UPDATE SET messages = bluesky_activity.messages + 1
            """, (datetime.now(PARIS).date(),))

    @tasks.loop(minutes=15)
    async def discord_loop(self):
        try:
            await self.publish('discord', await self.discord_data())
        except Exception as ex:
            self.log.exception(ex)

    @discord_loop.before_loop
    async def before_discord(self):
        await self.bot.wait_until_ready()

    async def discord_data(self) -> dict:
        guild = self.bot.guilds[0]
        now = datetime.now(timezone.utc)
        counted = await self.bot.fetch_guild(guild.id, with_counts=True)
        async with self.apool.connection() as conn:
            await conn.execute('INSERT INTO bluesky_presence (time, online) VALUES (%s, %s) ON CONFLICT DO NOTHING',
                               (now, counted.approximate_presence_count or 0))
            await conn.execute("DELETE FROM bluesky_presence WHERE time < NOW() - INTERVAL '30 days'")
            cursor = await conn.execute('SELECT day, messages FROM bluesky_activity WHERE day > %s',
                                        (date.today() - timedelta(days=90),))
            per_day = {row[0]: row[1] for row in await cursor.fetchall()}
            cursor = await conn.execute("""
                SELECT EXTRACT(HOUR FROM time AT TIME ZONE 'Europe/Paris')::INTEGER, ROUND(AVG(online))::INTEGER
                FROM bluesky_presence WHERE time > NOW() - INTERVAL '14 days' GROUP BY 1
            """)
            per_hour = {row[0]: row[1] for row in await cursor.fetchall()}
        today = datetime.now(PARIS).date()
        days = [today - timedelta(days=89 - i) for i in range(90)]
        return {
            'updated': now.isoformat(),
            'members': counted.approximate_member_count, 'online': counted.approximate_presence_count,
            'activity': {
                'since': min(per_day).isoformat() if per_day else today.isoformat(),
                'days': [{'date': d.isoformat(), 'value': per_day.get(d, 0)} for d in days],
                'online24h': [{'hour': h, 'value': per_hour.get(h, 0)} for h in range(24)],
                'newMembers30d': sum(1 for m in guild.members if m.joined_at and m.joined_at > now - timedelta(days=30)),
            },
            'events': [self.event_json(e) for e in sorted(await guild.fetch_scheduled_events(with_counts=True),
                                                          key=lambda e: e.start_time)
                       if e.status in (discord.EventStatus.scheduled, discord.EventStatus.active)],
        }

    @staticmethod
    def event_json(e: discord.ScheduledEvent) -> dict:
        """Lignes optionnelles dans la description : « Type : Formation », « Carte : Caucase », « Places : 16 »."""
        desc = e.description or ''

        def field(*keys):
            m = re.search(r'^\s*(?:' + '|'.join(keys) + r')\s*:\s*(.+)$', desc, re.I | re.M)
            return m.group(1).strip() if m else None

        places = field('places', 'slots')
        return {
            'title': e.name, 'date': e.start_time.isoformat(), 'end': e.end_time.isoformat() if e.end_time else None,
            'type': field('type') or 'Événement', 'map': field('carte', 'map') or e.location or '',
            'host': e.creator.display_name if e.creator else '', 'registered': e.user_count or 0,
            'slots': int(re.sub(r'\D', '', places)) if places and re.search(r'\d', places) else None,
            'url': e.url,
        }

    # ---------- Discord → DCS ----------
    async def popup_all(self, message: str, timeout: int = 20) -> int:
        n = 0
        for server in self.bus.servers.values():
            if server.status in (Status.RUNNING, Status.PAUSED):
                await server.sendPopupMessage(Coalition.ALL, message, timeout)
                n += 1
        return n

    @commands.Cog.listener()
    async def on_scheduled_event_create(self, event: discord.ScheduledEvent):
        if not self.cfg()['announce_events_ingame']:
            return
        when = event.start_time.astimezone(PARIS)
        await self.popup_all(f'DISCORD BLUE SKY - Nouvel evenement : {event.name}\n'
                             f'{when:%d/%m} a {when:%H:%M} - inscriptions sur le Discord')

    @command(description='Envoie un message à tous les joueurs du serveur DCS')
    @app_commands.guild_only()
    @utils.app_has_role('DCS Admin')
    async def annonce(self, interaction: discord.Interaction, message: str):
        n = await self.popup_all(f'{interaction.user.display_name} (Discord) :\n{message}', 30)
        # noinspection PyUnresolvedReferences
        await interaction.response.send_message(
            f'Annonce envoyée sur {n} serveur(s).' if n else 'Aucun serveur DCS en marche.', ephemeral=True)

    # ---------- DCS → Discord : commandes ----------
    async def pilot_autocomplete(self, _interaction: discord.Interaction, current: str) -> list[app_commands.Choice[str]]:
        low = current.lower()
        names = sorted(n for n in self.all_scores() if low in n.lower())
        return [app_commands.Choice(name=n[:100], value=n[:100]) for n in names[:25]]

    @command(description='Fiche d\'un pilote (Scores.lua du serveur DCS)')
    @app_commands.guild_only()
    @utils.app_has_role('DCS')
    @app_commands.autocomplete(pseudo=pilot_autocomplete)
    async def pilote(self, interaction: discord.Interaction, pseudo: str):
        found = sc.find_pilot(self.all_scores(), pseudo)
        if not found:
            # noinspection PyUnresolvedReferences
            await interaction.response.send_message(f'Aucun pilote « {pseudo} » dans les scores.', ephemeral=True)
            return
        name, p = found
        rank, nxt = sc.rank_for(p.get('points', 0))
        embed = discord.Embed(title=name, color=0x2a5ca8,
                              description=f'**{rank}** · {p.get("points", 0)} pts'
                                          + (f' · prochain grade {nxt[1]} à {nxt[0]} pts' if nxt else ''))
        rows = [
            ('Heures de vol', sc.hours(p.get('totalFlightTime', p.get('maxFlightTime', 0)))),
            ('Heures complètes', sc.hours(p.get('completedFlightTime', 0))),
            ('Vol le plus long', sc.hours(p.get('maxFlightTime', 0))), ('Vols', p.get('flights', 0)),
            ('Kills A/A', p.get('airair', 0)), ('Kills A/S', p.get('airsol', 0)), ('Kills A/M', p.get('airmer', 0)),
            ('Appontages', p.get('traps', 0)), ('Morts', p.get('deaths', 0)),
            ('Ravitaillement', sc.hours(p.get('refuelTime', 0))),
        ]
        for label, value in rows:
            embed.add_field(name=label, value=str(value))
        embed.set_footer(text='Classement complet : ' + self.cfg()['site_url'] + 'classements.html')
        # noinspection PyUnresolvedReferences
        await interaction.response.send_message(embed=embed)

    @command(description='Top 10 du serveur DCS')
    @app_commands.guild_only()
    @utils.app_has_role('DCS')
    @app_commands.choices(critere=[app_commands.Choice(name=v, value=k) for k, v in METRICS.items()])
    async def classement(self, interaction: discord.Interaction, critere: str = 'points'):
        ranked = sorted(self.all_scores().items(), key=lambda kv: kv[1].get(critere, 0) or 0, reverse=True)[:10]
        time_metric = critere in ('totalFlightTime', 'refuelTime')
        lines = [f'`{i:>2}.` **{n}** — ' + (sc.hours(p.get(critere, 0)) if time_metric else str(p.get(critere, 0)))
                 for i, (n, p) in enumerate(ranked, 1)]
        embed = discord.Embed(title=f'Top 10 · {METRICS.get(critere, critere)}', color=0x2a5ca8,
                              description='\n'.join(lines) or 'Aucun score pour l\'instant.')
        embed.set_footer(text=self.cfg()['site_url'] + 'classements.html')
        # noinspection PyUnresolvedReferences
        await interaction.response.send_message(embed=embed)

    @command(description='Qui vole en ce moment sur le serveur DCS ?')
    @app_commands.guild_only()
    @utils.app_has_role('DCS')
    async def enligne(self, interaction: discord.Interaction):
        lines = []
        for server in self.bus.servers.values():
            players = server.get_active_players()
            mission = server.current_mission.name if server.current_mission else 'pas de mission'
            lines.append(f'**{server.display_name}** — {mission} — {len(players)} joueur(s)')
            lines += [f'• {p.name} ({p.unit_type})' for p in players]
        # noinspection PyUnresolvedReferences
        await interaction.response.send_message('\n'.join(lines) or 'Aucun serveur DCS.')


async def setup(bot: DCSServerBot) -> None:
    """Enregistre le plugin et son écouteur d'événements DCS."""

    await bot.add_cog(BlueSky(bot, BlueSkyEventListener))
