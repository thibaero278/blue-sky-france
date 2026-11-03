"""Plugin Blue Sky : le bot fait circuler les infos entre le serveur DCS, Discord et le site web.

    DCS ──(Scores.lua, positions)──▶ bot ──▶ site (stats, carte live, joueurs en ligne)
     ▲     (Scores.lua de chaque serveur fusionnés dans la base de R2D2, total renvoyé à chaque mission)
     ▲                                │  └──▶ Discord (promotions, /pilote, /classement)
     └──(annonces, événements)────────┘
    Discord ──(activité, temps en vocal, événements planifiés)──▶ bot ──▶ site (page Discord, planning)
    #missions-dcs ──(clic droit « Publier sur le site »)──▶ bot ──▶ sondage dans #inscriptions + page mission du site

Réglages : config/dcssb/plugins/bluesky.yaml (modèle : config/templates/plugins/bluesky.yaml.template).
Le site est statique (GitHub Pages) : le bot pousse ses données vers le relais Apps Script
(circuit_site/Code.gs).
"""

import asyncio
import copy
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
from psycopg.types.json import Json

from core import Coalition, Plugin, Server, Status, command, utils
from services.bot import DCSServerBot

from . import scores as sc
from .listener import BlueSkyEventListener

PARIS = ZoneInfo('Europe/Paris')
DEFAULTS = {
    'scores_file': 'Scores.lua',   # relatif au dossier Saved Games de l'instance DCS
    'stats_interval': 60,          # s entre deux lectures de Scores.lua
    'live_interval': 30,           # s entre deux relevés de positions (0 = carte live coupée)
    'live_idle_interval': 120,     # s entre deux envois quand personne n'est connecté (le site passe « hors ligne » après 3 min)
    'discord_interval': 15,        # min entre deux envois de l'activité Discord / du planning
    'feed_channel': -1,            # salon Discord du fil DCS (promotions), -1 = coupé
    'announce_events_ingame': True,
    'site_url': 'https://thibaero278.github.io/blue-sky-france/',
    'discord_invite': 'https://discord.gg/zVEsRbm8h2',
    'relay': {'url': '', 'token': ''},
    # Rôles Discord affichés dans « L'équipe » du site (noms ou IDs, du plus haut au plus bas).
    # Vide = automatique : rôles affichés à part dans la liste des membres, avec droits de modération.
    'staff_roles': [],
    'mission_channel': 1419768783282896987,   # salon des briefings (#missions-dcs), -1 = n'importe quel salon
    'signup_channel': 1562459201618452540,    # salon où le bot poste le sondage d'inscription
    'publish_role': 'DCS Admin',              # rôle (de main.yaml) qui peut publier une mission
    'voice_stats': True,                      # temps passé en vocal (total par jour, sans nom) pour le site
    'voice_delay': 30,                        # s : après une entrée/sortie de vocal, envoi au site groupé (« En vocal maintenant »)
    'vote_delay': 1,                          # min : après un vote, envoi au site groupé (tous les votes de cette minute)
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
    'airmer': 'Kills air-mer', 'traps': 'Appontages', 'refuelTime': 'Ravitaillement', 'bsFlightTime': 'Heures Blue Sky',
}


