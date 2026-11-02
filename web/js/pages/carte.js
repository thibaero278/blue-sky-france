(function () {
  const { esc, fmt, airfields, loadLive, loadTrails, demoBadge } = window.BS;
  const $ = id => document.getElementById(id);
  // units : joueurs + IA en vol ; une unité = { key, ai, callsign?, aircraft, role, side, air, lat, lon, hdg, alt, spd, freq?, tacan?, trail }
  let units = [], selected = null, follow = false, filter = 'all', demo = true, offline = false, missionT0 = null, polls = 0;

  const map = L.map('map', { minZoom: 6, maxZoom: 12, zoomSnap: 0.5 }).setView([42.95, 42.2], 7);
  map.zoomControl.setPosition('topright');
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OpenStreetMap contributors', maxZoom: 19 }).addTo(map);
  map.setMaxBounds([[39.5, 34.5], [47.5, 48.5]]);
  const grid = { color: '#2a5ca8', weight: 1, opacity: 0.18, dashArray: '4 6', interactive: false };
  for (let lat = 41; lat <= 46; lat++) L.polyline([[lat, 35], [lat, 48]], grid).addTo(map);
  for (let lon = 36; lon <= 47; lon++) L.polyline([[40, lon], [47, lon]], grid).addTo(map);
  airfields.forEach(a => L.marker([a.lat, a.lon], { icon: L.divIcon({ className: '', html: '<div class="af"><span class="ring"></span><span class="nm">' + a.icao + '</span></div>', iconSize: [0, 0] }), keyboard: false })
    .addTo(map).bindTooltip(a.name + ' · ' + a.icao, { direction: 'top', offset: [0, -8] }));
  // Trajectoire : seulement celle de l'avion sélectionné, depuis son décollage
  const trailLine = L.polyline([], { color: '#d9b45a', weight: 3, opacity: 0.85, interactive: false }).addTo(map);

  const fl = p => p.alt < 5000 ? Math.round(p.alt) + ' ft' : 'FL' + String(Math.round(p.alt / 100)).padStart(3, '0');
  const hdg = p => String(Math.round(p.hdg)).padStart(3, '0') + '°';
  const dm = (v, pos, neg, w) => { const a = Math.abs(v), d = Math.floor(a), m = ((a - d) * 60).toFixed(1); return (v >= 0 ? pos : neg) + ' ' + String(d).padStart(w, '0') + '°' + m.padStart(4, '0') + "'"; };
  const enemy = p => p.side !== 2;  // les pilotes Blue Sky sont bleus (2)
  const ROLES = { awacs: 'AWACS', tanker: 'Ravitailleur', heli: 'Hélicoptère', heavy: 'Avion lourd', jet: 'Chasseur' };

  // Silhouettes vues de dessus, nez vers le haut (dessinées ici, pas reprises d'un autre site)
  const HEAVY = 'M0-15C1.2-15 1.6-13 1.6-10V-3L15 3V5L1.6 2.5V10L6 13V14.5L0 13.5L-6 14.5V13L-1.6 10V2.5L-15 5V3L-1.6-3V-10C-1.6-13-1.2-15 0-15Z';
  const SHAPES = {
    jet: '<path d="M0-15L2-6L13 4V6L2 3V9L6 12V14L0 12.5L-6 14V12L-2 9V3L-13 6V4L-2-6Z"/>',
    heavy: '<path d="' + HEAVY + '"/>',
    awacs: '<path d="' + HEAVY + '"/><circle cy="1" r="5"/>',
    tanker: '<path d="' + HEAVY + '"/><path d="M0 13V19" fill="none" stroke-width="2.4"/>',
    heli: '<circle r="12.5" fill="none" stroke-width="1.6" opacity=".7"/><path d="M0-8C3-8 3.5-4 3.5 0C3.5 3 2 5 1 6V14L3 15V16H-3V15L-1 14V6C-2 5-3.5 3-3.5 0C-3.5-4-3-8 0-8Z"/>',
  };
  const colorOf = p => selected === p.key ? '#d9b45a' : enemy(p) ? '#d0342c' : p.ai ? '#13a89e' : '#2a5ca8';
  const svg = (p, size) => '<svg viewBox="-17 -17 34 34" width="' + size + '" height="' + size + '" style="transform:rotate(' + Math.round(p.hdg) + 'deg)" fill="' + colorOf(p)
    + '" stroke="#fbfaf7" stroke-width="1.3" stroke-linejoin="round">' + (SHAPES[p.role] || SHAPES.jet) + '</svg>';
  const label = p => p.ai ? (enemy(p) ? '' : esc(p.callsign || '')) : esc(p.callsign);
  const iconFor = p => {
    const sel = selected === p.key ? ' sel' : '';
    if (!p.air) return L.divIcon({ className: '', html: '<div class="gnd' + sel + '"><span class="sq"></span></div>', iconSize: [0, 0] });
    const name = label(p);
    return L.divIcon({ className: '', html: '<div class="ac' + sel + (p.ai ? ' ai' : '') + '">' + svg(p, p.ai ? 24 : 28)
      + '<span class="tg">' + (name ? name + ' ' : '') + '<i>' + fl(p) + '</i></span></div>', iconSize: [0, 0] });
  };

  // Noms internes DCS (envoyés par le serveur) → noms lisibles
  const TYPES = { 'FA-18C_hornet': 'F/A-18C', 'F-16C_50': 'F-16C', 'A-10C_2': 'A-10C II', 'AV8BNA': 'AV-8B', 'F-15ESE': 'F-15E',
    'AH-64D_BLK_II': 'AH-64D', 'Mirage-F1EE': 'Mirage F1', 'M-2000C': 'Mirage 2000C', 'F-14B': 'F-14B', 'F-14A-135-GR': 'F-14A',
    'Ka-50_3': 'Ka-50', 'Mi-24P': 'Mi-24P', 'UH-1H': 'UH-1H', 'T-45': 'T-45C', 'JF-17': 'JF-17', 'MiG-29 Fulcrum': 'MiG-29',
    'KC-135': 'KC-135', 'KC135MPRS': 'KC-135 MPRS', 'KC130': 'KC-130', 'S-3B Tanker': 'S-3B Tanker', 'E-3A': 'E-3A Sentry', 'E-2C': 'E-2C Hawkeye' };
  const acName = t => TYPES[t] || String(t || '').replace(/_/g, ' ');

  // Met à jour les unités à partir d'une liste (réelle ou démo), en gardant marqueurs et trajectoires
  function sync(list) {
    const seen = new Set();
    list.forEach(n => {
      n = { ...n, aircraft: acName(n.aircraft), key: n.id || n.callsign, ai: !!n.id, side: n.side ?? 2 };
      seen.add(n.key);
      let p = units.find(x => x.key === n.key);
      if (!p) { p = { ...n, trail: [] }; units.push(p); }
      else Object.assign(p, n);
      p.fix = { lat: p.lat, lon: p.lon, at: Date.now() };
      if (p.air) p.trail.push([p.lat, p.lon]); else p.trail = [];
      if (!p.marker) p.marker = L.marker([p.lat, p.lon], { icon: iconFor(p) }).addTo(map).on('click', () => select(p.key, true));
      p.marker.setLatLng([p.lat, p.lon]).setIcon(iconFor(p)).setZIndexOffset(p.air ? (p.ai ? 500 : 1000) : 0);
    });
    units = units.filter(p => {
      if (seen.has(p.key)) return true;
      map.removeLayer(p.marker); return false;
    });
    if (selected && !units.some(p => p.key === selected)) selected = null;
  }

  // Trajectoire complète du sélectionné (relais ?format=trails, envoyée par le bot toutes les 30 s)
  function fetchTrail() {
    const key = selected;
    if (!key || demo) return;
    loadTrails().then(t => {
      const p = units.find(x => x.key === key);
      const pts = t && t.trails && t.trails[key];
      if (p && pts && pts.length) { p.trail = pts.slice(); drawTrail(); }
    });
  }
  function drawTrail() {
    const p = units.find(x => x.key === selected);
    trailLine.setLatLngs(p && p.air ? p.trail.concat([[p.lat, p.lon]]) : []);
  }

  function renderList() {
    const players = units.filter(p => !p.ai), air = players.filter(p => p.air).length;
    $('counts').textContent = air + ' en vol · ' + (players.length - air) + ' au sol';
    $('total').textContent = players.length + ' connectés';
    const list = filter === 'ai' ? units.filter(p => p.ai) : players.filter(p => filter === 'all' || (filter === 'air' ? p.air : !p.air));
    $('plist').innerHTML = list.map(p => `
      <button class="p${selected === p.key ? ' sel' : ''}" data-key="${esc(p.key)}">
        <span class="ic${p.air ? '' : ' g'}">${p.air ? svg(p, 22) : '<span class="sq"></span>'}</span>
        <span class="nm"><b>${p.ai ? (enemy(p) ? 'Inconnu' : esc(p.callsign || ROLES[p.role])) : esc(p.callsign)}</b><small>${esc(p.aircraft)}${p.ai && !enemy(p) && p.freq ? ' · ' + esc(p.freq) : ''}${p.air || !p.base ? '' : ' · ' + esc(p.base)}</small></span>
        <span class="data">${p.air ? '<span>' + fl(p) + '</span><span>' + Math.round(p.spd) + ' kt · ' + hdg(p) + '</span>' : '<span>Au sol</span>'}</span>
      </button>`).join('') || '<div class="empty" style="padding:24px">' + (filter === 'ai' ? 'Aucune IA en vol' : 'Aucun pilote connecté') + '</div>';
  }
  function renderFocus() {
    const p = units.find(x => x.key === selected);
    $('focus').classList.toggle('show', !!p);
    if (!p) return;
    const side = p.ai ? (enemy(p) ? 'IA ennemie · ' : 'IA amie · ') + ROLES[p.role] + ' · ' : '';
    $('fCs').textContent = p.ai ? (enemy(p) ? 'Inconnu' : p.callsign || ROLES[p.role]) : p.callsign;
    $('fType').textContent = side + p.aircraft + ' · ' + (p.air ? 'En vol' : 'Au sol' + (p.base ? ' · ' + p.base : ''));
    $('fAlt').textContent = p.air ? fl(p) : Math.round(p.alt) + ' ft';
    $('fSpd').textContent = Math.round(p.spd) + ' kt';
    $('fHdg').textContent = hdg(p);
    $('fRadio').style.display = p.freq || p.tacan ? '' : 'none';
    $('fFreq').textContent = p.freq || '—';
    $('fTacan').textContent = p.tacan || '—';
    $('fPos').textContent = dm(p.lat, 'N', 'S', 2) + '  ' + dm(p.lon, 'E', 'W', 3);
    $('followBtn').classList.toggle('on', follow);
  }
  function select(key, fly) {
    selected = key; follow = false;
    const p = units.find(x => x.key === key);
    units.forEach(x => x.marker.setIcon(iconFor(x)));
    if (p && fly) map.flyTo([p.lat, p.lon], Math.max(map.getZoom(), 8.5), { duration: 0.8 });
    drawTrail(); fetchTrail();
    renderList(); renderFocus();
  }
  $('plist').addEventListener('click', e => { const b = e.target.closest('.p'); if (b) select(b.dataset.key, true); });
  $('tabs').addEventListener('click', e => {
    const b = e.target.closest('button'); if (!b) return;
    filter = b.dataset.f;
    $('tabs').querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
    renderList();
  });
  $('closeFocus').onclick = () => select(null, false);
  $('followBtn').onclick = () => { follow = !follow; renderFocus(); };

  function after() {
    const sp = units.find(x => x.key === selected);
    if (follow && sp) map.panTo([sp.lat, sp.lon], { animate: true, duration: 0.8 });
    drawTrail(); renderList(); renderFocus();
  }

  // Démo : on fait voler les avions localement
  function demoTick() {
    units.forEach(p => {
      if (!p.air) return;
      const out = p.lat < 41.3 || p.lat > 45.2 || p.lon < 37.5 || p.lon > 45.6;
      if (out) {
        const brg = (90 - Math.atan2(42.6 - p.lat, (43.0 - p.lon) * Math.cos(p.lat * Math.PI / 180)) * 180 / Math.PI + 360) % 360;
        const diff = ((brg - p.hdg + 540) % 360) - 180;
        p.hdg = (p.hdg + Math.sign(diff) * Math.min(Math.abs(diff), 6) + 360) % 360;
      } else p.hdg = (p.hdg + (Math.random() - 0.5) * 3 + 360) % 360;
      const nm = p.spd * 6 / 3600, r = p.hdg * Math.PI / 180;
      p.lat += nm * Math.cos(r) / 60;
      p.lon += nm * Math.sin(r) / (60 * Math.cos(p.lat * Math.PI / 180));
      p.alt = Math.max(300, p.alt + (Math.random() - 0.5) * 120);
      p.spd = Math.max(90, p.spd + (Math.random() - 0.5) * 4);
    });
    sync(units.map(({ marker, trail, fix, key, ai, ...rest }) => rest));
    after();
  }

  function setWeather(w) {
    $('wx').innerHTML = [['Vent', w.wind], ['Visibilité', w.visibility], ['Nuages', w.clouds], ['Température', w.temp], ['QNH', w.qnh]]
      .map(([k, v], i) => '<div' + (i === 4 ? ' style="grid-column:span 2"' : '') + '><span class="label">' + k + '</span><span class="v">' + esc(v ?? '—') + '</span></div>').join('');
  }

  function load() {
    return loadLive().then(d => {
      demo = d.demo; offline = !!d.offline;
      if (d.weather) setWeather(d.weather);
      if (!demo && !d.weather) setWeather({});
      missionT0 = !d.offline && d.missionTime != null ? { t: d.missionTime, at: Date.now() } : null;
      const nOnline = (d.online || d.players || []).length;
      $('srv').innerHTML = demo ? demoBadge() : d.offline ? '<span style="color:#8a91a3">Hors ligne</span>'
        : nOnline ? '<span class="dot"></span><span style="color:#0b7d75">En ligne</span>' : '<span style="color:#8a91a3">Personne en ligne</span>';
      $('liveDemo').innerHTML = demo ? demoBadge('Démo · export live à venir') : '';
      $('noteSrc').textContent = d.offline ? 'Serveur DCS arrêté ou sans mission · la carte se remplit dès qu’une mission tourne'
        : !demo ? 'Positions envoyées par le bot du serveur DCS · mises à jour toutes les 5 s'
        : 'Données de démonstration · le serveur DCS n\'exporte pas encore les positions';
      sync((d.players || []).concat(d.ai || []));
      if (++polls % 6 === 0) fetchTrail();  // trajectoire du sélectionné relue toutes les 30 s
      after();
    });
  }

  // Relu toutes les 5 s quand le serveur tourne (le bot envoie les positions toutes les 5 s), toutes les 2 min sinon ;
  // rien tant que l'onglet est caché, relu dès qu'on y revient.
  let timer = null;
  const schedule = () => { timer = setTimeout(poll, offline ? 120e3 : 5e3); };
  function poll() {
    timer = null;
    if (!document.hidden) load().then(schedule);
  }
  // Entre deux envois du bot (5 s), on fait avancer les avions en vol selon leur cap et leur vitesse
  // shortcut: estimation en ligne droite, l'avion « saute » un peu à chaque vraie position ; suffisant à 5 s.
  function extrapolate() {
    units.forEach(p => {
      if (!p.air || !p.fix || !p.spd) return;
      const s = Math.min((Date.now() - p.fix.at) / 1000, 60), nm = p.spd * s / 3600, r = p.hdg * Math.PI / 180;
      p.lat = p.fix.lat + nm * Math.cos(r) / 60;
      p.lon = p.fix.lon + nm * Math.sin(r) / (60 * Math.cos(p.fix.lat * Math.PI / 180));
      p.marker.setLatLng([p.lat, p.lon]);
    });
    const sp = units.find(x => x.key === selected);
    if (sp) { $('fPos').textContent = dm(sp.lat, 'N', 'S', 2) + '  ' + dm(sp.lon, 'E', 'W', 3); if (follow) map.panTo([sp.lat, sp.lon], { animate: false }); }
    drawTrail();
  }

  load().then(() => {
    if (demo) { setInterval(demoTick, 1000); return; }
    setInterval(extrapolate, 1000);
    schedule();
    document.addEventListener('visibilitychange', () => { if (!document.hidden && !timer) poll(); });
  });
  // Heure in-game : envoyée par le serveur (secondes depuis minuit), horloge fictive en démo, « --:--:-- » serveur éteint
  setInterval(() => ($('clock').textContent = fmt.gameClock(missionT0, demo)), 1000);
})();
