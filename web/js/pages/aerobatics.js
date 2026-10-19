(function () {
  const { esc } = window.BS;
  const $ = id => document.getElementById(id);

  // Ajouter une photo : la mettre dans assets/ (en .webp de préférence) et l'ajouter ici.
  const PHOTOS = [
    { src: 'assets/forma-eiffel.webp', caption: 'Formation à 8 devant la tour Eiffel', cat: 'formation' },
    { src: 'assets/forma-dessous.webp', caption: 'Formation en flèche, fumigènes', cat: 'formation' },
    { src: 'assets/forma-arc.webp', caption: "Passage au-dessus de l'Arc de Triomphe", cat: 'formation' },
    { src: 'assets/duo-marine.webp', caption: 'Duo n°9', cat: 'formation' },
    { src: 'assets/solo-ville.webp', caption: 'N°8 en virage', cat: 'solo' },
    { src: 'assets/showroom.webp', caption: 'Alignement place de la Concorde', cat: 'sol' },
    { src: 'assets/duo-paris.webp', caption: 'Vol serré au-dessus de Paris', cat: 'formation' },
    { src: 'assets/duo-dynamique.webp', caption: 'Montée en duo', cat: 'formation' },
    { src: 'assets/solo-flou.webp', caption: 'Passage rapide à basse altitude', cat: 'solo' },
    { src: 'assets/nez-en-vol.webp', caption: 'Détail du nez', cat: 'solo' },
    { src: 'assets/au-sol.webp', caption: 'Au parking', cat: 'sol' },
    { src: 'assets/f18-sunset.webp', caption: 'Hornet au coucher du soleil', cat: 'sunset' },
    { src: 'assets/f18-dos-sunset.webp', caption: 'Retour au crépuscule', cat: 'sunset' },
    { src: 'assets/cockpit-sunset.webp', caption: 'Verrière au soleil couchant', cat: 'sunset' }
  ];
  const CATS = { all: 'Tout', formation: 'Formation', solo: 'Solo', sol: 'Au sol', sunset: 'Coucher de soleil' };
  const COLORS = [['Bleu nuit', '#1C2F57'], ['Blanc', '#F4F4F2'], ['Rouge', '#D22B26'], ['Or', '#D9B45A']];
  const THUMBS = ['assets/duo-paris.webp', 'assets/au-sol.webp', 'assets/nez-en-vol.webp'];

  let filter = 'all', lbList = PHOTOS, lbIdx = null;

  $('swatches').innerHTML = COLORS.map(([n, h]) => `<div class="swatch"><i style="background:${h}"></i><span style="flex:1">${n}</span><span class="mono" style="font-size:12px; color:#8a91a3">${h}</span></div>`).join('');
  const livery = PHOTOS.filter(p => p.cat !== 'sunset');
  $('photoCount').textContent = livery.length + ' photos';
  $('thumbs').innerHTML = THUMBS.map(src => `<button data-thumb="${src}" aria-label="Agrandir"><img src="${src}" alt="" loading="lazy"></button>`).join('');
  $('thumbs').addEventListener('click', e => {
    const b = e.target.closest('[data-thumb]');
    if (b) open(livery, livery.findIndex(p => p.src === b.dataset.thumb));
  });

  function renderGallery() {
    $('filters').innerHTML = Object.entries(CATS).map(([id, label]) => {
      const n = id === 'all' ? PHOTOS.length : PHOTOS.filter(p => p.cat === id).length;
      return `<button data-f="${id}"${id === filter ? ' class="on"' : ''}>${label} <small>${n}</small></button>`;
    }).join('');
    const list = filter === 'all' ? PHOTOS : PHOTOS.filter(p => p.cat === filter);
    $('gallery').innerHTML = list.map((p, i) => `<button data-i="${i}" style="--i:${i}"><img src="${p.src}" alt="${esc(p.caption)}" loading="lazy"><span>${CATS[p.cat]}</span></button>`).join('');
    $('gallery').onclick = e => { const b = e.target.closest('[data-i]'); if (b) open(list, Number(b.dataset.i)); };
  }
  $('filters').addEventListener('click', e => { const b = e.target.closest('[data-f]'); if (b && b.dataset.f !== filter) { filter = b.dataset.f; renderGallery(); if (window.BSMotion) BSMotion.replay($('gallery'), 'swap'); } });

  function open(list, i) { lbList = list; lbIdx = i; showLb(); }
  function showLb() {
    const lb = $('lightbox');
    if (lbIdx == null) { lb.hidden = true; document.body.style.overflow = ''; return; }
    const p = lbList[lbIdx];
    $('lbImg').src = p.src; $('lbImg').alt = p.caption;
    if (window.BSMotion) BSMotion.replay($('lbImg'), 'show');
    $('lbCap').textContent = p.caption + ' · ' + (lbIdx + 1) + ' / ' + lbList.length;
    lb.hidden = false; document.body.style.overflow = 'hidden';
  }
  const step = n => { lbIdx = (lbIdx + n + lbList.length) % lbList.length; showLb(); };
  $('lbPrev').onclick = e => { e.stopPropagation(); step(-1); };
  $('lbNext').onclick = e => { e.stopPropagation(); step(1); };
  $('lightbox').onclick = e => { if (e.target.id === 'lightbox' || e.target.id === 'lbClose') { lbIdx = null; showLb(); } };
  document.addEventListener('keydown', e => {
    if (lbIdx == null) return;
    if (e.key === 'Escape') { lbIdx = null; showLb(); }
    if (e.key === 'ArrowRight') step(1);
    if (e.key === 'ArrowLeft') step(-1);
  });

  renderGallery();
})();
