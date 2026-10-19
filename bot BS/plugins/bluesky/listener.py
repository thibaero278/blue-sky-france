"""Écouteur DCS du plugin Blue Sky : commandes de chat en jeu (préfixe de main.yaml, « - » par défaut).

Rien n'est envoyé automatiquement à la connexion : le joueur reçoit une réponse seulement s'il tape une commande.
    -discord  lien du Discord + prochain événement
    -site     adresse du site
    -stats    ses scores (Scores.lua)
"""

from datetime import datetime
from typing import TYPE_CHECKING
from zoneinfo import ZoneInfo

from core import EventListener, Player, Server, chat_command

from . import scores as sc

if TYPE_CHECKING:
    from .commands import BlueSky


class BlueSkyEventListener(EventListener["BlueSky"]):

    @chat_command(name='discord', help='lien du Discord Blue Sky et prochain evenement')
    async def discord(self, server: Server, player: Player, _params: list[str]):
        cfg = self.plugin.cfg(server)
        lines = [f"Discord Blue Sky : {cfg['discord_invite']}"]
        guild = self.bot.guilds[0] if self.bot.guilds else None
        if guild:
            now = datetime.now(ZoneInfo('Europe/Paris'))
            upcoming = sorted((e for e in guild.scheduled_events if e.start_time > now), key=lambda e: e.start_time)
            if upcoming:
                e = upcoming[0]
                when = e.start_time.astimezone(ZoneInfo('Europe/Paris'))
                lines.append(f"Prochain evenement : {e.name}, le {when:%d/%m} a {when:%H:%M}")
        await player.sendChatMessage('\n'.join(lines))

    @chat_command(name='site', help='adresse du site Blue Sky')
    async def site(self, server: Server, player: Player, _params: list[str]):
        await player.sendChatMessage(f"Site Blue Sky (classements, carte live) : {self.plugin.cfg(server)['site_url']}")

    @chat_command(name='stats', help='tes scores Blue Sky')
    async def stats(self, server: Server, player: Player, _params: list[str]):
        p = self.plugin.scores_of(server).get(player.name)
        if not p:
            await player.sendChatMessage("Pas encore de scores a ton nom : pose-toi apres un vol pour les valider.")
            return
        rank, nxt = sc.rank_for(p.get('points', 0))
        await player.sendChatMessage(
            f"{player.name} : {rank}, {p.get('points', 0)} pts"
            + (f" (prochain grade {nxt[1]} a {nxt[0]} pts)" if nxt else "") + "\n"
            f"Heures : {sc.hours(p.get('totalFlightTime', p.get('maxFlightTime', 0)))} - vols : {p.get('flights', 0)} - "
            f"kills A/A {p.get('airair', 0)}, A/S {p.get('airsol', 0)}, A/M {p.get('airmer', 0)} - "
            f"appontages : {p.get('traps', 0)}")
