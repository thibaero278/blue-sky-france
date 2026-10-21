# CONFORMITÉ JURIDIQUE — Site Blue Sky France

_Dernière mise à jour : 21/10/2026_

> Suivi de travail. Ce que voient les visiteurs, ce sont les **pages du site**, reliées depuis le pied de page bleu
> de toutes les pages (colonne « Infos légales » + dernière ligne) :
> `web/mentions-legales.html`, `web/confidentialite.html`, `web/cookies.html`, `web/mes-donnees.html` (formulaire « Supprimer mes stats »).

## 1. Réponses de Thibaud (21/10/2026)
- Particulier, site non monétisé → **régime anonyme** (LCEN art. 1-1 II) : seules les coordonnées de l'hébergeur sont publiées.
- Hébergeur : GitHub Pages. Pas d'autre sous-traitant connu.
- Conservation voulue : « à l'infini », avec un endroit pour demander la suppression totale de ses stats.
- « Beynost » retiré du pied de page (pas obligatoire). Pas d'âge minimum.

## 2. Audit du code (commit 249fa05, Graphify + lecture des fichiers)
| Point | Constat |
|---|---|
| Connexion / OAuth | Aucune (ni Google ni Discord sur le site). |
| Formulaires | Recherche de pilote (locale) ; **nouveau** : formulaire de suppression → Apps Script. |
| Cookies / localStorage / traceurs | Aucun. Pas d'analytics, pub, partage social, reCAPTCHA, embed. → **pas de bandeau**. |
| Contenu publié par les visiteurs | Aucun → pas de mécanisme de signalement DSA nécessaire sur le site. |
| Tiers contactés (reçoivent l'IP) | GitHub Pages (toutes), Apps Script (toutes : pastille serveur), Discord API (Accueil, Discord), OpenStreetMap (Carte). Google Fonts et unpkg **supprimés** (polices dans `web/assets/fonts/`, Leaflet 1.9.4 dans `web/assets/leaflet/`, empreinte SHA-384 identique à l'ancien SRI). |
| Données publiques | Pseudos DCS + stats ; joueurs en ligne + position en jeu ; pseudo Discord + rôle du staff ; organisateur des événements ; prénom « Thibaud » dans l'équipe (`config.js` → `staff`). |
| Stockage | Feuille Google « BS Stats » (Pilotes, Serveur, Changelog, **Demandes**) + propriétés LIVE/DISCORD ; base PostgreSQL de DCSServerBot (UCID, pseudo, **IP**, historique `players_hist`, liaison Discord, stats de mission) chez Thibaud et chez Weefe. |