class BlueSky(Plugin[BlueSkyEventListener]):
    """Pivot DCS ↔ Discord ↔ site."""

    def __init__(self, bot: DCSServerBot, listener):
        super().__init__(bot, listener)
        self._session: aiohttp.ClientSession | None = None
        # Scores fusionnés de tous les serveurs (table bluesky_scores) et dernier Scores.lua lu par serveur
        # (bluesky_scores_base) : ce qu'un serveur a gagné depuis sa dernière lecture s'ajoute au total.
        self._total: dict[str, dict] = {}
        self._base: dict[str, dict] = {}
        self._alias: dict[str, str] = {}  # pseudo → pseudo actuel du même UCID (tables players de DCSServerBot)
        self._hosts: dict[str, tuple[str, str]] = {}  # hôte déjà enregistré, par serveur : (ucid, pseudo)
        self._scores_loaded = asyncio.Event()
        self._scores_lock = asyncio.Lock()
        # total envoyé à un serveur, pas encore confirmé → (heure d'envoi, base d'avant) ; son fichier n'est pas lu en attendant
        self._push_pending: dict[str, tuple[datetime, dict | None]] = {}
        self._raw: dict[str, bytes] = {}       # contenu brut lu, pour ne retraiter que s'il change
        self._live_ok: dict[str, bool] = {}
        self._live_idle: dict[str, datetime] = {}  # dernier envoi « serveur vide », par serveur
        self._trails: dict[str, dict[str, list]] = {}  # trajectoires depuis le décollage, par serveur puis avion
        self._trails_sent: dict[str, datetime | None] = {}  # None = dernier envoi vide
        self._voice: dict[int, datetime] = {}  # membre en vocal → depuis quand (temps pas encore compté)
        self._voice_since: dict[int, datetime] = {}  # salon vocal occupé → depuis quand (page Discord du site)
        self._polls: set[int] = set()          # messages des sondages d'inscription (pour réagir aux votes)
        self._push_soon: asyncio.Task | None = None
        self._publish_menu = app_commands.ContextMenu(name='Publier sur le site', callback=self.publish_mission)
        self.bot.tree.add_command(self._publish_menu)
        self._choose_menu = app_commands.ContextMenu(name='Choisir les participants', callback=self.choose_players)
        self.bot.tree.add_command(self._choose_menu)

    # ---------- réglages ----------
    def cfg(self, server: Server | None = None) -> dict:
        return utils.deep_merge(DEFAULTS, self.get_config(server) or {})

    def scores_path(self, server: Server) -> str:
        path = os.path.expandvars(self.cfg(server)['scores_file'])
        return path if os.path.isabs(path) else os.path.join(server.instance.home, path)

    def all_servers(self) -> list[Server]:
        # aussi les serveurs des autres nœuds : le bot tourne sur R2D2, DCS sur le MSI
        return list(self.bus.servers.values())

    def scores_of(self, _server: Server) -> dict[str, dict]:
        # total de tous les serveurs, rempli par stats_loop (le fichier peut être sur un autre nœud)
        return self.all_scores()

    def all_scores(self) -> dict[str, dict]:
        # pseudos d'un même compte DCS regroupés ; self._total reste par pseudo (c'est lui qui est fusionné)
        return sc.group(self._total, self._alias)

    def pilot_scores(self, name: str) -> dict | None:
        return self.all_scores().get(self._alias.get(name, name))

    async def record_host(self, server: Server, ucid: str, name: str) -> None:
        """DCSServerBot ignore l'hôte (id 1), même en mémoire : son UCID arrive par l'événement bsHost
        (lua/commands.lua). On l'enregistre dans players avec la même requête que Player.prep, pour que ses
        pseudos soient aussi regroupés par UCID (players_hist suit ses changements)."""
        if not ucid or not name or self._hosts.get(server.name) == (ucid, name):
            return
        async with self.apool.connection() as conn:
            await conn.execute("""
                INSERT INTO players (ucid, discord_id, name, last_seen)
                VALUES (%s, -1, %s, (now() AT TIME ZONE 'utc'))
                ON CONFLICT (ucid) DO UPDATE SET name=excluded.name, last_seen=excluded.last_seen
            """, (ucid, name))
        self._hosts[server.name] = (ucid, name)
        await self.load_aliases()

    async def load_aliases(self) -> None:
        async with self.apool.connection() as conn:
            cursor = await conn.execute('SELECT p.ucid, p.name, h.name FROM players p '
                                        'LEFT JOIN players_hist h ON h.ucid = p.ucid')
            self._alias = sc.aliases(await cursor.fetchall())

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
        self.bot.tree.remove_command(self._choose_menu.name, type=self._choose_menu.type)
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
        """kind = stats | live | discord | missions, envoyé au relais Apps Script."""
        relay = self.cfg()['relay']
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
        try:
            await self.load_aliases()
        except Exception as ex:
            self.log.warning(f'BlueSky: pseudos par UCID non relus ({ex!r})')
        for server in self.all_servers():
            try:
                await self.check_scores(server)
            except Exception as ex:
                self.log.exception(ex)

    @stats_loop.before_loop
    async def before_stats(self):
        await self.bot.wait_until_ready()
        async with self.apool.connection() as conn:
            cursor = await conn.execute('SELECT name, data FROM bluesky_scores')
            self._total = {name: data for name, data in await cursor.fetchall()}
            cursor = await conn.execute('SELECT server, data FROM bluesky_scores_base')
            self._base = {name: data for name, data in await cursor.fetchall()}
        await self.load_aliases()
        self._scores_loaded.set()

    async def check_scores(self, server: Server, force: bool = False) -> None:
        if server.status == Status.UNREGISTERED:
            return  # nœud du serveur arrêté : inutile d'attendre le délai de lecture
        await self._scores_loaded.wait()
        async with self._scores_lock:
            await self._check_scores(server, force)

    async def _check_scores(self, server: Server, force: bool) -> None:
        if server.name in self._push_pending:
            return  # le fichier va être remplacé par le total : le lire maintenant compterait deux fois
        try:
            raw = await server.node.read_file(self.scores_path(server))
        except (FileNotFoundError, OSError):
            return  # pas encore de Scores.lua
        except (asyncio.TimeoutError, TimeoutError):
            return  # nœud du serveur injoignable (MSI éteint) : on retentera
        if not isinstance(raw, bytes) or (not force and self._raw.get(server.name) == raw):
            return
        new = sc.parse_scores(raw)
        if new is None:
            return
        self._raw[server.name] = raw
        base = self._base.get(server.name)
        old, total = self._total, sc.merge(self._total, base or {}, new, first_read=base is None)
        await self.save_scores(server, new, {n: p for n, p in total.items() if old.get(n) != p})
        self._total = total
        # pas de fil au premier chargement ni à l'import d'un nouveau serveur (le maximum ferait de fausses promotions)
        if old and base is not None:
            await self.post_feed(server, sc.group(old, self._alias), self.all_scores())
        await self.publish_stats(server)

    async def save_scores(self, server: Server, base: dict[str, dict], changed: dict[str, dict]) -> None:
        async with self.apool.connection() as conn:
            async with conn.transaction():
                await conn.execute('INSERT INTO bluesky_scores_base (server, data) VALUES (%s, %s) '
                                   'ON CONFLICT (server) DO UPDATE SET data = EXCLUDED.data', (server.name, Json(base)))
                for name, data in changed.items():
                    await conn.execute('INSERT INTO bluesky_scores (name, data) VALUES (%s, %s) '
                                       'ON CONFLICT (name) DO UPDATE SET data = EXCLUDED.data', (name, Json(data)))
        self._base[server.name] = base

    async def push_scores(self, server: Server) -> None:
        """Envoie le total au script de mission (kneeboard, grades en jeu), qui remplace son Scores.lua."""
        await self.check_scores(server, force=True)  # ce que le serveur a gagné juste avant l'envoi
        async with self._scores_lock:
            if not self._total or server.name in self._push_pending:
                return
            # le fichier du serveur va devenir le total envoyé : c'est sa nouvelle base. Les pilotes supprimés
            # (dans la base, plus dans le total) y restent pour ne pas être recomptés si le fichier les garde encore.
            sent = sc.for_mission(self._total, self._alias)
            old_base = self._base.get(server.name)
            removed = [n for n in (old_base or {}) if n not in sent]
            self._push_pending[server.name] = (datetime.now(timezone.utc), old_base)
            await self.save_scores(server, {**copy.deepcopy(old_base or {}), **copy.deepcopy(sent)}, {})
            await server.send_to_dcs({'command': 'bsSetScores', 'scores': json.dumps(sent),
                                      'remove': json.dumps(removed)})

    async def cancel_push(self, server: Server) -> None:
        """Total jamais confirmé par la mission : le fichier n'a pas changé, on remet la base d'avant l'envoi."""
        async with self._scores_lock:
            sent = self._push_pending.pop(server.name, None)
            if not sent:
                return
            if sent[1] is not None:
                await self.save_scores(server, sent[1], {})
                return
            async with self.apool.connection() as conn:  # serveur jamais lu avant l'envoi
                await conn.execute('DELETE FROM bluesky_scores_base WHERE server = %s', (server.name,))
            self._base.pop(server.name, None)

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
        # seulement les promotions : un message par vol ou par mort spammerait le salon
        for name, p in new.items():
            o = old.get(name, {})
            rank, _ = sc.rank_for(p.get('points', 0))
            old_rank, _ = sc.rank_for(o.get('points', 0))
            if rank == old_rank or (p.get('points', 0) or 0) <= (o.get('points', 0) or 0):
                continue
            embed = discord.Embed(title='🎖️ PROMOTION', color=0xd9b45a,
                                  description=f'**{name}** est promu **{rank}** ({p.get("points", 0)} pts) !')
            embed.set_footer(text=server.display_name)
            await channel.send(embed=embed)

    # ---------- DCS → site : carte live ----------
    @tasks.loop(seconds=5)
    async def live_loop(self):
        for server in self.all_servers():
            if server.status not in (Status.RUNNING, Status.PAUSED):
                await self.cancel_push(server)  # mission finie sans confirmation : son fichier redevient lisible
                if self._live_ok.pop(server.name, None):
                    await self.publish('live', {'server': server.display_name, 'time': None, 'players': []})
                continue
            try:
                data = await server.send_to_dcs_sync({'command': 'bsGetLive'}, timeout=10)
            except (asyncio.TimeoutError, TimeoutError):
                continue  # mission en cours de chargement, ou mission.lua pas encore chargé
            # script de mission chargé sans le total : on lui envoie (une fois par mission, confirmé par scoresSynced)
            sent = self._push_pending.get(server.name)
            if (data or {}).get('scoresSynced'):
                self._push_pending.pop(server.name, None)
            elif sent and (datetime.now(timezone.utc) - sent[0]).total_seconds() > 60:
                await self.cancel_push(server)  # perdu en route : on renverra au prochain tour
            elif (data or {}).get('scoresReady') and not sent:
                await self.push_scores(server)
            players = (data or {}).get('players') or []
            if isinstance(players, dict):  # table Lua vide → {} en JSON
                players = list(players.values())
            ai = (data or {}).get('ai') or []
            if isinstance(ai, dict):
                ai = list(ai.values())
            online = [p.name for p in server.get_active_players()]
            await self.update_trails(server, players + ai)
            # serveur vide : un envoi toutes les live_idle_interval s suffit (économise le quota du relais)
            now = datetime.now(timezone.utc)
            if not players and not online:
                last = self._live_idle.get(server.name)
                if last and (now - last).total_seconds() < int(self.cfg(server)['live_idle_interval']):
                    continue
                self._live_idle[server.name] = now
            else:
                self._live_idle.pop(server.name, None)
            self._live_ok[server.name] = True
            await self.publish('live', {
                'server': server.display_name, 'time': now.isoformat(),
                'missionTime': (data or {}).get('time'),  # secondes depuis minuit, heure de la mission
                'map': server.current_mission.map if server.current_mission else '', 'players': players,
                'mission': server.current_mission.name if server.current_mission else '',
                # tous les connectés (même sans avion), pour « Serveur · N en ligne » sur le site
                'online': online,
                'ai': ai,  # IA en vol (ennemis sans nom ni fréquence, filtré côté DCS)
                'weather': (data or {}).get('weather'),
            })

    TRAIL_STEP_S = 15   # un point de trajectoire toutes les 15 s
    TRAIL_MAX = 150     # au-delà, on garde un point sur deux : tout le vol reste visible, en moins détaillé

    async def update_trails(self, server: Server, units: list[dict]) -> None:
        """Trajectoire de chaque avion depuis son décollage, gardée après l'atterrissage jusqu'au décollage suivant,
        envoyée au relais toutes les 30 s (?format=trails)."""
        trails = self._trails.setdefault(server.name, {})
        now = datetime.now(timezone.utc)
        seen = set()
        for u in units:
            key = u.get('id') or u.get('callsign')
            if not key or u.get('lat') is None:
                continue
            seen.add(key)
            if not u.get('air'):
                if key in trails:
                    trails[key]['landed'] = True  # posé : trajectoire gardée, le prochain décollage repart de zéro
                continue
            t = trails.get(key)
            if not t or t.get('landed'):
                t = trails[key] = {'at': None, 'pts': []}
            if t['at'] and (now - t['at']).total_seconds() < self.TRAIL_STEP_S:
                continue
            t['at'] = now
            t['pts'].append([round(u['lat'], 3), round(u['lon'], 3), round(u.get('alt') or 0)])  # altitude en ft : couleur du tracé
            if len(t['pts']) > self.TRAIL_MAX:
                t['pts'] = t['pts'][::2]
        for key in set(trails) - seen:
            del trails[key]
        last = self._trails_sent.get(server.name, 'jamais')
        if last is None and not trails:
            return  # rien en vol, déjà envoyé vide : on économise le quota du relais
        if isinstance(last, datetime) and (now - last).total_seconds() < 30:
            return
        self._trails_sent[server.name] = now if trails else None
        await self.publish('trails', {'server': server.display_name, 'time': now.isoformat(),
                                      'trails': {k: v['pts'] for k, v in trails.items()}})

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
            self.track_channel(channel, now)
            for m in channel.members:
                if not m.bot and m.voice and self.in_voice(m.voice):
                    self._voice.setdefault(m.id, now)

    @staticmethod
    def voice_members(channel) -> list[discord.Member]:
        return [m for m in channel.members if not m.bot]

    def track_channel(self, channel, now: datetime) -> None:
        """Salon occupé : on retient depuis quand ; vide (ou AFK) : on l'oublie."""
        if not channel:
            return
        if channel != channel.guild.afk_channel and self.voice_members(channel):
            self._voice_since.setdefault(channel.id, now)
        else:
            self._voice_since.pop(channel.id, None)

    def voice_live(self, guild: discord.Guild) -> list[dict]:
        """Vocaux en cours pour le site : nom du salon, nombre de connectés, depuis quand (aucun pseudo)."""
        now = datetime.now(timezone.utc)
        out = []
        for channel in [*guild.voice_channels, *guild.stage_channels]:
            count = len(self.voice_members(channel))
            if channel == guild.afk_channel or not count:
                continue
            out.append({'name': channel.name, 'count': count,
                        'since': self._voice_since.setdefault(channel.id, now).isoformat(),
                        'url': self.channel_url(guild, channel.id)})
        return sorted(out, key=lambda v: -v['count'])

    @commands.Cog.listener()
    async def on_voice_state_update(self, member: discord.Member, before: discord.VoiceState,
                                    after: discord.VoiceState):
        if member.bot or not self.cfg()['voice_stats'] or member.guild != self.bot.guilds[0]:
            return
        if before.channel != after.channel:
            now = datetime.now(timezone.utc)
            self.track_channel(before.channel, now)
            self.track_channel(after.channel, now)
            self.push_soon(int(self.cfg()['voice_delay']))
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
            await conn.execute('DELETE FROM bluesky_selected WHERE event_id NOT IN (SELECT event_id FROM bluesky_missions)')
            cursor = await conn.execute('SELECT event_id, channel_id, message_id, poll_channel_id, poll_message_id, slots, '
                                        'status_message_id FROM bluesky_missions')
            linked = {row[0]: row[1:] for row in await cursor.fetchall()}
            cursor = await conn.execute('SELECT event_id, user_id FROM bluesky_selected')
            selected: dict[int, set[int]] = {}
            for event_id, user_id in await cursor.fetchall():
                selected.setdefault(event_id, set()).add(user_id)
        self._polls = {row[3] for row in linked.values() if row[3]}
        today = datetime.now(PARIS).date()
        days = [today - timedelta(days=89 - i) for i in range(90)]
        events, missions = [], []
        for e in sorted(await guild.fetch_scheduled_events(with_counts=True), key=lambda e: e.start_time):
            if e.status not in (discord.EventStatus.scheduled, discord.EventStatus.active):
                continue
            ev = self.event_json(e)
            if e.id in linked:
                await self.add_mission(guild, e, ev, linked[e.id], selected.get(e.id, set()), missions)
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
            # vocaux en cours (page Discord) ; renvoyé ~30 s après chaque entrée/sortie (voice_delay)
            'voiceLive': self.voice_live(guild) if self.cfg()['voice_stats'] else None,
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

    async def poll_voters(self, guild: discord.Guild, poll_msg: discord.Message) -> dict[str, list]:
        """{yes: [membres], maybe: [membres], no: nombre} d'un sondage d'inscription."""
        out = {}
        for answer, (key, _, _) in zip(poll_msg.poll.answers, POLL_ANSWERS):
            if key == 'no':  # absents : seulement le nombre, pas de noms sur le site
                out[key] = answer.vote_count
                continue
            out[key] = [guild.get_member(u.id) or u async for u in answer.voters()]
        return out

    @staticmethod
    def split_yes(yes: list, slots: int | None, chosen: set[int]) -> tuple[list, list]:
        """(retenus, liste d'attente). Sans limite : tous les « Présent » sont retenus.
        Avec limite : retenus = ceux choisis par le staff (et toujours « Présent »), les autres attendent."""
        if not slots:
            return yes, []
        return [u for u in yes if u.id in chosen], [u for u in yes if u.id not in chosen]

    async def add_mission(self, guild: discord.Guild, e: discord.ScheduledEvent, ev: dict, row: tuple,
                          chosen: set[int], missions: list[dict]) -> None:
        """Complète l'événement (inscrits du sondage) et ajoute sa mission (message de #missions-dcs)."""
        channel_id, message_id, poll_channel_id, poll_message_id, slots, status_id = row
        if slots:  # places choisies à la publication (prioritaires sur « Places : » de la description)
            ev['slots'] = slots
        poll_msg = await self.fetch_message(poll_channel_id, poll_message_id) if poll_message_id else None
        if poll_msg and poll_msg.poll:
            ev['signupUrl'] = poll_msg.jump_url
            votes = await self.poll_voters(guild, poll_msg)
            kept, waiting = self.split_yes(votes['yes'], ev['slots'], chosen)
            ev['signups'] = {'yes': [u.display_name for u in kept], 'waiting': [u.display_name for u in waiting],
                             'maybe': [u.display_name for u in votes['maybe']], 'no': votes['no']}
            ev['registered'] = len(kept)
            if ev['slots']:
                await self.update_status(e, poll_msg, ev['slots'], kept, waiting, status_id)
        msg = await self.fetch_message(channel_id, message_id)
        if not msg:
            return
        ev['mission'] = True
        # liens Discord valables ~24 h : le bot les renouvelle à chaque envoi
        images = [{'url': a.url, 'width': a.width, 'height': a.height, 'name': a.filename}
                  for a in msg.attachments if (a.content_type or '').startswith('image/')]
        if not ev.get('image') and images:
            ev['image'] = images[0]['url']
        missions.append({
            'id': ev['id'], 'title': e.name, 'date': ev['date'], 'type': ev['type'], 'map': ev['map'],
            'author': msg.author.display_name, 'text': msg.clean_content,
            'images': images,
            'messageUrl': msg.jump_url, 'signupUrl': ev.get('signupUrl'),
            'updated': datetime.now(timezone.utc).isoformat(),
        })

    async def update_status(self, e: discord.ScheduledEvent, poll_msg: discord.Message, slots: int,
                            kept: list, waiting: list, status_id: int | None) -> None:
        """Message « participants / liste d'attente » sous le sondage (événement à places limitées).
        Créé au premier « Présent », modifié ensuite seulement s'il change. Noms sans notification."""
        if not status_id and not kept and not waiting:
            return
        names = lambda users: ', '.join(u.mention for u in users)
        content = (f'✈️ **Participants · {e.name}** ({len(kept)}/{slots})\n'
                   + (names(kept) if kept else '_Pas encore choisis par le staff._') + '\n'
                   + f'⏳ **Liste d\'attente** ({len(waiting)}) : ' + (names(waiting) if waiting else 'personne') + '\n'
                   + '-# Le staff choisit les participants parmi les ✅ Présent : clic droit sur le sondage '
                     '→ Applications → Choisir les participants.')
        quiet = discord.AllowedMentions.none()
        msg = await self.fetch_message(poll_msg.channel.id, status_id) if status_id else None
        if msg:
            if msg.content != content:
                await msg.edit(content=content, allowed_mentions=quiet)
            return
        msg = await poll_msg.reply(content, allowed_mentions=quiet, mention_author=False)
        async with self.apool.connection() as conn:
            await conn.execute('UPDATE bluesky_missions SET status_message_id = %s WHERE event_id = %s', (msg.id, e.id))

    # ---------- #inscription : clic droit sur le sondage > Applications > Choisir les participants ----------
    async def choose_players(self, interaction: discord.Interaction, message: discord.Message):
        # noinspection PyUnresolvedReferences
        await interaction.response.defer(ephemeral=True, thinking=True)
        reply = interaction.followup.send
        if not self.can_publish(interaction):
            await reply('Réservé au staff (rôle DCS Admin de bot.yaml, ou administrateur du serveur).', ephemeral=True)
            return
        async with self.apool.connection() as conn:
            cursor = await conn.execute('SELECT event_id, slots FROM bluesky_missions WHERE poll_message_id = %s',
                                        (message.id,))
            row = await cursor.fetchone()
            cursor = await conn.execute('SELECT user_id FROM bluesky_selected WHERE event_id = %s', (row[0] if row else 0,))
            chosen = {r[0] for r in await cursor.fetchall()}
        if not row or not message.poll:
            await reply('Fais le clic droit sur un **sondage d\'inscription** posté par le bot.', ephemeral=True)
            return
        event_id, slots = row
        try:
            event = await interaction.guild.fetch_scheduled_event(event_id)
        except discord.NotFound:
            await reply('L\'événement de ce sondage n\'existe plus.', ephemeral=True)
            return
        slots = slots or self.event_json(event)['slots']
        if not slots:
            await reply('Pas de limite de places pour cet événement : tous les ✅ Présent participent.', ephemeral=True)
            return
        yes = (await self.poll_voters(interaction.guild, message))['yes']
        if not yes:
            await reply('Personne n\'a encore voté ✅ Présent.', ephemeral=True)
            return
        await reply(f'**{event.name}** · {slots} places · {len(yes)} candidat(s). Coche les participants :',
                    view=PlayersPicker(self, event, message, slots, yes, chosen), ephemeral=True)

    async def save_players(self, interaction: discord.Interaction, event: discord.ScheduledEvent,
                           poll_msg: discord.Message, slots: int, ids: set[int]) -> None:
        async with self.apool.connection() as conn:
            await conn.execute('DELETE FROM bluesky_selected WHERE event_id = %s', (event.id,))
            for uid in ids:
                await conn.execute('INSERT INTO bluesky_selected (event_id, user_id) VALUES (%s, %s)', (event.id, uid))
            cursor = await conn.execute('SELECT status_message_id FROM bluesky_missions WHERE event_id = %s', (event.id,))
            status_id = (await cursor.fetchone() or [None])[0]
        yes = (await self.poll_voters(interaction.guild, poll_msg))['yes']
        kept, waiting = self.split_yes(yes, slots, ids)
        await self.update_status(event, poll_msg, slots, kept, waiting, status_id)
        await interaction.followup.send(f'✅ {len(kept)}/{slots} participant(s) retenu(s), {len(waiting)} en liste '
                                        f'd\'attente. Site à jour dans la minute.', ephemeral=True)
        self.push_soon(10)

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
                           event: discord.ScheduledEvent, slots: int | None = None) -> None:
        """Lie le briefing à l'événement et poste le sondage d'inscription (un seul par événement).
        slots = nombre de places (None = illimité)."""
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
                + (f'👥 Places : {slots} · le staff choisit parmi les ✅ Présent, les autres sont en liste d\'attente\n'
                   if slots else '👥 Places illimitées : tous les ✅ Présent participent\n')
                + f'📄 Briefing : {message.jump_url}\n🌐 Sur le site : {self.cfg()["site_url"]}evenements.html',
                poll=poll)
        async with self.apool.connection() as conn:
            await conn.execute("""
                INSERT INTO bluesky_missions (event_id, channel_id, message_id, poll_channel_id, poll_message_id, start_time, slots)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (event_id) DO UPDATE SET channel_id = EXCLUDED.channel_id, message_id = EXCLUDED.message_id,
                    poll_channel_id = EXCLUDED.poll_channel_id, poll_message_id = EXCLUDED.poll_message_id,
                    start_time = EXCLUDED.start_time, slots = EXCLUDED.slots
            """, (event.id, message.channel.id, message.id, poll_msg.channel.id, poll_msg.id, event.start_time, slots))
        self._polls.add(poll_msg.id)
        self.push_soon(5)
        await interaction.followup.send(f'✅ Mission liée à **{event.name}**'
                                        + (f' ({slots} places)' if slots else ' (places illimitées)')
                                        + f'. Sondage : {poll_msg.jump_url}\nLe site se met à jour d\'ici une minute.',
                                        ephemeral=True)

    # ---------- vote ou vocal → site à jour dans la minute (vote_delay, voice_delay) ----------
    def push_soon(self, delay: int) -> None:
        """Envoi groupé : tous les votes / mouvements vocaux reçus pendant « delay » secondes = un seul envoi au relais."""
        if self._push_soon and not self._push_soon.done():
            return

        async def later():
            await asyncio.sleep(delay)
            await self.push_discord()
        self._push_soon = asyncio.create_task(later())

    @commands.Cog.listener()
    async def on_raw_poll_vote_add(self, payload: discord.RawPollVoteActionEvent):
        if payload.message_id in self._polls:
            self.push_soon(int(self.cfg()['vote_delay']) * 60)

    @commands.Cog.listener()
    async def on_raw_poll_vote_remove(self, payload: discord.RawPollVoteActionEvent):
        if payload.message_id in self._polls:
            self.push_soon(int(self.cfg()['vote_delay']) * 60)

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
            # image de fond sur le site : bannière de l'événement Discord (lien permanent),
            # sinon 1re photo du briefing (ajoutée par add_mission), sinon rien
            'image': e.cover_image.with_size(1024).url if e.cover_image else None,
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

    @command(description='RGPD : efface les stats d\'un pilote, avec tous ses pseudos (même UCID)')
    @app_commands.guild_only()
    @utils.app_has_role('DCS Admin')
    @app_commands.autocomplete(pseudo=pilot_autocomplete)
    async def supprimer_pilote(self, interaction: discord.Interaction, pseudo: str):
        key = self._alias.get(pseudo, pseudo)
        names = [n for n in self._total if self._alias.get(n, n) == key]
        if not names:
            # noinspection PyUnresolvedReferences
            await interaction.response.send_message(f'Aucun pilote « {pseudo} » dans les scores.', ephemeral=True)
            return
        if not await utils.yn_question(interaction, f'Effacer définitivement les stats de « {key} » ?',
                                       message='Pseudos effacés : ' + ', '.join(f'« {n} »' for n in names)):
            await interaction.followup.send('Annulé.', ephemeral=True)
            return
        async with self._scores_lock:
            async with self.apool.connection() as conn:
                await conn.execute('DELETE FROM bluesky_scores WHERE name = ANY(%s)', (names,))
            # les Scores.lua des serveurs les gardent encore : merge les ignore tant qu'ils ne rejouent pas,
            # et push_scores les retire du fichier au prochain lancement de mission
            self._total = {n: p for n, p in self._total.items() if n not in names}
        await self.bot.audit(f'a supprimé les stats de {", ".join(names)} (RGPD).', user=interaction.user)
        servers = self.all_servers()
        if servers:
            await self.publish_stats(servers[0])
        await interaction.followup.send(
            f'Stats effacées : {", ".join(names)}. Site à jour ; les fichiers des serveurs DCS seront nettoyés '
            f'au prochain lancement de mission. Reste `/prune` pour la base du bot (voir CONFORMITE.md § 5).',
            ephemeral=True)

    @command(description='Fiche d\'un pilote (Scores.lua du serveur DCS)')
    @app_commands.guild_only()
    @utils.app_has_role('DCS')
    @app_commands.autocomplete(pseudo=pilot_autocomplete)
    async def pilote(self, interaction: discord.Interaction, pseudo: str):
        found = sc.find_pilot(self.all_scores(), self._alias.get(pseudo, pseudo))
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
            ('Heures Blue Sky', sc.hours(p.get('bsFlightTime', 0))),
            ('Vol le plus long', sc.hours(p.get('maxFlightTime', 0))), ('Vols', p.get('flights', 0)),
            ('Kills A/A', p.get('airair', 0)), ('Kills A/S', p.get('airsol', 0)), ('Kills A/M', p.get('airmer', 0)),
            ('Appontages', p.get('traps', 0)), ('Atterrissages', p.get('landings', 0)), ('Morts', p.get('deaths', 0)),
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
        time_metric = critere in ('totalFlightTime', 'refuelTime', 'bsFlightTime')
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
        await interaction.response.send_modal(PlacesModal(self.plugin, self.message, event))
        self.stop()


