# Circuit stats → site Blue Sky

```
Serveur Weefe : script Caucase.lua → Scores.lua
                Scripts\Hooks\BS_site.lua → JSON → curl ──► Apps Script ──► Google Sheet "BS Stats"
Ton PC        : publier_maj.bat (changelog)  ─────────────►      │
                                                    Page web doGet() ──► intégrée dans Google Sites
```

## 1. Google Sheet + Apps Script (toi, une fois)
1. Crée une feuille Google vide nommée **BS Stats**. Les onglets Pilotes, Serveur et Changelog se créent tout seuls.
2. **Extensions → Apps Script**. Remplace le contenu de `Code.gs` par celui du fichier `Code.gs` de ce dossier.
3. Clique sur **+ → HTML** et nomme le fichier **Page** (exactement). Colle-y le contenu de `Page.html`.
4. **⚙️ Paramètres du projet → Propriétés du script → Ajouter** : propriété `TOKEN`, valeur = le token
   de `secrets.local.ps1` (fichier local, jamais publié sur GitHub).
5. Enregistre, puis **Déployer → Nouveau déploiement → type « Application Web »** :
   - Exécuter en tant que : **Moi**
   - Qui a accès : **Tout le monde**
   - Autorise l'accès quand Google le demande.
6. Copie l'**URL de l'application Web** (`https://script.google.com/macros/s/.../exec`) et colle-la :
   - dans `BS_site.lua` (`url = ...`, et `token = ...` avec le token)
   - dans `secrets.local.ps1` (`$url = ...`)
   - dans `web/js/config.js` (`statsUrl: ...`) : le site affiche alors les vraies stats au lieu de la démo.

⚠️ Après chaque modification de `Code.gs` ou `Page`, fais **Déployer → Gérer les déploiements → ✏️ → Version : nouvelle version**,
sinon l'ancienne version reste en ligne. L'URL ne change pas.

## 2. Serveur de Weefe (une fois)
1. Copier `BS_site.lua`, avec l'URL et le token remplis, dans
   `C:\Users\<weefe>\Saved Games\DCS.<nom_serveur>\Scripts\Hooks\` (créer `Hooks` s'il n'existe pas).
2. Redémarrer le serveur DCS. Dans `Logs\dcs.log`, on doit voir `BS_SITE ... BS_site.lua charge`,
   puis `stats envoyees (N pilotes)` environ 1 minute après le lancement d'une mission.
- Le hook lit le `Scores.lua` du même dossier Saved Games, celui qu'écrit `script Caucase.lua`.
- Il envoie les stats quand Scores.lua change, toutes les 5 min (pour les joueurs en ligne), à la connexion
  ou déconnexion d'un joueur, et en fin de mission.
- Il utilise `curl.exe`, fourni avec Windows 10 et 11 ; rien à installer.

## 3. Changelog (ton PC)
Après une modification de `mission\script Caucase.lua`, double-clique sur `publier_maj.bat`.
Le script te demande la version et les notes, puis les envoie dans l'onglet Changelog.

## 4. Google Sites
1. sites.google.com → **Vide** → nomme le site « Blue Sky France ».
2. Page « Classement » : **Insérer → Intégrer → Par URL** → colle l'URL de l'application Web
   → « Page entière ». Agrandis le cadre.
3. Autres pages : présentation, Discord, TikTok, YouTube, logos (`blue_sky.png`, `logo_bl.png`).
4. **Publier**.

Données brutes en JSON (pour un futur site perso) : `<URL>?format=json`.

## Test rapide sans DCS
Une fois le déploiement fait, envoie des stats de test (PowerShell) :
```powershell
$b = '{"token":"<TOKEN>","type":"scores","server":"test","mission":"test","online":[],"pilots":[{"name":"Test","points":10,"totalFlightTime":3600,"grade":"ROOKIE"}]}'
Invoke-RestMethod -Uri '<URL>' -Method Post -Body $b -ContentType 'application/json'
```
La réponse doit être `ok`, et la ligne « Test » doit apparaître dans l'onglet Pilotes.
