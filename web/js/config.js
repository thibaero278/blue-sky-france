// Réglages du site Blue Sky France.
// Une source laissée vide => la page affiche des données de démonstration, avec un badge « Démo ».
window.BS_CONFIG = {
  // URL de l'application Web Apps Script (circuit_site/Code.gs), sans ?format=json.
  // Ex. : 'https://script.google.com/macros/s/XXXX/exec'
  statsUrl: '',

  // Positions des joueurs pour la carte live (pas encore exporté par le serveur).
  liveUrl: '',

  // Statistiques d'activité Discord (messages/jour, en ligne sur 24 h) : viendra du bot Discord.
  discordActivityUrl: '',

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
