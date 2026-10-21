# CONFORMITE — Blue Sky France (site `web/`)

Dernière mise à jour : 20 octobre 2026. Ce document est pour toi, il n'est pas publié sur le site. Il ne remplace pas l'avis d'un juriste.

## Ce que le site fait réellement (audit du dépôt)

Ce n'est pas qu'une vitrine : le site **publie des données de joueurs**.

- **Joueurs DCS** : pseudo en jeu, camp, scores, grade, temps de vol, présence en ligne, et position/appareil en direct (carte live). Chemin : serveur DCS → `BS_site.lua` / bot → Google Apps Script → tableur Google « BS Stats » → site.
- **Instantané public** : `web/data/stats.json` contient les pseudos et scores, dans un dépôt GitHub public (historique Git compris).
- **Discord** : le site lit les compteurs de l'invitation publique ; le bot compte les messages par jour (sans contenu ni auteur) et les membres en ligne (base PostgreSQL locale), publie les événements planifiés et la liste de l'équipe.
- **Équipe** : indicatif, prénom et rôle (dont « Thibaud, Fondateur ») affichés sur l'accueil.
- **Appels tiers depuis le navigateur du visiteur** (testé dans Chromium) : Google Fonts (toutes les pages), Google Apps Script (toutes les pages), Discord (accueil, page Discord), unpkg.com et OpenStreetMap (carte live).
- **Cookies et stockage local** : aucun (testé : 0 cookie, `localStorage` vide). Pas d'analytics, pas d'embed YouTube/TikTok (simples liens), pas de formulaire.

## Ce qui a été fait

- Pages `web/mentions-legales.html`, `web/confidentialite.html`, `web/cookies.html`, avec date de mise à jour, et `web/css/legal.css`.
- Colonne « Informations légales » (Mentions légales, Politique de confidentialité, Cookies) dans le pied de page commun (`web/js/layout.js`), donc visible sur toutes les pages du site.
- Mentions légales en mode **non professionnel anonyme** (LCEN art. 1-1, II) : seul l'hébergeur est indiqué.
- Pas de bandeau cookies : aucun traceur soumis à consentement.

## Ce que tu dois me fournir (placeholders `[À REMPLIR]` dans les pages)

1. **Téléphone de l'hébergeur** : la documentation officielle de GitHub que j'ai consultée n'en donne pas. À chercher auprès de GitHub.
2. **Moyen de contact** pour les droits RGPD (adresse e-mail dédiée, ou salon de ticket Discord). Sans contact, la politique est incomplète (RGPD art. 13).
3. **Responsable du serveur DCS et du bot** : le serveur et le bot sont ceux de Weefe. Si vous décidez ensemble des finalités, c'est probablement une responsabilité conjointe (RGPD art. 26), qui demande un accord entre vous. À trancher avec lui.
4. **Durée de conservation** des scores des joueurs, et des compteurs Discord. Je n'ai rien inventé. Idée : suppression après X mois sans connexion, et à la demande.
5. **Qui a accès** au tableur Google « BS Stats » et au script Apps Script.

## À vérifier

- **Données conservées par DCSServerBot** (moteur du bot, non présent dans le dépôt) : identifiants DCS, adresses IP ? Pas publiées sur le site, mais à lister et à durée limitée. Question à poser à Weefe.
- **Garanties de transfert hors UE** de Google, Discord, unpkg, OpenStreetMap : seule la certification Data Privacy Framework de GitHub est vérifiée (déclaration de GitHub).
- **Équipe affichée** : accord de chaque personne pour son indicatif et son prénom.
- **Anonymat (LCEN art. 1-1, II)** : il suppose que tu as réellement communiqué ton identité à GitHub (nom du compte/de facturation). Sinon la mention est fausse. De plus, le pied de page indique « Fondé par Breakdown · Beynost, France » et l'accueil « Thibaud, Fondateur » : cela réduit l'anonymat que tu as choisi. À toi de décider si tu les gardes.
- **Statut non professionnel** : tes liens TikTok et YouTube sont affichés sur le site. Si ces chaînes sont monétisées (récompenses TikTok, par exemple), un juriste doit confirmer que le site reste hors du régime professionnel, car le critère est l'existence d'une contrepartie économique liée au site.
- **Hébergeur** : GitHub a aussi une entité européenne, GitHub B.V. (Amsterdam). Je n'ai pas pu établir laquelle héberge GitHub Pages pour la France ; j'ai mis GitHub, Inc.
- **Discord Developer Policy** : renseigner l'URL de `confidentialite.html` dans la fiche du bot (Developer Portal). Vérifier le chiffrement au repos de la base PostgreSQL (non traité dans la politique que j'ai lue).