## 3. Ce qui a été fait (21/10/2026)
- Pages mentions légales, confidentialité, cookies, mes données, datées, en HTML, publiques ; liens dans le pied de page de toutes les pages.
- Polices et Leaflet hébergés sur le site (plus d'IP envoyée à Google Fonts / unpkg).
- Formulaire « Supprimer mes stats » : `web/js/pages/mes-donnees.js` → `Code.gs` `suppression_()` (sans token, champ piège anti-robot,
  30 demandes/heure max, protection contre les formules dans Sheets) → onglet **Demandes** + e-mail au propriétaire du script.
  Testé : page (envoi simulé) et `Code.gs` (services Google simulés). **Pas encore actif en ligne** (voir § 4).
- Outil `tools/supprimer_pilote.py` (testé sur une copie : 22 → 21 pilotes, Lua valide).

## 4. Reste à faire par Thibaud
1. **Redéployer l'Apps Script** : coller le nouveau `circuit_site/Code.gs`, puis Déployer > Gérer les déploiements > modifier > **Nouvelle version**
   (même URL). Google demandera l'autorisation d'envoyer des e-mails (pour te prévenir des demandes) : accepter.
   Tant que ce n'est pas fait, le formulaire répond « la demande n'est pas passée » et renvoie vers Discord.
2. **Pousser le site** (git push) pour mettre les pages en ligne.
3. **Anonymat : GitHub doit vraiment avoir ton identité.** L'art. 1-1 II exige que tu aies communiqué à l'hébergeur tes nom, prénoms,
   domicile et téléphone. Un compte GitHub avec juste un e-mail ne le prouve pas. Piste : remplir tes informations de facturation
   (GitHub > Settings > Billing and licensing > Payment information). Sinon, publier ton identité dans les mentions légales.
   Toute monétisation (pub, affiliation, dons, vente) fait perdre ce régime.
4. **Durées de conservation à valider** : « à l'infini » n'est pas permis (RGPD art. 5.1.e : limitation de la conservation).
   Proposé et affiché sur le site : stats = tant que le pilote vole, effacées après **3 ans sans connexion** ;
   base du bot (UCID, IP, historique) = **12 mois** après la dernière connexion ; demandes = 1 an après traitement.
   À appliquer une fois par an : `/prune` (Discord, « users », 365 jours) et `supprimer_pilote.py` pour les pilotes absents depuis 3 ans.
5. Optionnel : `upload_errors: false` dans `cloud.yaml` du bot (les rapports de plantage partent chez le développeur de DCSServerBot).
6. Informer Weefe : il garde une copie de la base du bot ; les suppressions et durées s'appliquent aussi chez lui.

## 5. Procédure pour une demande de suppression (délai : 1 mois, RGPD art. 12.3)
1. E-mail reçu / ligne « A traiter » dans l'onglet Demandes.
2. Vérifier que c'est bien la personne (pseudo Discord cohérent, ou connexion au serveur avec ce pseudo).
3. **Mission arrêtée**, sur la machine du bot : `python tools/supprimer_pilote.py "…\Saved Games\DCS\Scores.lua" "pseudo"`
   (sauvegarde automatique dans `mission/bakup/`). Faire pareil avec le Scores.lua de Weefe.
4. Retirer le pseudo des alias dans `web/js/config.js` si l'outil le signale, pousser le site.
5. Discord : `/prune user:<membre ou UCID>` (efface le joueur de la base du bot).
   ⚠️ À vérifier : que `players_hist` (historique des IP) est bien vidé aussi (sinon `DELETE FROM players_hist WHERE ucid = …`).
6. Mettre « Traité le JJ/MM » dans la feuille, prévenir la personne sur Discord.

## 6. Points à vérifier avec la CNIL ou un juriste
- RGPD art. 13.1.a : l'identité du responsable de traitement doit être donnée. Le régime anonyme de la LCEN ne couvre que les
  mentions légales ; ici le responsable est désigné comme « le fondateur, particulier » avec un contact Discord + formulaire. Zone grise.
  Une adresse e-mail dédiée (sans ton nom) renforcerait le contact.
- Exception domestique (RGPD art. 2.2.c) : ne s'applique pas, car les données sont publiées sur Internet.
- Transferts hors UE : GitHub, Google, Discord déclarent le Data Privacy Framework UE–États-Unis (vérifié dans leurs politiques).
- Références vérifiées sur Légifrance le 21/10/2026 : LCEN art. 1-1 II et 1-2 (loi SREN 2024-449). Ne pas citer l'ancien art. 6 III.
  L'art. 1-1 II n'exige que le **nom et l'adresse** de l'hébergeur : pas besoin de son téléphone en régime anonyme.

## 7. Repris de la version du 20/10 (autre session, remplacée par celle-ci le 21/10)
Une première version des pages avait été mise en ligne le 20-21/10, avant les réponses de Thibaud
(placeholders publics, Google Fonts, sans formulaire). Elle est remplacée ; ses remarques encore utiles :
- **`web/data/stats.json` est dans un dépôt public** : un pseudo effacé reste lisible dans l'historique Git.
  Effacement complet = réécrire l'historique, ou ne plus versionner ce fichier (le site lit déjà le relais Apps Script).
- **Weefe** fait tourner le serveur et sa copie du bot : si vous décidez ensemble de l'usage des données, c'est une
  responsabilité conjointe (RGPD art. 26), à formaliser par un petit accord écrit entre vous.
- Demander l'accord de chaque membre de l'équipe affiché (indicatif, prénom). « Thibaud, Fondateur » sur l'accueil réduit l'anonymat : à toi de voir.
- Discord Developer Portal : mettre l'URL de `confidentialite.html` dans la fiche du bot. Chiffrement au repos de la base PostgreSQL : non traité.
- GitHub a aussi une entité européenne (GitHub B.V., Amsterdam) : je n'ai pas vérifié laquelle des deux fournit GitHub Pages en France.
  Pour l'instant, c'est GitHub, Inc. qui figure sur le site.
- Chaînes TikTok/YouTube liées : si elles deviennent monétisées, faire confirmer par un juriste que le site reste non professionnel.
- Les pages sans données (mentions, confidentialité, cookies) appellent quand même Apps Script pour la pastille du serveur : on pourrait l'éviter.
