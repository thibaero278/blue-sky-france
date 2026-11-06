// Page Blue Sky Ops (ops.html). Contenu dans data/ops.js.
(function () {
  const { C, esc, fmt, loadEvents } = window.BS;
  const O = window.BS_OPS;
  const $ = id => document.getElementById(id);
  const day = s => new Date(s + 'T12:00').toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
  const img = (p, alt = p.alt) => `<img src="${esc(p.src)}" alt="${esc(alt)}" width="1920" height="1080" loading="lazy">`;

  // ---------- intro : terminal, puis le dossier s'ouvre (à chaque arrivée sur la page) ----------
  const intro = $('bsoIntro');
  const seen = document.documentElement.classList.contains('bso-seen'); // ?intro=0 dans l'adresse saute l'intro
  if (seen) intro.remove();
  else {
    const quick = matchMedia('(prefers-reduced-motion: reduce)').matches;
    const LINES = [
      ['> BSO-TERMINAL // LIAISON CHIFFRÉE', ''],
      ['> IDENTIFICATION DU POSTE ......... ', 'OK'],
      ["> NIVEAU D'ACCRÉDITATION .......... ", 'BSO-2'],
      ['> DÉCHIFFREMENT DOSSIER BSO-001 ... ', '100 %']
    ];
    const term = $('bsoTerm');
    let done = false, timer;
    document.documentElement.style.overflow = 'hidden';
    const finish = () => {
      if (done) return; done = true; clearTimeout(timer);
      intro.classList.add('open');
      document.documentElement.style.overflow = '';
      document.dispatchEvent(new Event('bso:open'));
      setTimeout(() => intro.remove(), 900);
    };
    const line = ([a, b], n = a.length + b.length) => esc((a + b).slice(0, n)).replace(b && n >= a.length + b.length ? esc(b) : '\0', '<b>' + esc(b) + '</b>');
    if (quick) { term.innerHTML = LINES.map(l => line(l)).join('\n'); timer = setTimeout(finish, 1200); }
    else {
      let li = 0, ci = 0;
      const tick = () => {
        ci += 1;
        term.innerHTML = LINES.slice(0, li).map(l => line(l)).concat(line(LINES[li], ci)).join('\n') + '<span class="cur"></span>';
        if (ci < LINES[li][0].length + LINES[li][1].length) timer = setTimeout(tick, 22);
        else if (++li < LINES.length) { ci = 0; timer = setTimeout(tick, 380); }
        else timer = setTimeout(finish, 1400); // le temps de lire la dernière ligne
      };
      timer = setTimeout(tick, 400);
    }
    $('bsoSkip').onclick = finish;
    document.addEventListener('keydown', e => { if (e.key === 'Escape') finish(); });
    $('bsoSkip').focus({ preventScroll: true });
  }

  // ---------- anneau de photos autour du titre ----------
  const ring = $('bsoRing');
  const N = 16;
  ring.innerHTML = Array.from({ length: N }, (_, i) => {
    const p = O.photos[i % O.photos.length];
    const a = (i / N) * Math.PI * 2 - Math.PI / 2;
    const x = 50 + 39 * Math.cos(a), y = 52 + 35 * Math.sin(a);
    const grow = (1 + Math.sin(a)) / 2; // plus grand en bas : l'anneau paraît incliné
    const rot = Math.max(-30, Math.min(30, Math.cos(a) * 24));
    return `<span class="rf${i % 3 === 1 ? ' tall' : ''}" style="left:${x.toFixed(2)}%;top:${y.toFixed(2)}%;--dx:${Math.cos(a).toFixed(3)};--dy:${Math.sin(a).toFixed(3)};--w:${(110 + grow * 60).toFixed(0)}px;--r:${rot.toFixed(1)}deg">${img(p, '')}</span>`;
  }).join('');

  // ---------- ouvrir le dossier : seule façon d'afficher le reste de la page ----------
  // On traverse l'anneau, l'écran se referme sur « Dossier BSO-001 » puis se rouvre sur l'unité.
  const root = document.documentElement;
  $('openFile').addEventListener('click', e => {
    if (!root.classList.contains('bso-locked') || root.classList.contains('diving')) return;
    e.preventDefault();
    const unlock = () => {
      root.classList.remove('bso-locked');
      $('unite').scrollIntoView({ behavior: 'instant' });
    };
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) { unlock(); return; }
    root.classList.add('diving');
    setTimeout(() => root.classList.add('wipe-in'), 600);
    setTimeout(() => { unlock(); root.classList.remove('diving', 'wipe-in'); root.classList.add('wipe-out'); }, 2100); // « Dossier BSO-001 » reste ~1,2 s
    setTimeout(() => root.classList.remove('wipe-out'), 2750);
  });

  // ---------- livrée : deux versions ----------
  if (O.livery.tiktok) $('bsoLivery').href = O.livery.tiktok;
  $('bsoLiveries').innerHTML = O.livery.versions.map(v => `<figure>${v.photo
    ? `<img src="${esc(v.photo)}" alt="Livrée ${esc(v.name)}" width="1920" height="1080" loading="lazy">`
    : '<span class="soon">Photo à venir</span>'}<figcaption>${esc(v.name)}</figcaption></figure>`).join('');

  // ---------- types de missions : passer sur une ligne change la photo ----------
  const pic = $('missionPic');
  $('bsoMissions').innerHTML = O.missions.map((m, i) => `<li tabindex="0" data-i="${i}"><b>${esc(m.code)}</b><span>${esc(m.desc)}</span></li>`).join('');
  const showMission = e => {
    const li = e.target.closest('[data-i]'); if (!li) return;
    const p = O.missions[li.dataset.i].photo;
    $('bsoMissions').querySelectorAll('li').forEach(x => x.classList.toggle('on', x === li));
    if (!pic.src.endsWith(p.src)) { pic.src = p.src; pic.alt = p.alt; }
  };
  $('bsoMissions').addEventListener('pointerover', showMission);
  $('bsoMissions').addEventListener('focusin', showMission);
  showMission({ target: $('bsoMissions').firstElementChild });

  // ---------- dernière opération : une photo découpée en tuiles, à côté du débrief ----------
  const o = O.last, cols = 4, rows = 3;
  $('bsoMosaic').setAttribute('aria-label', o.cover.alt);
  $('bsoMosaic').innerHTML = Array.from({ length: cols * rows }, (_, i) =>
    `<i style="background-image:url('${esc(o.cover.src)}');background-position:${((i % cols) / (cols - 1) * 100).toFixed(2)}% ${(Math.floor(i / cols) / (rows - 1) * 100).toFixed(2)}%"></i>`).join('');
  $('lastName').textContent = o.code + (o.phase ? ' · ' + o.phase : '') + ' · ' + day(o.date);
  $('lastText').textContent = o.summary;
  $('lastFacts').innerHTML = [[o.pilots, 'Pilotes'], [o.duration, 'Durée'], [o.result, 'Résultat'], [o.map, 'Théâtre']]
    .map(([a, b]) => `<div><dt>${esc(b)}</dt><dd>${esc(a)}</dd></div>`).join('');
  const v = o.tiktok || o.youtube;
  if (v) { $('lastVideo').href = v; $('lastVideo').hidden = false; }
  if (O.demo) $('lastDemo').hidden = false;

  // ---------- prochaine opération (planning du Discord, sinon data/evenements.js) ----------
  loadEvents().then(ev => {
    const now = Date.now(), future = ev.list.filter(e => e.date.getTime() > now - 3 * 3600e3);
    const e = future.find(x => /op[ée]ration/i.test(x.type || '')) || future[0];
    $('bsoNext').textContent = e ? `Prochaine opération : ${e.title}, ${fmt.dateLong(e.date)} à ${fmt.hour(e.date)}.` : "Pas d'opération planifiée pour l'instant : les dates tombent sur le Discord.";
  });
  document.querySelectorAll('[data-discord]').forEach(a => { a.href = C.discordInvite; });

  // ---------- entrées des sections : titre, puis texte, puis image ----------
  if ('IntersectionObserver' in window && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    document.documentElement.classList.add('rv');
    const io = new IntersectionObserver(es => es.forEach(x => { if (x.isIntersecting) { x.target.classList.add('in'); io.unobserve(x.target); } }), { rootMargin: '0px 0px -8% 0px' });
    document.querySelectorAll('[data-r]').forEach(el => io.observe(el));
  }
  // le titre se lève quand le dossier s'ouvre (tout de suite si l'intro est déjà vue)
  const go = () => document.documentElement.classList.add('bso-go');
  if (seen) requestAnimationFrame(go); else document.addEventListener('bso:open', go);
})();
