// Blue Sky France — mouvements : apparition au défilement, compteurs, indicateur glissant des sélecteurs,
// parallaxe des photos, tri animé (FLIP). Rien ne se lance si le système demande moins d'animations.
(function () {
  const root = document.documentElement;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const t0 = performance.now();
  const frFmt = (v, dec) => v.toLocaleString('fr-FR', { minimumFractionDigits: dec, maximumFractionDigits: dec });

  // Éléments qui apparaissent en douceur quand on arrive dessus
  const REVEAL = [
    '.sec-head', '.section > .h2', '.grid-auto > *', '.tiers', '.teaser', '.cta-box', '.recruit', '.join-banner',
    '.event', '.gallery > button', '.livery-photo', '.table', '.changelog > div', '.dc-card', '.mapcard', '.side > .card',
    'section.wrap > .card', 'section.wrap > div > .card', '[data-reveal]'
  ].join(',');

  // ---------- utilitaires ----------
  const onVisible = (el, cb, threshold = 0.25) => {
    if (!('IntersectionObserver' in window)) return cb();
    const io = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { io.disconnect(); cb(); } }), { threshold });
    io.observe(el);
  };

  // ---------- apparition au défilement ----------
  const revealIO = 'IntersectionObserver' in window && new IntersectionObserver(entries => {
    entries.filter(e => e.isIntersecting)
      .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top || a.boundingClientRect.left - b.boundingClientRect.left)
      .forEach((e, i) => {
        const el = e.target;
        revealIO.unobserve(el);
        el.style.transitionDelay = Math.min(i, 5) * 55 + 'ms';
        el.classList.add('in');
        const done = ev => {
          if (ev && ev.target !== el) return;
          el.classList.remove('rv', 'in'); el.style.transitionDelay = '';
          el.removeEventListener('transitionend', done);
        };
        el.addEventListener('transitionend', done);
        setTimeout(done, 1600);
      });
  }, { rootMargin: '0px 0px 40px 0px', threshold: 0 });

  function reveal(el) {
    if (el.__rv || !revealIO) return;
    el.__rv = true;
    if (el.parentElement && el.parentElement.closest('.rv')) return;   // un parent apparaît déjà
    const r = el.getBoundingClientRect();
    const inView = r.top < innerHeight && r.bottom > 0;
    if (inView && performance.now() - t0 > 1200) return;              // contenu rafraîchi sous les yeux : pas d'effet
    el.classList.add('rv');
    revealIO.observe(el);
  }

  // ---------- compteurs ----------
  const counted = new Set();
  function count(el, to, opts = {}) {
    const dec = opts.dec || 0, key = opts.key;
    to = Number(to) || 0;
    const final = () => (el.textContent = frFmt(to, dec));
    // quiet : données rafraîchies (BS.refresh) → valeur directe, pas de comptage depuis 0
    if (reduced || window.BSMotion.quiet || (key && counted.has(key)) || to === 0) return final();
    if (key) counted.add(key);
    el.textContent = frFmt(0, dec);
    onVisible(el, () => {
      const start = performance.now(), dur = Math.min(1600, 700 + String(Math.round(to)).length * 120);
      const step = now => {
        const k = Math.min(1, (now - start) / dur), e = 1 - Math.pow(1 - k, 3);
        el.textContent = frFmt(to * e, dec);
        if (k < 1) requestAnimationFrame(step); else final();
      };
      requestAnimationFrame(step);
    }, 0.4);
  }

  // ---------- indicateur glissant des sélecteurs ----------
  function seg(el) {
    let ind = el.querySelector(':scope > .seg-ind');
    const on = el.querySelector(':scope > button.on');
    if (!on) { if (ind) ind.style.opacity = 0; return; }
    const r = { x: on.offsetLeft, y: on.offsetTop, w: on.offsetWidth, h: on.offsetHeight };
    const place = (p, anim) => {
      if (!anim) ind.style.transition = 'none';
      ind.style.width = p.w + 'px'; ind.style.height = p.h + 'px';
      ind.style.transform = `translate(${p.x}px, ${p.y}px)`; ind.style.opacity = 1;
      if (!anim) { ind.offsetWidth; ind.style.transition = ''; }
    };
    if (!ind) {
      ind = document.createElement('span');
      ind.className = 'seg-ind';
      el.prepend(ind);
      el.classList.add('has-ind');
      place(el.__last || r, false);       // reprend la position d'avant un nouveau rendu
    }
    const l = el.__last;
    if (!l || l.x !== r.x || l.y !== r.y || l.w !== r.w || l.h !== r.h || ind.style.opacity !== '1') requestAnimationFrame(() => place(r, !reduced));
    el.__last = r;
  }

  // ---------- flèches qui glissent au survol ----------
  function arrows(el) {
    if (el.__arr) return;
    el.__arr = true;
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    const nodes = [];
    while (walker.nextNode()) if (walker.currentNode.nodeValue.includes('→')) nodes.push(walker.currentNode);
    nodes.forEach(n => {
      if (n.parentElement.classList.contains('arr')) return;
      if (n.nodeValue.trim() === '→') { n.parentElement.classList.add('arr'); return; }
      const parts = n.nodeValue.split('→');
      const frag = document.createDocumentFragment();
      parts.forEach((p, i) => {
        frag.append(p);
        if (i < parts.length - 1) { const s = document.createElement('span'); s.className = 'arr'; s.textContent = '→'; frag.append(s); }
      });
      n.replaceWith(frag);
    });
  }

  // ---------- images : fondu au chargement ----------
  function lazyImg(img) {
    if (img.__lz) return;
    img.__lz = true;
    if (img.complete && img.naturalWidth) return;
    img.classList.add('lazy');
    const ok = () => img.classList.add('loaded');
    img.addEventListener('load', ok, { once: true });
    img.addEventListener('error', ok, { once: true });
  }

  // ---------- balayage du DOM (au chargement et à chaque rendu) ----------
  function scan(node) {
    if (node.nodeType !== 1) return;
    const all = sel => (node.matches(sel) ? [node] : []).concat([...node.querySelectorAll(sel)]);
    if (!reduced) all(REVEAL).forEach(reveal);
    all('[data-count]').forEach(el => {
      if (el.__ct) return; el.__ct = true;
      count(el, el.dataset.count, { dec: Number(el.dataset.dec) || 0, key: el.dataset.key });
    });
    all('.seg, .tabs').forEach(seg);
    all('.btn, .more, .live-chip, .teaser .btn').forEach(arrows);
    all('img[loading="lazy"]').forEach(lazyImg);
  }
  let pending = new Set(), raf = 0;
  const mo = new MutationObserver(muts => {
    muts.forEach(m => {
      if (m.type === 'attributes') { const s = m.target.closest('.seg, .tabs'); if (s) pending.add(s); return; }
      if (m.target.closest && m.target.closest('#map')) return;
      m.addedNodes.forEach(n => { if (n.nodeType === 1 && !n.classList.contains('seg-ind')) pending.add(n); });
      const s = m.target.closest && m.target.closest('.seg, .tabs'); if (s) pending.add(s);
    });
    if (!raf) raf = requestAnimationFrame(() => { raf = 0; const p = pending; pending = new Set(); p.forEach(n => n.isConnected && scan(n)); });
  });

  // ---------- parallaxe légère des grandes photos + barre de nav ----------
  const nav = document.querySelector('.navwrap');
  const plx = reduced ? [] : [...document.querySelectorAll('.hero-frame > img, .teaser > img, .join-banner > img, .dc-card > img')];
  let ticking = false;
  function onScroll() {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => {
      ticking = false;
      if (nav) nav.classList.toggle('scrolled', scrollY > 8);
      plx.forEach(img => {
        const r = img.parentElement.getBoundingClientRect();
        if (r.bottom < 0 || r.top > innerHeight) return;
        const off = (r.top + r.height / 2 - innerHeight / 2) / (innerHeight / 2 + r.height / 2); // -1 … 1
        img.style.translate = `0 ${(off * -3).toFixed(2)}%`;
      });
    });
  }
  addEventListener('scroll', onScroll, { passive: true });
  addEventListener('resize', () => { document.querySelectorAll('.seg, .tabs').forEach(s => { s.__last = null; seg(s); }); onScroll(); });

  // ---------- tri animé : les éléments glissent vers leur nouvelle place ----------
  function flip(selector, keyAttr, update) {
    if (reduced) return update();
    const before = new Map([...document.querySelectorAll(selector)].map(el => [el.getAttribute(keyAttr), el.getBoundingClientRect().top]));
    update();
    [...document.querySelectorAll(selector)].forEach((el, i) => {
      const old = before.get(el.getAttribute(keyAttr));
      if (old == null) return;
      const dy = old - el.getBoundingClientRect().top;
      if (Math.abs(dy) < 1) return;
      el.animate([{ transform: `translateY(${dy}px)` }, { transform: 'none' }], { duration: 600, easing: 'cubic-bezier(.2,.8,.2,1)', delay: Math.min(i, 14) * 10, fill: 'backwards' });
    });
  }

  // Rejoue une animation CSS liée à une classe (ex. galerie filtrée)
  function replay(el, cls) {
    if (reduced) return;
    el.classList.remove(cls); void el.offsetWidth; el.classList.add(cls);
  }

  window.BSMotion = { reduced, count, onVisible, flip, replay, scan };
  scan(document.body);
  mo.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['class'] });
  onScroll();
})();
