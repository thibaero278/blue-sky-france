// Contenu de la page Blue Sky Ops. À éditer à la main.
// Photos : les mettre dans assets/ops/ puis les déclarer dans PHOTOS. Uniquement des captures de nuit,
// pas de photos de jour (un filtre vert sur une photo de jour rend mal).
// tiktok / youtube : le lien complet de la vidéo, vide = « vidéo à venir ». date : 'AAAA-MM-JJ'.
(function () {
  const PHOTOS = {
    lune:      { src: 'assets/ops/hornet-lune.jpg', alt: 'Hornet en silhouette devant la pleine lune' },
    pont:      { src: 'assets/ops/hornet-pont-lune.jpg', alt: 'Hornet armé sur le pont, la lune entre les dérives' },
    verriere:  { src: 'assets/ops/pilote-verriere.jpg', alt: 'Pilote sous la verrière, au crépuscule' },
    c130:      { src: 'assets/ops/cockpit-c130-nvg.jpg', alt: 'Cockpit de C-130 en éclairage de nuit' },
    nvg:       { src: 'assets/ops/nvg-ailier.webp', alt: "L'ailier vu dans les lunettes de vision nocturne" },
    hud:       { src: 'assets/ops/cockpit-hornet-nuit.jpg', alt: 'Cockpit de Hornet de nuit, sous les étoiles' },
    plateformes: { src: 'assets/ops/flir-plateformes.jpg', alt: 'Plateformes en mer vues à la caméra infrarouge du pod de ciblage' },
    camp:      { src: 'assets/ops/flir-camp.webp', alt: 'Camp ennemi pointé au pod de ciblage' },
    ville:     { src: 'assets/ops/ville-nuit.jpg', alt: 'Survol de nuit au-dessus des lumières de la ville' }
  };

  window.BS_OPS = {
    demo: true,
    photos: Object.values(PHOTOS),
    // Ce qu'on vole. photo = celle qui s'affiche à côté quand on passe sur la ligne.
    missions: [
      { code: 'CAP', name: 'Patrouille de combat', desc: 'Tenir un secteur, identifier et intercepter tout ce qui y entre.', photo: PHOTOS.lune },
      { code: 'CAS', name: 'Appui rapproché', desc: "Soutenir les troupes au sol sous le guidage d'un contrôleur.", photo: PHOTOS.camp },
      { code: 'SEAD', name: 'Suppression des défenses', desc: 'Faire taire radars et missiles pour ouvrir le passage.', photo: PHOTOS.nvg },
      { code: 'Strike', name: 'Frappe planifiée', desc: 'Un objectif, une heure, et le package qui va avec.', photo: PHOTOS.plateformes },
      { code: 'Interception', name: 'Interception', desc: 'Décoller vite, rejoindre la piste radar et identifier avant de tirer.', photo: PHOTOS.hud }
    ],
    // Dernière opération affichée sur la page.
    last: {
      code: 'Silent Wave', phase: 'Phase 2', date: '2026-10-27', map: 'Syrie', pilots: 14, duration: '2 h 40', result: 'Succès',
      cover: PHOTOS.lune, tiktok: '',
      summary: "Une vague SEAD ouvre le corridor nord, la frappe suit sur le dépôt logistique. Deux appareils perdus, tous les pilotes récupérés."
    },
    // Les deux versions de la livrée. photo vide = « photo à venir » ; ex. photo: 'assets/ops/livree-visibility.jpg'
    livery: {
      tiktok: 'https://www.tiktok.com/@_thibaero_/video/7672770407853739296',
      versions: [
        { name: 'Blue Sky Ops Visibility', photo: '' },
        { name: 'Blue Sky Ops Low Visibility', photo: '' }
      ]
    }
  };
})();
