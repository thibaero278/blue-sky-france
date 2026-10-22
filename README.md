# Blue Sky France — site, mission DCS et circuit de stats

Communauté francophone DCS World. Ce dépôt regroupe tout ce qui relie le serveur DCS au site web.

```
mission/script Caucase.lua ──► Scores.lua (serveur DCS de Weefe)
circuit_site/BS_site.lua (hook serveur) ──► Apps Script (Code.gs) ──► Google Sheet « BS Stats »
web/ (site statique) ◄── Apps Script ?format=json      (classements, pilotes en ligne, changelog)
web/ ◄── API publique Discord (membres / en ligne)
```

| Dossier | Contenu |
|---|---|
| `web/` | Le site : Accueil, Aerobatics, Carte live, Classements, Discord. HTML/CSS/JS sans build. |
| `circuit_site/` | Hook serveur DCS, Apps Script, publication du changelog. Voir `INSTALLATION.md`. |
| `mission/` | Script de mission MOOSE (`script Caucase.lua`) et outils kneeboard. |
| `PASSATION.md` | Journal du projet et prochaines étapes. |

## Lancer le site en local
```bash
python -m http.server 8080 --directory web
```
puis ouvrir http://localhost:8080.

## Brancher les vraies données
Tout se règle dans `web/js/config.js`. Une source vide = données de démonstration, signalées par un badge « Démo ».

| Source | Réglage | État |
|---|---|---|
| Stats pilotes, joueurs en ligne, changelog | `statsUrl` (URL Apps Script) | prêt, à déployer |
| Membres / en ligne Discord | `discordInviteCode` | **actif** |
| Planning des vols | `web/data/evenements.js` | à remplir à la main |
| Positions live (carte) | `statsUrl` (relais, envoyé par le bot) | actif quand le bot tourne |
| Activité Discord, événements, équipe | `statsUrl` (relais, envoyé par le bot) | actif quand le bot tourne |

Les paliers de grade de `web/js/data.js` (`GRADES`) doivent rester identiques à la table `RANKS` de `mission/script Caucase.lua`.

## Secrets
Le token partagé entre le hook, l'Apps Script et `publier_maj` n'est **jamais** versionné :
il vit dans `circuit_site/secrets.local.ps1` (ignoré par git) et dans les propriétés du script Apps Script.
