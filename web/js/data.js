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
    missionClock: t => { const d = new Date(t + 6 * 3600e3 + 17 * 60e3); return pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds()); },
    hms: s => { s = Math.floor(s) % 86400; return pad(Math.floor(s / 3600)) + ':' + pad(Math.floor(s % 3600 / 60)) + ':' + pad(s % 60); },
    // Heure in-game : réelle si le serveur l'envoie (t0 = { t: secondes depuis minuit, at }), horloge fictive en démo, sinon rien
    gameClock: (t0, demo) => t0 ? fmt.hms(t0.t + (Date.now() - t0.at) / 1000) : demo ? fmt.missionClock(Date.now()) : '--:--:--'
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
      // ancien format (sans heures totales) : on se rabat sur le vol le plus long
      hours: (r.totalFlightTime != null ? n('totalFlightTime') : n('maxFlightTime')) / 3600, completedHours: n('completedFlightTime') / 3600,
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

  // Regroupe les pseudos d'une même personne (C.pilotAliases) et retire les pseudos génériques (C.ignorePilots)
  function mergePilots(list) {
    const alias = {};
    Object.entries(C.pilotAliases || {}).forEach(([cs, names]) => names.concat(cs).forEach(n => (alias[n.toLowerCase()] = cs)));
    const ignore = new Set((C.ignorePilots || []).map(n => n.toLowerCase()));
    const out = new Map();
    list.forEach(p => {
      if (p.name == null || p.name === '' || ignore.has(String(p.name).toLowerCase())) return;
      const cs = alias[String(p.name).toLowerCase()] || String(p.name);
      const cur = out.get(cs);
      if (!cur) { out.set(cs, { ...p, name: cs }); return; }
      Object.entries(p).forEach(([k, v]) => {
        if (typeof v !== 'number') { if (cur[k] == null || cur[k] === 'ROOKIE') cur[k] = v; return; }
        cur[k] = k === 'maxFlightTime' ? Math.max(cur[k] || 0, v) : (cur[k] || 0) + v;
      });
    });
    return [...out.values()].map(normPilot);
  }

  // Instantané Scores.lua converti par tools/scores_to_json.py
  function statsFromFile() {
    if (!C.statsFile) return Promise.resolve(demoStats());
    return fetch(C.statsFile, { cache: 'no-store' })
      .then(res => { if (!res.ok) throw new Error('HTTP ' + res.status); return res.json(); })
      .then(d => ({
        demo: false, source: 'file',
        legacy: !(d.pilots || []).some(p => p.totalFlightTime != null),
        pilots: mergePilots(d.pilots || []),
        server: { updated: d.updated ? new Date(d.updated) : null, name: C.serverName, mission: '', online: [] },
        changelog: []
      }))
      .catch(err => { console.warn('[BS] stats.json indisponible, démo affichée :', err); return { ...demoStats(), error: String(err) }; });
  }

  // Relais Apps Script (circuit_site/Code.gs), alimenté par le bot Discord : une seule requête pour stats + Discord
  const relayUrl = fmtName => C.statsUrl + (C.statsUrl.includes('?') ? '&' : '?') + 'format=' + fmtName;
  const getJson = url => fetch(url, { cache: 'no-store' }).then(res => { if (!res.ok) throw new Error('HTTP ' + res.status); return res.json(); });
  let relayP = null;
  const relay = () => relayP || (relayP = C.statsUrl ? getJson(relayUrl('json')) : Promise.reject(new Error('statsUrl vide')));
  // Données Discord exportées par le bot : relais, sinon fichier discordFile, sinon null
  let discordDataP = null;
  const discordData = () => discordDataP || (discordDataP = relay().then(d => d.discord || Promise.reject(new Error('pas de données Discord')))
    .catch(() => C.discordFile ? getJson(C.discordFile) : null)
    .catch(err => { console.warn('[BS] données Discord du bot indisponibles :', err); return null; }));

  let statsP = null;
  function loadStats() {
    if (statsP) return statsP;
    if (!C.statsUrl) return (statsP = statsFromFile());
    statsP = relay()
      .then(d => {
        const s = d.server || {};
        const upd = s['Derniere mise a jour'] ? new Date(s['Derniere mise a jour']) : null;
        return {
          demo: false,
          pilots: mergePilots(d.pilots || []),
          server: { updated: upd, name: s['Serveur'] || C.serverName, mission: s['Mission'] || '', online: String(s['En ligne'] || '').split(',').map(x => x.trim()).filter(Boolean) },
          changelog: (d.changelog || []).map(c => ({ ...c, date: new Date(c.date) }))
        };
      })
      .catch(err => { console.warn('[BS] Apps Script indisponible, on lit stats.json :', err); return statsFromFile(); });
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
    return { demo: true, days, online24h, newMembers30d: 9, voice: demoVoice(days) };
  }
  // Minutes en vocal par jour (exemple) : surtout le soir des vols, le week-end
  function demoVoice(days) {
    const r = rng(4242);
    return { demo: true, since: null, days: days.map(a => {
      const dow = a.date.getDay(), wk = dow === 5 || dow === 6 ? 2.2 : dow === 0 ? 1.6 : 1;
      return { date: a.date, value: Math.round(240 * wk * (0.4 + r() * 0.9)) };
    }) };
  }
  // Format (bot, plugin bluesky) : { since, days:[{date:'AAAA-MM-JJ', value}], online24h:[{hour, value}], newMembers30d,
  //   voiceSince, voice:[minutes en vocal, mêmes jours que days] }
  function loadActivity() {
    const src = C.discordActivityUrl ? getJson(C.discordActivityUrl) : discordData().then(d => d && d.activity);
    return src.then(j => {
      if (!j || !j.days) return demoActivity();
      const day = s => { const [y, m, dd] = s.slice(0, 10).split('-').map(Number); return new Date(y, m - 1, dd); };
      const days = j.days.map(d => ({ date: day(d.date), value: d.value }));
      const voice = Array.isArray(j.voice) && j.voice.length === days.length
        ? { demo: false, since: j.voiceSince ? day(j.voiceSince) : null, days: days.map((d, i) => ({ date: d.date, value: j.voice[i] || 0 })) }
        : demoVoice(days);
      return { demo: false, since: j.since ? day(j.since) : null, days, online24h: j.online24h, newMembers30d: j.newMembers30d, voice };
    }).catch(() => demoActivity());
  }

  // ---------- planning : événements Discord (via le bot), sinon data/evenements.js ----------
  // Un événement : { id, title, date, type, map, host, registered, slots (null = pas de limite), url,
  //   mission (briefing publié), signupUrl (sondage d'inscription), signups: { yes:[pseudos], maybe:[pseudos], no:nombre } }
  function events() {
    const E = window.BS_EVENTS || { demo: true, events: [] };
    return { demo: !!E.demo, source: 'file', list: E.events.map(e => ({ ...e, date: new Date(e.date) })).sort((a, b) => a.date - b.date) };
  }
  // Lieu de l'événement Discord : un lien (salon, site) n'est pas une carte → bouton à part
  const placeOf = e => /^https?:\/\//i.test(e.map || '') ? { map: '', link: e.link || e.map } : {};
  function loadEvents() {
    return discordData().then(d => d && Array.isArray(d.events)
      ? { demo: false, source: 'discord', signupChannel: d.signupChannel || C.signupChannel,
          list: d.events.map(e => ({ ...e, ...placeOf(e), date: new Date(e.date) })).sort((a, b) => a.date - b.date) }
      : events());
  }

  // Briefing d'une mission publiée depuis Discord : relais ?format=mission&id=…, sinon fichier missionsFile
  function loadMission(id) {
    if (!/^\d+$/.test(String(id || ''))) return Promise.resolve(null);
    const fromFile = () => C.missionsFile ? getJson(C.missionsFile).then(j => (j.missions || []).find(m => m.id === String(id)) || null) : null;
    return (C.statsUrl ? getJson(relayUrl('mission') + '&id=' + encodeURIComponent(id)).then(m => m && !m.error ? m : fromFile()) : Promise.resolve(fromFile()))
      .then(m => m && { ...m, date: new Date(m.date) })
      .catch(err => { console.warn('[BS] mission indisponible :', err); return null; });
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
  // Format (bot, plugin bluesky) : { time (ISO), missionTime (s), weather?:{...}, players:[{callsign, aircraft, air, lat, lon, hdg, alt(ft), spd(kt), base}] }
  // liveUrl, sinon relais ?format=live, sinon fichier liveFile. Données de plus de 3 min => serveur hors ligne.
  function loadLive() {
    const url = C.liveUrl || (C.statsUrl ? relayUrl('live') : C.liveFile);
    if (!url) return Promise.resolve(demoLive());
    return getJson(url).then(j => {
      const age = j.time ? Date.now() - new Date(j.time).getTime() : Infinity;
      return age > 180e3 ? { demo: false, offline: true, players: [] } : { demo: false, ...j };
    }).catch(err => { console.warn('[BS] live indisponible :', err); return { ...demoLive(), error: String(err) }; });
  }

  // État du serveur DCS d'après le live du bot (relevé toutes les 30 s) : { demo, up, online:[pseudos], mission }
  // up = mission qui tourne ; « en ligne » (point vert) seulement s'il y a au moins un joueur connecté.
  let serverP = null;
  function loadServer() {
    return serverP || (serverP = loadLive().then(l => {
      if (l.error || l.offline) return { demo: false, up: false, online: [], mission: '', clock: null };
      const online = (l.online || (l.players || []).map(p => p.callsign)).filter(Boolean);
      const clock = l.missionTime != null ? { t: l.missionTime, at: Date.now() } : null;
      return { demo: !!l.demo, up: true, online, mission: l.mission || '', clock };
    }));
  }
  const serverLabel = srv => !srv.up ? 'Serveur · hors ligne' : srv.online.length ? 'Serveur · ' + srv.online.length + ' en ligne' : 'Serveur · personne en ligne';

  // ---------- l'équipe : rôles fixes du Discord Blue Sky (exportés par le bot), sinon C.staff ----------
  // Un membre : { name, role, color (#rrggbb ou null), sub? }
  function loadStaff() {
    const fromConfig = () => ({ source: 'config', list: (C.staff || []).map(m => ({ name: m.callsign, sub: m.name, role: m.role, color: m.roleColor || null })) });
    const hidden = (C.staffHidden || []).map(n => n.toLowerCase());
    return discordData().then(d => d && Array.isArray(d.staff) && d.staff.length
      ? { source: 'discord', list: d.staff.filter(m => !hidden.some(h => m.name.toLowerCase().includes(h))).map(m => {
          // pseudo Discord « Breakdown | Thibaud » : on reprend l'indicatif et le prénom de C.staff s'il correspond
          const known = (C.staff || []).find(s => [s.discord, s.callsign, s.pseudo, s.name].filter(Boolean).some(n => m.name.toLowerCase().includes(n.toLowerCase())));
          return { name: known ? known.callsign : m.name, sub: known ? known.name : null, role: m.role, color: m.color };
        }) }
      : fromConfig()).catch(fromConfig);
  }
  // Pastille du rôle : initiale du rôle sur la couleur du rôle Discord
  // Icône du rôle : C.roleIcons (« CAG » → =✪=), sinon le premier émoji du nom du rôle, sinon son initiale
  const EMOJI = /\p{Extended_Pictographic}/u;
  const roleIcon = role => {
    const r = String(role || '');
    const rule = (C.roleIcons || []).find(x => r.toLowerCase().includes(String(x.match).toLowerCase()));
    if (rule) return rule.icon;
    const em = r.match(EMOJI);
    return em ? em[0] : (r.replace(/[^\p{L}\p{N}]/gu, '').charAt(0) || '?').toUpperCase();
  };
  // Nom du rôle sans décorations Discord : « =✪=Blue Sky CAG=✪= » → « Blue Sky CAG », « 📡~AWACS~📡 » → « AWACS »
  const roleLabel = role => String(role || '').replace(/[\p{Extended_Pictographic}️‍]/gu, '')
    .replace(/^[\s=~✪★•|_\-]+|[\s=~✪★•|_\-]+$/g, '').trim() || String(role || '');
  const roleBadge = m => {
    const icon = roleIcon(m.role);
    const cls = EMOJI.test(icon) ? ' emoji' : [...icon].length > 1 ? ' small' : '';
    return '<span class="role-badge' + cls + '" title="' + esc(m.role) + '" style="--rc:' + esc(m.color || '#d9b45a') + '">' + esc(icon) + '</span>';
  };

  const demoBadge = (txt = 'Démo') => '<span class="demo-badge" title="Source pas encore branchée : données d\'exemple">' + esc(txt) + '</span>';

  // Affiche un nombre (compteur animé si motion.js est chargé)
  const num = (el, n, opts) => window.BSMotion ? window.BSMotion.count(el, n, opts) : (el.textContent = fmt.n(n));

  window.BS = { C, num, GRADES, gradeFor, insignia, esc, fmt, loadStats, loadDiscord, loadActivity, events, loadEvents, loadMission, airfields, loadLive, loadServer, serverLabel, loadStaff, roleBadge, roleLabel, demoBadge };
})();
