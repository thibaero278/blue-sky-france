"""Plugin Blue Sky : le bot fait circuler les infos entre le serveur DCS, Discord et le site web.

    DCS ──(Scores.lua, positions)──▶ bot ──▶ site (stats, carte live, joueurs en ligne)
     ▲                                │  └──▶ Discord (promotions, bilans de vol, /pilote, /classement)
     └──(annonces, événements)────────┘
    Discord ──(activité, temps en vocal, événements planifiés)──▶ bot ──▶ site (page Discord, planning)
    #missions-dcs ──(clic droit « Publier sur le site »)──▶ bot ──▶ sondage dans #inscriptions + page mission du site

Réglages : config/dcssb/plugins/bluesky.yaml (modèle : config/templates/plugins/bluesky.yaml.template).
Le site est statique (GitHub Pages) : le bot pousse ses données vers le relais Apps Script
(circuit_site/Code.gs) et/ou les écrit en JSON dans un dossier (export_dir).
"""

import asyncio
import json
import math
import os
import re
from datetime import date, datetime, time as dtime, timedelta, timezone
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
    # Rôles Discord affichés dans « L'équipe » du site (noms ou IDs, du plus haut au plus bas).
    # Vide = automatique : rôles affichés à part dans la liste des membres, avec droits de modération.
    'staff_roles': [],
    'mission_channel': 1419768783282896987,   # salon des briefings (#missions-dcs), -1 = n'importe quel salon
    'signup_channel': 1562459201618452540,    # salon où le bot poste le sondage d'inscription
    'publish_role': 'DCS Admin',              # rôle (de main.yaml) qui peut publier une mission
    'voice_stats': True,                      # temps passé en vocal (total par jour, sans nom) pour le site
    # Commandes slash des autres plugins à masquer (« groupe » ou « groupe sous-commande »).
    # Les plugins restent chargés : mission, monitoring… en ont besoin.
    'hide_commands': [
        # mission : la mission se gère en jeu ; on garde la modération (/player, /watch, /link, /find, /info, /linkme)
        'mission', 'airbase', 'warehouse', 'group', 'menu', 'convert', 'linkcheck', 'mislinks',
        # scheduler : l'ouverture du serveur se fait à la main
        'server', 'scheduler',
        # admin : DCS se met à jour lui-même ; on garde /dcs ban, /dcs unban, /dcs bans
        'dcs update', 'dcs repair', 'dcs install', 'dcs uninstall', 'dcs info', 'download', 'prune',
        'node', 'plugin', 'extension',
        # userstats / missionstats : doublons de /pilote et /classement
        'statistics', 'highscore', 'reset_statistics', 'delete_statistics', 'squadron',
        'missionstats', 'sorties', 'refuelings', 'nemesis', 'antagonist',
        # gamemaster : /annonce suffit
        'chat', 'popup', 'broadcast', 'flag', 'variable', 'do_script', 'do_script_file',
        'reset_coalition', 'reset_coalitions', 'campaign', 'message',
    ],
    # Commandes du chat en jeu à couper (restent : -ban -kick -spec -mute -unmute -linkme -911 et les nôtres)
    'hide_chat_commands': ['pause', 'unpause', 'atis', 'restart', 'list', 'load', 'preset',
                           'maintenance', 'clear', 'timeleft', 'coalition', 'password', 'flag', 'ack', 'popup'],
}
POLL_ANSWERS = (('yes', 'Présent', '✅'), ('maybe', 'Peut-être', '❔'), ('no', 'Absent', '❌'))
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
        self._voice: dict[int, datetime] = {}  # membre en vocal → depuis quand (temps pas encore compté)
        self._publish_menu = app_commands.ContextMenu(name='Publier sur le site', callback=self.publish_mission)
        self.bot.tree.add_command(self._publish_menu)

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
        self.bot.tree.remove_command(self._publish_menu.name, type=self._publish_menu.type)
        self.stats_loop.cancel()
        self.live_loop.cancel()
        self.discord_loop.cancel()
        try:
            await self.flush_voice()
        except Exception as ex:
            self.log.warning(f'BlueSky: temps vocal non enregistré à l\'arrêt ({ex!r})')
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
                'mission': server.current_mission.name if server.current_mission else '',
                # tous les connectés (même sans avion), pour « Serveur · N en ligne » sur le site
                'online': [p.name for p in server.get_active_players()],
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
        await self.push_discord()

    async def push_discord(self) -> None:
        try:
            await self.flush_voice()
            data, missions = await self.discord_data()
            await self.publish('discord', data)
            await self.publish('missions', {'missions': missions})
        except Exception as ex:
            self.log.exception(ex)

    @discord_loop.before_loop
    async def before_discord(self):
        await self.bot.wait_until_ready()
        self.scan_voice()

    # ---------- Discord → site : temps en vocal (total par jour, aucun nom gardé) ----------
    @staticmethod
    def in_voice(state: discord.VoiceState) -> bool:
        """Compté : dans un salon vocal autre que l'AFK, casque non coupé."""
        return bool(state.channel) and state.channel != state.channel.guild.afk_channel \
            and not (state.self_deaf or state.deaf)

    def scan_voice(self) -> None:
        """Au démarrage : ceux qui sont déjà en vocal."""
        if not self.cfg()['voice_stats'] or not self.bot.guilds:
            return
        now = datetime.now(timezone.utc)
        guild = self.bot.guilds[0]
        for channel in [*guild.voice_channels, *guild.stage_channels]:
            for m in channel.members:
                if not m.bot and m.voice and self.in_voice(m.voice):
                    self._voice.setdefault(m.id, now)

    @commands.Cog.listener()
    async def on_voice_state_update(self, member: discord.Member, before: discord.VoiceState,
                                    after: discord.VoiceState):
        if member.bot or not self.cfg()['voice_stats'] or member.guild != self.bot.guilds[0]:
            return
        was_in, is_in = self.in_voice(before), self.in_voice(after)
        if was_in and not is_in:
            await self.flush_voice(member.id)
        elif is_in and not was_in:
            self._voice[member.id] = datetime.now(timezone.utc)

    async def flush_voice(self, leaving: int | None = None) -> None:
        """Ajoute en base le temps passé depuis le dernier relevé, coupé par jour (heure de Paris).
        leaving = membre qui quitte le vocal ; sinon tous ceux en vocal (relevé périodique)."""
        now = datetime.now(timezone.utc)
        per_day: dict[date, float] = {}
        for uid in ([leaving] if leaving is not None else list(self._voice)):
            start = self._voice.pop(uid, None)
            if start is None:
                continue
            if leaving is None:
                self._voice[uid] = now
            t, end = start.astimezone(PARIS), now.astimezone(PARIS)
            while t < end:
                cut = min(end, datetime.combine(t.date() + timedelta(days=1), dtime(0), PARIS))
                per_day[t.date()] = per_day.get(t.date(), 0) + (cut - t).total_seconds()
                t = cut
        if not per_day:
            return
        async with self.apool.connection() as conn:
            for day, seconds in per_day.items():
                await conn.execute("""
                    INSERT INTO bluesky_voice (day, seconds) VALUES (%s, %s)
                    ON CONFLICT (day) DO UPDATE SET seconds = bluesky_voice.seconds + EXCLUDED.seconds
                """, (day, int(seconds)))

    async def discord_data(self) -> tuple[dict, list[dict]]:
        """(données de la page Discord, missions publiées pour mission.html)."""
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
            cursor = await conn.execute('SELECT day, seconds FROM bluesky_voice WHERE day > %s',
                                        (date.today() - timedelta(days=90),))
            voice = {row[0]: row[1] for row in await cursor.fetchall()}
            await conn.execute("DELETE FROM bluesky_missions WHERE start_time < NOW() - INTERVAL '7 days'")
            cursor = await conn.execute('SELECT event_id, channel_id, message_id, poll_channel_id, poll_message_id '
                                        'FROM bluesky_missions')
            linked = {row[0]: row[1:] for row in await cursor.fetchall()}
        today = datetime.now(PARIS).date()
        days = [today - timedelta(days=89 - i) for i in range(90)]
        events, missions = [], []
        for e in sorted(await guild.fetch_scheduled_events(with_counts=True), key=lambda e: e.start_time):
            if e.status not in (discord.EventStatus.scheduled, discord.EventStatus.active):
                continue
            ev = self.event_json(e)
            if e.id in linked:
                await self.add_mission(guild, e, ev, linked[e.id], missions)
            events.append(ev)
        return {
            'updated': now.isoformat(),
            'members': counted.approximate_member_count, 'online': counted.approximate_presence_count,
            'activity': {
                'since': min(per_day).isoformat() if per_day else today.isoformat(),
                'days': [{'date': d.isoformat(), 'value': per_day.get(d, 0)} for d in days],
                'online24h': [{'hour': h, 'value': per_hour.get(h, 0)} for h in range(24)],
                'newMembers30d': sum(1 for m in guild.members if m.joined_at and m.joined_at > now - timedelta(days=30)),
                # minutes passées en vocal par jour, tous membres confondus, mêmes jours que « days »
                # (simple liste de nombres : le relais limite le tout à 9 ko)
                # dès que le comptage est actif (même à 0) : le site affiche les vraies valeurs, pas la démo
                'voiceSince': (min(voice) if voice else today).isoformat() if self.cfg()['voice_stats'] else None,
                'voice': [round(voice.get(d, 0) / 60) for d in days] if self.cfg()['voice_stats'] else None,
            },
            'events': events,
            'signupChannel': self.channel_url(guild, self.cfg()['signup_channel']),
            'staff': self.staff_json(guild),
        }, missions

    @staticmethod
    def channel_url(guild: discord.Guild, channel_id) -> str | None:
        return f'https://discord.com/channels/{guild.id}/{int(channel_id)}' if int(channel_id or -1) > 0 else None

    async def fetch_message(self, channel_id: int, message_id: int) -> discord.Message | None:
        channel = self.bot.get_channel(channel_id)
        if not channel:
            return None
        try:
            return await channel.fetch_message(message_id)
        except (discord.NotFound, discord.Forbidden):
            return None

    async def add_mission(self, guild: discord.Guild, e: discord.ScheduledEvent, ev: dict, row: tuple,
                          missions: list[dict]) -> None:
        """Complète l'événement (inscrits du sondage) et ajoute sa mission (message de #missions-dcs)."""
        channel_id, message_id, poll_channel_id, poll_message_id = row
        poll_msg = await self.fetch_message(poll_channel_id, poll_message_id) if poll_message_id else None
        if poll_msg and poll_msg.poll:
            ev['signupUrl'] = poll_msg.jump_url
            signups = {}
            for answer, (key, _, _) in zip(poll_msg.poll.answers, POLL_ANSWERS):
                if key == 'no':  # absents : seulement le nombre, pas de noms sur le site
                    signups[key] = answer.vote_count
                    continue
                names = []
                async for user in answer.voters():
                    member = guild.get_member(user.id)
                    names.append((member or user).display_name)
                signups[key] = names
            ev['signups'] = signups
            ev['registered'] = len(signups.get('yes', []))
        msg = await self.fetch_message(channel_id, message_id)
        if not msg:
            return
        ev['mission'] = True
        missions.append({
            'id': ev['id'], 'title': e.name, 'date': ev['date'], 'type': ev['type'], 'map': ev['map'],
            'author': msg.author.display_name, 'text': msg.clean_content,
            # liens Discord valables ~24 h : le bot les renouvelle à chaque envoi
            'images': [{'url': a.url, 'width': a.width, 'height': a.height, 'name': a.filename}
                       for a in msg.attachments if (a.content_type or '').startswith('image/')],
            'messageUrl': msg.jump_url, 'signupUrl': ev.get('signupUrl'),
            'updated': datetime.now(timezone.utc).isoformat(),
        })

    # ---------- #missions-dcs → site : clic droit sur le briefing > Applications > Publier sur le site ----------
    def can_publish(self, interaction: discord.Interaction) -> bool:
        if not self.bot.node.locals.get('restrict_owner', False) and interaction.user.id == self.bot.owner_id:
            return True
        # propriétaire du serveur Discord et administrateurs : toujours autorisés
        user = interaction.user
        if interaction.guild and (user.id == interaction.guild.owner_id
                                  or (isinstance(user, discord.Member) and user.guild_permissions.administrator)):
            return True
        role = self.cfg()['publish_role']
        return utils.check_roles(self.bot.roles.get(role, [role]), interaction.user)

    async def publish_mission(self, interaction: discord.Interaction, message: discord.Message):
        cfg = self.cfg()
        # Discord veut une réponse en moins de 3 s : on la réserve tout de suite, la suite part en « followup »
        # noinspection PyUnresolvedReferences
        await interaction.response.defer(ephemeral=True, thinking=True)
        reply = interaction.followup.send
        if not self.can_publish(interaction):
            await reply('Réservé au staff (rôle DCS Admin de bot.yaml, ou administrateur du serveur).', ephemeral=True)
            return
        if int(cfg['mission_channel']) > 0 and message.channel.id != int(cfg['mission_channel']):
            await reply(f'Les missions se publient depuis <#{int(cfg["mission_channel"])}>.', ephemeral=True)
            return
        now = datetime.now(timezone.utc)
        upcoming = sorted((e for e in await interaction.guild.fetch_scheduled_events()
                           if e.status in (discord.EventStatus.scheduled, discord.EventStatus.active)
                           and (e.end_time or e.start_time + timedelta(hours=3)) > now),
                          key=lambda e: e.start_time)[:25]
        if not upcoming:
            await reply('Aucun événement Discord à venir : crée d\'abord l\'événement, puis recommence.', ephemeral=True)
            return
        await reply('À quel événement correspond cette mission ?', view=EventPicker(self, message, upcoming),
                    ephemeral=True)

    async def link_mission(self, interaction: discord.Interaction, message: discord.Message,
                           event: discord.ScheduledEvent) -> None:
        """Lie le briefing à l'événement et poste le sondage d'inscription (un seul par événement)."""
        async with self.apool.connection() as conn:
            cursor = await conn.execute('SELECT poll_channel_id, poll_message_id FROM bluesky_missions '
                                        'WHERE event_id = %s', (event.id,))
            row = await cursor.fetchone()
        poll_msg = await self.fetch_message(*row) if row and row[1] else None
        if not poll_msg:
            channel = self.bot.get_channel(int(self.cfg()['signup_channel']))
            if not channel:
                await interaction.followup.send('Salon d\'inscription introuvable (signup_channel dans bluesky.yaml).',
                                                ephemeral=True)
                return
            # le sondage se ferme à l'heure de l'événement (Discord : 1 h à 32 jours, en heures entières)
            hours = max(1, min(768, math.ceil((event.start_time - datetime.now(timezone.utc)).total_seconds() / 3600)))
            poll = discord.Poll(question=f'Tu participes à « {event.name} » ?'[:300], duration=timedelta(hours=hours))
            for _, label, emoji in POLL_ANSWERS:
                poll.add_answer(text=label, emoji=emoji)
            ts = int(event.start_time.timestamp())
            poll_msg = await channel.send(
                f'## 📋 Inscriptions : {event.name}\n🗓️ <t:{ts}:F> (<t:{ts}:R>)\n'
                f'📄 Briefing : {message.jump_url}\n🌐 Sur le site : {self.cfg()["site_url"]}evenements.html',
                poll=poll)
        async with self.apool.connection() as conn:
            await conn.execute("""
                INSERT INTO bluesky_missions (event_id, channel_id, message_id, poll_channel_id, poll_message_id, start_time)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (event_id) DO UPDATE SET channel_id = EXCLUDED.channel_id, message_id = EXCLUDED.message_id,
                    poll_channel_id = EXCLUDED.poll_channel_id, poll_message_id = EXCLUDED.poll_message_id,
                    start_time = EXCLUDED.start_time
            """, (event.id, message.channel.id, message.id, poll_msg.channel.id, poll_msg.id, event.start_time))
        await interaction.followup.send(f'✅ Mission liée à **{event.name}**. Sondage : {poll_msg.jump_url}\n'
                                        f'Le site se met à jour d\'ici une minute.', ephemeral=True)
        asyncio.create_task(self.push_discord())

    def staff_json(self, guild: discord.Guild) -> list[dict]:
        """Équipe du serveur Discord : [{name, role, color}], chaque membre une fois, sous son rôle le plus haut."""
        wanted = [str(r).strip().lower() for r in self.cfg()['staff_roles'] or []]
        if wanted:
            roles = [r for r in guild.roles if r.name.lower() in wanted or str(r.id) in wanted]
        else:
            p = discord.Permissions
            mod = p(administrator=True).value | p(manage_guild=True).value | p(manage_messages=True).value \
                | p(kick_members=True).value | p(moderate_members=True).value
            roles = [r for r in guild.roles if r.hoist and not r.managed and not r.is_default() and r.permissions.value & mod]
        out, seen = [], set()
        for role in sorted(roles, key=lambda r: -r.position):
            for m in sorted(role.members, key=lambda m: m.display_name.lower()):
                if m.bot or m.id in seen:
                    continue
                seen.add(m.id)
                out.append({'name': m.display_name, 'role': role.name,
                            'color': f'#{role.color.value:06x}' if role.color.value else None})
        return out[:20]

    @staticmethod
    def event_json(e: discord.ScheduledEvent) -> dict:
        """Lignes optionnelles dans la description : « Type : Formation », « Carte : Caucase », « Places : 16 »."""
        desc = e.description or ''

        def field(*keys):
            m = re.search(r'^\s*(?:' + '|'.join(keys) + r')\s*:\s*(.+)$', desc, re.I | re.M)
            return m.group(1).strip() if m else None

        places = field('places', 'slots')
        # lieu = lien (salon Discord, site…) → bouton à part sur le site, pas affiché comme carte
        location = (e.location or '').strip()
        link = location if re.match(r'https?://', location, re.I) else None
        return {
            'id': str(e.id),  # en texte : trop grand pour un nombre JavaScript
            'title': e.name, 'date': e.start_time.isoformat(), 'end': e.end_time.isoformat() if e.end_time else None,
            'type': field('type') or 'Événement', 'map': field('carte', 'map') or ('' if link else location),
            'link': link,
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


class EventPicker(discord.ui.View):
    """Liste des événements à venir, visible seulement par celui qui publie."""

    def __init__(self, plugin: BlueSky, message: discord.Message, events: list[discord.ScheduledEvent]):
        super().__init__(timeout=300)
        self.plugin, self.message = plugin, message
        self.events = {str(e.id): e for e in events}
        select = discord.ui.Select(placeholder='Choisis l\'événement', options=[
            discord.SelectOption(label=e.name[:100], value=str(e.id),
                                 description=e.start_time.astimezone(PARIS).strftime('%d/%m/%Y à %H:%M'))
            for e in events])
        select.callback = self.chosen
        self.add_item(select)

    async def chosen(self, interaction: discord.Interaction):
        event = self.events[interaction.data['values'][0]]
        # noinspection PyUnresolvedReferences
        await interaction.response.edit_message(content=f'Publication de la mission pour **{event.name}**…', view=None)
        await self.plugin.link_mission(interaction, self.message, event)
        self.stop()


def hide_commands(bot: DCSServerBot, cfg: dict) -> None:
    """Retire les commandes des autres plugins listées dans hide_commands / hide_chat_commands.
    Appelé avant leur enregistrement sur Discord : bluesky (opt_plugins) est chargé après les plugins de base."""
    for name in cfg['hide_commands'] or []:
        top, *sub = str(name).split()
        cmd = bot.tree.get_command(top)
        if cmd is None:
            continue
        if not sub:
            bot.tree.remove_command(top)
        elif isinstance(cmd, app_commands.Group):
            cmd.remove_command(sub[0])
    hidden = {str(n) for n in cfg['hide_chat_commands'] or []}
    for cog in bot.cogs.values():
        listener = getattr(cog, 'eventlistener', None)
        for cmd in (getattr(listener, '__chat_commands__', None) or {}).values():
            if cmd.name in hidden:
                cmd.enabled = False


async def setup(bot: DCSServerBot) -> None:
    """Enregistre le plugin et son écouteur d'événements DCS, puis masque les commandes inutiles."""

    plugin = BlueSky(bot, BlueSkyEventListener)
    await bot.add_cog(plugin)
    hide_commands(bot, plugin.cfg())
