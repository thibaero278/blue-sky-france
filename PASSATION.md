# PASSATION — Projet site Blue Sky (DCS)

_Dernière mise à jour : 21/10/2026 (missions, inscriptions, temps vocal, ménage des commandes du bot)_

> À lire en début de session. Mis à jour par Claude Code à chaque changement.
> (`CLAUDE.md` est géré par Claude Chat : ne pas y toucher.)

## Contexte
- Communauté DCS francophone **Blue Sky France** (~140 membres), fondée par Thibaud.
- **Weefe** (admin BS) héberge les serveurs multi (chez Thibaud l'hébergement ne marche pas).
- Mission : `Blue Sky Multi-joueur DAY_Caucasus.miz` (Caucase).
- Script : `multi jours thib.lua` (1243 lignes, basé sur **MOOSE**).

## Objectif final
Un site Blue Sky (Google Sites envisagé) avec :
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
  - Serveur invisible en multi : pare-feu Windows OK (règles DCS TCP/UDP 10308 entrantes). Box **SFR** (192.168.1.1), PC en
    192.168.1.43 (Ethernet) **et** 192.168.1.66 (Wi-Fi) → redirection 10308 TCP+UDP à faire sur la box vers la bonne IP + bail DHCP fixe.
    IP publique 37.67.72.41 (à comparer avec l'IP WAN de la box pour écarter un CGNAT).
  - **Fait par Thibaud** (box GR140IG) : bail statique MAC `D8:43:AE:7B:38:C5` (câble) → **192.168.1.200** (PC renouvelé, OK),
    anciennes règles (33674, 10308 UDP → .43) supprimées, nouvelle règle « DCS » 10308 TCP/UDP → 192.168.1.200.
    ⚠️ La box avertit que l'IPv4 utilisateur peut ne pas marcher « en raison de l'architecture de routage IPv6 WAN »
    → IPv4 partagée probable (MAP-T / DS-Lite, plage de ports limitée).
  - **CGNAT confirmé** (menu WAN) : IPv4 WAN de la box = **10.153.38.136** (privée), passerelle 10.153.38.137 ; l'IP publique
    37.67.72.41 est partagée par SFR. **Aucune redirection de port ne peut marcher** : c'est la vraie raison pour laquelle personne
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

## Prochaines étapes
- **Missions / vocal** : redéployer `Code.gs` (Gérer les déploiements → nouvelle version), redémarrer le bot (STOP/GO), créer un
  événement test, publier un briefing par clic droit, voter, vérifier la page Discord et la page mission ; pousser le site.
0. Vérifier en jeu le kneeboard (RShift+K) et que la nouvelle .miz charge bien le script ; l'envoyer à Weefe.
1. Retester rapidement les heures complétées (atterrir puis crasher → seul le total doit bouger).
2. Ajouter `thibaero278/blue-sky-france` dans Graphify (accès de l'app GitHub Graphify au dépôt).
3. Déployer l'Apps Script (INSTALLATION.md § 1), remplir `relay` (+ `feed_channel`) dans `bluesky.yaml`, redémarrer le bot,
   mettre l'URL dans `web/js/config.js` → site en données réelles. Tester en jeu : `-stats`, carte live, `/annonce`.
4. **Connexion DCS ↔ site (plan)** :
   - a. Stats : déjà prévu via hook + Apps Script (étape 3).
   - b. Carte live : étendre `BS_site.lua` : toutes les ~5 s, `net.dostring_in('server', …)` lit les unités des joueurs
     (`coalition.getPlayers`, `Unit:getPoint`, `coord.LOtoLL`, cap/vitesse) → JSON au format de `liveUrl` (voir `web/js/data.js`).
     Apps Script trop lent/limité pour 5 s → petit relais (Cloudflare Worker gratuit) ou DCSServerBot.
   - c. Discord activité + planning auto : bot Discord (ou DCSServerBot, qui gère déjà Discord + stats + événements) —
     demander à Weefe s'il l'utilise déjà sur le serveur.
