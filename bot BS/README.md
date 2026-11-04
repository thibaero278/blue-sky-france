# Bot Discord Blue Sky (squelette)

Structure du bot de Weefe (`BlueSky-Founder-Package-20261019-142713.zip`), **sans ses fonctionnalités** :
pas de cours T-45, pas de mod T-45, pas de mission, pas de message automatique à la connexion
sur le serveur DCS, pas d'appel d'instructeur. Base de données neuve (l'ancienne n'est pas reprise).

## Contenu

| Dossier / fichier | Rôle |
|---|---|
| `bot\DCSServerBot\` | Moteur DCSServerBot v3.0.4.27, non modifié (plugin T-45 retiré). |
| `plugins\bluesky\` | **Notre plugin** : lien DCS ↔ Discord ↔ site (voir plus bas), et ici qu'on ajoute nos commandes. |
| `config\templates\` | Modèles de config (le vrai fichier est généré dans `config\dcssb\`). |
| `tools\` | Installation, configuration Discord, lancement, panneau GO/STOP. |
| `tools\downloads\` | Installateurs hors ligne : Python 3.12, PostgreSQL 18, dépendances Python. |
| `INSTALLER.cmd` | 1. Installe Python, PostgreSQL, les dépendances et déploie le plugin. |
| `CONFIGURER-DISCORD.cmd` | 2. Demande le token du bot (saisie masquée) et génère la config. |
| `BLUE-SKY-CONTROL.cmd` | 3. Panneau GO / STOP du bot. |

DCS World n'est pas inclus.

## Installation (sur le PC qui fera tourner le bot)

1. Double-clic `INSTALLER.cmd`, accepter l'UAC, attendre « POSTE PRÊT ».
2. Lancer une fois le serveur DCS (pour que `serverSettings.lua` existe), puis double-clic
   `CONFIGURER-DISCORD.cmd` et coller le token du bot.
   Si une config existe déjà : `CONFIGURER-DISCORD.cmd -ReplaceExisting`.
3. Double-clic `BLUE-SKY-CONTROL.cmd` → **GO**.

Vérification : `powershell -ExecutionPolicy Bypass -File tools\Test-BlueSkyEnvironment.ps1 -RequireDiscord`.

## Cluster R2D2 + MSI (depuis le 28/10/2026)

| Machine | Rôle | Lancement |
|---|---|---|
| **R2D2** (serveur maison, Debian) | Maître : Discord, PostgreSQL, envoi vers le site. Tourne 24 h/24. | Docker, `~/bluesky-bot` (fichiers dans `r2d2\`), redémarre seul |
| **MSI** | Agent : DCS, `Scores.lua`. `no_master` : sans R2D2 il attend. | `BLUE-SKY-CONTROL.cmd` → GO, comme avant |

- La base est sur R2D2 (`db`, Docker) ; le MSI s'y connecte par Tailscale (IP Tailscale de R2D2, port 5432).
  La base PostgreSQL du MSI n'est plus utilisée (copie du 28/10, gardée en secours).
- `config\dcssb\` est la même sur les deux machines : après une modif, la recopier sur R2D2 puis
  `docker compose restart bot` (dans `~/bluesky-bot`). Idem pour le plugin (`bot\DCSServerBot\plugins\bluesky`).
- ⚠️ Ne pas relancer `CONFIGURER-DISCORD.cmd` : il régénère un `nodes.yaml` sans R2D2.
- Logs R2D2 : `docker compose logs -f bot` ou `~/bluesky-bot/DCSServerBot/logs/dcssb-R2D2.log`.

### Sauvegarde de la base (depuis le 30/10/2026)

- `r2d2\backup-db.sh` (copié dans `~/bluesky-bot`) : `pg_dump` de `dcsserverbot` + rôles PostgreSQL dans
  `~/backups/bluesky-bot`, gardés 14 jours. Lancé chaque jour à 4 h par la crontab de `thibaud`.
- ⚠️ Même disque que la base : protège d'une erreur ou d'une base cassée, **pas** d'une panne du disque.
- Restauration testée le 30/10 (38 tables, mêmes nombres de lignes). Pour restaurer, dans `~/bluesky-bot` :
  1. `docker compose stop bot`
  2. `docker compose exec -T db psql -U postgres -c "drop database dcsserverbot" -c "create database dcsserverbot"`
  3. `docker compose exec -T db pg_restore -U postgres -d dcsserverbot < ~/backups/bluesky-bot/dcsserverbot-AAAA-MM-JJ.dump`
  4. `docker compose start bot`
  - Volume `pgdata` perdu (rôles disparus) : passer d'abord `globals-AAAA-MM-JJ.sql` avec `psql -U postgres`.

### PC de Weefe (agent, depuis le 02/11/2026)

- 2e agent du cluster (serveur « Weefe le GOAT », SRS auto). R2D2 lui est partagé par Tailscale. Voir `GUIDE-WEEFE.md`.
- **Envoyer un fichier ou une mise à jour à Weefe** : conteneur `partage` (nginx, `r2d2\partage.conf`, port 8099,
  Tailscale seulement, lecture seule). Bouton **FICHIERS / MAJ** du panneau :
  - `~/bluesky-bot/partage/fichiers/…` → téléchargé dans `Recus de Thibaud\` (dossier du bot) ;
  - `~/bluesky-bot/partage/maj/<chemin dans le dossier du bot>` → copié par-dessus, ancienne version en `.bak`.
  - Déposer avec `scp` **sans** `-p` (le panneau ne reprend un fichier que s'il est plus récent ou de taille différente).
  - Ce qui est dans `maj/` s'applique aussi au MSI si on clique le bouton ici.

## Plugin `bluesky` : lien DCS ↔ Discord ↔ site

Le plugin lit `Scores.lua` et les positions des joueurs sur chaque serveur DCS, compte l'activité Discord et lit les
événements planifiés, puis pousse tout vers le site (relais Apps Script, voir `site\circuit_site\INSTALLATION.md`).
- **Scores fusionnés** (depuis le 03/11/2026, v1.5) : le total de chaque pilote est dans la base de R2D2 ; chaque lecture
  d'un `Scores.lua` y ajoute ce que ce serveur a gagné depuis la lecture d'avant (un serveur jamais lu : maximum par stat).
  Le total est renvoyé à la mission à son lancement. Supprimer un pilote : voir `site\CONFORMITE.md` § 5.
- **Pseudos regroupés par UCID** (03/11/2026) : les pseudos d'un même compte DCS (tables `players` / `players_hist`)
  comptent pour un seul pilote, affiché sous son pseudo actuel (site, Discord, jeu). L'hôte est ajouté à `players` par le plugin
  (DCSServerBot l'ignore). La table `bluesky_scores` reste par pseudo.
- **Mode Blue Sky** (03/11/2026) : activé au sol dans le menu F10 de la mission, il ajoute le temps du vol à `bsFlightTime`
  (heures Blue Sky : site, `/pilote`, `/classement`) et donne l'icône F-18 Blue Sky sur la carte (`bs` dans `lua/mission.lua`).
- **Multi-équipage** (04/11/2026) : `lua/commands.lua` envoie à la mission les places 2+ de chaque avion (`bsSetCrew`) ;
  le script de mission crédite tout l'équipage (heures, kills, points…). Carte : « Pilote + Gunner ».
- Discord : `/pilote`, `/classement`, `/enligne`, `/annonce` et `/supprimer_pilote` (RGPD, tous les pseudos de l'UCID) (DCS Admin) ; salon fil (promotions seulement) si `feed_channel` est rempli.
- Missions : clic droit sur le briefing dans #missions-dcs → Applications → **Publier sur le site** → choisir l'événement Discord.
  Le bot poste un sondage d'inscription dans #inscriptions ; le site affiche les inscrits et une page `mission.html`.
- Temps passé en vocal (total par jour, sans nom) → graphique de la page Discord du site.
- Commandes inutiles des autres plugins **masquées** (`hide_commands`, `hide_chat_commands`) : il reste la modération
  (`/player`, `/watch`, `/link`, `/find`, `/info`, `/linkme`, `/dcs ban|unban|bans`) et `/serverstats`, `/serverload`.
  `creditsystem` et `cloud` ne sont plus chargés.
- En jeu : `-discord`, `-site`, `-stats` (réponse seulement au joueur qui tape la commande, rien à la connexion).
- Réglages : `config\dcssb\plugins\bluesky.yaml` (modèle `config\templates\plugins\bluesky.yaml.template`).
- Tables PostgreSQL `bluesky_activity`, `bluesky_presence` (v1.1), `bluesky_scores`, `bluesky_scores_base` (v1.5),
  créées au démarrage (`db\tables.sql`, mises à jour par `db\update_v*.sql`).

## Ajouter une fonctionnalité

- Commande Discord → `plugins\bluesky\commands.py` ; événement DCS → `plugins\bluesky\listener.py`
  (exemples en commentaire dans chaque fichier, modèle complet dans `bot\DCSServerBot\plugins\sample`).
- Table en base → créer `plugins\bluesky\db\tables.sql`.
- Réglages → `config\dcssb\plugins\bluesky.yaml` (lu automatiquement s'il existe).
- Puis relancer `tools\Install-BlueSkyPlugin.ps1` (copie le plugin dans le moteur) et redémarrer le bot.

## Règles

- **Un seul bot Discord avec ce token** : le maître R2D2. Les agents (MSI, PC de Weefe) n'ouvrent pas Discord ;
  l'ancienne installation de Weefe ne doit plus être lancée.
- Le token et les mots de passe PostgreSQL sont dans `config\dcssb\.secret\` et `config\secrets\`
  (exclus par `.gitignore`). Ne jamais les partager ; si le token fuite, le régénérer sur le portail
  développeur Discord.
- Ne jamais mettre `token:` dans `bot.yaml` (DCSServerBot écraserait le vrai token).
- Ne pas exposer le plugin `restapi` de DCSServerBot sur Internet (il permet de piloter le serveur).
