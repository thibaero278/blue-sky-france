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

  // Silhouettes vues de dessus, nez vers le haut, dans l'esprit de la planche ADS-B Exchange (redessinées ici).
  // sym() : demi-contour droit [x, y] du nez à la queue, recopié en miroir à gauche.
  const sym = pts => '<path d="M' + pts.map(([x, y]) => x + ' ' + y).join('L') + 'L' + pts.slice().reverse().map(([x, y]) => -x + ' ' + y).join('L') + 'Z"/>';
  const QUAD = [[0, -15], [1.4, -12.5], [1.4, -4], [14, 3], [14, 4.6], [1.4, 1], [1.2, 10], [6, 13], [6, 14.5], [1, 14], [0, 14.5]];
  const SHAPES = {
    hornet: sym([[0, -15], [1, -11], [1.6, -6], [2.6, -3], [12, 3], [12, 5], [3, 5], [3, 8], [7, 11], [7, 13], [2.5, 12.5], [1.5, 14], [0, 14]]),
    tomcat: sym([[0, -15], [1.2, -10], [2, -6], [4.5, -3], [13.5, 4], [13.5, 5.5], [5, 4], [4, 9], [8, 13], [8, 14.5], [3, 13.5], [2.5, 15], [0, 14.5]]),
    eagle: sym([[0, -15], [1.3, -10], [2.5, -5], [3.5, -3], [12, 3], [12, 6], [4, 5], [4, 9], [8, 12], [8, 14], [3.5, 13.5], [3, 15], [0, 14]]),
    viper: sym([[0, -15], [1, -10], [1.5, -5], [2.5, -2], [11, 4], [11, 5.5], [2.5, 4.5], [2.5, 10], [6.5, 13], [6.5, 14.5], [1.5, 14], [1, 15.5], [0, 15]]),
    phantom: sym([[0, -15], [1.2, -9], [2, -4], [11, 3], [11.5, 4.5], [2.5, 5], [2.5, 10], [7, 12], [7, 13.5], [1.5, 13.5], [0, 14]]),
    tiger: sym([[0, -15], [0.9, -9], [1.3, -4], [9, 3], [9, 4.5], [1.5, 4], [1.5, 10], [5, 12.5], [5, 13.5], [1, 13.5], [0, 14]]),
    flanker: sym([[0, -15], [1, -11], [1.8, -7], [2.5, -4], [4, -2], [13, 4], [13, 6], [4.5, 6], [4.5, 10], [8, 12.5], [8, 14], [3, 13], [1.2, 13.5], [1, 15.5], [0, 15.5]]),
    fulcrum: sym([[0, -15], [1, -10], [1.6, -6], [3.5, -3], [11, 3], [11, 5], [4, 5], [4, 10], [7.5, 12.5], [7.5, 14], [2.5, 13], [0, 14]]),
    delta: sym([[0, -15], [1, -9], [1.5, -5], [10, 8], [10, 10], [1.5, 10], [1, 12], [0, 12.5]]),
    f1: sym([[0, -15], [1, -9], [1.4, -2], [8, 4], [8, 5.5], [1.5, 4.5], [1.5, 9], [5, 12], [5, 13.5], [1, 13], [0, 13.5]]),
    jf17: sym([[0, -15], [1, -10], [1.6, -5], [3, -2], [10, 3.5], [10, 5], [2.5, 5], [2.5, 10], [6, 13], [6, 14.5], [1.2, 14], [0, 14.5]]),
    harrier: sym([[0, -15], [1, -10], [1.8, -5], [2.5, -1], [9, 4], [9, 5.5], [2.3, 4], [2, 9], [5, 11], [5, 12.5], [1, 12.5], [0, 14]]),
    hog: sym([[0, -15], [1, -12], [1.3, -4], [14, -3.5], [14, -0.5], [1.3, -0.5], [1.3, 9], [6, 10], [6, 12.5], [1, 12], [0, 12.5]])
      + '<rect x="2" y="1.5" width="2.6" height="6" rx="1.3"/><rect x="-4.6" y="1.5" width="2.6" height="6" rx="1.3"/>',
    frogfoot: sym([[0, -15], [1, -11], [1.6, -4], [12, 0], [12, 1.5], [1.8, 1], [1.6, 9], [5.5, 11], [5.5, 12.5], [1, 12], [0, 13]]),
    swing: sym([[0, -15], [1.2, -10], [2, -5], [4, -3], [11, 6], [10.5, 7], [3.5, 4], [2.5, 10], [7, 13], [7, 14.5], [1.5, 14], [0, 14.5]]),
    stealth: sym([[0, -15], [1.5, -8], [3, -4], [11, 3], [11, 5], [4, 5.5], [6, 10], [6, 12], [2, 11], [0, 11.5]]),
    foxbat: sym([[0, -15], [1, -10], [3.5, -5], [4, -3], [12, 3], [12, 5], [4, 5], [4, 10], [7, 13], [7, 14], [3, 13], [0, 13]]),
    trainer: sym([[0, -14], [1, -9], [1.3, -3], [10, 0], [10, 1.5], [1.4, 2], [1.2, 9], [4.5, 10.5], [4.5, 12], [0.8, 12], [0, 12.5]]),
    bomber: sym([[0, -15], [1.2, -12], [1.2, -6], [15, 3], [15, 4.5], [1.2, 0], [1.2, 10], [6, 12], [6, 13.5], [1, 13.5], [0, 14]]),
    quad: sym(QUAD),
    radome: sym(QUAD) + '<circle cy="1.5" r="5"/>',
    cargo: sym([[0, -14], [1.8, -12], [2, -4], [15, -3], [15, -1], [2, -1], [1.8, 8], [6, 10], [6, 12], [1.2, 11.5], [0, 12]]),
    prop: sym([[0, -13], [1.2, -11.5], [1.4, -7], [12, -6], [12, -3.5], [1.4, -3], [1, 8], [5, 9], [5, 11], [0.8, 11], [0, 11.5]])
      + '<path d="M-5.5-14H5.5" fill="none" stroke-width="1.6"/>',
    heli: '<circle cy="-2" r="12.5" fill="none" stroke-width="1.6" opacity=".7"/><path d="M0-8C3-8 3.5-4 3.5 0C3.5 3 2 5 1 6V14L3 15V16H-3V15L-1 14V6C-2 5-3.5 3-3.5 0C-3.5-4-3-8 0-8Z"/>',
    chinook: '<circle cy="-8" r="8" fill="none" stroke-width="1.4" opacity=".7"/><circle cy="8" r="8" fill="none" stroke-width="1.4" opacity=".7"/><rect x="-2.6" y="-12" width="5.2" height="24" rx="2.6"/>',
    drone: sym([[0, -10], [1, -8], [1, -2], [15, -1], [15, 0.5], [1, 0.5], [0.8, 7], [4, 10], [4, 11], [0, 10]]),
  };
  // Type DCS → silhouette (les avions qui se ressemblent partagent la même) ; inconnu → chasseur générique
  const FAMILIES = [
    [/F.A-18|FA-18/, 'hornet'], [/F-14/, 'tomcat'], [/F-15/, 'eagle'], [/F-16/, 'viper'], [/F-4/, 'phantom'], [/F-5/, 'tiger'],
    [/Su-2[7]|Su-3[034]|J-11/, 'flanker'], [/MiG-29/, 'fulcrum'], [/M-2000|Mirage 2000|MiG-21|J-10/, 'delta'], [/Mirage-F1|F1/, 'f1'],
    [/JF-17/, 'jf17'], [/AV8|Harrier/, 'harrier'], [/A-10/, 'hog'], [/Su-25/, 'frogfoot'],
    [/Su-24|Tornado|MiG-2[37]|B-1|Tu-160|Tu-22/, 'swing'], [/F-35|F-22|F-117/, 'stealth'], [/MiG-25|MiG-31/, 'foxbat'],
    [/T-45|L-39|C-101|MB-339|A-4|F-86|MiG-15|Yak-52/, 'trainer'], [/B-52|Tu-95|Tu-142/, 'bomber'],
    [/E-3|E-2|A-50|KJ-2000/, 'radome'], [/KC-?135|IL-7[68]|C-17|707|A400|Tu-134|Yak-40|S-3B/, 'quad'], [/C-130|KC.?130|An-2[6]|An-30/, 'cargo'],
    [/P-51|P-47|TF-51|Spitfire|Bf.?109|FW.?190|Fw 190|I-16|Mosquito|Ju-88|A6M|F4U|Corsair|Christen|Yak-52|SPAD|Fokker|Sopwith|Camel/, 'prop'],
    [/CH-47/, 'chinook'], [/MQ-|RQ-|WingLoong/, 'drone'],
  ];
  const shapeOf = p => {
    if (p.role === 'heli' && !/CH-47/.test(p.aircraft)) return 'heli';
    const f = FAMILIES.find(([re]) => re.test(p.type || p.aircraft));
    return f ? f[1] : p.role === 'awacs' ? 'radome' : p.role === 'tanker' || p.role === 'heavy' ? 'quad' : 'hornet';
  };
  const colorOf = p => selected === p.key ? '#d9b45a' : enemy(p) ? '#d0342c' : p.ai ? '#13a89e' : '#2a5ca8';
  const svg = (p, size) => '<svg viewBox="-17 -17 34 34" width="' + size + '" height="' + size + '" style="transform:rotate(' + Math.round(p.hdg) + 'deg)" fill="' + colorOf(p)
    + '" stroke="#13213a" stroke-width="1.1" stroke-linejoin="round">' + SHAPES[shapeOf(p)] + '</svg>';

  // Porte-avions vus du dessus, noir et blanc : CVN (pont oblique), Kuznetsov (tremplin), Tarawa (pont droit)
  const SHIPS = {
    cvn: '<path d="M-1.8-15H2.2L4.6-9V12L3 15H-3.6L-4.6 12V5L-7.2 2.5V-3.5L-4.6-6.5V-9Z"/><path d="M-1 14L-5.6-1.8" fill="none" stroke-dasharray="1.6 1.4" stroke-width=".8"/><rect x="4.6" y="1" width="1.8" height="5" fill="#13213a"/>',
    kuz: '<path d="M0-15.5C2.4-15.5 4.2-12 4.6-8V12L3 15H-3.6L-4.6 12V5L-6.6 2.5V-3L-4.4-6V-8C-4-12-2.4-15.5 0-15.5Z"/><path d="M-3.4-11.5Q0-14.4 3.4-11.5" fill="none" stroke-width=".9"/><path d="M-0.6 14L-4.8-1" fill="none" stroke-dasharray="1.6 1.4" stroke-width=".8"/><rect x="4.6" y="-1" width="2" height="7" fill="#13213a"/>',
    lha: '<path d="M0-15.5C2.6-15.5 4.2-12.5 4.2-9.5V14.5H-4.2V-9.5C-4.2-12.5-2.6-15.5 0-15.5Z"/><path d="M0-12V12.5" fill="none" stroke-dasharray="1.6 1.4" stroke-width=".8"/><rect x="4.2" y="-2" width="1.9" height="8" fill="#13213a"/>',
  };
  const shipSvg = (p, size) => '<svg viewBox="-17 -17 34 34" width="' + size + '" height="' + size + '" style="transform:rotate(' + Math.round(p.hdg) + 'deg)" fill="#fbfaf7" stroke="'
    + (selected === p.key ? '#d9b45a' : enemy(p) ? '#d0342c' : '#13213a') + '" stroke-width="1.2" stroke-linejoin="round">' + SHIPS[p.ship] + '</svg>';
  const SHIP_NAMES = { cvn: 'Porte-avions (CVN)', kuz: 'Porte-avions (Kuznetsov)', lha: 'Porte-aéronefs (Tarawa)' };
  const label = p => p.ai ? (enemy(p) ? '' : esc(p.callsign || '')) : esc(p.callsign);
  const iconFor = p => {
    const sel = selected === p.key ? ' sel' : '';
    if (p.ship) return L.divIcon({ className: '', html: '<div class="shp' + sel + '">' + shipSvg(p, 44)
      + (enemy(p) ? '' : '<span class="tg">' + esc(p.callsign || SHIP_NAMES[p.ship]) + '</span>') + '</div>', iconSize: [0, 0] });
    if (!p.air) return L.divIcon({ className: '', html: '<div class="gnd' + sel + '"><span class="sq"></span></div>', iconSize: [0, 0] });
    const name = label(p);
    return L.divIcon({ className: '', html: '<div class="ac' + sel + (p.ai ? ' ai' : '') + '">' + svg(p, p.ai ? 24 : 28)
      + '<span class="tg">' + (name ? name + ' ' : '') + '<i>' + fl(p) + '</i></span></div>', iconSize: [0, 0] });
  };

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
      n = { ...n, aircraft: acName(n.aircraft), key: n.id || n.callsign, ai: !!n.id, side: n.side ?? 2 };
      seen.add(n.key);
      let p = units.find(x => x.key === n.key);
      if (!p) { p = { ...n, trail: [] }; units.push(p); }
      else Object.assign(p, n);
      p.fix = { lat: p.lat, lon: p.lon, at: Date.now() };
      if (p.air) p.trail.push([p.lat, p.lon]); else p.trail = [];
      if (!p.marker) p.marker = L.marker([p.lat, p.lon], { icon: iconFor(p) }).addTo(map).on('click', () => select(p.key, true));
      p.marker.setLatLng([p.lat, p.lon]).setIcon(iconFor(p)).setZIndexOffset(p.ship ? -500 : p.air ? (p.ai ? 500 : 1000) : 0);
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
        <span class="ic${p.air || p.ship ? '' : ' g'}">${p.ship ? shipSvg(p, 26) : p.air ? svg(p, 22) : '<span class="sq"></span>'}</span>
        <span class="nm"><b>${p.ai ? (enemy(p) ? 'Inconnu' : esc(p.callsign || ROLES[p.role] || SHIP_NAMES[p.ship])) : esc(p.callsign)}</b><small>${esc(p.aircraft)}${p.ai && !enemy(p) && p.freq ? ' · ' + esc(p.freq) : ''}${p.air || !p.base ? '' : ' · ' + esc(p.base)}</small></span>
        <span class="data">${p.ship ? '<span>' + Math.round(p.spd) + ' kt</span><span>' + hdg(p) + '</span>' : p.air ? '<span>' + fl(p) + '</span><span>' + Math.round(p.spd) + ' kt · ' + hdg(p) + '</span>' : '<span>Au sol</span>'}</span>
      </button>`).join('') || '<div class="empty" style="padding:24px">' + (filter === 'ai' ? 'Aucune IA en vol' : 'Aucun pilote connecté') + '</div>';
  }
  function renderFocus() {
    const p = units.find(x => x.key === selected);
    $('focus').classList.toggle('show', !!p);
    if (!p) return;
    const kind = p.ship ? SHIP_NAMES[p.ship] : ROLES[p.role];
    const side = p.ai ? (enemy(p) ? (p.ship ? 'Ennemi · ' : 'IA ennemie · ') : (p.ship ? 'Ami · ' : 'IA amie · ')) + kind + ' · ' : '';
    $('fCs').textContent = p.ai ? (enemy(p) ? 'Inconnu' : p.callsign || kind) : p.callsign;
    $('fType').textContent = side + p.aircraft + (p.ship ? '' : ' · ' + (p.air ? 'En vol' : 'Au sol' + (p.base ? ' · ' + p.base : '')));
    $('fAlt').textContent = p.ship ? '—' : p.air ? fl(p) : Math.round(p.alt) + ' ft';
    $('fSpd').textContent = Math.round(p.spd) + ' kt';
    $('fHdg').textContent = hdg(p);
    const radio = [['Fréquence', p.freq], ['TACAN', p.tacan], ['ICLS', p.icls], ['Link 4', p.link4]].filter(([, v]) => v);
    $('fRadio').style.display = radio.length ? '' : 'none';
    $('fRadio').innerHTML = radio.map(([k, v]) => '<div><span class="k">' + k + '</span><span class="v">' + esc(v) + '</span></div>').join('');
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