## Rappels et alertes

- **Sanction** (LCEN art. 1-2) : un manquement aux mentions légales est puni d'un an de prison et 75 000 € d'amende pour une personne physique (375 000 € pour une personne morale). À ne pas afficher sur le site.
- **Perte de l'anonymat** : toute monétisation (publicité, affiliation, vente) fait perdre le régime non professionnel. Le site ne doit pas en avoir.
- **Pseudos de joueurs** : ils peuvent contenir un prénom, et certains joueurs sont probablement mineurs. Prévois une procédure simple pour retirer un pseudo (l'opposition de l'art. 21 RGPD est annoncée dans la politique).
- **Historique Git** : `stats.json` reste lisible dans l'historique du dépôt public même après suppression. Pour un vrai effacement, il faudrait réécrire l'historique. Option plus simple : ne plus publier de pseudos dans le dépôt, ou ne publier que le relais Apps Script.
- **Si tu ajoutes une inscription** (même sans e-mail) : il faudra mettre à jour la politique avant ouverture. Si elle repose sur le consentement, le consentement des moins de 15 ans demande celui du titulaire de l'autorité parentale. S'il y a du contenu publié par les utilisateurs, il faudra un point de contact public, un moyen de signalement et des CGU (règlement UE 2022/2065).

## Recommandations de code non appliquées

- **Héberger les polices en local** plutôt que charger Google Fonts, et idem pour Leaflet (unpkg) : le visiteur n'enverrait plus son adresse IP à ces services.
- **Ne plus charger le relais Google Apps Script sur les pages sans données** (mentions, politique, cookies) : aujourd'hui `layout.js` l'appelle partout pour la pastille « serveur en ligne ».
- **Anonymiser les pseudos** dans `stats.json` et dans les captures publiques, ou n'y mettre que les agrégats.

## Sections de la demande non applicables

- **Google OAuth** (§3) : le site n'utilise aucune connexion Google.
- **Discord, connexion ou bot côté site** (§4) : le site n'utilise pas la connexion Discord. Le bot existe, voir « À vérifier ».
- **DSA et CGU** (§7) : le site ne publie aucun contenu d'utilisateur ; la modération du serveur Discord relève de Discord.
- **Vente, abonnement, publicité** (§8) : aucun. Accessibilité numérique (directive 2019/882) et CGV : sans objet tant qu'il n'y a pas de vente.

## État de vérification des références

| Référence | Statut |
|---|---|
| LCEN art. 1-1 (II anonymat, I 5° sous-traitant de stockage), art. 1-2 (sanctions) | Vérifiée dans un commentaire juridique. Texte officiel **non consulté** (Légifrance inaccessible depuis mon environnement) : à relire sur Légifrance |
| Art. 6 III LCEN (supprimé), « numéro de déclaration CNIL » | Volontairement non cités |
| Art. 82 loi Informatique et Libertés, exemptions « strictement nécessaire » | Vérifiée sur cnil.fr. La page ne cite pas explicitement le stockage local ; la formulation générale « stockage sur le terminal » le couvre selon moi |
| Art. 45 loi Informatique et Libertés (15 ans) | Vérifié seulement dans des sources secondaires : à relire sur Légifrance |
| Délibérations CNIL 2020-091 et 2020-092 du 17 septembre 2020 | Titres confirmés, non citées dans les pages. La « FAQ du 29 avril 2026 » n'a pas été retrouvée et n'est pas citée |
| RGPD art. 6.1.b/6.1.f, 15 à 22, 26 | Références standard |
| Adresse de GitHub, Inc., Data Privacy Framework | Lues dans la politique de confidentialité officielle de GitHub |
| Google API Services User Data Policy, Discord Developer Policy | Lues sur les pages officielles (Discord : sur la partie accessible) |

## Pour le déploiement

- Les pages utilisent des liens relatifs, donc elles fonctionnent sur GitHub Pages (`/mentions-legales`, `/confidentialite`, `/cookies`).
- Ces modifications sont sur la branche `conformite`, pas sur `main` : rien n'est publié tant que tu ne fusionnes pas.
