(function () {
  const { esc, fmt, airfields, loadLive, demoBadge } = window.BS;
  const $ = id => document.getElementById(id);
  let players = [], selected = null, follow = false, filter = 'all', demo = true, missionT0 = null;

  const map = L.map('map', { minZoom: 6, maxZoom: 12, zoomSnap: 0.5 }).setView([42.95, 42.2], 7);
  map.zoomControl.setPosition('topright');
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OpenStreetMap contributors', maxZoom: 19 }).addTo(map);
  map.setMaxBounds([[39.5, 34.5], [47.5, 48.5]]);
  const grid = { color: '#2a5ca8', weight: 1, opacity: 0.18, dashArray: '4 6', interactive: false };
  for (let lat = 41; lat <= 46; lat++) L.polyline([[lat, 35], [lat, 48]], grid).addTo(map);
  for (let lon = 36; lon <= 47; lon++) L.polyline([[40, lon], [47, lon]], grid).addTo(map);
  airfields.forEach(a => L.marker([a.lat, a.lon], { icon: L.divIcon({ className: '', html: '<div class="af"><span class="ring"></span><span class="nm">' + a.icao + '</span></div>', iconSize: [0, 0] }), keyboard: false })
    .addTo(map).bindTooltip(a.name + ' · ' + a.icao, { direction: 'top', offset: [0, -8] }));

  const fl = p => p.alt < 5000 ? Math.round(p.alt) + ' ft' : 'FL' + String(Math.round(p.alt / 100)).padStart(3, '0');
  const hdg = p => String(Math.round(p.hdg)).padStart(3, '0') + '°';
  const dm = (v, pos, neg, w) => { const a = Math.abs(v), d = Math.floor(a), m = ((a - d) * 60).toFixed(1); return (v >= 0 ? pos : neg) + ' ' + String(d).padStart(w, '0') + '°' + m.padStart(4, '0') + "'"; };
  const iconFor = p => {
    const sel = selected === p.callsign ? ' sel' : '';
    if (!p.air) return L.divIcon({ className: '', html: '<div class="gnd' + sel + '"><span class="sq"></span></div>', iconSize: [0, 0] });
    return L.divIcon({ className: '', html: '<div class="ac' + sel + '"><span class="arrow" style="transform:rotate(' + Math.round(p.hdg) + 'deg)"></span><span class="tg">' + esc(p.callsign) + ' <i>' + fl(p) + '</i></span></div>', iconSize: [0, 0] });
  };

  // Noms internes DCS (envoyés par le serveur) → noms lisibles
  const TYPES = { 'FA-18C_hornet': 'F/A-18C', 'F-16C_50': 'F-16C', 'A-10C_2': 'A-10C II', 'AV8BNA': 'AV-8B', 'F-15ESE': 'F-15E',
    'AH-64D_BLK_II': 'AH-64D', 'Mirage-F1EE': 'Mirage F1', 'M-2000C': 'Mirage 2000C', 'F-14B': 'F-14B', 'F-14A-135-GR': 'F-14A',
    'Ka-50_3': 'Ka-50', 'Mi-24P': 'Mi-24P', 'UH-1H': 'UH-1H', 'T-45': 'T-45C', 'JF-17': 'JF-17', 'MiG-29 Fulcrum': 'MiG-29' };
  const acName = t => TYPES[t] || String(t || '').replace(/_/g, ' ');

  // Met à jour les joueurs à partir d'une liste (réelle ou démo), en gardant marqueurs et traînées
  function sync(list) {
    const seen = new Set();
    list.forEach(n => {
      n = { ...n, aircraft: acName(n.aircraft) };
      seen.add(n.callsign);
      let p = players.find(x => x.callsign === n.callsign);
      if (!p) { p = { ...n, trail: [] }; players.push(p); }
      else Object.assign(p, n);
      if (p.air) { p.trail.push([p.lat, p.lon]); if (p.trail.length > 45) p.trail.shift(); } else p.trail = [];
      if (!p.line) p.line = L.polyline(p.trail, { color: '#2a5ca8', weight: 2, opacity: 0.4, interactive: false }).addTo(map);
      p.line.setLatLngs(p.trail);
      if (!p.marker) p.marker = L.marker([p.lat, p.lon], { icon: iconFor(p) }).addTo(map).on('click', () => select(p.callsign, true));
      p.marker.setLatLng([p.lat, p.lon]).setIcon(iconFor(p)).setZIndexOffset(p.air ? 1000 : 0);
    });
    players = players.filter(p => {
      if (seen.has(p.callsign)) return true;
      map.removeLayer(p.marker); map.removeLayer(p.line); return false;
    });
  }

  function renderList() {
    const air = players.filter(p => p.air).length;
    $('counts').textContent = air + ' en vol · ' + (players.length - air) + ' au sol';
    $('total').textContent = players.length + ' connectés';
    const list = players.filter(p => filter === 'all' || (filter === 'air' ? p.air : !p.air));
    $('plist').innerHTML = list.map(p => `
      <button class="p${selected === p.callsign ? ' sel' : ''}" data-cs="${esc(p.callsign)}">
        <span class="ic${p.air ? '' : ' g'}">${p.air ? '<span class="tri" style="transform:rotate(' + Math.round(p.hdg) + 'deg)"></span>' : '<span class="sq"></span>'}</span>
        <span class="nm"><b>${esc(p.callsign)}</b><small>${esc(p.aircraft)}${p.air || !p.base ? '' : ' · ' + esc(p.base)}</small></span>
        <span class="data">${p.air ? '<span>' + fl(p) + '</span><span>' + Math.round(p.spd) + ' kt · ' + hdg(p) + '</span>' : '<span>Au sol</span>'}</span>
      </button>`).join('') || '<div class="empty" style="padding:24px">Aucun pilote connecté</div>';
  }
  function renderFocus() {
    const p = players.find(x => x.callsign === selected);
    $('focus').classList.toggle('show', !!p);
    if (!p) return;
    $('fCs').textContent = p.callsign;
    $('fType').textContent = p.aircraft + ' · ' + (p.air ? 'En vol' : 'Au sol' + (p.base ? ' · ' + p.base : ''));
    $('fAlt').textContent = p.air ? fl(p) : Math.round(p.alt) + ' ft';
    $('fSpd').textContent = Math.round(p.spd) + ' kt';
    $('fHdg').textContent = hdg(p);
    $('fPos').textContent = dm(p.lat, 'N', 'S', 2) + '  ' + dm(p.lon, 'E', 'W', 3);
    $('followBtn').classList.toggle('on', follow);
  }
  function select(cs, fly) {
    selected = cs; follow = false;
    const p = players.find(x => x.callsign === cs);
    players.forEach(x => x.marker.setIcon(iconFor(x)));
    if (p && fly) map.flyTo([p.lat, p.lon], Math.max(map.getZoom(), 8.5), { duration: 0.8 });
    renderList(); renderFocus();
  }
  $('plist').addEventListener('click', e => { const b = e.target.closest('.p'); if (b) select(b.dataset.cs, true); });
  $('tabs').addEventListener('click', e => {
    const b = e.target.closest('button'); if (!b) return;
    filter = b.dataset.f;
    $('tabs').querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
    renderList();
  });
  $('closeFocus').onclick = () => select(null, false);
  $('followBtn').onclick = () => { follow = !follow; renderFocus(); };

  function after() {
    const sp = players.find(x => x.callsign === selected);
    if (follow && sp) map.panTo([sp.lat, sp.lon], { animate: true, duration: 0.8 });
    renderList(); renderFocus();
  }

  // Démo : on fait voler les avions localement
  function demoTick() {
    players.forEach(p => {
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
    sync(players.map(({ marker, line, trail, ...rest }) => rest));
    after();
  }

  function setWeather(w) {
    $('wx').innerHTML = [['Vent', w.wind], ['Visibilité', w.visibility], ['Nuages', w.clouds], ['Température', w.temp], ['QNH', w.qnh]]
      .map(([k, v], i) => '<div' + (i === 4 ? ' style="grid-column:span 2"' : '') + '><span class="label">' + k + '</span><span class="v">' + esc(v ?? '—') + '</span></div>').join('');
  }

  function load() {
    return loadLive().then(d => {
      demo = d.demo;
      if (d.weather) setWeather(d.weather);
      if (!demo && !d.weather) setWeather({});
      if (d.missionTime != null) missionT0 = { t: d.missionTime, at: Date.now() };
      $('srv').innerHTML = demo ? demoBadge() : d.offline ? '<span style="color:#8a91a3">Hors ligne</span>' : '<span class="dot"></span><span style="color:#0b7d75">En ligne</span>';
      $('liveDemo').innerHTML = demo ? demoBadge('Démo · export live à venir') : '';
      $('noteSrc').textContent = d.offline ? 'Serveur DCS arrêté ou sans mission · la carte se remplit dès qu’une mission tourne'
        : !demo ? 'Positions envoyées par le bot du serveur DCS · mises à jour toutes les 30 s environ'
        : 'Données de démonstration · le serveur DCS n\'exporte pas encore les positions';
      sync(d.players || []);
      after();
    });
  }

  load().then(() => {
    if (demo) setInterval(demoTick, 1000);
    else setInterval(load, 15000);
  });
  // Heure in-game : envoyée par le serveur (secondes depuis minuit), sinon horloge de démo
  const hms = s => { s = Math.floor(s) % 86400; return [s / 3600, s % 3600 / 60, s % 60].map(x => String(Math.floor(x)).padStart(2, '0')).join(':'); };
  setInterval(() => ($('clock').textContent = missionT0 ? hms(missionT0.t + (Date.now() - missionT0.at) / 1000) : fmt.missionClock(Date.now())), 1000);
})();
