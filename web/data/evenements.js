// Planning des vols, affiché sur l'accueil et la page Discord.
// À éditer à la main en attendant la synchro avec les événements Discord (bot).
// date : 'AAAA-MM-JJTHH:MM' (heure de Paris). demo: true affiche le badge « Exemple ».
window.BS_EVENTS = {
  demo: true,
  events: [
    { title: 'Foothold — Soirée campagne', type: 'Multijoueur', map: 'Caucase', date: '2026-10-20T21:00', slots: 16, registered: 11, host: 'Branch' },
    { title: 'Entraînement appontage Case I', type: 'Formation', map: 'Caucase', date: '2026-10-22T20:30', slots: 8, registered: 5, host: 'Breakdown' },
    { title: 'Blue Sky Aerobatics — Répétition', type: 'Patrouille', map: 'Normandie · Paris', date: '2026-10-24T21:00', slots: 8, registered: 8, host: 'Breakdown' },
    { title: 'OPERATION SILENT WAVE — Phase 2', type: 'Opération', map: 'Syrie', date: '2026-10-27T21:00', slots: 20, registered: 14, host: 'Breakdown' },
    { title: 'Soirée découverte nouveaux pilotes', type: 'Accueil', map: 'Caucase', date: '2026-10-31T20:30', slots: 12, registered: 4, host: 'Smokey' }
  ]
};