class PlayersPicker(discord.ui.View):
    """Cases à cocher : les ✅ Présent retenus (au plus « slots »), visibles seulement par le staff qui choisit."""

    def __init__(self, plugin: BlueSky, event: discord.ScheduledEvent, poll_msg: discord.Message, slots: int,
                 yes: list, chosen: set[int]):
        super().__init__(timeout=600)
        self.plugin, self.event, self.poll_msg, self.slots = plugin, event, poll_msg, slots
        yes = yes[:25]  # limite Discord d'une liste
        select = discord.ui.Select(placeholder='Participants retenus', min_values=0,
                                   max_values=min(slots, len(yes)), options=[
            discord.SelectOption(label=u.display_name[:100], value=str(u.id), default=u.id in chosen) for u in yes])
        select.callback = self.chosen
        self.add_item(select)

    async def chosen(self, interaction: discord.Interaction):
        ids = {int(v) for v in interaction.data['values']}
        # noinspection PyUnresolvedReferences
        await interaction.response.edit_message(content=f'Enregistrement des participants de **{self.event.name}**…',
                                                view=None)
        await self.plugin.save_players(interaction, self.event, self.poll_msg, self.slots, ids)
        self.stop()


class PlacesModal(discord.ui.Modal):
    """Après le choix de l'événement : nombre de places (vide = illimité)."""

    def __init__(self, plugin: BlueSky, message: discord.Message, event: discord.ScheduledEvent):
        super().__init__(title=f'Places · {event.name}'[:45], timeout=300)
        self.plugin, self.message, self.event = plugin, message, event
        # valeur proposée : ligne « Places : 16 » de la description de l'événement, s'il y en a une
        found = re.search(r'^\s*(?:places|slots)\s*:\s*(\d+)', event.description or '', re.I | re.M)
        self.places = discord.ui.TextInput(label='Nombre de places (vide = illimité)', required=False, max_length=3,
                                           placeholder='ex. 8', default=found.group(1) if found else None)
        self.add_item(self.places)

    async def on_submit(self, interaction: discord.Interaction):
        raw = str(self.places.value or '').strip()
        if raw and not raw.isdigit():
            # noinspection PyUnresolvedReferences
            await interaction.response.send_message(f'« {raw} » n\'est pas un nombre : recommence le clic droit.',
                                                    ephemeral=True)
            return
        slots = int(raw) if raw and int(raw) > 0 else None
        # noinspection PyUnresolvedReferences
        await interaction.response.edit_message(content=f'Publication de la mission pour **{self.event.name}**…',
                                                view=None)
        await self.plugin.link_mission(interaction, self.message, self.event, slots)


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
