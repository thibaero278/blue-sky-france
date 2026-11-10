# PASSATION — Projet site Blue Sky (DCS)

_Dernière mise à jour : 10/11/2026 (mode Blue Sky, kills en un vol séparés, nouveau barème : codés, pas déployés ; voir section 10/11 en bas de fichier)_

> **09/11, panne « plus rien ne se rafraîchit » :** depuis le 06/11 23 h 33, 5 lignes de `commands.py` sur R2D2 avaient perdu leur « r » final
> (`BlueSkyEventListene`), plugin `bluesky` non chargé. Probable `sed 's/\r$//'` au backslash mangé par PowerShell : déployer avec `scp` seul.
> Fichier recopié (ancien : `~/bluesky-bot/commands.py.casse-2026-11-06`), bot relancé à 01 h 53, plugin chargé, classement envoyé au site.
> ⚠️ Relancer le maître ou un agent **pendant une mission** : la mission continue, mais l'agent marque le serveur « Shutdown » dès que son test du port
> webgui échoue (`register_local_servers`, service.py) et le statut reste bloqué jusqu'au prochain chargement de mission ; le plugin n'envoie la carte live
> qu'en Running/Paused. Donc : lancer le bot **avant** la mission, ou recharger la mission après. Pourquoi l'agent de Weefe s'est arrêté à 01 h 53:55 : inconnu.
> Carte live à revérifier après le prochain chargement de mission sur le serveur de Weefe.

> **09/11, plan de mise à jour vers DCSServerBot 3.0.5.2 :** `bot BS\PLAN-MAJ-3.0.5.md`, rien d'appliqué. ⚠️ Une fois le maître à jour, un agent resté en 3.0.4.27
> lance `update.py` seul, même avec `--noupdate`, et perd ses patchs : tout passer dans la même soirée, agents en STOP.
> Banc d'essai fait le 09/11 (`serveur BS\banc-3.0.5.2`) : tous les contrôles OK, sans démarrage réel du bot (pas de base, Discord ni DCS). Paquet + `MAJ-MOTEUR.cmd` / `RETOUR-MOTEUR.cmd` prêts dans `banc-3.0.5.2\livraison\maj`, répétés sur copie ; image Docker testée sur R2D2. Paquet et scripts envoyés dans `partage/maj/` le 09/11. **R2D2 passé en 3.0.5.2 le 09/11 à 16 h 35** (base v3.23, plugin chargé, pas d'erreur) ; MSI et Weefe passés en 3.0.5.2 le 09/11, agents connectés. SRS, carte live et `/classement` validés le 09/11 ; reste à tester une mission sur le MSI et les autres commandes (voir la recette du plan).
> `/marker` et `/webadmin` ajoutées à `hide_commands` dans la source du plugin, pas encore déployé.

> À lire en début de session. Mis à jour par Claude Code à chaque changement.
> `CLAUDE.md` : version maître dans `Bureau thibaud\Claude code\MD\CLAUDE.md`, la modifier puis la recopier ici.

## Contexte
- Communauté DCS francophone **Blue Sky France** (~140 membres), fondée par Thibaud.
- Serveurs multi : le MSI de Thibaud (« Blue sky ») et le PC de **Weefe** (admin BS, « Weefe le GOAT »),
  agents du bot DCSServerBot dont **R2D2** (serveur maison de Thibaud) est le maître (voir `bot BS\README.md`).
- Mission : `Blue Sky Multi-joueur DAY_Caucasus.miz` (Caucase).
- Script : `mission\script Caucase.lua` (basé sur **MOOSE** ; s'appelait `multi jours thib.lua` jusqu'au 18/10).

