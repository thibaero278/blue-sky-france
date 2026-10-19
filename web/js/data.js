// Blue Sky France — données du site.
// Chaque source (stats serveur, Discord, carte live…) est lue si elle est configurée dans config.js,
// sinon on renvoie des données de démonstration marquées `demo: true`.
(function () {
  const C = window.BS_CONFIG || {};
  const GOLD = '#d9b45a', SILVER = '#dde2ea', BLUEBAR = '#9fb6d8';

  // Paliers identiques à la table RANKS de mission/script Caucase.lua (à garder synchronisés).
  const GRADES = [
    { name: 'Aspirant', short: 'ASP', min: 0, bars: 1, aspirant: true },
    { name: 'Sous-lieutenant', short: 'SLT', min: 10, bars: 1 },
    { name: 'Lieutenant', short: 'LTN', min: 30, bars: 2 },
    { name: 'Capitaine', short: 'CNE', min: 60, bars: 3 },
    { name: 'Commandant', short: 'CDT', min: 120, bars: 4 },
    { name: 'Lieutenant-colonel', short: 'LCL', min: 200, bars: 5, mixed: true },
    { name: 'Colonel', short: 'COL', min: 350, bars: 5 },
    { name: 'Général de brigade aérienne', short: 'GBA', min: 600, stars: 2 },
    { name: 'Général de division aérienne', short: 'GDA', min: 1000, stars: 3 },
    { name: 'Général de corps aérien', short: 'GCA', min: 1800, stars: 4 },
    { name: "Général d'armée aérienne", short: 'GAA', min: 3000, stars: 5 }
  ];
  GRADES.forEach((g, i) => {
    g.rank = i + 1;
    g.next = GRADES[i + 1] || null;
    g.marks = g.stars
      ? Array.from({ length: g.stars }, () => ({ star: true, color: GOLD }))
      : Array.from({ length: g.bars }, (_, k) => ({ star: false, color: g.aspirant ? BLUEBAR : g.mixed && (k === 1 || k === 3) ? SILVER : GOLD }));
  });
  const gradeFor = pts => { let g = GRADES[0]; for (const x of GRADES) if (pts >= x.min) g = x; return g; };

  const insignia = (g, size) => '<span class="ins ' + size + '" title="' + esc(g.name) + '">' +
    g.marks.map(m => m.star ? '<span class="s" style="color:' + m.color + '">★</span>' : '<i class="b" style="background:' + m.color + '"></i>').join('') + '</span>';

  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const pad = n => String(n).padStart(2, '0');
  const fmt = {
    n: x => Number(x).toLocaleString('fr-FR'),
    h1: x => (Math.round(x * 10) / 10).toLocaleString('fr-FR'),
    dur: s => { s = Math.round(s || 0); const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60); return h ? h + ' h ' + pad(m) : m + ' min'; },
    dateLong: d => d.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' }),
    dateShort: d => d.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' }),
    dayShort: d => d.toLocaleDateString('fr-FR', { weekday: 'short' }).replace('.', ''),
    month: d => d.toLocaleDateString('fr-FR', { month: 'short' }).replace('.', ''),
    hour: d => pad(d.getHours()) + ':' + pad(d.getMinutes()),
    ago: d => {
      const m = Math.max(0, Math.round((Date.now() - d.getTime()) / 60000));
      return m < 1 ? "à l'instant" : m < 60 ? 'il y a ' + m + ' min' : m < 1440 ? 'il y a ' + Math.round(m / 60) + ' h' : 'le ' + fmt.dateShort(d);
    },
    countdown: ms => {
      if (ms <= 0) return 'En cours';
      const s = Math.floor(ms / 1000), d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60);
      return (d ? 'J-' + d + ' · ' : '') + pad(h) + ':' + pad(m) + ':' + pad(s % 60);
    },
    missionClock: t => { const d = new Date(t + 6 * 3600e3 + 17 * 60e3); return pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds()); }
  };

  // Générateur pseudo-aléatoire stable (mêmes données de démo à chaque chargement)
  const rng = seed => () => (seed = (seed * 16807) % 2147483647) / 2147483647;

  // ---------- stats serveur (Scores.lua → hook → Apps Script) ----------
  // Un pilote tel qu'exporté par Code.gs : name, grade, points, totalFlightTime, completedFlightTime,
  // maxFlightTime, flights, airair, airsol, airmer, traps, deaths, teamkills, refuelTime, rang
  function normPilot(r, i) {
    const n = k => Number(r[k]) || 0;
    const points = n('points');
    return {
      id: i, callsign: String(r.name ?? '?'), points,
      hours: n('totalFlightTime') / 3600, completedHours: n('completedFlightTime') / 3600,
      longest: n('maxFlightTime'), flights: n('flights'),
      airKills: n('airair'), groundKills: n('airsol'), navalKills: n('airmer'),
      traps: n('traps'), deaths: n('deaths'), teamkills: n('teamkills'), refuel: n('refuelTime'),
      level: r.grade || '', grade: gradeFor(points)
    };
  }

  function demoStats() {
    const r = rng(20240618);
    const names = ['Breakdown', 'Branch', 'Smokey', 'Redman', 'Mistral', 'Sirocco', 'Corsaire', 'Fennec', 'Gerfaut', 'Albatros', 'Hermine',
      'Nimbus', 'Tramontane', 'Lynx', 'Phénix', 'Cirrus', 'Orage', 'Vercors', 'Cigogne', 'Gascon', 'Brumaire', 'Kestrel', 'Écho', 'Sabre', 'Zéphyr', 'Harfang'];
    const fixed = { Breakdown: 1240, Branch: 980, Smokey: 410, Redman: 215 };
    const raw = names.map(name => {
      const points = fixed[name] || Math.round(2 + 520 * Math.pow(r(), 2.4));
      const total = Math.round((points * 140 + r() * 40 * 3600));
      const flights = Math.max(1, Math.round(total / (3600 * (0.8 + r()))));
      return {
        name, points, totalFlightTime: total, completedFlightTime: Math.round(total * (0.75 + r() * 0.2)),
        maxFlightTime: Math.round(3600 + r() * 7200), flights,
        airair: Math.round(points / 9 * (0.5 + r() * 0.6)), airsol: Math.round(points / 3 * (0.4 + r() * 0.6)), airmer: Math.round(points / 60 * r()),
        traps: Math.round(flights * r() * 0.6), deaths: Math.round(flights * (0.05 + r() * 0.2)), teamkills: r() > 0.85 ? 1 : 0,
        refuelTime: Math.round(r() * 3 * 3600), grade: 'ROOKIE'
      };
    });
    return {
      demo: true, pilots: raw.map(normPilot),
      server: { updated: new Date(Date.now() - 4 * 60e3), name: C.serverName, mission: C.missionLabel, online: ['Branch', 'Breakdown', 'Smokey', 'Mistral', 'Fennec', 'Gerfaut', 'Hermine', 'Corsaire', 'Nimbus', 'Lynx', 'Cirrus'] },
      changelog: [
        { date: new Date(Date.now() - 1 * 86400e3), version: 'v2.2', notes: 'Grades automatiques aux points (échelle Armée de l\'Air).' },
        { date: new Date(Date.now() - 2 * 86400e3), version: 'v2.1', notes: 'Heures complètes, kneeboard Blue Sky.' }
      ]
    };
  }

  let statsP = null;
  function loadStats() {
    if (statsP) return statsP;
    if (!C.statsUrl) return (statsP = Promise.resolve(demoStats()));
    statsP = fetch(C.statsUrl + (C.statsUrl.includes('?') ? '&' : '?') + 'format=json', { cache: 'no-store' })
      .then(res => { if (!res.ok) throw new Error('HTTP ' + res.status); return res.json(); })
      .then(d => {
        const s = d.server || {};
        const upd = s['Derniere mise a jour'] ? new Date(s['Derniere mise a jour']) : null;
        return {
          demo: false,
          pilots: (d.pilots || []).filter(p => p.name !== '' && p.name != null).map(normPilot),
          server: { updated: upd, name: s['Serveur'] || C.serverName, mission: s['Mission'] || '', online: String(s['En ligne'] || '').split(',').map(x => x.trim()).filter(Boolean) },
          changelog: (d.changelog || []).map(c => ({ ...c, date: new Date(c.date) }))
        };
      })
      .catch(err => { console.warn('[BS] stats indisponibles, démo affichée :', err); return { ...demoStats(), error: String(err) }; });
    return statsP;
  }

  // ---------- Discord : membres / en ligne via l'API publique des invitations ----------
  let discordP = null;
  function loadDiscord() {
    if (discordP) return discordP;
    const demo = { demo: true, members: 142, online: 38 };
    if (!C.discordInviteCode) return (discordP = Promise.resolve(demo));
    discordP = fetch('https://discord.com/api/v10/invites/' + C.discordInviteCode + '?with_counts=true')
      .then(res => { if (!res.ok) throw new Error('HTTP ' + res.status); return res.json(); })
      .then(j => ({ demo: false, members: j.approximate_member_count, online: j.approximate_presence_count, name: j.guild && j.guild.name }))
      .catch(err => { console.warn('[BS] Discord indisponible :', err); return demo; });
    return discordP;
  }

  // ---------- activité Discord (bot à venir) ----------
  function demoActivity() {
    const r = rng(777);
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const days = Array.from({ length: 90 }, (_, i) => {
      const d = new Date(today); d.setDate(d.getDate() - (89 - i));
      const dow = d.getDay();
      const wk = dow === 5 || dow === 6 ? 1.5 : dow === 0 ? 1.2 : dow === 3 ? 1.15 : 1;
      return { date: d, value: Math.round((150 + i * 1.2) * wk * (0.75 + r() * 0.5)) };
    });
    const online24h = Array.from({ length: 24 }, (_, h) => {
      const c = h < 7 ? 4 + (7 - h) * 0.5 : h < 12 ? 8 + (h - 7) * 2 : h < 18 ? 16 + (h - 12) * 1.5 : h < 23 ? 34 + (h - 18) * 3 : 30;
      return { hour: h, value: Math.round(c * (0.85 + r() * 0.3)) };
    });
    return { demo: true, days, online24h, newMembers30d: 9 };
  }
  function loadActivity() {
    if (!C.discordActivityUrl) return Promise.resolve(demoActivity());
    return fetch(C.discordActivityUrl, { cache: 'no-store' }).then(r => r.json())
      .then(j => ({ demo: false, days: j.days.map(d => ({ date: new Date(d.date), value: d.value })), online24h: j.online24h, newMembers30d: j.newMembers30d }))
      .catch(() => demoActivity());
  }

  // ---------- planning (data/evenements.js) ----------
  function events() {
    const E = window.BS_EVENTS || { demo: true, events: [] };
    return { demo: !!E.demo, list: E.events.map(e => ({ ...e, date: new Date(e.date) })).sort((a, b) => a.date - b.date) };
  }

  // ---------- carte live ----------
  const airfields = [
    ['Batumi', 'UGSB', 41.6103, 41.5997], ['Kobuleti', 'UG5X', 41.9296, 41.8642], ['Senaki-Kolkhi', 'UGKS', 42.2387, 42.0613],
    ['Kutaisi', 'UGKO', 42.1764, 42.4826], ['Sukhumi', 'UGSS', 42.8582, 41.1281], ['Gudauta', 'UG23', 43.1010, 40.5800],
    ['Sochi-Adler', 'URSS', 43.4499, 39.9566], ['Maykop', 'URKH', 44.6713, 40.0219], ['Krasnodar-Centre', 'URKI', 45.0847, 38.9259],
    ['Krasnodar-Pashkovsky', 'URKK', 45.0347, 39.1705], ['Krymsk', 'URKW', 44.9614, 37.9846], ['Anapa', 'URKA', 45.0021, 37.3473],
    ['Gelendzhik', 'URKG', 44.5675, 38.0040], ['Mineralnye Vody', 'URMM', 44.2251, 43.0819], ['Nalchik', 'URMN', 43.5129, 43.6366],
    ['Mozdok', 'XRMF', 43.7897, 44.6000], ['Beslan', 'URMO', 43.2051, 44.6066], ['Vaziani', 'UG27', 41.6290, 45.0270],
    ['Tbilissi-Lochini', 'UGTB', 41.6692, 44.9547]
  ].map(([name, icao, lat, lon]) => ({ name, icao, lat, lon }));

  function demoLive() {
    return {
      demo: true,
      weather: { wind: '240° / 12 kt', visibility: '10 km +', clouds: 'FEW 4 500 ft', temp: '14 °C', qnh: '1013 hPa · 29.92 inHg' },
      players: [
        { callsign: 'Branch', aircraft: 'F/A-18C', air: true, lat: 42.42, lon: 42.10, hdg: 72, alt: 18500, spd: 420 },
        { callsign: 'Breakdown', aircraft: 'F/A-18C', air: true, lat: 42.30, lon: 41.75, hdg: 64, alt: 19200, spd: 428 },
        { callsign: 'Smokey', aircraft: 'F-16C', air: true, lat: 43.05, lon: 43.30, hdg: 118, alt: 24000, spd: 465 },
        { callsign: 'Mistral', aircraft: 'M-2000C', air: true, lat: 43.32, lon: 43.85, hdg: 140, alt: 21000, spd: 450 },
        { callsign: 'Fennec', aircraft: 'A-10C II', air: true, lat: 42.62, lon: 43.55, hdg: 25, alt: 9500, spd: 290 },
        { callsign: 'Gerfaut', aircraft: 'AH-64D', air: true, lat: 42.25, lon: 42.75, hdg: 95, alt: 400, spd: 120 },
        { callsign: 'Hermine', aircraft: 'F-14B', air: true, lat: 42.05, lon: 40.90, hdg: 40, alt: 26000, spd: 480 },
        { callsign: 'Corsaire', aircraft: 'F-15E', air: true, lat: 41.85, lon: 44.40, hdg: 300, alt: 22500, spd: 455 },
        { callsign: 'Nimbus', aircraft: 'F/A-18C', air: false, lat: 42.2387, lon: 42.0613, hdg: 90, alt: 43, spd: 0, base: 'Senaki-Kolkhi' },
        { callsign: 'Lynx', aircraft: 'F-16C', air: false, lat: 42.1764, lon: 42.4826, hdg: 70, alt: 148, spd: 0, base: 'Kutaisi' },
        { callsign: 'Cirrus', aircraft: 'Mirage F1', air: false, lat: 41.6103, lon: 41.5997, hdg: 130, alt: 10, spd: 0, base: 'Batumi' }
      ]
    };
  }
  // Format attendu de liveUrl : { time, weather:{...}, players:[{callsign, aircraft, air, lat, lon, hdg, alt(ft), spd(kt), base}] }
  function loadLive() {
    if (!C.liveUrl) return Promise.resolve(demoLive());
    return fetch(C.liveUrl, { cache: 'no-store' }).then(r => r.json()).then(j => ({ demo: false, ...j }))
      .catch(err => { console.warn('[BS] live indisponible :', err); return { ...demoLive(), error: String(err) }; });
  }

  const demoBadge = (txt = 'Démo') => '<span class="demo-badge" title="Source pas encore branchée : données d\'exemple">' + esc(txt) + '</span>';

  // Affiche un nombre (compteur animé si motion.js est chargé)
  const num = (el, n, opts) => window.BSMotion ? window.BSMotion.count(el, n, opts) : (el.textContent = fmt.n(n));

  window.BS = { C, num, GRADES, gradeFor, insignia, esc, fmt, loadStats, loadDiscord, loadActivity, events, airfields, loadLive, demoBadge };
})();
