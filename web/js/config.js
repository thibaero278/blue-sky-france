// Réglages du site Blue Sky France.
// Une source laissée vide => la page affiche des données de démonstration, avec un badge « Démo ».
window.BS_CONFIG = {
  // URL du relais Apps Script (circuit_site/Code.gs), sans ?format=… — alimenté par le bot Discord (plugin bluesky).
  // Donne d'un coup : stats pilotes, joueurs en ligne, carte live (?format=live), activité et événements Discord.
  // Ex. : 'https://script.google.com/macros/s/XXXX/exec'
  statsUrl: 'https://script.google.com/macros/s/AKfycbyTW5T54LWVUvsy-mKAArZf-J3dsQ_GV6eBYCgB5-sxTKwoEWTaiNCBR2ZiBYNlPCfg5w/exec',

  // Sinon : instantané de Scores.lua, à régénérer avec  python tools/scores_to_json.py "Scores.lua"
  statsFile: 'data/stats.json',

  // Une même personne sous plusieurs pseudos en jeu → un seul pilote (nom affiché = la clé).
  pilotAliases: {
    'Breakdown': ['Breakdown 1-1 | Thibaud', '[ BS ]Thibaud | Breakdown'],
    'Branch': ['Branch 1-1 | Weefe'],
    'Smokey': ['Xerion I Smokey'],
    'Redman': ['Redman 1-1 | Titirex'],
    'Lixx': ['Napster 1-1 | Lixx', 'Napster1-1 | Lixx'],
    'DEX': ['WAVE OFF 1-1 l DEX', 'DEX WAVE OFF 1-1']
  },
  // Pseudos par défaut de DCS, jamais affichés au classement
  ignorePilots: ['Player', 'Joueur'],

  // Sources directes, seulement si on n'utilise pas le relais (fichiers écrits par le bot dans son export_dir).
  liveUrl: '',             // URL d'un live.json
  liveFile: '',            // ex. 'data/live.json'
  discordFile: '',         // ex. 'data/discord.json' (activité + événements Discord)
  missionsFile: '',        // ex. 'data/missions.json' (briefings publiés depuis Discord)
  discordActivityUrl: '',  // ancien réglage, gardé pour compatibilité

  discordInvite: 'https://discord.gg/zVEsRbm8h2',
  discordInviteCode: 'zVEsRbm8h2',   // sert à lire le nombre de membres / en ligne via l'API publique Discord
  // Salon #inscriptions (bouton « S'inscrire » quand l'événement n'a pas encore de sondage)
  signupChannel: 'https://discord.com/channels/864983516516843570/1562459201618452540',

  serverName: 'Blue Sky | Foothold',
  missionLabel: 'Foothold · Caucase',

  refreshSeconds: 60,

  // Icône des rôles de l'équipe (le nom du rôle Discord contient « match »), sinon le 1er émoji du rôle
  roleIcons: [
    { match: 'CAG', icon: '=✪=' },
    { match: 'AWACS', icon: '📡' },
    { match: 'ATC', icon: '🌐' },
    { match: 'MIAOU', icon: '🐱' }
  ],
  // Membres du Discord à ne pas montrer dans « L'équipe » (pseudo contenant ce texte)
  staffHidden: [],

  // Équipe affichée sur l'accueil. `pseudo` = nom en jeu (pour retrouver le grade dans les stats).
  staff: [
    { callsign: 'Breakdown', name: 'Thibaud', role: 'Fondateur', pseudo: 'Breakdown' },
    { callsign: 'Branch', name: 'Weefe', role: 'Second · Admin serveur DCS', pseudo: 'Branch' },
    { callsign: 'Smokey', name: 'Xerion', role: 'Modérateur', pseudo: 'Smokey' },
    { callsign: 'Redman', name: 'Titirex', role: 'Helper', pseudo: 'Redman' }
  ]
};
