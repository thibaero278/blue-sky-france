# PASSATION — Projet site Blue Sky (DCS)

_Dernière mise à jour : 03/11/2026 (scores fusionnés sur R2D2, stats de Weefe importées, .md remis en cohérence)_

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
