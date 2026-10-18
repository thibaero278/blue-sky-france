# PASSATION — Projet site Blue Sky (DCS)

_Dernière mise à jour : 19/10/2026_

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
  `image\` (sauf claude-design.md), `.miz`, `bakup\`, kneeboard PNG générés, secrets. Pas encore poussé sur GitHub.

## Prochaines étapes
0. Vérifier en jeu le kneeboard (RShift+K) et que la nouvelle .miz charge bien le script ; l'envoyer à Weefe.
1. Retester rapidement les heures complétées (atterrir puis crasher → seul le total doit bouger).
2. **GitHub** : créer le dépôt `thibaero278/<nom>`, pousser, puis l'ajouter dans Graphify (il indexe les dépôts GitHub du compte).
   Hébergement possible : GitHub Pages (dépôt public sur compte gratuit) — le token n'est pas dans le dépôt.
3. Déployer le circuit stats (INSTALLATION.md) puis mettre l'URL dans `web/js/config.js` → le site passe en données réelles.
4. **Connexion DCS ↔ site (plan)** :
   - a. Stats : déjà prévu via hook + Apps Script (étape 3).
   - b. Carte live : étendre `BS_site.lua` : toutes les ~5 s, `net.dostring_in('server', …)` lit les unités des joueurs
     (`coalition.getPlayers`, `Unit:getPoint`, `coord.LOtoLL`, cap/vitesse) → JSON au format de `liveUrl` (voir `web/js/data.js`).
     Apps Script trop lent/limité pour 5 s → petit relais (Cloudflare Worker gratuit) ou DCSServerBot.
   - c. Discord activité + planning auto : bot Discord (ou DCSServerBot, qui gère déjà Discord + stats + événements) —
     demander à Weefe s'il l'utilise déjà sur le serveur.
