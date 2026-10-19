// Réglages du site Blue Sky France.
// Une source laissée vide => la page affiche des données de démonstration, avec un badge « Démo ».
window.BS_CONFIG = {
  // URL du relais Apps Script (circuit_site/Code.gs), sans ?format=… — alimenté par le bot Discord (plugin bluesky).
  // Donne d'un coup : stats pilotes, joueurs en ligne, carte live (?format=live), activité et événements Discord.
  // Ex. : 'https://script.google.com/macros/s/XXXX/exec'
  statsUrl: '',

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
  discordActivityUrl: '',  // ancien réglage, gardé pour compatibilité

  discordInvite: 'https://discord.gg/zVEsRbm8h2',
  discordInviteCode: 'zVEsRbm8h2',   // sert à lire le nombre de membres / en ligne via l'API publique Discord

  serverName: 'Blue Sky | Foothold',
  missionLabel: 'Foothold · Caucase',

  refreshSeconds: 60,

  // Équipe affichée sur l'accueil. `pseudo` = nom en jeu (pour retrouver le grade dans les stats).
  staff: [
    { callsign: 'Breakdown', name: 'Thibaud', role: 'Fondateur', pseudo: 'Breakdown' },
    { callsign: 'Branch', name: 'Weefe', role: 'Second · Admin serveur DCS', pseudo: 'Branch' },
    { callsign: 'Smokey', name: 'Xerion', role: 'Modérateur', pseudo: 'Smokey' },
    { callsign: 'Redman', name: null, role: 'Helper', pseudo: 'Redman' }
  ]
};