## Objectif final
Un site Blue Sky (fait : GitHub Pages, https://thibaero278.github.io/blue-sky-france/ ; Google Sites abandonné) avec :
1. Suivi de la progression : heures de vol, kills, points, appontages, grades de chaque pilote.
2. Pub / présentation de la Blue Sky, infos de missions, liens TikTok/YouTube/Discord, etc.

## Ce que fait le script Lua (analyse du 18/10/2026)
- **Scores persistants** dans `Saved Games\DCS...\Scores.lua` (`lfs.writedir()`), par pseudo :
  `traps, airair, airsol, airmer, points, grade, maxFlightTime`.
  ⚠️ Pas de temps de vol cumulé ni de nombre de vols/morts — seulement le vol le plus long.
- **Timer de vol** : démarre au décollage, s'arrête à l'atterrissage.
- **Atterrissage** : bilan du vol (kills A/A, A/S, A/M, points, durée). Sur CVN-74 / CVN-75 :
  +1 appontage, sauf si train cassé → message « troll » de l'AIRBOSS + son `troll.ogg`.
- **Kills** : A/A avion 3 pts, hélico 2 pts, navire 5 pts, sol 1 pt, défense aérienne/radar 3 pts,
  static 1 pt. Affiche distance impact-cible et avion-cible (tracking des armes via `land.getIP`).
- **Menu F10 « STATISTIQUES »** : mes scores, top 10 points, top 10 vol, top 10 temps de vol,
  choix du grade (Rookie / Intermediate / Expert).
- **Menu F10 coalition bleue** : spawn MiG-21 / MiG-29 / Su-27 (4 groupes chacun, zone « Spawn Air »),
  Clear hostile, tankers (S-3B, KC-135 MPRS, KC-135, KC-130, IL-78), reset cibles « Croix »,
  convoi aléatoire (8 itinéraires).

## Points faibles repérés dans l'original (corrigés en v2, sauf l'export)
- Stats de vol perdues si crash / éjection / déco (pas d'event Crash/Eject/PilotDead).
- `Top 10 vol` basé sur `FlightStats`, remis à zéro à chaque atterrissage.
- Pas d'export exploitable par un site (format Lua, pas JSON, local au serveur).
- `local Clear = MENU...` masque la fonction `Clear` (marche car déjà passée en argument, mais fragile).
- Menus/spawns très dupliqués (pourrait être factorisé).

## Réalisé
- 18/10/2026 : analyse complète du Lua, création de ce fichier.
- 18/10/2026 : **v2 du script** (`multi jours thib.lua`, original gardé dans `multi jours thib ORIGINAL.lua`).
  Syntaxe vérifiée (luaparse, Lua 5.1). **Pas encore testée en jeu.**
  - Nouveaux champs dans Scores.lua : `totalFlightTime, flights, deaths, teamkills, refuelTime`
    (les anciens profils sont complétés automatiquement au chargement).
  - Règle : kills/points **en attente** pendant le vol, validés à l'atterrissage.
    Mort (crash, éjection, pilote tué, avion détruit) → temps ajouté, +1 mort, kills du vol perdus.
    Quitter le slot en vol → temps ajouté, kills perdus, pas de mort.
    Kill au sol (pas en vol) → validé tout de suite.
  - Teamkill (même coalition) → +1 teamkill, 0 point.
  - Ravitaillement : events Refueling/RefuelingStop, durée cumulée + message à la fin du contact.
  - Air start : timer lancé à la naissance si l'avion est déjà en vol.
  - Fin de mission : temps des pilotes en l'air ajouté.
  - Menu STATISTIQUES : + Top heures de vol, Top vol le plus long, Top ravitaillement ; « Mes scores » complet.
  - Optimisations : un objet SPAWN par template (avant : noms de groupe réutilisés), « Clear hostile »
    détruit tous les hostiles, « Reset Croix » détruit aussi les anciens groupes, tracking d'armes
    limité aux joueurs + plus de fuite mémoire, plus de message parasite aux décollages IA,
    keyword SAM « tor » remplacé par « tor 9a331 » (attrapait « tractor »), menus générés par boucles.
  - ⚠️ Weefe doit **réintégrer le .lua dans la .miz** (trigger DO SCRIPT FILE, après Moose.lua).

- 18/10/2026 : fichiers renommés par Thibaud → **`script Caucase.lua`** (actif) et `Script caucase ORIGINAL.lua`.
  v2 **testée en jeu par Thibaud : tout marche**.
- 18/10/2026 : ajout `completedFlightTime` (heures « complétées » = vols terminés par un atterrissage),
  ajouté dans le handler d'atterrissage via `CommitFlightKills(playerName, f, elapsed)`.
  `totalFlightTime` = toutes les heures, morts comprises. Affiché dans « Mes scores » + menu « Top 10 heures completes ».
  Syntaxe OK, pas encore retesté en jeu.

- 18/10/2026 : **outil kneeboard** `site\kneeboard\ajouter_kneeboard.bat/.ps1` : injecte les images du dossier
  dans la .miz (`KNEEBOARD/IMAGES/` pour tous, sous-dossier = type d'avion → `KNEEBOARD/<type>/IMAGES/`),
  remplace l'ancien kneeboard, crée une sauvegarde `.miz.bak`. Testé sur une copie : OK.
  Rappel : l'éditeur de mission n'a pas d'option kneeboard ; ne pas resauvegarder la mission dans l'éditeur après.
  ⚠️ La .miz actuelle contient encore l'ancien `multi jours thib.lua` : y mettre `script Caucase.lua`.

- 18/10/2026 : **dossiers réorganisés par Thibaud** → mission, scripts et kneeboard dans `site\mission\`
  (`.miz`, `script Caucase.lua`, `Script caucase ORIGINAL.lua`, `kneeboard\`, `kneeboard_source\`).
- 18/10/2026 : **kneeboard v2, style « carte de nav »** (demandé par Thibaud, réf. DimOn / notes F-14) :
  fond gris clair, chiffres en Consolas, police Bahnschrift, code couleur (TACAN magenta, ICLS vert,
  Link 4 orange, VHF noir, UHF bleu), onglets de section noirs, bandeau n° + jaune BLUE SKY, pied « PAGE 0X ».
  3 pages : `BS_01_comms-nav.png` (PA + tankers), `BS_02_menu-bareme.png`, `BS_03_briefing.png` (règles + situation).
  Source `site\mission\kneeboard_source\kneeboard.html` ; `generer_kneeboard.bat` → rendu Edge 1536×2048,
  ne supprime/régénère que les `BS_*.png` (images perso intactes).
  Page terrains Caucase : abandonnée (déjà fournie par le kneeboard de base de DCS).
- 18/10/2026 : **.miz mise à jour** : 3 pages kneeboard injectées (`KNEEBOARD/IMAGES/`) + script embarqué remplacé
  par `script Caucase.lua`, gardé sous le nom interne `l10n/DEFAULT/multi jours thib.lua` pour que le trigger
  DO SCRIPT FILE marche sans retoucher la mission. Vérifié : contenu identique, archive OK.
  Sauvegarde de la mission d'avant : `mission\bakup\Blue Sky Multi-joueur DAY_Caucasus.miz.bak`.
- 18/10/2026 : **dossier `mission\bakup\`** créé par Thibaud pour les sauvegardes (contient aussi
  `Script caucase ORIGINAL.lua`). `ajouter_kneeboard.ps1` y range maintenant ses sauvegardes,
  horodatées (`<mission>_AAAA-MM-JJ_HH-mm-ss.miz.bak`, jamais écrasées). Testé sur une copie : OK.
  Règle : toute sauvegarde future (scripts, .miz) va dans `bakup\`.
  Si on modifie le script plus tard : refaire ce remplacement (même nom interne) ou recharger le fichier dans l'éditeur.

- 18/10/2026 : **circuit stats → site** dans `site\circuit_site\` (voir `INSTALLATION.md`) :
  - `BS_site.lua` = **hook serveur DCS** (`Saved Games\...\Scripts\Hooks\`, doc : `DCS World\API\Sim_ControlAPI.md`).
    Il lit Scores.lua, le convertit en JSON (`net.lua2json`) et l'envoie avec `curl` en arrière-plan (`os.execute`), car Lua ne fait pas de HTTPS.
    Envoi quand Scores.lua change, battement toutes les 5 min avec les joueurs en ligne, et en fin de mission. Aucune modif du script de mission.
  - `Code.gs` + `Page.html` = Apps Script de la feuille « BS Stats » (onglets Pilotes / Serveur / Changelog),
    `doGet` = page classement à intégrer dans Google Sites (`?format=json` pour les données brutes).
  - `publier_maj.bat` = publie une version de `script Caucase.lua` dans le Changelog.
  - Un même token partagé est utilisé dans les 3 fichiers. Syntaxe vérifiée (luaparse, node). **Rien n'est encore déployé ni testé en réel.**

- 18/10/2026 : **grades automatiques aux points** (échelle Armée de l'Air, choisie par Thibaud) dans `script Caucase.lua`
  (sauvegarde d'avant : `mission\bakup\script Caucase_2026-10-18_avant-grades.lua`).
  - Paramétrage : table `RANKS` en haut du script (CONFIG), `{ min = points, name = ... }`, ordre croissant.
    Officiers seulement (demande de Thibaud) : Aspirant 0 → Sous-lieutenant 10 → Lieutenant 30 → Capitaine 60 →
    Commandant 120 → Lieutenant-colonel 200 → Colonel 350 → General de brigade aerienne 600 →
    General de division aerienne 1000 → General de corps aerien 1800 → General d'armee aerienne 3000.
  - Calculé à partir des points validés (`GetRank`) → changer les seuils s'applique à tous rétroactivement.
    Sauvegardé dans Scores.lua sous `rang` (pour le site). Message « PROMOTION » à tous quand on monte de grade (dans `CommitFlightKills`).
  - « Mes scores » affiche le grade + le suivant ; nouveau menu F10 « Echelle des grades ».
  - ⚠️ `s.grade` (ROOKIE/INTERMEDIATE/EXPERT, choix manuel F10) **non touché** à la demande de Thibaud (sert au spawn des bots selon lui).
  - Site : `Code.gs` colonne `rang` ajoutée en fin (en-tête « Grade », l'ancien « Grade » renommé « Niveau ») ; `Page.html` affiche `rang`.
  - Syntaxe OK (luaparse + JS). **Pas testé en jeu**, et la .miz contient encore l'ancienne version du script.
- 18/10/2026 : reset du score de vol au décollage : **déjà en place** (`StartFlight` crée un vol neuf à chaque Takeoff).
  Seul ajout : le message de décollage dit « Score de vol remis a 0 ».

- 19/10/2026 : **site codé** dans `site\web\` à partir de la maquette Claude Design (`Site web serveur Discord Blue Sky.zip`,
  format « dc » qui dépendait d'un runtime React/Babel → réécrit en HTML/CSS/JS statique, sans build).
  - 5 pages : `index.html` (Accueil), `aerobatics.html`, `carte.html`, `classements.html`, `discord.html`.
  - Réglages dans `web/js/config.js` ; une source vide = démo avec badge « Démo ».
    - Stats : `statsUrl` = URL Apps Script (lit `?format=json`). Pas encore déployé → démo.
    - Discord membres/en ligne : **réel**, via l'API publique de l'invitation `zVEsRbm8h2` (145 membres / 20 en ligne au test).
    - Planning : `web/data/evenements.js`, à remplir à la main (exemples pour l'instant).
    - Carte live et activité Discord (messages/jour) : démo, rien côté serveur pour l'instant.
  - Corrections par rapport à la maquette : paliers de grades alignés sur `RANKS` du script (la maquette avait 300/800/…),
    colonnes classement adaptées à Scores.lua (Appontages, Morts au lieu d'Éjections non suivies ; fiche pilote avec
    heures complètes, vol le plus long, ravitaillement, teamkills), textes « Your text here » parasites supprimés,
    phrase coupée du héros Aerobatics, fautes (« Phoénix », « Ventre »).
  - Images compressées en WebP : 61 Mo → 3 Mo (`web/assets`). Testé desktop + mobile 375 px, aucune erreur console.
  - Lancer en local : `python -m http.server 8080 --directory web` (config `serveur BS\.claude\launch.json`).
- 19/10/2026 : **token sorti des fichiers versionnés** : `Code.gs` lit la propriété de script `TOKEN`,
  `BS_site.lua` a `COLLE_ICI_LE_TOKEN`, `publier_maj.ps1` lit `circuit_site\secrets.local.ps1` (non versionné, contient le token).
  INSTALLATION.md mis à jour.
- 19/10/2026 : **dépôt git local** dans `site\` (branche `main`, 1er commit). Ignorés : CLAUDE.md, zip, `_design_zip\`,
  `image\` (sauf claude-design.md), `.miz`, `bakup\`, kneeboard PNG générés, secrets. Poussé sur GitHub le 19/10/2026.

- 19/10/2026 : **dépôt public https://github.com/thibaero278/blue-sky-france**, créé avec GitHub CLI (installé via winget, connecté).
  **Site en ligne : https://thibaero278.github.io/blue-sky-france/**, publié automatiquement depuis `web/`
  par `.github/workflows/pages.yml` à chaque push sur main.
  Graphify : le dépôt n'apparaît pas encore dans le workspace, il faut l'ajouter depuis Graphify.

- 19/10/2026 : **animations du site** (`web/css/motion.css`, `web/js/motion.js`) : transitions entre pages, apparitions au défilement,
  compteurs, tri animé, survols ; coupées si « réduire les animations ».
- 19/10/2026 : **Weefe utilise DCSServerBot**. Son plugin REST API (`restapi`) expose stats, serveurs et météo, mais aussi des
  commandes (start/stop, upload mission…) → ne jamais l'exposer au site public. Plan : script planifié chez Weefe qui lit l'API
  en local et pousse un JSON nettoyé (Apps Script ou fichier). Questions envoyées à Weefe : restapi activé ? api_key ? port ?
  server_name ? plugins actifs ? OK pour un script planifié ?
- 19/10/2026 : **vraies stats sur le site** : `tools/scores_to_json.py "Scores.lua"` → `web/data/stats.json` (Scores.lua du serveur,
  ancien format sans heures totales → heures = vol le plus long, signalé sur la page). Le site lit statsUrl, sinon stats.json, sinon démo.
  `config.js` : `pilotAliases` (fusion des pseudos d'une même personne) et `ignorePilots` (Player, Joueur). 25 pseudos → 19 pilotes.

- 19/10/2026 : **Scores.lua optimisé et migré v2**.
  - `script Caucase.lua` (sauvegarde d'avant : `bakup\script Caucase_2026-10-19_avant-sauvegarde-sure.lua`) :
    sauvegarde sûre (écrit `Scores.lua.tmp` puis remplace ; récupère le .tmp au chargement si crash entre les deux ;
    repli en écriture directe si le module `os` est bloqué par MissionScripting.lua), pilotes triés par points,
    pseudos par défaut (Player, Joueur, New callsign) jamais sauvegardés. Syntaxe OK (luaparse 5.1), **pas testé en jeu**.
  - `tools/migrer_scores.py "ancien Scores.lua"` → `mission\Scores.lua` au format v2 exact (champs lus dans le script,
    rang recalculé, tri, retire Player/Joueur/profils vides). Ancien format : vol le plus long (vol atterri) utilisé comme
    minimum pour heures totales/complètes, flights = 1. Généré depuis le Scores.lua du serveur : 22 pilotes (retirés : MR WHITE, Player, Joueur).
  - Les doublons de pseudos ne sont **pas** fusionnés dans le fichier (la clé doit rester le pseudo en jeu) : fusion côté site seulement.
  - À faire par Weefe, **serveur arrêté** : remplacer `Saved Games\...\Scores.lua` par `mission\Scores.lua`, et mettre le
    nouveau script dans la .miz (nom interne `l10n/DEFAULT/multi jours thib.lua`).

- 19/10/2026 : **paquet bot de Weefe reçu** : `site\BlueSky-Founder-Package-20261019-142713.zip` (1,4 Go, intact, SHA256 OK).
  (`Bot discord.zip` = juste Python 3.12, pas de code.) **CONFIDENTIEL** : vrai token Discord (`config\dcssb\.secret\token.pkl`),
  mots de passe PostgreSQL (`config\secrets\`), sauvegarde de la base. Ignoré par git (`*.zip`) : ne jamais le committer/partager.
  - Contenu : DCSServerBot v3.0.4.27 + plugin perso **`blueskytraining`** (cours T-45 : T45-01 actif, T45-02 à 08 vides ;
    demande d'instructeur sur Discord, liaison de compte `/linkme`, onboarding), config réelle (`config\dcssb`), installateurs
    hors ligne (Python, PostgreSQL 18, wheels, mod VNAO T-45), missions `BlueSky_T45-01_Marianas_CLEAN/DEV.miz`, docs, outils.
    Installation : `INSTALLER-FONDATEUR.cmd` puis `BLUE-SKY-CONTROL.cmd` (voir `README_FONDATEUR.md`). Un seul bot actif à la fois.
  - Ce qui n'y est pas : plugin **`restapi`** non configuré (seulement admin, blueskytraining, cloud, scheduler) ; salons
    status/chat/admin à `-1` dans `servers.yaml` ; aucun lien avec la mission Caucase / Scores.lua ; rien sur le vocal
    join-to-create ni l'autorole (YAGPDB est un bot séparé). DCS World non inclus.
- 19/10/2026 : **squelette du bot** dans `serveur BS\bot BS\` (hors dépôt git public, voir son `README.md`), demandé par Thibaud :
  structure du bot de Weefe **sans ses fonctionnalités** ni le mod T-45.
  - Gardé : moteur DCSServerBot 3.0.4.27 (avec les 3 petits correctifs de Weefe : mode sans Discord, scheduler),
    installateurs hors ligne (Python 3.12, PostgreSQL 18, wheels), panneau GO/STOP, scripts d'install/lancement.
  - Retiré : plugin `blueskytraining` (cours T-45, popups, appel instructeur), mod VNAO T-45, missions Marianas,
    sauvegarde de la base (base neuve), secrets (token/mots de passe à refaire), outils de mission/onboarding.
  - Nouveau plugin **vide** `plugins\bluesky\` (exemples en commentaire). Install : `INSTALLER.cmd` →
    `CONFIGURER-DISCORD.cmd` (token masqué, IDs serveur/propriétaire repris de Weefe) → `BLUE-SKY-CONTROL.cmd`.
  - **Aucun message automatique à la connexion** : DCSServerBot en envoie de base → patch « off » dans
    `plugins\mission\listener.py` et `plugins\cloud\listener.py` + `greeting_message_*: 'off'` dans `servers.yaml`,
    et plugin `help` retiré de `main.yaml` (il envoyait « Use -help for commands »).
  - Vérifié : install pip hors ligne OK (Python 3.12), configs générées validées par le schéma strict DCSServerBot,
    plugin importé avec le moteur, scripts PowerShell sans erreur de syntaxe (BOM UTF-8 ajouté pour les accents).
    **Pas installé ni lancé en réel** (PostgreSQL, token, connexion Discord non testés).
- 19/10/2026 : dossier **déplacé par Thibaud dans `site\bot BS\`** (dans le dépôt git : le `.gitignore` de `bot BS`
  exclut bien secrets, config générée, installateurs — vérifié avec `git check-ignore`). **Installé sur le PC de Thibaud** :
  Python 3.12 + venv `%USERPROFILE%\.dcssb`, PostgreSQL 18 (service `postgresql-x64-18`, auto), base `dcsserverbot`, plugin déployé.
  Corrigé dans `Initialize-PostgreSQL.ps1` (bugs du script de Weefe) : mot de passe généré avec des API PowerShell 7 seulement
  (`RandomNumberGenerator.Fill`, `Convert.ToHexString`) → version 5.1 ; chemin du fichier d'options non guillemeté
  (cassait avec les espaces de « serveur BS »/« bot BS »).
  Reste : `CONFIGURER-DISCORD.cmd` (Thibaud colle le token lui-même), puis lancer **seulement si le bot est arrêté chez Weefe**.
- 19/10/2026 : **config Discord faite par Thibaud** et vérifiée : nœud `MSI`, serveur DCS « Blue sky » (lu dans serverSettings.lua),
  configs validées par le schéma strict, `Test-BlueSkyEnvironment.ps1 -RequireDiscord` OK. Token valide (test REST lecture seule) :
  bot **BlueSkyDCSServeurBot**, présent sur le serveur « ~Blue Sky~ ». Aucun secret visible par git.
  **Bot jamais démarré** (GO non cliqué) : à faire seulement quand la copie de Weefe est arrêtée (même token).
  Salons status/chat/admin encore à `-1` dans `servers.yaml`.
- 19/10/2026 : **bot démarré et connecté à Discord** sur le PC de Thibaud (log : « Discord Bot started, accepting commands »,
  plugin BlueSky chargé, serveur DCS « Blue sky » détecté). Bug corrigé dans `tools\bluesky_control_center.py` : le bouton GO
  passait le chemin du lanceur sans guillemets → cassé par les espaces du chemin, le panneau tournait dans le vide.
  `CHANGER-TOKEN.cmd` ajouté (= `CONFIGURER-DISCORD.cmd -ReplaceExisting`). Intents du bot : Members + Message Content ON
  (Presence non requis par DCSServerBot).
  `cloud.yaml` (config + modèle) : `register: false` (plus d'envoi des stats d'usage / IP publique au cloud DCSServerBot,
  demandé par Thibaud) ; `upload_errors: true` gardé (rapports de plantage). Prend effet au prochain redémarrage du bot.

- 19/10/2026 : **commerce triangulaire DCS ↔ bot Discord ↔ site** (demandé par Thibaud), le bot est le pivot.
  Schéma et mise en route : `circuit_site\INSTALLATION.md` § 0.
  - Plugin `bot BS\plugins\bluesky` v1.1 : `scores.py` (lecture Scores.lua + grades), `commands.py` (boucles + slash),
    `listener.py` (chat en jeu), `lua\` (callbacks → charge `mission.lua` qui lit position/cap/alt/vitesse des joueurs,
    appelé par `send_to_dcs_sync({'command':'bsGetLive'})`), `db\` (tables activité/présence, `update_v1.0.sql` pour l'install existante).
  - DCS → site : stats (à chaque changement de Scores.lua), joueurs en ligne, carte live toutes les 30 s, heure in-game.
    DCS → Discord : fil promotions / bilans / vols perdus (diff de Scores.lua, salon `feed_channel`, coupé par défaut),
    `/pilote` (autocomplétion), `/classement [critère]`, `/enligne`.
    Discord → site : messages/jour (compteur `on_message`, démarre à 0 : pas d'historique), moyenne en ligne par heure
    (relevé toutes les 15 min), nouveaux membres 30 j, planning = **événements Discord** (lignes `Type :`, `Carte :`, `Places :`).
    Discord → DCS : `/annonce` (DCS Admin), popup en jeu à la création d'un événement (`announce_events_ingame`).
    Chat en jeu : `-discord`, `-site`, `-stats` (aucun message automatique à la connexion, conforme à la demande).
  - `Code.gs` : accepte `stats` (= `scores`), `live`, `discord` (gardés en propriétés de script, ≤ 9 ko), `?format=live`,
    `discord` ajouté à `?format=json`. **À redéployer** (nouvelle version) quand l'Apps Script sera créé.
  - Site : `data.js` une seule requête relais pour stats + Discord ; `loadEvents()` (événements Discord sinon `evenements.js`) ;
    carte : « Hors ligne » si données > 3 min, heure in-game réelle, noms d'avions lisibles, rafraîchie toutes les 15 s ;
    `config.js` : `liveFile`, `discordFile` (sources fichier optionnelles).
  - Config locale `bot BS\config\dcssb\plugins\bluesky.yaml` créée (valeurs par défaut, relais vide).
  - Vérifié : import du plugin avec le moteur (4 slash, 3 commandes chat), lecture du vrai Scores.lua (22 pilotes),
    fil simulé (promotion, bilan, vol perdu), événement Discord simulé, export fichier, syntaxe Lua (luaparse 5.1),
    Code.gs (node), pages Discord / Accueil / Carte testées dans le navigateur avec des JSON du bot simulés (+ cas hors ligne
    et mode démo sans source), aucune erreur console.
    **Pas testé en réel** : bot pas redémarré avec le plugin, Apps Script pas encore déployé, positions DCS jamais relevées en jeu.

- 19/10/2026 : **Apps Script déployé par Thibaud** (feuille « BS Stats », propriété TOKEN, Application Web « Tout le monde »).
  URL mise dans `web/js/config.js` (statsUrl), `bluesky.yaml` (relay.url + token) et `secrets.local.ps1`.
  Testé : POST stats (22 pilotes de `mission/Scores.lua`) et live → `ok`, mauvais token → `forbidden`,
  `?format=json` / `?format=live` OK, page Classements locale en vraies données. Site poussé (GitHub Pages).
  Reste : redémarrer le bot (STOP/GO) pour charger le plugin, `feed_channel` à remplir, test en jeu.

- 19/10/2026 (soir) : **premier test réel DCS ↔ bot ↔ site** (mission lancée en multi sur le PC de Thibaud). Diagnostic :
  - Le bot **s'est bien connecté** à DCS (événements, slot F/A-18, `bsGetLive`), mais `max_hung_minutes: 0` (censé désactiver,
    d'après la doc) était lu comme « 0 minute » par DCSServerBot 3.0.4.27 → serveur déclaré planté au bout d'1 min, passé en
    SHUTDOWN, plus aucune carte live / joueurs en ligne. **Corrigé** dans `bot\DCSServerBot\services\monitoring\service.py`
    (`if max_hung and …`). DCS lancé en client (pas `-w`) → le bot ne trouve pas le processus : normal, sans conséquence maintenant.
  - `/classement` « Thibaud 0 pt » : le bot lit le `Scores.lua` **du PC** (`Saved Games\DCS`), qui ne contenait que le vol du jour.
    Pire : au démarrage le bot l'a publié → le relais (et le site) n'avaient plus qu'1 pilote. **Corrigé** : `mission\Scores.lua`
    (22 pilotes) fusionné avec le vol du jour → `Saved Games\DCS\Scores.lua` (sauvegarde `bakup\Scores_PC-Thibaud_2026-10-19_avant-fusion.lua`),
    puis republié au relais (22 pilotes vérifiés). ⚠️ Le Scores.lua de la machine qui fait tourner le bot = la vérité du site.
  - La mission réellement lancée était une **vieille copie** : `Saved Games\DCS\Missions\multi\Caucasus\Blue sky multi\` (18/10 20:08,
    script sans grades ni sauvegarde sûre). La .miz de `site\mission\` contenait aussi un script antérieur → **script actuel injecté**
    (nom interne `l10n/DEFAULT/multi jours thib.lua`, sauvegarde `bakup\…_2026-10-19_17-51-26.miz.bak`). Lancer **cette** .miz.
  - Site : le point vert « Serveur · N en ligne » était **codé en dur**. Maintenant `loadServer()` (`data.js`) lit le live du bot :
    hors ligne si données > 3 min (point gris), sinon nombre de connectés. Le bot ajoute `online` (tous les connectés) et `mission`
    au live. Accueil (« En ce moment ») branché dessus aussi. Testé en local (cas hors ligne), **pas encore poussé**.
  - Serveur invisible en multi : pare-feu Windows OK (règles DCS TCP/UDP 10308 entrantes). Box **SFR**, PC en
    une IP en Ethernet **et** une en Wi-Fi → redirection 10308 TCP+UDP à faire sur la box vers la bonne IP + bail DHCP fixe.
    IP publique (à comparer avec l'IP WAN de la box pour écarter un CGNAT).
  - **Fait par Thibaud** (box GR140IG) : bail statique (câble) → IP fixe du PC (PC renouvelé, OK),
    anciennes règles (33674, 10308 UDP) supprimées, nouvelle règle « DCS » 10308 TCP/UDP → IP fixe du PC.
    ⚠️ La box avertit que l'IPv4 utilisateur peut ne pas marcher « en raison de l'architecture de routage IPv6 WAN »
    → IPv4 partagée probable (MAP-T / DS-Lite, plage de ports limitée).
  - **CGNAT confirmé** (menu WAN) : IPv4 WAN de la box = **privée** ; l'IP publique
    est partagée par SFR. **Aucune redirection de port ne peut marcher** : c'est la vraie raison pour laquelle personne
    ne voit le serveur. Solution : demander à SFR une **IPv4 dédiée / « full-stack »** (service client 1023). Ensuite la règle
    10308 → .200 déjà créée suffit. Plan B : tunnel (playit.gg, ZeroTier/Radmin) ou laisser Weefe héberger.

- 19/10/2026 (nuit) : **statut serveur et équipe corrigés** (analyse du code via Graphify, dépôt indexé à 284f85d).
  - Le bot publie le live dès que la mission tourne, même vide → le site mettait un point vert « 0 en ligne ».
    Maintenant (`data.js` `serverLabel`, `layout.js`, `accueil.js`, `carte.js`) : vert / « EN DIRECT » **seulement avec ≥ 1 joueur** ;
    mission vide = point gris « personne en ligne » / « SERVEUR VIDE » ; serveur éteint = « hors ligne », mission « Serveur DCS éteint ».
  - L'heure in-game de l'Accueil et de la Carte était une **fausse horloge** (heure locale + 6 h 17) affichée même serveur éteint :
    `fmt.gameClock` = heure envoyée par le bot (`missionTime`), horloge fictive seulement en démo, sinon `--:--:--`.
  - « L'équipe » : n'affiche plus les insignes de grade aux points mais les **rôles fixes du Discord BS**. Le bot exporte `staff`
    (`discord_data` → `staff_json`, réglage `staff_roles` dans `bluesky.yaml` : noms/IDs ; vide = auto, rôles affichés à part avec droits
    de modération ; couleur du rôle Discord). Site : `loadStaff()` + `roleBadge()`, repli sur `C.staff` de `config.js` tant que le bot
    n'a pas republié. Indicatif/prénom repris de `C.staff` si le pseudo Discord correspond.
  - Testé en local : cas réel (serveur éteint), mission vide simulée, rôles Discord simulés. **Bot pas redémarré** (nécessaire pour `staff`), rien poussé.
  - Lecture directe des rôles via le token du bot refusée par la sécurité de Claude Code : passer par le bot.
- 19/10/2026 : **audit conformité juridique (étape 0)** fait, en attente des réponses de Thibaud avant rédaction
  (mentions légales, confidentialité, cookies, CONFORMITE.md). Voir la session du 19/10.
- 21/10/2026 : **audit refait et enregistré dans `CONFORMITE.md`** (celui du 19/10 n'avait pas été écrit), analyse via Graphify (commit 249fa05).
  Site sans connexion, sans cookie, sans traceur, sans contenu publié par les visiteurs → pas de bandeau cookies.
  Tiers recevant l'IP des visiteurs : Google Fonts, unpkg, OpenStreetMap, Discord, Apps Script. Le bot stocke UCID + IP des joueurs.
  Prévu : liens « Mentions légales · Confidentialité · Cookies » dans le pied de page bleu. En attente des réponses de Thibaud (§ 2 de CONFORMITE.md).
- 21/10/2026 : **mise en conformité faite** (Thibaud : particulier, non monétisé, anonyme, hébergeur GitHub, pas d'âge minimum).
  - Pages `mentions-legales.html`, `confidentialite.html`, `cookies.html`, `mes-donnees.html` (formulaire « Supprimer mes stats ») ;
    liens dans le pied de page de toutes les pages (`layout.js` : colonne « Infos légales » + dernière ligne), « Beynost » retiré.
  - Polices (`web/assets/fonts/`) et Leaflet (`web/assets/leaflet/`) hébergés sur le site : plus d'appel à Google Fonts / unpkg.
  - `Code.gs` : type `suppression` sans token → onglet « Demandes » + e-mail. **À redéployer** (nouvelle version) par Thibaud.
  - `tools/supprimer_pilote.py` : retire un pilote de Scores.lua (sauvegarde dans bakup) et de stats.json.
  - Durées proposées (Thibaud voulait « à l'infini », non permis) : stats 3 ans sans connexion, base du bot 12 mois. À valider.
  - Testé en local (pages, mobile, formulaire simulé, carte, Code.gs simulé). Détails et reste à faire : `CONFORMITE.md`.
  - **Poussé et en ligne** (vérifié sur GitHub Pages). Une autre session avait mis en ligne une 1re version le 20-21/10
    (placeholders publics, Google Fonts) : remplacée à la fusion, ses remarques utiles reprises dans `CONFORMITE.md` § 7.
  - Apps Script **redéployé par Thibaud** + `testMail` lancé pour autoriser les e-mails : formulaire et mail testés, **tout marche**.
    Demandes → onglet « Demandes » de BS Stats + e-mail. Une ligne TEST y a été créée par Claude (à effacer).
- 21/10/2026 : **ménage des commandes du bot + missions/inscriptions + temps vocal** (plugin `bluesky` v1.2, demandé par Thibaud).
  - Commandes : plugins `creditsystem` et `cloud` retirés de `main.yaml` (config + modèle). Les autres restent chargés car requis
    (mission ← gamemaster et missionstats, monitoring ← userstats) ; leurs commandes inutiles sont **masquées** par `bluesky`
    avant l'enregistrement sur Discord (`hide_commands` / `hide_chat_commands` dans `DEFAULTS` de `commands.py`).
    Restent : `/pilote /classement /enligne /annonce`, modération `/player …`, `/watch …`, `/link /unlink /find /info /linkme`,
    `/dcs ban|unban|bans`, `/serverstats /serverload` ; en jeu `-ban -kick -spec -mute -unmute -linkme -911 -discord -site -stats`.
    `/node upgrade` (mise à jour du bot) masqué exprès : il écraserait les patchs locaux (max_hung, messages d'accueil).
  - Missions : clic droit sur le briefing dans #missions-dcs (`mission_channel` 1419768783282896987) → Applications →
    **Publier sur le site** (rôle `DCS Admin`) → liste des événements Discord à venir → le bot poste un **sondage Discord natif**
    (Présent / Peut-être / Absent, fermé à l'heure de l'événement) dans #inscriptions (`signup_channel` 1562459201618452540).
    Lien événement ↔ briefing ↔ sondage par **ID d'événement** (table `bluesky_missions`, purgée 7 j après l'événement).
    Les votes marchent même bot éteint (sondage Discord) ; le site se met à jour quand le bot tourne (toutes les 15 min).
  - Site : carte d'événement = pseudos Présent / Peut-être (Absent : nombre seulement), boutons **Voir la mission**
    (`mission.html?id=…`, nouvelle page : texte Discord mis en forme + photos) et **S'inscrire** (sondage, sinon salon #inscriptions,
    `C.signupChannel`). Nouveau graphique **Temps en vocal par jour** sous celui des messages (démo tant que le bot n'a rien compté).
  - Vocal : `on_voice_state_update`, total par jour (table `bluesky_voice`, secondes), hors salon AFK et casque coupé, aucun nom gardé.
  - `Code.gs` : type `missions` (une propriété `MISSION_<id>` par briefing, 9 ko max, texte raccourci si besoin) et
    `?format=mission&id=…` ; `voice` raccourci avec `days`. **À redéployer** (nouvelle version) par Thibaud.
  - Confidentialité : § 5 « Inscriptions aux missions », temps vocal (§ 4), 2 durées de conservation ; cookies : Discord sur page Mission.
  - Testé : import du plugin et masquage des commandes (arbre de commandes simulé), découpe du vocal par jour, sondage et menu
    discord.py 2.7.1 ; site avec relais simulé (desktop + mobile, page mission, mission introuvable, photo expirée → lien Discord).
    Plugin déployé dans `bot\DCSServerBot\plugins\bluesky`. **Pas testé en réel** : bot pas redémarré, Code.gs pas redéployé, rien poussé.
  - Limites : liens photo Discord valables ~24 h, renouvelés par le bot → si le bot est éteint plus d'un jour, la page mission
    affiche « Photo visible sur le Discord ». Même token que Weefe : si c'est sa copie du bot qui tourne, le clic droit
    « Publier sur le site » et les nouvelles commandes n'existent pas (ses commandes à lui reviennent).

- 21/10/2026 (fin d'après-midi) : **retours du premier test réel**.
  - « Réservé au rôle DCS Admin » : dans `config\dcssb\services\bot.yaml`, `DCS Admin` et `Admin` étaient **vides**
    (personne n'avait les droits, /annonce et la modération comprises). Mis : rôle `=✪=Blue Sky CAG=✪=` (Thibaud, Weefe), aussi dans
    le modèle. « Publier sur le site » accepte en plus le propriétaire du serveur et la permission Administrateur.
  - Graphique vocal en démo : le bot n'envoyait rien tant qu'aucune minute n'était comptée → il envoie maintenant des zéros dès le départ.
  - Lieu d'événement = lien Discord affiché comme carte (débordait) : le bot l'exporte en `link`, le site affiche un bouton
    « Voir le salon » / « Ouvrir le lien » (le site corrige aussi les anciennes données). Photos DCS de Thibaud en fond des cartes
    « Prochain vol » (`assets/ravito-b52.webp` accueil, `assets/cockpit-c130.webp` page Discord).
  - Il faut **redémarrer le bot** (STOP/GO) pour bot.yaml et le plugin.
- 21/10/2026 (soir) : **onglet Événements + équipe**.
  - « L'application ne répond plus » sur Publier sur le site : réponse Discord après 3 s (log : `Unknown interaction`) → le bot
    répond tout de suite (`defer`) puis envoie la liste.
  - Nouvelle page `evenements.html` (onglet « Événements » dans la barre) : bannière Apache (image 7 de Thibaud,
    `assets/vol-evenements.webp`), carte Prochain vol (B-52), « Comment ça marche », planning, bandeau C-130.
    Code du planning déplacé de `discord.js` vers `pages/evenements.js` ; la page Discord garde un lien vers l'onglet.
    Accueil, page mission et message du sondage pointent vers `evenements.html`.
  - Équipe : icônes de rôle (`C.roleIcons` : CAG =✪=, AWACS 📡, ATC 🌐), nom de rôle sans décorations, couleurs trop claires
    assombries, Joshua gardé finalement (rôle MIAOU, icône 🐱) ; `staff_roles` dans `bluesky.yaml` : CAG, AWACS, ATC, MIAOU ;
    `C.staffHidden` permet de masquer quelqu'un si besoin.
  - Communauté : Vétérans violet, Pilotes Blue Sky vert clair, Aviateurs bleu, Visiteurs vert foncé.
- 21/10/2026 (soir) : **premier vrai test de publication réussi** (sondage posté, 2 votes). Mais le site restait à « 0 présent » :
  le bot n'envoyait qu'au moment de la publication puis toutes les 15 min. Plugin **v1.3** :
  - chaque vote/retrait de vote dans un sondage d'inscription (`on_raw_poll_vote_add/remove`) déclenche un envoi au relais
    **1 min** après (réglage `vote_delay` ; tous les votes de cette minute = un seul envoi) ;
  - **nombre de places** demandé à la publication (fenêtre après le choix de l'événement, vide = illimité, prérempli par
    « Places : N » de la description) ; colonne `slots` de `bluesky_missions` (`update_v1.2.sql`), affiché dans le message du
    sondage et sur le site (« 2 présents / 8 », « Complet »).
  - Testé hors ligne (fenêtre, envoi groupé). Plugin déployé ; **STOP/GO du bot nécessaire**.
- 21/10/2026 (soir) : **liste d'attente + choix manuel des participants** (demande de Weefe ; les sondages Discord ne permettent
  pas de bloquer « Présent » ni de retirer un vote). Plugin **v1.4** :
  - Sans limite de places : tous les ✅ Présent participent (inchangé).
  - Avec limite : les ✅ Présent sont candidats ; le staff choisit par **clic droit sur le sondage → Applications →
    Choisir les participants** (cases à cocher, au plus N, 25 candidats max par liste Discord). Table `bluesky_selected`.
    Les non choisis = liste d'attente. Un choisi qui retire son vote sort des retenus.
  - Message « ✈️ Participants (x/N) / ⏳ Liste d'attente » posté en réponse au sondage (noms sans notification), modifié à
    chaque changement (`status_message_id`). Message du sondage : explique places limitées ou illimitées.
  - Site : « 1 retenu / 1 · 2 en attente », pastilles ⏳ jaunes, bouton « Liste d'attente » quand c'est plein.
    Bug corrigé : un vol ce soir affichait « Demain » (calcul en tranches de 24 h → jours calendaires).
  - Confidentialité § 5 : retenus / liste d'attente sur le site et dans le salon.
  - Testé hors ligne (répartition, message, liste à cocher) + site avec données simulées. Plugin déployé ; **STOP/GO nécessaire**.
- 21/10/2026 (soir) : **photo en fond des cartes d'événement** (onglet Événements). Le bot exporte `image` : bannière de
  l'événement Discord (`cover_image`, lien permanent), sinon 1re photo du briefing (lien ~24 h renouvelé par le bot), sinon rien.
  Site : classe `.event.has-img` (photo + voile sombre, texte blanc) ; si le lien ne charge plus, la carte redevient blanche.
  Testé avec données simulées (bannière, photo expirée, sans image). Plugin déployé ; **STOP/GO nécessaire**.

- 22/10/2026 : **référencement Google**. Propriété Search Console validée par fichier (`web/google39ebbca43b85ea0c.html`,
  **ne jamais le supprimer**). `web/sitemap.xml` (10 pages, sans mission.html) envoyé dans Search Console, indexation de l'accueil demandée.
  Sur les 10 pages : `canonical`, Open Graph (aperçu Discord, image `forma-eiffel.webp`), `twitter:card` ; accueil : JSON-LD `Organization`.
  Pas de robots.txt (Google ne le lit qu'à la racine de thibaero278.github.io). Nom « Bluesky » (réseau social) : pas de risque juridique
  a priori, mais viser « Blue Sky France DCS » plutôt que « Blue Sky » dans Google.
- 22/10/2026 : **audit d'optimisation** (Graphify, commit 6a43aa8), rien de modifié. Points relevés, par priorité :
  1. Quota Apps Script « Properties read/write » (50 000/jour en compte gratuit) : le bot écrit LIVE toutes les 30 s (2 880/jour)
     et chaque onglet ouvert lit LIVE + DISCORD toutes les 30 s (carte : toutes les 15 s) → passer par CacheService + n'envoyer le live
     vide que toutes les ~2 min. `?format=json` relit 3 onglets Sheets à chaque visite → mettre le JSON en cache.
  2. Carte : si le relais ne répond pas au 1er chargement, elle affiche 11 faux pilotes en démo et ne réessaie plus jamais.
  3. Code mort : `refreshSeconds` (inutilisé, 30 s codé en dur dans layout.js), `discordActivityUrl`, sources fichier
     (`liveUrl/liveFile/discordFile/missionsFile` + `export_dir` du bot), `Page.html` + page HTML de `doGet` (Google Sites abandonné),
     ~~`BS_site.lua`~~ : finalement **gardé** (seul moyen d'avoir les stats d'un serveur où notre bot ne tourne pas, ex. Weefe).
  4. Grades recopiés à 3-4 endroits (RANKS Lua, `data.js`, `scores.py`) ; rafraîchissements qui tournent onglet caché (carte) ;
     nombre de membres Discord relu sur l'API publique alors que le bot l'envoie déjà ; pas de météo réelle sur la carte.
  5. Ménage local : `BlueSky-Founder-Package-*.zip` (1,4 Go, **contient le vrai token**) à sortir du dossier du projet ;
     `_design_zip/` (60 Mo) et `Site web serveur Discord Blue Sky.zip` (62 Mo) devenus inutiles.
- 22/10/2026 : **optimisations faites** (suite de l'audit, demandées par Thibaud).
  - `Code.gs` : lectures du site servies par **CacheService** (live, `?format=json` complet, token) ; live copié dans les
    propriétés au plus toutes les 5 min (secours) ; feuille relue seulement après un envoi de stats/Discord/changelog.
    Page HTML de `doGet` et `Page.html` supprimées (`doGet` sans format = petit texte). Simulé dans node : 10 envois live = 2 accès
    propriétés, 20 visites = 1. Sauvegarde : `mission\bakup\Code_2026-10-22_avant-cache.gs`. **À redéployer** (nouvelle version) par Thibaud ;
    le fichier HTML « Page » peut être supprimé de l'éditeur Apps Script.
  - Bot (plugin, toujours v1.4) : serveur DCS sans personne → live envoyé toutes les `live_idle_interval` s (120) au lieu de 30 ;
    `export_dir` supprimé. Testé avec le moteur (5 tours vide = 1 envoi ; joueur = envoi à chaque tour). Déployé ; **STOP/GO nécessaire**.
  - Site : carte relue toutes les 30 s si le serveur tourne, 2 min sinon, rien onglet caché ; relais injoignable = « Hors ligne »
    (plus de faux pilotes de démo, la carte réessaie). Rafraîchissement général : 30 s serveur allumé, 2 min serveur éteint.
    Membres / en ligne Discord : chiffres du bot (s'ils ont moins de 30 min), sinon API publique des invitations.
    Réglages morts retirés de `config.js` (`refreshSeconds`, `liveUrl`, `liveFile`, `discordFile`, `missionsFile`, `discordActivityUrl`).
    Testé en local : carte (relais réel serveur éteint + relais coupé), Discord (143 membres du bot, 0 appel API), accueil,
    événements, mission introuvable, aucune erreur console.
  - Ménage : `BlueSky-Founder-Package-*.zip` déplacé dans `jeux\dcs\Archives Blue Sky (confidentiel)\` ;
    `_design_zip\` et `Site web serveur Discord Blue Sky.zip` mis à la corbeille.
  - Grades (3 copies) et météo de la carte : laissés tels quels (choix de Thibaud).
- 22/10/2026 (après-midi) : **« En vocal maintenant » ne s'affichait jamais** (page Discord). Le site (commit 6dcaf1d) attendait
  `voiceLive` dans les données Discord, mais le plugin ne l'envoyait pas. Ajouté au plugin (toujours v1.4) : `voice_live()`
  (nom du salon, nombre de connectés hors bots, depuis quand le salon est occupé, lien ; aucun pseudo ; salon AFK exclu),
  envoi groupé `voice_delay` s (30) après chaque entrée/sortie de vocal via `push_soon`, en plus de l'envoi des 15 min.
  « Depuis » repart de l'heure de démarrage du bot pour les salons déjà occupés à ce moment. Testé hors bot (salons simulés :
  entrée, AFK, salon avec bot seul, sortie). Déployé (`Install-BlueSkyPlugin.ps1`) ; **STOP/GO nécessaire**.
  `Circuit-Blue-Sky.pdf` (schéma complet du circuit, 18 p.) est à la racine du dépôt, non suivi : ne pas le committer.
- 31/10/2026 : **`troll.ogg` jouait en quittant le slot** (DCS envoie Dead/PilotDead pour l'avion retiré). Son retiré de
  `OnPlayerDeath` : il ne joue plus qu'au train cassé sur PA (une vraie mort ne le joue plus non plus).
  Sauvegarde `mission\bakup\script Caucase 2026-10-31_1541.lua`. **Validé en jeu par Weefe.**
- 03/11/2026 : **carte, atterrissages, SRS de l'hôte**.
  - Carte : silhouettes d'origine de tar1090 (ADS-B Exchange, GPL v2+, sélection dans `web/js/markers.js` avec la source),
    à la place des dessins maison (les porte-avions restent dessinés maison). Trajectoire lissée (Chaikin). Fiche d'un joueur = ses stats (grade, points,
    heures, victoires, appontages, atterrissages). Aérodromes : barre diagonale. Pseudo de la fiche moins serré.
  - `script Caucase.lua` : compteur `landings` (atterrissage sur base terrestre, même endroit que la musique PA.ogg),
    affiché au message d'arrivée et au kneeboard des scores. Sauvegarde `bakup\script Caucase_2026-11-03_avant-atterrissages.lua`.
    **Intégré dans la .miz du MSI** (`Saved Games\...\Blue sky multi\`, ancienne .miz dans `bakup\..._2026-11-03_00-33-48.miz.bak`) :
    elle contenait encore la version du 18/10 (sans grades), elle a maintenant la v2 complète. .miz déposée dans FICHIERS pour Weefe.
  - `Code.gs` : colonne `landings` / « Atterrissages » (en-têtes réécrits à chaque envoi). **À redéployer.**
  - SRS : le serveur SRS démarre bien, mais SRS n'envoie l'auto-connexion qu'aux joueurs qui rejoignent, jamais à l'hôte (id 1).
    `callbacks.lua` (plugin bluesky) lance le client SRS de l'hôte à `onSimulationStart` (srs.dll du mod DCS-SRS, 127.0.0.1:5002).
    Pas testé en jeu. Le hook auto-connexion de DCSServerBot n'est posé que si le bot démarre DCS lui-même.
  - Constat : `publish_stats` n'envoyait que le Scores.lua du serveur concerné et Code.gs écrase la feuille → quand Weefe
    hébergeait, ses scores remplaçaient ceux du MSI sur le site. Réglé par la fusion ci-dessous.
- 03/11/2026 : **scores fusionnés sur R2D2** (plugin bluesky v1.5, idée de Weefe adaptée : R2D2 au lieu de Google).
  - Tables `bluesky_scores` (total par pilote) et `bluesky_scores_base` (dernier Scores.lua lu par serveur), migrées sur R2D2.
  - Chaque lecture d'un Scores.lua ajoute au total ce que ce serveur a gagné depuis sa lecture précédente (une baisse
    n'enlève rien) ; un serveur jamais lu = import au **maximum par stat** (sans annonce de promotion). Base gardée en
    Postgres : ce qui est fait pendant une coupure de R2D2 est rattrapé. Site, `/pilote`, `/classement`, `-stats` = total.
  - En jeu : quand le script de mission est chargé (`scoresReady` dans bsGetLive), le bot envoie le total
    (`bsSetScores` → mission.lua remplace `Scores` et appelle `SaveScores`), confirmé par `scoresSynced` ; sans
    confirmation en 60 s ou mission finie : base d'avant remise, renvoi au tour suivant.
  - Testé hors bot (faux serveurs/base/DCS : départ au max, gains simultanés, envoi perdu, redémarrage de R2D2) et Lua (lupa).
    Première lecture réelle du MSI faite (22 pilotes importés). Pas encore vu : le serveur de Weefe lu par R2D2, l'envoi du total en jeu.
  - Sauvegarde du plugin d'avant : `~/backups/bluesky-plugin-avant-fusion-20261103.tgz` sur R2D2.
  - Suppression RGPD : étape SQL ajoutée dans `CONFORMITE.md` § 5 (sinon le pilote revient).
- 03/11/2026 : **Scores.lua de Weefe importé dans celui du MSI** (stats seulement : maximum par stat, grades du MSI gardés,
  « Player »/« Joueur » ignorés). 22 → 24 pilotes (MR WHITE, noxi), 1074 points, déjà repris par R2D2.
  Sauvegardes : `bakup\Scores_MSI_2026-11-03_avant-fusion-weefe.lua` et `bakup\Scores_Weefe_2026-11-03.lua`.
  Doublons de pseudo non fusionnés (ex. « Napster 1-1 | Lixx » / « Napster1-1 | Lixx »).
- 03/11/2026 : **SRS de l'hôte, vol en cours sur la carte, confidentialité, icône Google**.
  - SRS (logs client/serveur + bot) : le client de l'hôte était lancé à `onSimulationStart`, mais le serveur SRS (démarré par
    le bot avec la mission) n'écoute qu'après ~10 s (essai UPnP, `UPNP_ENABLED=true` dans `Config\SRS.cfg`) → refusé.
    Le serveur SRS s'arrête aussi en fin de mission et quand le bot est arrêté (STOP) : sans bot, pas de SRS.
    `callbacks.lua` attend maintenant que le port 5002 réponde (essai toutes les 2 s, 3 min max) avant de lancer le client.
    Testé hors jeu (lupa). Sauvegarde `mission\bakup\callbacks_2026-11-03_avant-attente-srs.lua`.
  - Carte : `mission.lua` envoie `flight` par joueur en vol (durée, points, ravitaillement, kills A/A, A/S, A/M en attente,
    lus dans `Flights` de `script Caucase.lua`) ; la fiche du joueur l'affiche (sans titre). Fiche allégée à la demande de
    Thibaud : grade = insigne à côté du pseudo, stats totales = points et heures seulement (plus de victoires, appontages, atterrissages). Testé dans le navigateur
    avec un faux relais. Relais (Code.gs) inchangé : il garde le JSON tel quel.
  - Plugin déployé : moteur local, R2D2, `partage/maj` (Weefe). **STOP/GO nécessaire** sur le MSI, MAJ chez Weefe.
  - `confidentialite.html` (3/11) : stats additionnées entre serveurs, atterrissages, vol en cours et trajectoire sur la carte,
    stockage sur un serveur personnel du fondateur en France. Sauvegarde `mission\bakup\confidentialite_2026-11-03.html`.
  - Icône grise dans Google : `https://thibaero278.github.io/` (racine) renvoie 404. Google prend l'icône et le nom du site
    (« GitHub Pages documentation ») sur la page d'accueil de l'hôte, pas sur `/blue-sky-france/`. Page racine préparée dans
    `serveur BS\racine-github-io\` (à publier dans un dépôt `thibaero278.github.io`). Favicon des pages passé à
    `icon-192.png` (Google veut un carré multiple de 48 px ; `ecusson.png` fait 800 px).
- 03/11/2026 : **menu STATISTIQUES par joueur + message d'accueil** (`script Caucase.lua`, chantiers 1 et 2 ci-dessous).
  `ForEachGroupPlayer` : « Mes scores » et « Echelle des grades » envoient à chaque joueur du groupe **ses** stats
  (`outTextForUnit`) ; Top 10 toujours au groupe. Sous-menu GRADES et `SetPlayerGrade` supprimés, « (ROOKIE) » retiré de « Mes scores ».
  Accueil dans `ScoreMenuHandler:OnEventBirth` (15 s, au joueur seul, à chaque apparition).
  Testé hors jeu (lupa, Lua 5.1, faux MOOSE : groupe de 2 joueurs + 1 place vide, accueil). **Pas testé en jeu.**
  Sauvegarde `bakup\script Caucase_2026-11-03_avant-menu-par-joueur.lua`. Injecté dans la .miz du MSI
  (`Saved Games\DCS\Missions\multi\Caucasus\Blue sky multi\`, + copie libre du script à côté), ancienne .miz :
  `bakup\Blue Sky Multi-joueur DAY_Caucasus_2026-11-03_11-55-38.miz.bak`. **Validé en jeu par Thibaud** ; .miz déposée dans FICHIERS pour Weefe.
- 03/11/2026 : **fusion des pseudos par UCID** (plugin bluesky, version laissée à 1.5 : pas de nouvelle table).
  - `bluesky_scores` reste **par pseudo** (c'est lui qui est fusionné, logique inchangée). Le regroupement est une vue :
    `sc.aliases` (tables `players` + `players_hist` de DCSServerBot : pseudo → pseudo actuel du même UCID ; pseudo porté
    par plusieurs UCID = ambigu, pas touché), `sc.group` (somme, max pour `maxFlightTime`). Utilisé par le site, `/pilote`,
    `/classement`, `-stats`, le fil des promotions. Alias relus à chaque tour de `stats_loop` (60 s).
  - En jeu : `sc.for_mission` = total regroupé sous le pseudo actuel + **anciens pseudos remis à 0** (`bsSetScores` ne
    retire pas de pilote du fichier : sinon recomptés en double). Ce qui est envoyé devient la base du serveur.
  - **L'hôte n'avait pas d'UCID en base** (DCSServerBot ignore l'id 1, `Player.prep`) : `record_host` l'enregistre dans
    `players` avec la même requête que le moteur, dans `live_loop`, avant l'envoi du total.
  - Constat au déploiement : `players` était **vide** (personne n'avait encore rejoint en client, seuls les hôtes jouaient)
    → aucun regroupement tant que les joueurs ne se sont pas connectés une fois avec le bot en marche.
  - Testé : simulation (renommage, envoi en jeu, gains sous le nouveau puis l'ancien pseudo, pseudo ambigu, sans alias =
    comportement d'avant) + aperçu lecture seule sur les vraies données de R2D2. Déployé sur R2D2 (bot redémarré, aucune
    erreur), moteur du MSI, `partage/maj` pour Weefe. Sauvegardes : `~/backups/bluesky-plugin-avant-ucid-20261103.tgz`
    et dump de la base du 03/11 midi sur R2D2. **Pas encore vu en réel** : un joueur qui change de pseudo.
- 03/11/2026 : **suppression RGPD en une commande** : `/supprimer_pilote pseudo` (DCS Admin, confirmation oui/non) efface
  du total tous les pseudos du même UCID, republie le site, trace dans l'audit. Avant, un serveur oublié dans la procédure
  manuelle faisait revenir le pilote avec toutes ses stats.
  - `sc.merge` : un pseudo absent du total mais présent dans la base d'un serveur (= supprimé) est ignoré tant qu'il ne
    gagne rien ; s'il rejoue, seuls les nouveaux gains comptent.
  - `push_scores` : base du serveur = ancienne base + envoi (les supprimés y restent), et liste `remove` envoyée à la
    mission → `bsSetScores(json, removeJson)` (`mission.lua`, `lua/commands.lua`) les retire de `Scores.lua`.
    Compatible avec un agent pas à jour (argument ignoré, fichier nettoyé plus tard).
  - Testé : simulation (fichier pas nettoyé, envoi, retour du joueur, ancien agent) + Lua (lupa). Déployé R2D2 (aucune
    erreur), moteur du MSI, `partage/maj`. Sauvegarde `~/backups/bluesky-plugin-avant-rgpd-20261103.tgz`.
    **STOP/GO du MSI nécessaire** pour les fichiers Lua. Commande pas encore utilisée en réel.
  - `CONFORMITE.md` § 5 réécrit.
- 03/11/2026 : **slots dynamiques des bases ignorés par le script** (vol de Thibaud en F-5E-3_FC dynamique à Kobuleti,
  mission BAD NIGHT : aucun message). Cause : DCS n'a envoyé **aucun décollage** (absent du debrief.log) → pas de vol en
  cours → atterrissage ignoré ; l'apparition reposait sur `EventData.IniUnit` de MOOSE, souvent vide pour ces avions.
  Les deux missions (DAY et BAD NIGHT) ont le spawn dynamique sur 29 bases. Corrigé dans `script Caucase.lua` :
  apparition et menu F10 par les objets DCS (`IniDCSUnit`, groupe ajouté à MOOSE par `_DATABASE:AddGroup`),
  `GroupPlayerName` / `ForEachGroupPlayer` lisent les unités dans DCS, **détection de décollage de secours** toutes les 5 s
  (joueur en l'air sans vol en cours, pas dans les 10 s après la fin d'un vol), et un vrai Takeoff ne remet plus à zéro
  un vol déjà lancé. Testé hors jeu (lupa : slot dynamique sans IniUnit ni Takeoff, rebond, groupe à 2 joueurs).
  Sauvegarde `bakup\script Caucase_2026-11-03_avant-slots-dynamiques.lua` ; injecté dans les 2 .miz (anciennes dans `bakup\`).
  **Validé en jeu par Thibaud** (03/11). Les 2 .miz (DAY + BAD NIGHT) déposées dans FICHIERS pour Weefe.
- 03/11/2026 : **poussé sur GitHub** (plugin, script, docs ; fichiers jamais suivis de `bot BS/` laissés hors dépôt) puis
  **historique Git nettoyé** (`git filter-repo --replace-text`) : IP publique, MAC, IP de la box et IP locales remplacées par
  « (masqué) » dans tous les commits, push forcé (0 fork). Contenu final identique (même arbre). Sauvegarde de l'ancien
  historique : `serveur BS\sauvegarde-git-blue-sky-france_2026-11-03.git` (contient encore ces données, hors dépôt).
  Purge du cache GitHub des anciens commits (756f466, 249fa05, 284f85d) demandée au support : **ticket #4945116**
  (03/11, réponse attendue par mail). Supprimer la sauvegarde locale une fois le ticket clos.
  Hôte : l'UCID passe désormais par l'événement `bsHost` (lua/commands.lua → listener) ; le 1er essai (`server.get_player(id=1)`)
  ne marchait pas, le moteur ignorant l'hôte aussi en mémoire. **Vérifié** : `[ BS ]Thibaud | Breakdown` est dans `players` (03/11).
  - Carte : **trajectoire colorée selon l'altitude** (comme ADS-B Exchange) : orange au sol → vert 10 000 ft → cyan 20 000
    → bleu 30 000 → violet 40 000 ft et plus. Chaque point de trajectoire du bot porte l'altitude (`[lat, lon, alt ft]`,
    `update_trails`) ; les anciens points sans altitude restent dorés. Testé en local avec un faux vol. `commands.py` déployé sur R2D2 (bot redémarré, 0 erreur).

- 03/11/2026 (nuit) : **SRS toujours KO, trajectoire, classement, bannière Événements**.
  - SRS : le nouveau `callbacks.lua` était bien installé (01:34) mais DCS tournait depuis 01:03 : les hooks ne sont chargés
    qu'au **démarrage de DCS**, l'ancien code tournait encore (client lancé avant le serveur SRS). Il faut fermer DCS en entier.
    `UPNP_ENABLED=false` mis dans `Saved Games\DCS\Config\SRS.cfg` du MSI (CGNAT : UPnP inutile, retardait le serveur de 10 s),
    sauvegarde `mission\bakup\SRS_2026-11-03_avant-upnp-off.cfg`. Serveur SRS = `C:\Program Files\DCS-SimpleRadio-Standalone\
    ServerCommandLine-Windows\`, lancé et arrêté par le bot avec la mission (port 5002).
  - Trajectoire gardée après l'atterrissage jusqu'au décollage suivant (bot `update_trails` + `carte.js`), effacée à la
    déconnexion. Testé hors bot. `commands.py` déployé sur R2D2 (bot redémarré, 0 erreur) et `partage/maj`.
    `confidentialite.html` mise à jour en conséquence.
  - Classements : colonne Atterrissages, tri par Atterrissages et par Morts (bouton et en-tête cliquable). Testé en local.
  - Page Événements : la carte « Prochain vol » prend la bannière de l'événement Discord (B-52 si aucune), comme l'accueil.
    Publié (commit 4d41692).
  - Garde-fou quota Apps Script (`carte.js`) : relais lent (> 3 s) → intervalle de la carte doublé jusqu'à 60 s, relais rapide →
    divisé par deux jusqu'à 5 s ; relais en erreur → « hors ligne », relu toutes les 2 min. Testé avec un relais lent simulé (5 → 10 s).

- 03/11/2026 (soir) : **FICHIERS / MAJ en 403 chez Weefe**. Tailscale s'est mis à jour sur R2D2 à 6 h 23 ; depuis, Docker
  présentait les clients du partage avec l'adresse `172.18.0.1` au lieu de leur IP Tailscale et `partage.conf` refusait tout.
  Le conteneur `partage` tourne maintenant en `network_mode: host` (nginx écoute 8099 directement, vraie IP du client).
  Vérifié : Tailscale → 200, réseau local → 403. Sauvegardes `~/backups/*.avant-partage-host-20261103`.

- 03/11/2026 (soir) : **Mode Blue Sky** (demande de Thibaud). Choix : ouvert à tous ; activable **au sol seulement** ;
  coupé à l'atterrissage, à la mort / au crash / à l'éjection, au changement de slot, par le bouton, et à chaque apparition.
  - Mission : menu F10 **MODE BLUE SKY** (Activer (au sol) / Desactiver), table `BSMode`, champ `bsFlightTime` dans Scores.lua
    (temps du vol ajouté à la fin du vol, y compris s'il finit par une mort ; « Desactiver » en vol compte le temps déjà volé).
    Le clic vaut pour tous les joueurs du groupe (DCS ne dit pas qui a cliqué). Ligne dans « Mes scores », « Top 10 heures
    Blue Sky », rappel dans le message d'accueil. Sauvegarde `bakup\script Caucase_2026-11-03_avant-mode-bluesky.lua`.
    Testé hors jeu (lupa, faux DCS/MOOSE : 7 cas). **Pas testé en jeu.** Injecté dans les 2 .miz (DAY de `Saved Games\…\Blue sky multi\`,
    BAD NIGHT reprise du partage R2D2 et rangée dans `mission\`) ; anciennes en `bakup\*_2026-11-03_19-52-53.miz.bak`.
  - Plugin : `lua/mission.lua` envoie `bs: true` pour la carte ; `/pilote` (Heures Blue Sky) et `/classement` (critère Heures Blue Sky).
  - Site : F-18 aux couleurs Blue Sky sur la carte pour les pilotes en mode (livrée « Blue Sky Aerobatics » dessinée par Thibaud :
    `web/assets/f18-bluesky.svg` = original (PNG dans un SVG), `f18-bluesky.webp` 160 px = ce qu'affiche la carte), « Mode Blue Sky »
    dans la fiche ; colonne et tri « Heures Blue Sky » + ligne dans la fiche pilote (Classements). Testé en local (faux live).
  - `Code.gs` : colonne `bsFlightTime`. **À redéployer** (sinon le site affiche 0).
    04/11 : constaté que le relais en ligne ne renvoie toujours pas `bsFlightTime` → « H. Blue Sky » = 0 pour tous.
    Thibaud doit faire Déployer → Gérer les déploiements → ✏️ → nouvelle version. Site : `fmt.h1` affiche « < 0,1 »
    au lieu de « 0 » pour un temps non nul sous 3 min (le vol test de Weefe, 1 min 40, aurait sinon affiché 0).
  - Déployé le 03/11 au soir : site (commit 04ea838), plugin sur R2D2 (bot redémarré, 0 erreur ; sauvegardes
    `~/backups/*.avant-mode-bluesky-20261103`), `partage/maj` (2 copies du plugin) et les 2 .miz dans `partage/fichiers`.
    Reste : Thibaud STOP → GO sur le MSI, Weefe FICHIERS / MAJ + STOP → GO + .miz dans ses Missions, test en jeu.
  - ⚠️ Réenregistrer la mission dans l'éditeur DCS y remet l'ancien script (vu le 03/11 à 21 h 21) : recharger le
    « DO SCRIPT FILE » avant d'enregistrer, ou faire réinjecter le script.

- 04/11/2026 : **Durée de la mission sur la carte + multi-équipage** (après une grosse session sur le serveur).
  - Carte : case « Mission lancée depuis » (`uptime` = `current_mission.real_time` de DCSServerBot, temps réel pauses comprises,
    relevé au keep-alive, à ~1 min près ; le site avance l'horloge entre deux envois).
  - Multi-équipage (Apache, F-14…) : DCS n'envoie les événements qu'au nom du pilote. `lua/commands.lua` (hook) lit les places 2+
    (`getMulticrewAllParameters`, comme DCSServerBot) et les passe à la mission toutes les 5 s (`dcsbot.bsSetCrew` → `BSCrew`).
    Le script donne à **chaque place** son vol : heures, vols, kills et points entiers (validés à l'atterrissage), atterrissages,
    appontages, morts, teamkills, ravitaillement, mode Blue Sky (le clic vaut aussi pour l'équipage). Place montée en vol :
    vol démarré à la détection suivante (5 s) ; place quittée en vol : vol fermé, temps compté, kills perdus. Messages et son
    restent ceux du pilote (même écran). Sans le bot, l'équipage ne gagne rien (comme avant). Carte : « Pilote + Gunner ».
  - Sauvegarde `bakup\script Caucase_2026-11-04_avant-multi-equipage.lua`. Testé hors jeu (lupa : 7 cas mode Blue Sky + 4 cas
    équipage). **Lecture des places côté DCS pas testable hors jeu** (protégée par pcall). **Pas testé en jeu : à tester à deux.**
    Injecté dans les 2 .miz (anciennes en `bakup\*_2026-11-04_02-01-47.miz.bak`).
  - Déployé le 04/11 (2 h) : R2D2 (bot redémarré, 0 erreur ; sauvegardes `~/backups/*.avant-equipage-20261104`),
    `partage/maj` (2 copies) et les 2 .miz dans `partage/fichiers`. Site : commit 2029f62.
    Reste : STOP → GO (MSI et Weefe), Weefe FICHIERS / MAJ + .miz, **test à deux dans un Apache**.
  - 05/11 : bug vu sur la carte après le vol Apache Dex + Weefe : un F-14 au sol affichait « DEX … + Weefe » avec la trace
    de l'Apache alors que Dex était parti. Causes : DCS garde parfois l'ancien pilote dans `getPlayerName()` des multi-places,
    et la trace était rangée par pseudo (suivait le pilote dans un autre avion). Corrigé : `BSCrew` contient maintenant
    **tous** les occupants vus par le serveur (pilote en premier) et la carte n'affiche que ça (avion sans occupant réel = caché) ;
    la trace repart de zéro au changement de type d'avion (`commands.py`), zoom carte max 18. Site : commit 6e0d96e.
    Déployé le 05/11 : R2D2 (bot redémarré, BlueSky chargé, 0 erreur ; sauvegardes `~/backups/*.avant-fantome-20261105`),
    `partage/maj` (2 copies). Reste : STOP → GO sur le MSI, Weefe FICHIERS / MAJ + STOP → GO. Pas testé en jeu.
  - 05/11 soir : session de 2 h sur « Weefe le GOAT » : IA visibles mais **0 joueur** dans presque tous les relevés (log R2D2).
    Cause probable : le filtre strict ci-dessus (avion absent de `BSCrew` = caché). Remplacé par un filtre prudent : nom DCS
    gardé par défaut, avion caché seulement si son pilote est vu assis dans un autre avion. Déployé R2D2 + `partage/maj`
    (sauvegarde `~/backups/lua_mission.lua.avant-prudent-20261105`). Reste : Weefe FICHIERS / MAJ + STOP → GO, MSI STOP → GO.

- 05/11/2026 : **Section « Les records » sur la page Classements** (site seul, phase 1).
  - 11 records tirés des scores existants (points, heures, vol le plus long, heures Blue Sky, kills air/sol/mer, appontages,
    atterrissages, vols, ravitaillement) : pilote en tête + valeur, clic = fiche pilote. Égalité : le premier trouvé garde le record.
  - 5 cases vides « Pas encore de record » en attente de la **phase 2** (script de mission + `scores.py`, pas commencée) :
    champs attendus dans Scores.lua `maxKillsFlight`, `maxKillDistance` et `minKillDistance` (m, reprendre `shooterDist`
    déjà calculé au kill), `maxAltitude` (m, affichée en ft), `maxSpeed` (m/s, affichée en km/h).
    Côté bot : les ajouter à `MAX_FIELDS` ; `minKillDistance` doit garder le **plus petit** (cas à coder dans `merge`).
    `data.js` les lit déjà (max/min aussi pour la fusion des pseudos). Ces records partent de zéro (pas d'historique).
  - Abandonné : avion le plus joué (trop de travail : champ non numérique dans Scores.lua).
  - Phase 2 commencée le 05/11 : **`maxKillsFlight` codé** (record mis à jour dans `CommitFlightKills`, donc seulement pour les
    kills validés à l'atterrissage), ajouté à `MAX_FIELDS` du bot. `Code.gs` a déjà les **5** colonnes de records
    (un seul redéploiement Apps Script pour toute la phase 2). Convention : **0 = pas encore de record** (y compris pour
    `minKillDistance`, que `data.js` traite comme vide). Sauvegarde `bakup\script Caucase_2026-11-05_avant-record-kills-vol.lua`.
    Testé hors jeu (lupa : syntaxe + calcul du record ; fusion du bot). **Pas encore déployé** : script à réinjecter
    dans les 2 .miz, `scores.py` sur R2D2, `Code.gs` à redéployer, site à pousser. Restent à coder : distances, altitude, vitesse.
  - 06/11 : **`maxKillDistance` et `minKillDistance` codés**. Distance avion-cible au moment du kill (même `Distance2D`
    que le message en jeu, en m, arrondie, au moins 1 m), sans repli sur l'impact. Rangée dans le vol (`killFar` / `killNear`)
    puis validée avec les kills (`CommitFlightKills`) : vol crashé = distances perdues, comme les points. Chaque membre
    d'équipage a la même distance. Bot : `MIN_FIELDS` + `best()` dans `scores.py` (plus petit non nul ; utilisé par
    `merge` et `group`). Vérifié : `dcsbot.bsSetScores` recopie tous les champs, donc le total renvoyé en jeu garde les records.
    Testé hors jeu (lupa + fusion du bot). Même sauvegarde que ci-dessus. **Toujours pas déployé.** Restent : altitude, vitesse.
  - 06/11 : **`maxAltitude` et `maxSpeed` codés** → phase 2 entièrement codée. Nouvelle boucle `SampleFlights` (toutes les 1 s,
    sous pcall) : pour chaque joueur en l'air, altitude au-dessus de la mer (`getPoint().y`, m) et vitesse sol
    (norme de `getVelocity()`, m/s), rangées dans le vol de chaque membre d'équipage. Validées dans `CloseFlight` comme le
    vol le plus long, donc **gardées même si le vol finit en crash ou éjection** (différent des kills). Site : ft et km/h.
    Ajoutées à `MAX_FIELDS`. Testé hors jeu (lupa avec unités simulées + fusion du bot).
    **À déployer d'un coup** : script dans les 2 .miz, `scores.py` sur R2D2 (bot redémarré), site poussé
    (`data.js`, `classements.html`), et **Thibaud** : coller `Code.gs` dans Apps Script et redéployer. Puis test en jeu.
  - 06/11 : **« RECORD BATTU » en jeu + date des records**.
    - Script : `SetRecord(pilote, s, champ, valeur)` (avant `PlayerFromEvent`) remplace les mises à jour des 6 records
      (vol le plus long, kills en un vol, kill loin / proche, altitude, vitesse). Si le pilote bat le **record du serveur**
      (meilleur de la table `Scores` de la mission), message à tous 12 s : `*** RECORD BATTU ***` / record : pilote /
      valeur / `(ancien : … par …)`. Pas d'annonce pour un tout premier record (évite le spam au déploiement).
      Pas sur Discord (choix de Thibaud, pour l'instant). Avec équipage : une annonce par membre.
    - Date : posée par le **bot** (`merge`, champ `<record>At` = AAAAMMJJ en nombre, pour que Sheets ne le transforme pas),
      seulement quand le record perso monte, jamais au premier import d'un serveur. Les anciens records n'ont pas de date.
      `group` : la date suit le pseudo qui détient le record. Pas écrite dans Scores.lua (la mission l'ignore).
      `Code.gs` : 6 colonnes de dates en plus. Site : « valeur · depuis le JJ/MM/AAAA ».
    - Testé hors jeu : annonces (lupa, 3 cas + 2 sans annonce), dates du bot (battu / inchangé / premier import / pseudos
      regroupés), lecture des dates par `data.js` (node). **Pas déployé.**
  - **Déploiement commencé le 06/11 vers 0 h 15, arrêté à la demande de Thibaud (Weefe jouait)** :
    - ✅ script injecté dans les 2 .miz : `Saved Games\DCS\Missions\multi\Caucasus\Blue sky multi\…DAY…miz` (celle du MSI)
      et `mission\…BAD NIGHT…miz` ; anciennes en `bakup\*_2026-11-06_00-12-46.miz.bak` ; `script Caucase.lua` recopié
      à côté de la .miz du MSI. (`mission\…DAY…miz` du dépôt date du 19/10, pas utilisée.)
    - ✅ `scores.py` sur R2D2 (sauvegarde `~/backups/scores.py.avant-records-20261106`), moteur local du MSI, et
      `partage/maj` (2 copies). Le bot R2D2 **a été redémarré** pendant que Weefe jouait (Thibaud a dit de continuer) :
      BlueSky chargé, 0 erreur, le serveur de Weefe s'est reconnecté seul et ses scores sont relus.
    - ✅ les 2 .miz dans `partage/fichiers` ; site poussé (même commit que cette ligne).
    - ❌ reste : **Thibaud** : redéployer `Code.gs` (Déployer → Gérer les déploiements → ✏️ → nouvelle version),
      sinon les nouveaux records et leurs dates restent vides sur le site ; STOP → GO sur le MSI.
      **Weefe** : FICHIERS / MAJ + STOP → GO + nouvelle .miz dans ses Missions. Puis test en jeu.

## Prochaines étapes (état au 03/11/2026)
1. ✅ `Code.gs` redéployé le 03/11 : les atterrissages arrivent sur le site (vérifié : 3 pour « [ BS ]Thibaud | Breakdown »).
2. **Thibaud** : STOP → GO sur le MSI puis lancer la mission, et vérifier en jeu :
   - ✅ client SRS de l'hôte : **validé par Thibaud le 03/11** (après redémarrage complet de DCS) ;
   - la fiche « Vol en cours » sur la carte du site une fois en vol ;
   - le compteur d'atterrissages (message d'arrivée, kneeboard des scores, RShift+K) ;
   - le total fusionné arrive dans la mission (`BlueSky : scores fusionnes recus de R2D2` dans `dcs.log`) ;
   - la carte live avec une mission lancée (envoi toutes les 2 min serveur vide, 30 s avec des joueurs).
3. **Weefe** : FICHIERS / MAJ puis STOP → GO ; copier la nouvelle .miz (dans `Recus de Thibaud\`) dans ses Missions
   (version du 03/11 midi : menu par joueur + accueil ; MAJ plugin : fusion UCID).
   Ensuite, vérifier sur R2D2 que son serveur est lu (`bluesky_scores_base` doit avoir une 2e ligne).
4. Retester rapidement les heures complétées (atterrir puis crasher → seul le total doit bouger).
5. **Search Console** (prévu vers le 29/10, pas fait à ma connaissance) : rapports « Pages » et « Sitemaps » (doit être vert).
   Vérifié le 23/10 côté code : pas de page orpheline, doublons couverts par les `canonical`. Lien Instagram du pied de page =
   page d'accueil d'Instagram (pas de compte renseigné).
6. **Icône Google** : dépôt public `thibaero278.github.io` créé par Thibaud le 03/11 (contenu de `serveur BS\racine-github-io\`),
   page en ligne, 2e propriété Search Console `https://thibaero278.github.io/` validée par fichier HTML
   (**ne jamais supprimer le fichier `google….html` de ce dépôt**). Indexation demandée le 03/11 : reste à attendre
   (jours à semaines) que Google affiche l'écusson et « Blue Sky France ». Contrôler vers le 17/11 en cherchant « blue sky dcs ».
7. Doublons de pseudo : réglés par UCID (03/11) dès que le joueur se connecte avec le bot en marche. À vérifier plus tard :
   `players` se remplit (clients) et l'hôte y apparaît après une mission ; un ancien pseudo sans UCID reste séparé en jeu
   (le site garde `pilotAliases`).

Fait depuis (retiré de la liste) : Apps Script déployé et relais branché (19/10), carte live et activité Discord par le bot,
publication des missions testée en réel (21/10), dépôt ajouté dans Graphify, .miz v2 envoyée à Weefe (03/11).

## Chantier décidé le 03/11/2026 (grill-me avec Thibaud), dans cet ordre
Avant de toucher au script, faire une sauvegarde dans `mission\bakup\`.
Déjà validé en jeu par Thibaud le 03/11 : vol en cours sur la carte, compteur d'atterrissages, total fusionné R2D2, heures complétées.
1. ✅ codé le 03/11, à tester en jeu. **Menu STATISTIQUES partagé** (bug) : 3 groupes de la .miz ont 4 places joueur ; menu et messages sont par groupe
   (`ToGroup`) et « Mes scores » montre le 1er joueur du groupe. DCS ne dit pas qui a cliqué. Décision : **option B**,
   « Mes scores » envoie à **chaque** joueur du groupe ses propres stats (`outTextForUnit`) ; Top 10 inchangés (groupe).
   Sous-menu GRADES (ROOKIE/INTERMEDIATE/EXPERT) **retiré** : utilisé nulle part ; champ `grade` gardé dans Scores.lua.
2. ✅ codé le 03/11, à tester en jeu. **Message d'accueil** à **chaque** apparition, au joueur seul :
   `Bienvenue sur Blue Sky, <pseudo> !` / `GRADE : <grade> (<points> pts)` (pas le prochain grade) /
   `Frequences PA / tankers : sur le kneeboard` (pas de touche, chacun a la sienne) / `Tes stats : F10 > STATISTIQUES` /
   `Discord : discord.gg/zVEsRbm8h2` (lien du site, à changer si Thibaud en donne un autre).
3. ✅ codé et déployé le 03/11. **Fusion des pseudos par UCID** sur R2D2 (plugin bluesky) : regrouper les pseudos d'un même UCID (`players` +
   `players_hist` de DCSServerBot) en un pilote ; total renvoyé en jeu sous le pseudo actuel ; site = pseudo le plus récent,
   **UCID jamais publié**. Anciens pseudos sans UCID : rattachés d'eux-mêmes si le joueur revient avec le même pseudo,
   sinon `pilotAliases` du site. Tester sur une copie de la base avant la vraie.
Abandonné : notes d'appontage LSO (le LSO les affiche déjà, menu encombré pour rien).
Fait avant : annonce des promotions (« PROMOTION » à tous + fil Discord du bot).
Pas retenu pour l'instant : nouveaux modules air-air / air-sol, nettoyage automatique, kill feed.
Après modif : remettre le script dans la .miz (nom interne `l10n/DEFAULT/script Caucase.lua` depuis le 03/11).

## Chantier annoncé le 05/11/2026 : page « Blue Sky Ops » (plan seulement, rien codé)
Idée de Thibaud : un onglet qui fait changer d'univers. On quitte les couleurs Blue Sky pour du noir et du bleu nuit,
avec l'ambiance d'une salle de briefing ou d'archives militaires classées (un côté CIA, aéronautique).
- **Nom validé : Blue Sky Ops.**
- **Intro animée** (~3 s) au chargement de `web/ops.html` (pas au clic, pour marcher aussi depuis un lien direct) :
  terminal, « AUTHENTIFICATION… OK », tampon « ACCÈS RESTREINT », dossier qui s'ouvre. Bouton « Passer »,
  jouée une fois par visite, version courte si l'appareil demande moins d'animations.
- **Pas de son** (décision de Thibaud : les sons sur les sites, c'est pénible).
- **Contenu** : en-tête « DOSSIER BSO-001 », présentation et doctrine, livrets PDF, types de missions (CAP, SEAD, CAS, appontage…),
  archives des missions avec vidéos YouTube, prochaine opération (tirée de `data/evenements.js`, type « Opération »),
  comment nous rejoindre (Discord → rôle → SRS → sondage du bot). Contenu d'exemple accepté en attendant le vrai.
- **« Dernière mission effectuée »** : à trancher plus tard (on la met ou pas ; à la main ou depuis R2D2).
- **Fichiers prévus** : `ops.html`, `js/pages/ops.js`, `css/ops.css`, `data/ops.js` (édité à la main), onglet dans
  `js/layout.js`, encart sur l'accueil (comme Aerobatics), `sw.js`, `sitemap.xml`, puis les .md (CLAUDE.md maître + copies, README, CONFORMITE).
- **Points de vigilance** : vidéos YouTube en miniature, chargées en `youtube-nocookie` seulement au clic (RGPD) ;
  aucun vrai insigne militaire ni vraie mention « Confidentiel Défense », l'univers reste fictif.
- **06/11 : maquette faite en local, PAS poussée.** Fichiers créés : `web/ops.html`, `web/css/ops.css`, `web/js/pages/ops.js`,
  `web/data/ops.js` (contenu d'exemple, `demo: true`). Onglet ajouté dans `js/layout.js`. Le menu burger bascule désormais
  sous 1120 px (au lieu de 900) : avec 7 onglets la nav débordait. Versions alignées sur toutes les pages : `style.css?v=9`, `layout.js?v=8`.
  Testé dans le navigateur (intro, page, mobile 375 px). « Prochaine opération » lit le planning Discord (vide pour l'instant).
- **Reste à faire** : retours de Thibaud sur la maquette, vrais textes et vidéos dans `data/ops.js`, encart sur l'accueil,
  `sitemap.xml`, CLAUDE.md maître + copies, README, CONFORMITE (vidéos YouTube chargées seulement au clic), puis push.
- **06/11 (suite) : refonte « anti-IA » en deux variantes à comparer, PAS poussées.** Thibaud trouvait la 1re maquette trop « IA »
  (cadres fins, étiquettes mono, numérotation). Thème passé au **noir et vert vision nocturne** (plus de bleu).
  - `web/ops.html` = **planche contact** (anneau de photos autour du titre, une bande de photos par opération, liste des missions).
  - `web/ops-tuiles.html` = **tableau de tuiles** (blocs bord à bord, onglets des types de missions). En `noindex`.
  - Communs : `css/ops.css`, `js/pages/ops.js`, `data/ops.js` (photos déclarées en tête, opérations d'exemple).
    Bouton « Vision nocturne » : passe les photos de jour en vert (choix retenu dans le navigateur). `?intro=0` dans l'adresse saute l'intro.
  - Photos de Thibaud dans `web/assets/ops/` (Hornet devant la lune, pilote sous la verrière, cockpit C-130, vision nocturne, cockpit Hornet de nuit).
  - Vidéos : Thibaud a surtout des **TikTok** (champ `tiktok` des opérations, lien sortant, pas de lecteur intégré pour éviter les traceurs).
    Présentation de la livrée : https://www.tiktok.com/@_thibaero_/video/7672770407853739296 (photos de la livrée à venir).
  - Contrôlé avec l'outil design-taste-frontend (dossier `.taste-skill/`, à ne pas committer) : il reste l'icône ☰ du menu commun du site.
  - **À faire** : Thibaud choisit une variante → supprimer l'autre, puis vraies opérations/photos, encart accueil, sitemap, .md, push.

## 06/11/2026 : kneeboard « Mémo radio » (phraséologie ATC humain)
- Source : `formation/Blue_Sky_Phraseologie_ATC_Humain_Memo_Radio_Complet.pdf` (PDF de Thibaud, 21 p., guide v1.8),
  mis de côté pour la future rubrique **Formation** du site (pas encore publié, pas dans `web/`).
- **21 pages kneeboard ajoutées** (04 à 24), **une par page du PDF**, texte complet, dans `mission/kneeboard_source/kneeboard.html`,
  même style DimOn que les pages 01-03 : 04 décollage piste, 05-07 catapultage CASE I / II / III, 08 atterrissage piste,
  09-11 appontage CASE I / II / III, 12 AWACS, 13-16 JTAC (contact, 9-Line à remplir, attaque Type 2, après la passe),
  17-23 lexiques (radio-nav, AWACS, air-air, PA départ, appontage, JTAC, tir JTAC), 24 alphabet + acronymes.
  Calls écrits en `<pre class="calls">` (`ROLE|texte`), lexiques en `<pre class="gloss">` (`terme|définition`) :
  le script de la page fabrique les tableaux, bandeau et pied. Pages chargées : classe `dense` (11 à 14).
- Couleurs demandées par Thibaud : `[valeur]` et types d'avions / armes (F/A-18, Hornet, Su-27, GBU-12, AGM-65, Shilka) en **bleu** = à adapter ;
  indicatif **Weefe 1-1 / Weefe flight en vert** ; pastille contrôleur (TWR, MAR, APP, DEP, LSO, AWX, JTAC) en **bleu Blue Sky #2a5ca8** ; pilote en noir.
  Le bandeau jaune « BLUE SKY » en haut est resté jaune (comme pages 01-03).
- `generer_kneeboard.ps1` génère les 24 `BS_*.png`. Vérifié : aucune page ne déborde, bandeaux sur une ligne.
- Sauvegarde avant modif : `mission/bakup/kneeboard_2026-11-06_avant-phraseo.html`.
- **Page 01 « Comms & Nav » refaite** à partir des deux .miz (DAY et BAD NIGHT), lues directement (tâches ActivateBeacon / ICLS / Link4,
  fréquences des unités) : le script Lua ne contient aucune fréquence. Ajoutés : Essex (TACAN 2X, ICLS 1 en DAY / 2 en NIGHT),
  Kuznetsov « Ruskov » (130.00), AWACS Overlord 1-1 (251.00), drone MQ-9 Colt 1-1 FAC (251.00), indicatifs TACAN.
  **Erreurs corrigées** : ICLS Truman 22 → 20 ; Texaco 244 → 255 et Shell 255 → 246.
  À signaler à Thibaud (pas modifié dans la mission) : Truman et Stennis tous les deux en ICLS 20 ; Shell 2-1 et Arco 2-1 tous les deux
  sur 246.00 ; AWACS et drone tous les deux sur 251.00.
  Copie des PNG aussi dans `serveur BS\kneeboard\` (à refaire après chaque régénération).
  **Mise à jour 06/11 16 h** : la vraie mission DAY est `Saved Games\DCS\Missions\multi\Caucasus\Blue sky multi\` (8 Mo) ;
  celle de `site\mission\` date du 19/10 et est **périmée** (c'est elle qui donnait Essex ICLS 1 et KC-135 TKR). Page 01 alignée :
  Essex ICLS 2, KC-135 indicatif KC1, MQ-9 Colt 1-1 sur 244.00 (changé par Thibaud), Stennis **ICLS 19** (vérifié dans la .miz
  de 16 h 20). IL-78 Arco 2-1 passé sur 249.00. B-52 Buff 1-1 passé sur 111.00 (plus de doublon avec l'AWACS), pas mis sur le kneeboard.
- **06/11 16 h 27 : 24 pages injectées** dans la vraie mission `Saved Games\DCS\Missions\multi\Caucasus\Blue sky multi\Blue Sky Multi-joueur DAY_Caucasus.miz`
  (`KNEEBOARD/IMAGES/`, pour tous les avions). Archive vérifiée. Sauvegarde : `bakup\` à côté de la .miz (16-27-23).
  **La NIGHT n'existe plus** (dixit Thibaud) : rangée dans `mission\bakup\..._ancienne-version.miz`. La DAY de `site\mission\` (19/10) est périmée.
  Rappel : après une sauvegarde dans l'éditeur, relancer l'injection.
- **06/11 16 h 42 : mission DAY (avec kneeboard) envoyée à Weefe** dans `partage/fichiers/` sur R2D2 (somme de contrôle identique),
  ancienne NIGHT retirée du partage. **16 h 55 : Thibaud a resauvegardé dans l'éditeur → kneeboard effacé** ; réinjecté et renvoyé
  (somme 284e4651…). À chaque sauvegarde dans l'éditeur, il faut réinjecter. MAJ du bot : rien de neuf (mission.lua et scores.py déjà identiques sur le partage).
- (ancien) Thibaud voulait d'abord faire les kneeboards de pistes (il va montrer un modèle), puis tout injecter
  dans la mission (`ajouter_kneeboard.bat`).
- **06/11 (fin) : variante unique, épurée selon les retours de Thibaud. PAS poussée.** `ops-tuiles.html` supprimée.
  `web/ops.html` = anneau de photos autour du titre (gardé) → L'unité (texte + **la livrée** : photo, TikTok, téléchargement à venir)
  → Ce qu'on vole (CAP, CAS, SEAD, Strike, Interception ; survoler une ligne change la photo ; pas de niveaux, pas de Case I)
  → Dernière opération (photo en tuiles, plus petite, à côté du débrief) → Prêt pour le briefing (+ prochaine opération du planning).
  Supprimé à sa demande : bandes de photos par opération, bouton vision nocturne, livrets, galerie, soirée type, onglets, « réserver ».
  **Plus aucune photo de jour passée au filtre vert** (il trouve ça moche) : uniquement ses captures de nuit dans `assets/ops/` (9 photos).
  Thibaud va envoyer d'autres captures. Reste : vraie dernière opération, photos de la livrée, encart accueil, sitemap, .md, push.
- **06/11 (retouches) :** la page reste **bloquée sur l'anneau** tant qu'on n'a pas cliqué « Ouvrir le dossier » (une fois par visite,
  `sessionStorage` `bso-open`). Au clic : on traverse l'anneau (photos qui s'écartent, titre qui grossit), l'écran se ferme sur
  « Dossier BSO-001 » puis s'ouvre sur l'unité. `?intro=0` saute l'intro ET le blocage (pour les tests).
  Livrée en **deux versions** (Blue Sky Ops Visibility / Low Visibility), photos à mettre dans `data/ops.js` → `livery.versions[].photo`.
  « Ce qu'on vole » renommé « Ce qu'on fait ».
- **06/11 (suite) :** l'intro et le blocage se rejouent maintenant **à chaque arrivée sur la page** (plus de `sessionStorage` :
  le navigateur de Claude gardait la session même après fermeture de l'onglet). Intro ralentie, environ 7 s, bouton « Passer l'intro » et Échap.
- **06/11 (fin) :** tampon rouge « Accès autorisé » supprimé de l'intro (elle s'ouvre 1,4 s après la dernière ligne, ~6 s au total).
  L'écran « Dossier BSO-001 » à l'ouverture reste affiché ~1,2 s (au lieu de ~0,3 s). Thibaud valide la page ; reste les vraies données et le push.
- **06/11 : EN LIGNE** (commit db8905e) : https://thibaero278.github.io/blue-sky-france/ops.html — ajoutée au sitemap, README, CONFORMITE,
  CLAUDE.md maître + copies à jour. Reste : vraie dernière opération, photos de la livrée (2 versions), éventuel encart sur l'accueil.

## 06/11/2026 : livrées voltige téléchargeables sur le site
- Zip `Blue-Sky-Aerobatics-Livrees.zip` (437 Mo) : 9 dossiers de livrées F/A-18C à la racine + `LISEZ-MOI.txt`, `LISEZ-MOI.pdf`,
  `PROMPT POUR TON IA.txt`. Source locale : `serveur BS\livrée\New\` ; notice éditable dans `livrée\New\aide\notice.html`
  (PDF imprimé avec Edge headless, style mémo radio). Pas d'exécutable (choix de Thibaud).
- Hébergé en **Release GitHub** `livrees-voltige` du dépôt public (GitHub Pages refuse les fichiers > 100 Mo).
  Lien direct : https://github.com/thibaero278/blue-sky-france/releases/download/livrees-voltige/Blue-Sky-Aerobatics-Livrees.zip
- Bouton « Télécharger les 9 livrées » dans `web/aerobatics.html` (carte « La livrée Blue Sky »).
  **10/11 :** + bouton contour « Voir la présentation sur TikTok » juste dessous (vidéo de Weefe :
  https://www.tiktok.com/@weefe_/video/7505668783676165398). Publié le 10/11 (commit 67e08d8), vérifié en ligne.
  Push depuis WSL : `wsl.exe -e git -c "credential.helper=" -c "credential.helper=!'/mnt/c/Program Files/GitHub CLI/gh.exe' auth git-credential" push origin main`
  (sans ça, `git push` attend un identifiant et bloque).
- Bon dossier d'installation : `Saved Games\DCS\Liveries\FA-18C_hornet\` (à créer, n'existe pas par défaut).
  Pas `Program Files\...\CoreMods` (écrasé aux MAJ), pas `Saved Games\DCS\Mods` (DCS n'y lit pas les livrées).
- Mettre à jour le zip : `gh release upload livrees-voltige <zip> --clobber -R thibaero278/blue-sky-france` (même nom de fichier = même lien).
- **Blue Sky Ops fait aussi (06/11)** : `Blue-Sky-Ops-Livrees.zip` (168 Mo, 7 livrées : hight vis, low vis, Weefe, Thibaud, Dex,
  Xerion, Joshua + notice/prompt adaptés). Source : `serveur BS\livrée\livrée terminier\` (aide dans `aide-ops\`).
  Release `livrees-ops`, bouton « Télécharger les livrées » + TikTok en contour dans `web/ops.html`.
- **06/11 :** photos de la livrée ajoutées : **High Visibility** (blanc et rouge) et **Low Visibility** (gris), dans
  `web/assets/ops/livree-*.jpg`. Seules photos de jour de la page (ce sont les livrées, sans filtre).

## 07/11/2026 : nouvelle carte F10 + front russe dynamique
- **Nouvelle carte** faite par Thibaud dans l'éditeur (`Saved Games\...\Blue sky multi\…DAY…miz`, 07/11 15 h 59) : est = entraînement
  et camp bleu (tankers au menu, convois / bateaux / Mi-8 d'entraînement, PA, croix) ; zones **Dogfight** (bleus de Tbilissi-Lochini,
  rouges de Soganlug), **BVR** (rouges de Beslan, bleus de Minvody, ~45 NM avant le croisement ; Minvody sert aussi pour la HOST A/A AERA),
  Mozdok = base Blue Sky. **Frontière** Soukhoumi → Minvody → nord : difficulté croissante vers l'ouest (Gudauta strike léger, Sochi,
  SAM au centre (« SAM GG »), bateaux côtiers, Maykop SA-3, Krasnodar-Pashkovsky SAM moderne, Krasnodar-Centre AA d'époque, Top Gun Zone
  Anapa SA-10, Krymsk / Novorossiysk / Gelendzhik SA-8 / SA-22 / SA-9). HOST Naval AERA (groupe « Admiral » autour d'un Kuznetsov),
  Naval AERA non offensive, convois d'entraînement non retardés au nord des montagnes (« sochi convoie-1 » à « -6 »), zone industrielle
  (GCI-2) défendue aux manpads, pads hélico près des bases russes. Les zones dessinées (Dogfight, BVR…) sont des dessins, pas des zones
  de trigger : seules `Spawn Air`, `Spawn ENI`, `fumi red`, `fumi white` existent. `Spawn Air` a été déplacée au nord (HOST A/A AERA).
- **Codé (script Caucase.lua)**, sauvegarde `bakup\script Caucase_2026-11-07_avant-front-russe.lua` :
  - **Renforts au premier kill** (table `BASES`, rayon 8 km, une fois par mission) : premier véhicule / statique / bateau détruit
    → activation des groupes retardés. Gudauta → `Gudauta convoie` + `KA 50 gudauta` ; Sochi → `sochi convoie` +
    `hélico sochi convoie` (son escorte) + `helico sochi` ; Anapa → `hélico anapa` ; **Soukhoumi** (base bleue) → `sukumi convoie`
    (contre-attaque partie de Gudauta). Avions abattus ignorés. Nouveau convoi = une ligne dans `BASES`.
  - **Spawn ENI** (F10 AIR-AIR > Spawn ENI > Activer / Desactiver, **désactivé au lancement**) : un groupe tiré au sort apparaît
    n'importe où dans la zone quad `Spawn ENI` (Anapa–Pashkovsky–Gelendzhik) et suit sa route de l'éditeur. Une vague à la fois :
    la suivante quand chaque avion est détruit, posé, sous 15 % de carburant ou sans armement (canon seul = sans), ou après 1 h.
    10 tirages (`ENI_WAVES`) : mig29s, mig21, su33, jf17, Aérien_g-1, su34, su25, l39, tu95 + escorte 95, tu160 + escorte 160
    (bombardiers vers le SAM de Soukhoumi ; escorte respawnée à côté et retaskée en Escort, sa tâche « Follow » de l'éditeur visait le modèle).
    Les avions ENI sont aussi effacés par « Clear hostile ». Aucun message aux bleus à chaque vague (surprise), seulement à l'activation.
  - Au chargement, tout nom de groupe absent de la mission est signalé dans `dcs.log` (`BLUESKY : groupe absent de la mission`).
  - `GetSpawner(template, zone)` prend maintenant une zone MOOSE ; les hostiles gardent `ZONE:New("Spawn Air")` (cercle de 3 km au centre).
- Testé hors jeu (lupa, DCS/MOOSE simulés : renforts par base, une seule fois, avion ignoré ; vagues ENI, escorte, fin de vague, désactivation,
  limite 1 h ; 19 noms vérifiés dans la .miz du 07/11). **Pas testé en jeu.**
- **Injecté** dans `Saved Games\...\Blue sky multi\…DAY…miz` à 16 h 22 (sauvegarde `bakup\…_2026-11-07_16-22-46.miz.bak` à côté, kneeboard
  24 pages toujours présent) + copie du script à côté. ⚠️ Si Thibaud resauvegarde dans l'éditeur, réinjecter le script.
- **07/11 16 h 39** : Thibaud a resauvegardé dans l'éditeur ouvert avant l'injection → ancien script remis ; réinjecté.
  Leçon : l'éditeur réécrit le script qu'il a chargé à l'ouverture. Fermer l'éditeur avant d'injecter, puis rouvrir.
- **07/11 17 h 30, premier test en jeu** : les MiG-29 ENI sont partis droit vers la zone BVR au lieu de suivre leur route.
  Cause : la tâche CAP auto `EngageTargets` de l'éditeur n'a pas de distance max, l'IA va chercher tout bleu vu par l'A-50.
  Corrigé : `LimitEngage` borne `EngageTargets` à 60 km de la route (`ENI_ENGAGE_M`) dans les modèles MOOSE des groupes ENI
  (les hostiles du menu AIR-AIR ne sont pas touchés). Message réduit à « SPAWN ENI ACTIVE / DESACTIVE ».
  `Aérien_g-1` renommé `su27` par Thibaud ; zone `Spawn ENI` redessinée (Anapa – Krasnodar – Maykop).
  Injecté éditeur fermé (sauvegarde de la .miz de 17 h 27 dans `bakup\` à côté), kneeboard 24 pages intact.
- **À faire** : test en jeu ; convois / hélicos de renfort pour les autres bases (Maykop, Krasnodar, Pashkovsky, Gelendzhik, Novorossiysk,
  Krymsk, SAM GG) quand Thibaud les aura posés en activation retardée ; envoyer la .miz à Weefe (partage R2D2) après validation.

## 08/11/2026 : templates de slots dynamiques, points strike, interception
- **Slots dynamiques** (fait par Thibaud, validé en jeu) : waypoints pré-rentrés via un groupe Client « Template de spawn dynamique »
  + activation retardée par type et par base, relié dans l'entrepôt de la base (colonne « Modèle de groupe »). Route de base, pas la DTC.
- ⚠️ La .miz sauvegardée le 08/11 à 1 h 09 contenait de nouveau **l'ancien script** (avant `LimitEngage`) : l'éditeur était ouvert
  pendant l'injection du 07/11. À réinjecter éditeur fermé.
- **Codé (script Caucase.lua)**, sauvegarde `bakup\script Caucase_2026-11-08_avant-interception.lua` :
  - **Points strike** (`StaticPoints`) : derricks et plateforme gaz (`Oil rig`, `Gas platform`, cercle Petrol Strike) **5 pts** ;
    statiques du cercle à 27 objets (dépôt de munitions, PC, pompes… centre x -33689 / y 587156, r 969 m, repris du dessin F10)
    **2 pts** ; tous les autres statiques 1 pt (inchangé). Si le dessin bouge, mettre à jour `STRIKE_ZONES`.
  - **Interception** (F10 > INTERCEPTION > Lancer / Appel radio) : tirage dans `INTERCEPTS` (pour l'instant `Yak 40`). Alerte aux
    bleus, route au sud par les montagnes (-250000 / 680000) vers Tbilissi-Lochini, FL200, 150 m/s (~35 min). Appel radio seulement
    à 500 ft (3D) du Yak, 20 s entre deux appels, par n'importe quel bleu (DCS ne dit pas qui clique : les bleus à 500 ft sont
    les appelants). 40 % muet : 3 appels (générique, avertissement, dernier avertissement) puis TIR AUTORISÉ, il fuit bas (600 m sol)
    vers Tbilissi. 60 % répond à un appel au hasard, puis 50/50 : panne moteur → atterrissage à **Beslan** (base rouge), ou erreur de
    navigation → retour à son point de départ (10 km). Points : hostile abattu après autorisation = kill + 5 ; dérouté arrivé =
    5 pts par appelant ; tir non autorisé = 0 pt + message à tous ; Tbilissi atteint = interception ratée. Une à la fois.
- Testé hors jeu (lupa) : points strike, hostile, tir non autorisé, Beslan, frontière, ratée, détruit ; tests du front russe toujours OK.
- **Mis de côté** : onglet Missions (interception / strike / anti-navire avec points), voix IA, Tu-95 / chasseurs avec leur histoire.
- **Injecté** le 08/11 à 1 h 40, éditeur fermé (sauvegarde `bakup\…_2026-11-08_01-40-12.miz.bak` à côté de la .miz) : interception,
  points strike et `LimitEngage` présents, kneeboard 24 pages intact.
- **08/11, premier test en jeu** : marche. Thibaud a mis le Yak en « réaction aux menaces : aucune » dans l'éditeur (sinon il fuyait
  en rase-mottes dans les montagnes). Tirage panne de nav obtenu. Retours corrigés (pas encore injectés) : vitesse 150 → 190 m/s
  (il volait à ~200 kt indiqués) ; panne de nav = il demande un cap, l'appel suivant lui donne le cap vers sa frontière (calculé),
  puis il rentre et continue se poser à **Maykop-Khanskaya** ; les fins réussies ne le font plus disparaître (Beslan compris).
- Injecté le 08/11 à 2 h 08, éditeur fermé (sauvegarde `bakup\…_2026-11-08_02-08-09.miz.bak`), kneeboard 24 pages intact.
- **Menu F10 MISSIONS** (08/11) : contient INTERCEPTION (Lancer / Appel radio) et **HOST Naval AERA**, qui active une fois
  le groupe `Admiral` (porte-avions et escorte, beaucoup de bateaux : passé en activation retardée par Thibaud pour ne pas charger
  le serveur). Autres groupes à ajouter dans `NAVAL_HOST`. Pas encore injecté.
- **Tu-95** (08/11, pas encore injecté) : interception réorganisée, chaque avion a ses fonctions `call` / `tick` dans `INTERCEPTS`,
  « Lancer » tire Yak-40 ou Tu-95 au hasard. Groupes de l'éditeur : `TU95 inter` (6 Kh-555, FL300, 230 m/s) et
  `Escorte tu95 inter` (Su-27), en activation retardée. Route : nord des montagnes (-170000 / 820000) puis plein sud sur Tbilissi.
  1er appel : il ment (erreur de nav) et garde son cap. 2e appel (« demi-tour, cap X ») : 30 % il rentre (point de départ puis
  Maykop, 10 pts par appelant), 70 % il refuse et appelle le Su-27, qui part de sa position de l'éditeur, escorte le Tu-95 en
  tir interdit et passe en tir libre une fois à 2 km : TIR AUTORISÉ sur les deux (escorte abattue avant = 0 pt, puis tir autorisé
  sur le Tu-95). Tu-95 abattu après autorisation = kill + 10. À **60 NM de Tbilissi** sans demi-tour : tâche Bombing
  (arme Auto, tout) sur l'aéroport, interception ratée (environ 14 min de vol jusque-là).
- Menu MISSIONS + Tu-95 **injectés** le 08/11 à 2 h 47, éditeur fermé (sauvegarde `bakup\…_2026-11-08_02-47-27.miz.bak`),
  kneeboard 24 pages intact.
- **Retours du test Tu-95** (08/11, injectés à 12 h 09, éditeur fermé, sauvegarde `bakup\…_2026-11-08_12-09-29.miz.bak`) : plus aucune indication dans les réponses (il ment : « petit problème
  d'autopilote, nous allons changer de cap », le Su-27 reste secret jusqu'au tir autorisé) ; à 15 km de son virage vers Tbilissi,
  si l'escorte n'est pas arrivée : « l'autopilote est réglé, nous tournons ». Tu-95 à 255 m/s (quasi son maxi réel). Su-27 déplacé par
  Thibaud (x -135076 / y 746077) : il fonce sur le Tu-95 à 600 m/s (route recalculée toutes les 15 s), passe en Escort à 10 km,
  ouvre le feu à **500 m** du Tu-95 (au lieu de 2 km). Appels sur **121.5** (Guard VHF, 243.0 en UHF). Impossible de conditionner
  l'appel à la radio du joueur : un script de mission ne lit pas la fréquence d'un avion joueur.
- 08/11 à 12 h 22 (injecté éditeur fermé, sauvegarde `bakup\…_2026-11-08_12-22-10.miz.bak`) : Su-27 à pleine vitesse jusqu'à 15 km, puis vitesse du Tu-95 + 100 m/s (route recalculée à chaque
  tick), formation à 2 km au lieu de 10. Appels sur **243.0** ; `Yak 40`, `TU95 inter` et `Escorte tu95 inter` passés sur 243 AM dans la .miz.
- 08/11, retours du 2e test Tu-95 (injectés à 12 h 56, DCS fermé, sauvegarde `bakup\…_2026-11-08_12-56-52.miz.bak`) : tirage **sans répétition** (`IcptBag`, chaque avion une fois puis on repart de zéro) ;
  Su-27 créé par `SpawnFromVec3` **15 km derrière le Tu-95, dans son axe** (sa position dans l'éditeur ne sert plus), plein gaz jusqu'à 4 km ;
  plus de message à son arrivée (seule la surprise de son tir l'annonce) ; annonce du virage à 8 km (au lieu de 15).
  **Kh-555 non tirés au test** : la tâche envoyée n'avait que `point`, DCS attend `x` / `y` (comme l'éditeur) ; passé par `TaskBombing` de MOOSE,
  type d'arme missile de croisière (2097152), porté par un waypoint 3 km devant lui ; ensuite retour à son point de départ et atterrissage à Maykop (plus Beslan). Aucun avion d'interception n'est plus effacé (abattu il tombe, posé il reste).
- 08/11 à 14 h 02 (injecté DCS fermé, sauvegarde `bakup\…_2026-11-08_14-02-53.miz.bak`) : appel radio à **1000 ft** (305 m, 3D) au lieu de 500 ; Su-27 ouvre le feu à **800 m** du Tu-95 au lieu de 500 (à 500 m il plongeait dans le relief, effet à confirmer en jeu) ;
  messages radio réécrits en phraséologie (« Parlez », indicatifs `RA-87412` pour le Yak et `Strela 21` pour le Tu-95, contrôleur `BLUE SKY CONTROL`, Guard 243.0, MAYDAY).
- 08/11 à 14 h 22 (injecté DCS fermé, sauvegarde `bakup\…_2026-11-08_14-22-36.miz.bak`) : Kh-555 **tir et retour Maykop validés en jeu** ; impact visé sur le parking du terminal de Tbilissi (`aim`, X -314935, Z +896939) ; Su-27 ouvre le feu à **1500 m** (à 800 m il plongeait encore, à tester).
- 08/11, dernier retour (injecté, DCS fermé) : indicatifs **I-JAKE** (Yak) et **RF-59** (Tu-95), appels sans type ni niveau ; Kh-555 et combat du Su-27 **validés en jeu**.
  Bug : Tu-95 abattu en retraite compté en kill normal. Le tick voyait l'avion mourant (vie < 1) et fermait l'interception avant l'événement Kill ; il attend maintenant jusqu'à 120 s (`ICPT_LOST_S`), et le tir non autorisé annonce « Interception ratee ».
  Tu-95 perdu : `IcptEnd` renvoie le Su-27 se poser à Maykop (sauf s'il est au combat quand le Tu-95 tire ses Kh-555).
  Su-27 parti vers Mozdok **après avoir abattu le joueur, Tu-95 intact** : à 1500 m il sautait souvent la tâche Escort (ouverture du feu dès le tick où il passe sous 1500 m), donc plus rien à suivre après son kill. Dès qu'aucun joueur bleu n'est à moins de 20 km de lui (`TU_REJOIN_M`), il reçoit une fois la tâche Escort du Tu-95 ; rien pendant le combat, qui marche bien sans. Cause probable, à tester en jeu comme les corrections ci-dessus.
- 08/11 soir (injecté, DCS fermé) : **3e interception Su-34**, groupe `Su34 inter` (2 avions, n° 034 et 035, 243 MHz, FL270, 231 m/s), indicatif **VVS 34/35**. Alerte au lancement ; appel possible seulement hors frontière.
  Trajet rouge (franchissement puis Mineralnye). 1re interception : détour jaune par le nord et 2e sortie annoncée par le contrôleur. 2e interception : flèche verte, retour Maykop, **+15 pts** aux appelants quand ils repassent la frontière.
  Non interceptés : largage à 25 km de la cible (centre de l'aéroport), **tir autorisé après largage** (kill normal, sans bonus), fuite vers le nord puis Maykop. Tir avant largage sur l'un des deux = 0 pt et mission ratée.
  Coordonnées relevées sur une capture peinte (dessin absent de la .miz), calées sur la boîte BVR, précision environ 2 km. Non testé en jeu : largage réel de l'IA (KAB-1500Kr et charge de l'ailier), points du trajet, détection du largage par baisse de munitions (sinon délai de 180 s).
- 08/11 soir (injecté, DCS fermé) : Su-34, **vengeance** : dès que l'un des deux est abattu (autorisé ou non), le survivant passe en tir libre et attaque le joueur bleu le plus proche dans 100 km (tâche `AttackUnit`), tir autorisé sur lui ; plus de joueur à portée = retour Maykop. Le kill avant largage reste à 0 pt et « Interception ratee ». `GroupUnit` prend désormais le premier avion vivant du groupe. Non testé en jeu.
- 08/11 à 22 h 20 : **.miz envoyée à Weefe** dans `partage/fichiers/` sur R2D2 (somme de contrôle identique, version du soir avec les 3 interceptions). Fichiers du bot dans `partage/maj` déjà à jour, rien d'autre à envoyer. Reste : Weefe FICHIERS / MAJ puis .miz de `Recus de Thibaud\` dans ses Missions.
- Traînées (réglé par Thibaud à 15 °C, condensation OK en jeu) : mission à 23,2 °C au sol, soit environ -36 °C au FL300, sans doute trop chaud ; à essayer vers 10 °C (non vérifié).
- **À faire** : retester (vitesse suffisante ? Beslan ? fuite hostile à 600 m sol) ; Tu-95 : vérifier que l'IA tire vraiment ses
  Kh-555 avec la tâche Bombing (sinon essayer le type d'arme « missile de croisière ») et que le Su-27 attaque bien en tir libre.

## 09/11/2026 : corrections de bugs (après le grill-me de la liste de 37 tâches)
- `Code.gs` : déjà à jour en ligne (les 30 colonnes sortent de `?format=json`), pas de redéploiement à faire.
- **Carte, mode Blue Sky** : `sync` (`carte.js`) force `bs: !!n.bs`. Le champ est absent du JSON quand le mode est coupé et `Object.assign` gardait l'ancien `true`. Vérifié dans le navigateur (faux live : icône retirée).
- **Barre de navigation** : `serverLabel` court (« Hors ligne », « N en ligne », « Serveur vide ») et pastille masquée sous 1280 px. Vérifié à 1120, 1200, 1279, 1280, 1440 px. `?v=` montés dans les pages HTML (`style.css`, `data.js`, `carte.js`).
- **Kill loin / proche** (0 pilote renseigné sur le relais) : `GetTargetPoint` renvoyait nil quand la cible avait déjà disparu au moment du kill. Le script garde maintenant la position de la cible au dernier coup au but du tireur (`LastHit`, 30 s), ce qui sert aussi aux points des zones strike. Choix de Thibaud : distance **au tir** pour les armes suivies (`Shots`, par `id_` de l'arme : distance de la cible verrouillée, sinon position du tireur au tir → cible) ; canon : distance au moment du kill. Test hors jeu : `python tools/test_kill_distance.py`. Sauvegarde `bakup\script Caucase_2026-11-09_avant-records-distance.lua`.
- **Altitude / vitesse comptées seulement après crash ou éjection (selon Thibaud)** : cause **non trouvée**. Le message d'atterrissage s'affiche et le code passe par `CloseFlight` dans les deux cas. Ajout d'une ligne dans `dcs.log` à chaque fin de vol (`BlueSky records : fin de vol …`), à retirer une fois résolu. À faire : un vol, atterrissage, puis lire cette ligne et comparer à `Scores.lua`.
- Injecté le 09/11 à 14 h 12, DCS fermé (sauvegarde `bakup\…_2026-11-09_14-12-53.miz.bak`), kneeboard 24 pages intact. La .miz envoyée à Weefe le 08/11 n'a pas ces corrections.
- **Test en jeu du 09/11 vers 15 h** (`dcs.log` + `Scores.lua`) : 2 kills AIM-120 sur Mi-8 tirés à environ 35 km, posé à Kutaisi → `maxKillDistance` 35218, `minKillDistance` 34463, `maxKillsFlight` 2 : distances et records de kills **validés**. Les atterrissages passent bien par `CloseFlight` (ligne de log à chaque fin de vol). Non vérifié : un record d'altitude ou de vitesse **battu** au moment d'un atterrissage (28447 m / 754 m/s venaient d'une éjection, les vols posés étaient en dessous). Ligne de diagnostic gardée jusque-là.
- **Formats des records** (demande de Thibaud, 09/11) : distances en NM, en mètres sous 1 NM (1852 m) ; altitude en ft + km ; vitesse en km/h + Mach. Site (`classements.js`, `?v=12`) et script (`RECORDS`, `FormatDistance`, message de kill). Mach approché avec le son en haute altitude (295 m/s) : le vrai Mach demanderait un champ en plus (script, bot, `Code.gs`). Sauvegarde `bakup\script Caucase_2026-11-09_avant-formats-records.lua`. Script injecté le 09/11 à 16 h 20, DCS fermé (sauvegarde `bakup\…_2026-11-09_16-20-16.miz.bak`), kneeboard 24 pages intact ; site poussé le 09/11.
- **Fiche pilote** (`classements.js`, `?v=13`) : bloc « Records personnels » (7 records, date, ★ si record du serveur) ; ligne « Niveau des bots (F10) » retirée, « Vol le plus long » déplacé dans le bloc. Vérifié en local.
- **Kills air-air / air-sol séparés** (09/11, choix de Thibaud : 4 records) : `maxKillDistance` / `minKillDistance` = **air-air** (seul le Mi-8 du 09/11 y figurait) ; nouveaux `maxKillDistanceAS` / `minKillDistanceAS` = air-sol, bateaux compris. Script, `scores.py`, `Code.gs` (4 colonnes en fin), `data.js`, `classements.js`. Sauvegarde `bakup\script Caucase_2026-11-09_avant-kills-air-sol.lua`. Testé hors jeu et dans le navigateur (données simulées). `scores.py` déployé sur R2D2 (sauvegarde `~/backups/scores.py.avant-air-sol-20261109`, bot relancé à 16 h 40, aucun serveur connecté), moteur local et `partage/maj` (2 copies). Script injecté à 16 h 41, DCS fermé (sauvegarde `bakup\…_2026-11-09_16-41-06.miz.bak`), kneeboard 24 pages intact. ⚠️ Le zip `moteur-3.0.5.2-bluesky.zip` contient encore l'ancien `scores.py` (sans effet tant que la fusion tourne sur le maître, à refaire si le paquet resert). `Code.gs` redéployé par Thibaud le 09/11 vers 20 h (selon lui ; à confirmer : 34 colonnes dans `?format=json` après le prochain envoi de scores).
- **Mission envoyée à Weefe** (09/11, 19 h 48) : .miz du 09/11 16 h 41 déposée dans `partage/fichiers/` (distances + air-sol, vérifiée par téléchargement HTTP, kneeboard 24 pages). Ancienne copie : `~/backups/mission-weefe-avant-2026-11-09.miz`. Cause du « kills proche / loin vides » : sa .miz du 08/11 sans le correctif. Reste Weefe : FICHIERS / MAJ, remplacer la mission du serveur, la relancer. Les anciens kills resteront sans distance. Livrées, zips et `PROMPT-WEEFE.md` sortis du partage le même soir (`~/partage-retire-2026-11-09` sur R2D2) : `fichiers/` ne contient plus que la mission.

## 10/11/2026 : heures Blue Sky, distances, kills en un vol, barème (codé, PAS déployé, pas testé en jeu)
Sauvegarde `mission\bakup\script Caucase_2026-11-10_avant-kills-separes.lua`. Tests hors jeu : `python tools/test_kill_distance.py` OK, page Classements vérifiée en local.
- **Heures Blue Sky** : Weefe a 72 vols pour 82 s de mode Blue Sky, donc le mode était déjà retiré à la fin de ses vols (le temps BS et le compteur de vols sont ajoutés au même endroit). Bug trouvé : `CloseFlight` retirait `BSMode` même sans vol actif, et DCS envoie de faux Land au sol sur PA. Corrigé (retrait après le test du vol actif). Cause la plus probable, **pas prouvée** : `dcs.log` de Weefe non lu. Nouvelles traces dans `dcs.log` : `mode Blue Sky active par …` et `mode BS oui/non` sur la ligne de fin de vol.
- **Distances** : site et base concordent (Weefe : air-sol 8 484 m et 2 394 m). Les **350 km (SLAM-ER) et 0 m (canon d'Apache) sont réels selon Thibaud** et absents des scores. Deux défauts corrigés pour les longues portées : `Shots` était purgé après 5 min (`SHOT_KEEP_S`, passé à 1 h) alors qu'un SLAM-ER vole plus de 20 min ; une cible détruite d'un coup n'a plus de position, donc plus de distance (repli : dernière position du missile, `shot.last`). Canon : pas de cause prouvée (pas de suivi d'arme ; Weefe, hôte de son serveur, n'est pas dans `missionstats`) ; vol non validé (crash, slot quitté) ou cible non localisée. Nouvelle ligne `BlueSky kill : …` dans `dcs.log` à chaque kill (arme, distance, cible localisée, tir suivi). Un kill à moins de 1 m est enregistré à 1 m (0 = pas de record). Message en jeu : impact de moins de 30 s et jamais à la place de la cible ; il affiche « Distance de tir », la valeur des records. Un missile en vol quand le pilote quitte son avion, ou un vol qui finit mal, ne compte toujours pas (règle des kills validés à l'atterrissage).
- **Kills en un vol séparés** : `maxKillsFlightAA` et `maxKillsFlightAS` (bateaux compris) remplacent `maxKillsFlight`, qui reste en base mais n'est plus affiché. Les deux records repartent de zéro (l'ancien cumul ne se découpe pas). Script, `scores.py`, `Code.gs` (4 colonnes en fin), `data.js`, `classements.js` (`?v=15`).
- **Barème** (choix de Thibaud) : véhicule 2 (avant 1), défense aérienne 5 (avant 3), navire 8 (avant 5) ; dépôt de munitions, poste de commandement, réservoir (`Tank 2`) 5 ; avions parqués statiques 2 ; autres statiques 1 ; A/A inchangé. S'applique aux nouveaux kills seulement. Kneeboard page 02 modifié dans la source.
- **Déploiement** : ✅ `scores.py` sur R2D2 (10/11 à 1 h 35, sauvegarde `~/backups/scores.py.avant-kills-separes-20261110`, bot relancé, BlueSky chargé), `partage/maj` (2 copies) et moteur local ; site poussé (commit 3c4de71, vérifié en ligne ; `kneeboard.html` laissé hors du commit car il contient le mémo radio jamais publié). Git : plus de git sous Windows, utiliser `wsl.exe -e git` (dépôt sous `/mnt/c/...`) avec le jeton de `gh auth token`. Script + page 02 du kneeboard injectés le 10/11 à 1 h 43, DCS fermé (sauvegarde `bakup\…_2026-11-10_01-43-58.miz.bak` à côté de la .miz, 24 pages intactes) ; .miz déposée dans `partage/fichiers` (ancienne : `~/backups/mission-weefe-avant-2026-11-10.miz`). `Code.gs` redéployé par Thibaud, vérifié le 10/11 (38 colonnes dans `?format=json`). Restent : Weefe : FICHIERS / MAJ, remplacer la mission du serveur, relancer ; test en jeu (mode Blue Sky, tir longue portée, canon). Le bot doit garder le nouveau `scores.py` avant toute mission avec le nouveau script (sinon il additionne les nouveaux records comme des compteurs).
## 10/11/2026 : onglets F10 SPAWN / MISSIONS / CODE, missions à code (codé, injecté, PAS testé en jeu)
Sauvegardes : `mission\bakup\script Caucase_2026-11-10_avant-missions-code.lua` et `bakup\…_2026-11-10_11-39-59.miz.bak` à côté de la .miz. Injecté DCS fermé, kneeboard 24 pages intact (page 02 refaite). La .miz de Weefe n'a pas ces changements. Test hors jeu : `python tools/test_missions_code.py`.
- **SPAWN** (coalition bleue, remplace AIR-AIR et AIR-SOL) : Spawn ENI, HOST A/A AERA (MiG-21/29, Su-27, Clear hostile), HOST Naval AERA (active `Admiral`), Reset Croix, Spawn Convoi.
- **MISSIONS** (menu par groupe, pour savoir qui lance) : INTERCEPTION (Lancer / Appel radio), Petrol Strike, HOST Naval AERA, Rappel de mes missions.
- **CODE** (menu par groupe) : chiffres 1 à 9 + Effacer, code à 3 chiffres. Le lanceur est inscrit d'office et reçoit briefing + code à donner à ses équipiers. Une seule mission de chaque type à la fois.
- **Privé aux membres** : briefing et messages de mission, appel radio, bonus. Bonus égal à chaque membre encore en vie (mort ou slot quitté : rien), validé à l'atterrissage. Interception : tous les membres ont le bonus (avant : seulement ceux qui appelaient, ou le tireur). Pilote hors mission qui abat la cible : kill normal, pas de bonus, interception finie.
- **Petrol Strike** : détruire les 3 derricks et la plateforme (`Oil rig` / `Gas platform` à moins de 3 km du champ), **+20 pts**. **HOST Naval AERA** : couler le Kuznetsov (`CV_1143_5` du groupe `Admiral`, activé par le lancement), **+50 pts**. Autre mission = une entrée dans `STRIKES`. Cibles détruites : mission non relançable jusqu'au redémarrage. Plus aucun membre en slot pendant 10 min : mission fermée.
- **À tester en jeu** : menus de groupe sur slot dynamique, code à plusieurs joueurs, détection des derricks détruits (`getLife` sur statiques) et du Kuznetsov coulé, bonus à l'atterrissage.
- Tu-95 (10/11, injecté DCS fermé, sauvegarde `bakup\…_2026-11-10_11-44-59.miz.bak`) : message du dernier virage (`turning`) envoyé dans tous les cas sauf en plein combat (avant : seulement si le Su-27 était appelé et pas encore arrivé). Spawn : position de l'éditeur, x -77375 / y 645263 (reculée d'environ 60 km par Thibaud), aucun changement de code. À faire par Thibaud dans l'éditeur : retirer canon et R-73 du Su-27 `Escorte tu95 inter`. Textes radio du Tu-95 à réécrire avec lui.
- Textes des interceptions (10/11, injecté DCS fermé, sauvegarde `bakup\…_2026-11-10_11-57-06.miz.bak`) : « BLUE SKY CONTROL » remplacé par **SCRAMBLE** (alertes) et **COMMANDEMENT** (le reste), « chasse Blue Sky » par « chasseur d'interception », mentions de 243.0 retirées, frontière au lieu de zone, plus de destination annoncée en fin de mission. Tu-95 : alerte avec le cap du lanceur vers l'avion (`cap %03d depuis pseudo`), « dans quelques instants » ajouté, ordre de tir du COMMANDEMENT à la mort du Su-27 (une fois, avant ou après son ouverture du feu). **10 s** entre deux appels ; plus d'appel à faire = « Personne ne repond ». **Punition** (`TuPunish`) : Tu-95 abattu sans autorisation par un membre : le Su-27 attaque le tireur (créé 15 km derrière lui s'il n'est pas en vol), sans annonce, puis rentre à Maykop. Test hors jeu : `tools/test_missions_code.py`. Pas testé en jeu.
- Yak-40 et Su-34 alignés sur le Tu-95 (10/11, injecté DCS fermé, sauvegarde `bakup\…_2026-11-10_11-58-47.miz.bak`) : cap du lanceur dans l'alerte, ordres de tir reformulés (plus de « déclaré HOSTILE »), « Personne ne repond » quand aucun appel n'est possible (`noCall` du Su-34 retiré), plus de destination annoncée. Pas testé en jeu.
- **Anti-triche des bonus** (10/11, injecté DCS fermé, sauvegarde `bakup\…_2026-11-10_12-05-39.miz.bak`) : un membre n'a le bonus que s'il est venu au moins une fois sur zone (`OpMarkPresent`, vérifié toutes les 5 s, message de confirmation au joueur). HOST Naval : zone d'éditeur `Host naval aera` (45,7 km, 25 NM). Petrol : cercle du dessin F10 (`PETROL`, 7,6 km, 4 NM). Interception : moins de 20 NM de l'avion (`ICPT_NEAR_M`). Les absents vivants sont nommés dans le message de fin. Pas testé en jeu.
- Zone du bonus d'interception ramenée à **3 NM** de l'avion (`ICPT_NEAR_M`, 10/11, injecté DCS fermé, sauvegarde `bakup\…_2026-11-10_12-09-22.miz.bak`). À trancher par Thibaud : condition de zone de Petrol Strike une fois son cercle F10 retiré (10 NM, 4 NM ou aucune).
- Petrol Strike (10/11, choix de Thibaud, injecté DCS fermé, sauvegarde `bakup\…_2026-11-10_12-11-26.miz.bak`) : **aucune condition de zone**, tout membre vivant a le bonus (`STRIKES` sans `zone`). `PETROL` ne sert plus qu'à trouver les derricks. La condition de présence reste pour HOST Naval (25 NM) et les interceptions (3 NM). Remplace la décision « à trancher » ci-dessus.

## 10/11/2026 : voix IA des interceptions (essais, PAS intégré à la mission)
Dossier `serveur BS\voix-ia` (hors `site`, pas dans le dépôt) : Chatterbox Multilingual en local sur la RTX 4070 (`.venv` Python 3.11, projet abandonné depuis 08/2026 : garder le dossier tel quel, `setuptools<81` obligatoire). `generer.py` génère, `references\` contient les voix modèles.
- **Validé par Thibaud** dans `voix-ia\validees` (.wav + .ogg, ne jamais les régénérer, le résultat change à chaque passage) : `tu95_refus` (voix russe), `yak_mayday` (version forte) et `yak_nav` (version lointaine), voix de Thibaud.
- Réglages retenus : exaggeration 0.6, cfg 0.7, temperature 0.6, voix baissée de 1,5 demi-ton, durée recalée à 7 s. Pas de mot anglais dans une phrase française (ça fait bégayer).
- Seule une voix dont la personne est d'accord sert de modèle (refus de cloner une voix YouTube). La voix russe vient de la démo Chatterbox : droit de réutilisation non vérifié.
- Indicatifs épelés à la voix (demande de Thibaud) : « India Juliette Alpha Kilo Écho », « Ромео Фокстрот пять девять », « Виктор Виктор Сьерра три четыре » ; les messages texte du script gardent I-JAKE, RF-59, VVS 34. Verrouillés le 10/11 dans `voix-ia\validees` : `yak_mayday`, `yak_nav`, `yak_cap`, `tu95_refus`, `tu95_mensonge`, `tu95_demitour`, `tu95_virage`, `su34_recu`, `su34_base`. Les caps variables ne sont pas dits à la voix (« ce cap », « demi-tour »), le chiffre reste dans le texte.
- Voix françaises décidées : chasseur = voix de Titirex `references\fr_titirex.wav` (accord donné sur Discord le 10/11), 1 demi-ton plus bas, effet radio fort avec souffle (entrée `fr_chasseur` de `generer.py`), `chasseur_tu95_1` verrouillé dans `validees` ; COMMANDEMENT = voix de Weefe `references\fr_weefe.wav`, débit +15 % (`atempo=1.15`, entrée `fr_commandement` de `generer.py`), décidé pour tous ses messages présents et futurs. `commandement_tir` est verrouillé dans `validees`. L'extrait vient d'un texte lu par Weefe pour un TikTok : obtenir l'accord de Weefe avant l'intégration à la mission. Appellations du script : « chasseur d'interception », COMMANDEMENT, SCRAMBLE (plus de « Blue Sky Control » ni de « chasse Blue Sky »).
- Décisions du 10/11 : SCRAMBLE dit par la voix du COMMANDEMENT, pas de voix pour les messages AIRBOSS d'appontage, tous les indicatifs à la voix en alphabet OACI, en français pour le COMMANDEMENT et le chasseur (« Roméo Foxtrot cinq neuf », « Victor Victor Sierra trois quatre »). Yak-40 retiré : ses 3 voix de `validees` ne servent plus. Russes à refaire en anglais avec un fort accent russe (voix retenue le 10/11 : `references\en_accent_russe.wav`, enregistrée par un ami de Thibaud, accord de cette personne à obtenir avant intégration ; langue `en`, essais dans `essais_bluesky\russe_en`, réglage normal ou fort à choisir) ; les 6 voix russes de `validees` restent en attendant la validation.
- 10/11 : textes validés par Thibaud, toutes les répliques générées (4 prises, meilleure gardée à la transcription) dans `voix-ia\a_ecouter`, nommées par numéro de call (`cNN_...`), avec un fichier `*_complet.wav` par voix. Pas encore validées à l'oreille.
- **Injecté le 10/11 à 19 h 04**, DCS fermé (sauvegarde `bakup\…_2026-11-10_19-04-52.miz.bak`, script `bakup\script Caucase_2026-11-10_avant-voix.lua`). Les 31 calls sont verrouillés dans `validees` (`cNN_*.wav/.ogg`, numéros = liste des calls), copiés dans la .miz et référencés dans `mapResource` et le déclencheur de départ, comme PA.ogg (sinon l'éditeur les supprime). Script : table `VOIX` (fichier, durée) et `OpVoice` (sons à la suite, aux seuls membres de la mission, `outSoundForUnit`) ; chaque texte d'interception, strike et CAP a son champ `voice`. Alertes des calls 1 et 12 : « COMMANDEMENT : » au lieu de « SCRAMBLE : » ; 3 espaces manquantes corrigées. Accords : Titirex (capture Discord), Weefe et l'ami confirmés par Thibaud le 10/11. Test hors jeu `tools/test_missions_code.py` (voix incluses) OK.
- Reste : test en jeu (sons entendus, enchaînement appel / réponse / ordre du COMMANDEMENT), la .miz de Weefe n'a pas les voix, voix de l'accueil à trancher. Un joueur qui rejoint par code n'entend pas le briefing déjà joué.


## 10/11/2026 : zone CAP en vagues + mission CAP à code, Yak-40 retiré (codé, injecté, PAS testé en jeu)
- Thibaud a supprimé le groupe `Yak 40` de la .miz : son code et son entrée `INTERCEPTS` sont retirés du script. Restent Tu-95 et Su-34.
- Zone polygonale `spawn cap` (autour de Maykop), 10 groupes dans `CAP_GROUPS`. Une vague = 1 groupe tiré au sort, position aléatoire dans la zone. Vague suivante quand tous ses avions sont abattus, posés, à court de carburant ou sans missile (`EniWaveOver`, 1 h maxi). Une vague finie encore en l'air rentre à Maykop.
- Patrouille : le script donne des points au hasard dans la zone (240 m/s, tick 15 s). Sorti de la zone : retour sans engager, puis 90 s avant de réengager (`CAP_BACK_S`), ce qui évite les allers-retours sur la limite. Altitude de l'éditeur bornée entre 5000 m (sommets) et 12000 m (le MiG-31 était à 21000 m).
- F10 SPAWN > Zone CAP > Activer / Desactiver. F10 MISSIONS > CAP : code, 5 avions de la zone abattus par les membres, +30 pts par membre vivant passé au moins une fois dans la zone. La mission fait tourner les vagues ; à la fin elles s'arrêtent sauf si Activer a été cliqué.
- Kneeboard : page 01, Reaper 244 -> 227 (valeur de la .miz) ; page 02, Zone CAP et CAP ajoutés. Injecté avec le script, sauvegarde `Blue Sky Multi-joueur DAY_Caucasus_2026-11-10_16-54-44.miz.bak`.
- Tests hors jeu : `python site/tools/test_missions_code.py` (CAP inclus). À vérifier en jeu : tenue dans la zone en combat, engagement du `su34 cap` (tâche Ground Attack dans l'éditeur).
- Même jour : les 21 groupes rouges qui n'étaient pas sur 300 MHz y sont passés dans la .miz (HOST A/A, interceptions, `su30 cap`, `awacs-red`, hélicos), seul changement vérifié par comparaison complète de la mission. Sauvegarde Blue Sky Multi-joueur DAY_Caucasus_2026-11-10_16-59-38.miz.bak.
