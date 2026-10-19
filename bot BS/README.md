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

## Plugin `bluesky` : lien DCS ↔ Discord ↔ site

Le plugin lit `Scores.lua` et les positions des joueurs sur le serveur DCS, compte l'activité Discord et lit les
événements planifiés, puis pousse tout vers le site (relais Apps Script, voir `site\circuit_site\INSTALLATION.md`).
- Discord : `/pilote`, `/classement`, `/enligne`, `/annonce` (DCS Admin) ; salon fil (promotions, bilans) si `feed_channel` est rempli.
- En jeu : `-discord`, `-site`, `-stats` (réponse seulement au joueur qui tape la commande, rien à la connexion).
- Réglages : `config\dcssb\plugins\bluesky.yaml` (modèle `config\templates\plugins\bluesky.yaml.template`).
- Tables PostgreSQL `bluesky_activity`, `bluesky_presence` créées au démarrage (version 1.1 du plugin).

## Ajouter une fonctionnalité

- Commande Discord → `plugins\bluesky\commands.py` ; événement DCS → `plugins\bluesky\listener.py`
  (exemples en commentaire dans chaque fichier, modèle complet dans `bot\DCSServerBot\plugins\sample`).
- Table en base → créer `plugins\bluesky\db\tables.sql`.
- Réglages → `config\dcssb\plugins\bluesky.yaml` (lu automatiquement s'il existe).
- Puis relancer `tools\Install-BlueSkyPlugin.ps1` (copie le plugin dans le moteur) et redémarrer le bot.

## Règles

- **Un seul bot actif à la fois avec le même token** : ne pas le lancer pendant qu'il tourne chez Weefe.
- Le token et les mots de passe PostgreSQL sont dans `config\dcssb\.secret\` et `config\secrets\`
  (exclus par `.gitignore`). Ne jamais les partager ; si le token fuite, le régénérer sur le portail
  développeur Discord.
- Ne jamais mettre `token:` dans `bot.yaml` (DCSServerBot écraserait le vrai token).
- Ne pas exposer le plugin `restapi` de DCSServerBot sur Internet (il permet de piloter le serveur).
