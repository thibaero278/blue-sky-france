(function () {
  const { C, esc, fmt, insignia, airfields, loadLive, loadTrails, loadStats, demoBadge } = window.BS;
  const $ = id => document.getElementById(id);
  // units : joueurs + IA en vol ; une unité = { key, ai, callsign?, aircraft, role, side, air, lat, lon, hdg, alt, spd, freq?, tacan?, trail }
  let units = [], selected = null, follow = false, filter = 'all', demo = true, offline = false, missionT0 = null, upT0 = null, polls = 0;

  const map = L.map('map', { minZoom: 6, maxZoom: 18, zoomSnap: 0.5, preferCanvas: true }).setView([42.95, 42.2], 7);
  map.zoomControl.setPosition('topright');
  // CARTO testé le 06/11 : tuiles raster désormais sous clé API (filigrane « API KEY REQUIRED »), donc on reste sur OSM
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OpenStreetMap contributors', maxZoom: 19, keepBuffer: 4, updateWhenZooming: false }).addTo(map);
  map.setMaxBounds([[39.5, 34.5], [47.5, 48.5]]);
  const grid = { color: '#2a5ca8', weight: 1, opacity: 0.18, dashArray: '4 6', interactive: false };
  for (let lat = 41; lat <= 46; lat++) L.polyline([[lat, 35], [lat, 48]], grid).addTo(map);
  for (let lon = 36; lon <= 47; lon++) L.polyline([[40, lon], [47, lon]], grid).addTo(map);
  airfields.forEach(a => L.marker([a.lat, a.lon], { icon: L.divIcon({ className: '', html: '<div class="af"><span class="ring"></span><span class="nm">' + a.icao + '</span></div>', iconSize: [0, 0] }), keyboard: false })
    .addTo(map).bindTooltip(a.name + ' · ' + a.icao, { direction: 'top', offset: [0, -8] }));
  // Trajectoire : seulement celle de l'avion sélectionné, depuis son décollage, colorée selon l'altitude
  const trailLayer = L.layerGroup().addTo(map);
  // 0 ft orange → 10 000 vert → 20 000 cyan → 30 000 bleu → 40 000 ft et plus violet ; ancien point sans altitude : doré
  const altColor = alt => alt == null ? '#d9b45a' : 'hsl(' + Math.round((25 + Math.min(Math.max(alt, 0), 40000) / 40000 * 255) / 10) * 10 + ',85%,52%)';

  const fl = p => p.alt < 5000 ? Math.round(p.alt) + ' ft' : 'FL' + String(Math.round(p.alt / 100)).padStart(3, '0');
  const hdg = p => String(Math.round(p.hdg)).padStart(3, '0') + '°';
  const dm = (v, pos, neg, w) => { const a = Math.abs(v), d = Math.floor(a), m = ((a - d) * 60).toFixed(1); return (v >= 0 ? pos : neg) + ' ' + String(d).padStart(w, '0') + '°' + m.padStart(4, '0') + "'"; };
  const enemy = p => p.side !== 2;  // les pilotes Blue Sky sont bleus (2)
  // Stats du pilote cliqué (classement), en passant par les alias de pseudo de config.js
  let pilots = [];
  loadStats().then(s => (pilots = s.pilots || []));
  const alias = {};
  Object.entries(C.pilotAliases || {}).forEach(([cs, names]) => names.concat(cs).forEach(n => (alias[n.toLowerCase()] = cs)));
  const short = cs => alias[String(cs).toLowerCase()] || cs;  // pseudo court de config.js (« Breakdown »), sinon celui du jeu
  const statsOf = cs => pilots.find(x => x.callsign === short(cs));
  const ROLES = { awacs: 'AWACS', tanker: 'Ravitailleur', heli: 'Hélicoptère', heavy: 'Avion lourd', jet: 'Chasseur' };

  // Silhouettes de tar1090 / ADS-B Exchange (js/markers.js). Type DCS → forme ; les avions qui se ressemblent partagent la même.
  const FAMILIES = [
    [/F.A-18|FA-18/, 'f18'], [/F-14|Su-24|Tornado|MiG-2[37]|Tu-22/, 'tornado'], [/B-1|Tu-160/, 'b1b_lancer'],
    [/F-15|Su-2[7]|Su-3[034]|J-11|MiG-29|MiG-25|MiG-31/, 'md_f15'], [/F-35|F-22/, 'f35'], [/F-5/, 'f5_tiger'],
    [/M-2000|Mirage 2000|MiG-21|J-10/, 'mirage'], [/Mirage.F1|^F1/, 'miragef1'], [/Rafale/, 'rafale'], [/Eurofighter|Typhoon/, 'typhoon'],
    [/JAS|Gripen/, 'sb39'], [/A-10/, 'a10'], [/A-4/, 'md_a4'], [/L-39/, 'l159'], [/C-101|MB-339/, 'm326'], [/T-45|Hawk\b/, 'bae_hawk'],
    [/Alpha/, 'alpha_jet'], [/F-86|MiG-15|MiG-19/, 'hunter'],
    [/B-52|Tu-95|Tu-142/, 'b52'], [/E-3|E-2|A-50|KJ-2000/, 'e3awacs'], [/KC-?135|707/, 'b707'], [/KC-10|KC10/, 'md11'],
    [/C-17|IL-7[68]|Il-7[68]/, 'c17'], [/A400/, 'a400'], [/C-130|KC.?130|An-2[6]|An-30/, 'c130'],
    [/P-51|P-47|TF-51|Spitfire|Bf.?109|FW.?190|Fw 190|I-16|Mosquito|Ju-88|A6M|F4U|Corsair|Christen|Yak-52|SPAD|Fokker|Sopwith|Camel/, 'single_turbo'],
    [/AH-64/, 'apache'], [/UH-60|SH-60|MH-60/, 'blackhawk'], [/Mi-24|Mi-35/, 'mil24'], [/SA342|Gazelle/, 'gazelle'],
    [/Mi-8|Mi-17|Mi-26|SA330|Puma/, 'puma'], [/CH-47/, 'chinook'], [/MQ-|RQ-|WingLoong/, 'uav'],
  ];
  const shapeOf = p => {
    const f = FAMILIES.find(([re]) => re.test(p.type || p.aircraft));
    return f ? f[1] : { awacs: 'e3awacs', tanker: 'b707', heavy: 'c17', heli: 'helicopter' }[p.role] || 'hi_perf';
  };
  const colorOf = p => selected === p.key ? '#d9b45a' : enemy(p) ? '#d0342c' : p.ai ? '#13a89e' : '#2a5ca8';
  // Même rendu que svgShapeToSVG de tar1090 (contour 2× l'épaisseur, détails à 0,6×)
  const svg = (p, scale) => {
    if (p.bs && !p.ai) return bsSvg(p, scale);
    const s = window.BS_SHAPES[shapeOf(p)], k = s.strokeScale || 1, c = colorOf(p);
    return '<svg viewBox="' + s.viewBox + '" width="' + Math.round(s.w * scale) + '" height="' + Math.round(s.h * scale)
      + '" style="transform:rotate(' + Math.round(p.hdg) + 'deg)">'
      + s.path.map(d => '<path paint-order="stroke" fill="' + c + '" stroke="#13213a" stroke-width="' + (1.2 * k) + '" d="' + d + '"/>').join('')
      + (s.accent || []).map(d => '<path fill="none" stroke="#13213a" stroke-width="' + (0.36 * (s.accentMult || 1) * k) + '" d="' + d + '"/>').join('')
      + '</svg>';
  };

  // Pilote en mode Blue Sky (F10 > MODE BLUE SKY) : F-18 aux couleurs de l'escadrille, quel que soit son avion.
  // Livrée dessinée par Thibaud (assets/f18-bluesky.svg, réduite en .webp), nez en haut ; halo or si sélectionné.
  const bsSvg = (p, scale) => {
    const w = Math.round(38 * scale);
    return '<img class="bsj' + (selected === p.key ? ' sel' : '') + '" src="assets/f18-bluesky.webp" alt="" width="' + w + '" height="' + w
      + '" style="transform:rotate(' + Math.round(p.hdg) + 'deg)">';
  };

  // Porte-avions vus du dessus, noir et blanc : CVN (pont oblique), Kuznetsov (tremplin), Tarawa (pont droit)
  const SHIPS = {
    cvn: '<path d="M-1.8-15H2.2L4.6-9V12L3 15H-3.6L-4.6 12V5L-7.2 2.5V-3.5L-4.6-6.5V-9Z"/><path d="M-1 14L-5.6-1.8" fill="none" stroke-dasharray="1.6 1.4" stroke-width=".8"/><rect x="4.6" y="1" width="1.8" height="5" fill="#13213a"/>',
    kuz: '<path d="M0-15.5C2.4-15.5 4.2-12 4.6-8V12L3 15H-3.6L-4.6 12V5L-6.6 2.5V-3L-4.4-6V-8C-4-12-2.4-15.5 0-15.5Z"/><path d="M-3.4-11.5Q0-14.4 3.4-11.5" fill="none" stroke-width=".9"/><path d="M-0.6 14L-4.8-1" fill="none" stroke-dasharray="1.6 1.4" stroke-width=".8"/><rect x="4.6" y="-1" width="2" height="7" fill="#13213a"/>',
    lha: '<path d="M0-15.5C2.6-15.5 4.2-12.5 4.2-9.5V14.5H-4.2V-9.5C-4.2-12.5-2.6-15.5 0-15.5Z"/><path d="M0-12V12.5" fill="none" stroke-dasharray="1.6 1.4" stroke-width=".8"/><rect x="4.2" y="-2" width="1.9" height="8" fill="#13213a"/>',
  };
  const shipSvg = (p, size) => '<svg viewBox="-17 -17 34 34" width="' + size + '" height="' + size + '" style="transform:rotate(' + Math.round(p.hdg) + 'deg)" fill="#fbfaf7" stroke="'
    + (selected === p.key ? '#d9b45a' : enemy(p) ? '#d0342c' : '#13213a') + '" stroke-width="1.2" stroke-linejoin="round">' + SHIPS[p.ship] + '</svg>';
  const SHIP_NAMES = { cvn: 'Porte-avions (CVN)', kuz: 'Porte-avions (Kuznetsov)', lha: 'Porte-aéronefs (Tarawa)' };
  // multi-équipage : « Pilote + Gunner »
  const crewName = p => esc([p.callsign].concat(p.crew || []).map(short).join(' + '));
  const label = p => p.ai ? (enemy(p) ? '' : esc(p.callsign || '')) : crewName(p);
  const iconFor = p => {
    const sel = selected === p.key ? ' sel' : '';
    if (p.ship) return L.divIcon({ className: '', html: '<div class="shp' + sel + '">' + shipSvg(p, 44)
      + (enemy(p) ? '' : '<span class="tg">' + esc(p.callsign || SHIP_NAMES[p.ship]) + '</span>') + '</div>', iconSize: [0, 0] });
    if (!p.air) return L.divIcon({ className: '', html: '<div class="gnd' + sel + '"><span class="sq"></span></div>', iconSize: [0, 0] });
    // avions superposés à l'écran (formation) : une seule étiquette, une ligne par avion (voir declutter)
    const line = q => { const n = label(q); return (n ? n + ' ' : '') + '<i>' + fl(q) + '</i>'; };
    const tag = p.lead ? '' : '<span class="tg">' + [p].concat(p.stack || []).map(line).join('<br>') + '</span>';
    return L.divIcon({ className: '', html: '<div class="ac' + sel + (p.ai ? ' ai' : '') + '">' + svg(p, p.ai ? 1 : 1.15)
      + tag + '</div>', iconSize: [0, 0] });
  };

  // Regroupe les avions en vol à moins de 28 px les uns des autres (joueurs d'abord) : le premier porte l'étiquette
  function declutter() {
    const air = units.filter(p => p.air && !p.ship).sort((a, b) => a.ai - b.ai);
    air.forEach(p => { p.lead = null; p.stack = null; });
    air.forEach((p, i) => {
      if (p.lead) return;
      const pt = map.latLngToLayerPoint([p.lat, p.lon]);
      air.slice(i + 1).forEach(q => {
        if (!q.lead && pt.distanceTo(map.latLngToLayerPoint([q.lat, q.lon])) < 28) { q.lead = p; (p.stack = p.stack || []).push(q); }
      });
      // l'étiquette du groupe passe au-dessus des avions qu'elle chevauche
      p.marker.setZIndexOffset((p.ai ? 500 : 1000) + (p.stack ? 100 : 0));
    });
    units.forEach(p => p.marker.setIcon(iconFor(p)));
  }
  map.on('zoomend', () => declutter());

  // Noms internes DCS (envoyés par le serveur) → noms lisibles
  const TYPES = { 'FA-18C_hornet': 'F/A-18C', 'F-16C_50': 'F-16C', 'A-10C_2': 'A-10C II', 'AV8BNA': 'AV-8B', 'F-15ESE': 'F-15E',
    'AH-64D_BLK_II': 'AH-64D', 'Mirage-F1EE': 'Mirage F1', 'M-2000C': 'Mirage 2000C', 'F-14B': 'F-14B', 'F-14A-135-GR': 'F-14A',
    'Ka-50_3': 'Ka-50', 'Mi-24P': 'Mi-24P', 'UH-1H': 'UH-1H', 'T-45': 'T-45C', 'JF-17': 'JF-17', 'MiG-29 Fulcrum': 'MiG-29',
    'KC-135': 'KC-135', 'KC135MPRS': 'KC-135 MPRS', 'KC130': 'KC-130', 'S-3B Tanker': 'S-3B Tanker', 'E-3A': 'E-3A Sentry', 'E-2C': 'E-2C Hawkeye',
    CVN_71: 'CVN-71 Roosevelt', CVN_72: 'CVN-72 Lincoln', CVN_73: 'CVN-73 Washington', Stennis: 'CVN-74 Stennis', CVN_75: 'CVN-75 Truman',
    Forrestal: 'CV-59 Forrestal', KUZNECOW: 'Amiral Kouznetsov', CV_1143_5: 'Amiral Kouznetsov', LHA_Tarawa: 'LHA-1 Tarawa' };
  const acName = t => TYPES[t] || String(t || '').replace(/_/g, ' ');

  // Met à jour les unités à partir d'une liste (réelle ou démo), en gardant marqueurs et trajectoires
  function sync(list) {
    const seen = new Set();
    list.forEach(n => {
      // bs : absent du JSON quand le mode est coupé, sans ce !! Object.assign garderait l'ancien true
      n = { ...n, aircraft: acName(n.aircraft), key: n.id || n.callsign, ai: !!n.id, side: n.side ?? 2, bs: !!n.bs };
      seen.add(n.key);
      let p = units.find(x => x.key === n.key);
      if (!p) { p = { ...n, trail: [] }; units.push(p); }
      else Object.assign(p, n);
      p.fix = { lat: p.lat, lon: p.lon, at: Date.now() };
      // posé : trajectoire gardée jusqu'au décollage suivant
      if (p.air) { if (p.landed) { p.trail = []; p.landed = false; } p.trail.push([p.lat, p.lon, p.alt]); } else p.landed = true;
      if (!p.marker) p.marker = L.marker([p.lat, p.lon], { icon: iconFor(p) }).addTo(map).on('click', () => select(p.key, true));
      p.marker.setLatLng([p.lat, p.lon]).setZIndexOffset(p.ship ? -500 : p.air ? (p.ai ? 500 : 1000) : 0);
    });
    units = units.filter(p => {
      if (seen.has(p.key)) return true;
      map.removeLayer(p.marker); return false;
    });
    if (selected && !units.some(p => p.key === selected)) selected = null;
    declutter();
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
  // Lissage de Chaikin (3 passes) : un point toutes les 15 s fait des angles, un avion vire en courbe.
  // Seule la fin du tracé est lissée : sur les points anciens (espacés), le lissage écartait la trace de plusieurs nautiques.
  const TAIL = 24;
  function smooth(pts) {
    for (let n = 0; n < 3 && pts.length > 2; n++) {
      const out = [pts[0]];
      for (let i = 0; i < pts.length - 1; i++) {
        const [a, b] = [pts[i], pts[i + 1]];
        const mix = w => a.map((v, k) => v == null || b[k] == null ? v ?? b[k] : v * w + b[k] * (1 - w));  // lat, lon, altitude
        out.push(mix(.75), mix(.25));
      }
      out.push(pts[pts.length - 1]);
      pts = out;
    }
    return pts;
  }
  // un tracé par suite de segments de même couleur
  function paint(pts, layer) {
    let run = [pts[0]], color = altColor(pts[0][2]);
    const flush = () => run.length > 1 && L.polyline(run, { color, weight: 3, opacity: 0.9, interactive: false }).addTo(layer);
    for (let i = 1; i < pts.length; i++) {
      const c = altColor(pts[i][2]);
      run.push(pts[i]);
      if (c !== color) { flush(); run = [pts[i]]; color = c; }
    }
    flush();
  }
  // Partie ancienne (brute) redessinée seulement quand la trace change ; fin lissée redessinée chaque seconde
  const oldLayer = L.layerGroup().addTo(map);
  let oldKey = '';
  function drawTrail() {
    const p = units.find(x => x.key === selected);
    trailLayer.clearLayers();
    if (!p || !p.trail.length) { oldLayer.clearLayers(); oldKey = ''; return; }
    const cut = Math.max(0, p.trail.length - TAIL), k = p.key + ':' + cut + ':' + p.trail.length + ':' + p.trail[0];
    if (k !== oldKey) {
      oldKey = k; oldLayer.clearLayers();
      if (cut > 0) paint(p.trail.slice(0, cut + 1), oldLayer);
    }
    paint(smooth(p.trail.slice(cut).concat([[p.lat, p.lon, p.alt]])), trailLayer);
  }

  function renderList() {
    const players = units.filter(p => !p.ai), air = players.filter(p => p.air).length;
    $('counts').textContent = air + ' en vol · ' + (players.length - air) + ' au sol';
    $('total').textContent = players.length + ' connectés';
    const list = filter === 'ai' ? units.filter(p => p.ai) : players.filter(p => filter === 'all' || (filter === 'air' ? p.air : !p.air));
    $('plist').innerHTML = list.map(p => `
      <button class="p${selected === p.key ? ' sel' : ''}" data-key="${esc(p.key)}">
        <span class="ic${p.air || p.ship ? '' : ' g'}">${p.ship ? shipSvg(p, 26) : p.air ? svg(p, 0.85) : '<span class="sq"></span>'}</span>
        <span class="nm"><b>${p.ai ? (enemy(p) ? 'Inconnu' : esc(p.callsign || ROLES[p.role] || SHIP_NAMES[p.ship])) : crewName(p)}</b><small>${esc(p.aircraft)}${p.ai && !enemy(p) && p.freq ? ' · ' + esc(p.freq) : ''}${p.air || !p.base ? '' : ' · ' + esc(p.base)}</small></span>
        <span class="data">${p.ship ? '<span>' + Math.round(p.spd) + ' kt</span><span>' + hdg(p) + '</span>' : p.air ? '<span>' + fl(p) + '</span><span>' + Math.round(p.spd) + ' kt · ' + hdg(p) + '</span>' : '<span>Au sol</span>'}</span>
      </button>`).join('') || '<div class="empty" style="padding:24px">' + (filter === 'ai' ? 'Aucune IA en vol' : 'Aucun pilote connecté') + '</div>';
  }
  function renderFocus() {
    const p = units.find(x => x.key === selected);
    $('focus').classList.toggle('show', !!p);
    if (!p) return;
    const kind = p.ship ? SHIP_NAMES[p.ship] : ROLES[p.role];
    const side = p.ai ? (enemy(p) ? (p.ship ? 'Ennemi · ' : 'IA ennemie · ') : (p.ship ? 'Ami · ' : 'IA amie · ')) + kind + ' · ' : '';
    $('fCs').textContent = p.ai ? (enemy(p) ? 'Inconnu' : p.callsign || kind) : [p.callsign].concat(p.crew || []).map(short).join(' + ');
    $('fType').textContent = side + (p.bs && !p.ai ? 'Mode Blue Sky · ' : '') + p.aircraft +(p.ship ? '' : ' · ' + (p.air ? 'En vol' : 'Au sol' + (p.base ? ' · ' + p.base : '')));
    $('fAlt').textContent = p.ship ? '—' : p.air ? fl(p) : Math.round(p.alt) + ' ft';
    $('fSpd').textContent = Math.round(p.spd) + ' kt';
    $('fHdg').textContent = hdg(p);
    const radio = [['Fréquence', p.freq], ['TACAN', p.tacan], ['ICLS', p.icls], ['Link 4', p.link4]].filter(([, v]) => v);
    $('fRadio').style.display = radio.length ? '' : 'none';
    $('fRadio').innerHTML = radio.map(([k, v]) => '<div><span class="k">' + k + '</span><span class="v">' + esc(v) + '</span></div>').join('');
    const cur = !p.ai && p.flight, mins = s => Math.floor(s / 60);
    $('fFlight').style.display = cur ? '' : 'none';
    if (cur) $('fFlight').innerHTML =
      [['En vol depuis', cur.time >= 3600 ? Math.floor(cur.time / 3600) + ' h ' + String(mins(cur.time) % 60).padStart(2, '0') : mins(cur.time) + ' min'],
       ['Points du vol', fmt.n(cur.points)], ['Ravitaillé', mins(cur.refuel) + ' min'],
       ['Kills A/A', fmt.n(cur.airair)], ['Kills A/S', fmt.n(cur.airsol)], ['Kills A/M', fmt.n(cur.airmer)]]
      .map(([k, v]) => '<div><span class="k">' + k + '</span><span class="v">' + esc(v) + '</span></div>').join('');
    const st = !p.ai && statsOf(p.callsign);
    $('fStats').style.display = st ? '' : 'none';
    $('fRank').innerHTML = st ? insignia(st.grade, 'xs') : '';
    if (st) $('fStats').innerHTML = [['Points', fmt.n(st.points)], ['Heures', fmt.h1(st.hours) + ' h']]
      .map(([k, v]) => '<div><span class="k">' + k + '</span><span class="v">' + esc(v) + '</span></div>').join('');
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
      // relevé côté bot à quelques dizaines de secondes près : on avance à partir de l'heure de l'envoi
      upT0 = !d.offline && d.uptime ? { t: d.uptime, at: d.time ? new Date(d.time).getTime() : Date.now() } : demo ? { t: 8040, at: Date.now() } : null;
      const nOnline = (d.online || d.players || []).length;
      $('srv').innerHTML = demo ? demoBadge() : d.offline ? '<span style="color:#8a91a3">Hors ligne</span>'
        : nOnline ? '<span class="dot"></span><span style="color:#0b7d75">En ligne</span>' : '<span style="color:#8a91a3">Personne en ligne</span>';
      $('liveDemo').innerHTML = demo ? demoBadge('Démo · export live à venir') : '';
      $('noteSrc').textContent = d.offline ? 'Serveur DCS arrêté ou sans mission · la carte se remplit dès qu’une mission tourne'
        : !demo ? 'Positions envoyées par le bot du serveur DCS · mises à jour toutes les ' + delay / 1000 + ' s'
        : 'Données de démonstration · le serveur DCS n\'exporte pas encore les positions';
      sync((d.players || []).concat(d.ai || []));
      if (++polls % 6 === 0) fetchTrail();  // trajectoire du sélectionné relue toutes les 30 s
      after();
    });
  }

  // Relu toutes les 5 s quand le serveur tourne (le bot envoie les positions toutes les 5 s), toutes les 2 min sinon ;
  // rien tant que l'onglet est caché, relu dès qu'on y revient.
  // Garde-fou quota Google : un relais lent (> 3 s, Apps Script saturé) double l'intervalle jusqu'à 60 s,
  // un relais rapide le divise par deux jusqu'à revenir à 5 s. Relais en erreur = « hors ligne », relu toutes les 2 min.
  let timer = null, delay = 5e3;
  const schedule = took => {
    if (took != null) delay = took > 3e3 ? Math.min(delay * 2, 60e3) : Math.max(5e3, delay / 2);
    timer = setTimeout(poll, offline ? 120e3 : delay);
  };
  function poll() {
    timer = null;
    if (document.hidden) return;
    const t0 = Date.now();
    load().then(() => schedule(Date.now() - t0));
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
  const upText = () => {
    if (!upT0) return '–';
    const m = Math.floor((upT0.t + (Date.now() - upT0.at) / 1000) / 60);
    return m >= 60 ? Math.floor(m / 60) + ' h ' + String(m % 60).padStart(2, '0') : m + ' min';
  };
  setInterval(() => ($('uptime').textContent = upText()), 1000);
})();
