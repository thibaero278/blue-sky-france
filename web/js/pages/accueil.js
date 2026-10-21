(function () {
  const { C, esc, fmt, num, loadStats, loadServer, loadStaff, roleBadge, roleLabel, loadDiscord, loadEvents, demoBadge } = window.BS;
  const $ = id => document.getElementById(id);

  // L'équipe : rôles fixes du Discord Blue Sky (pas les grades aux points du serveur DCS)
  // Couleur de rôle Discord trop claire sur fond clair (ex. #e7dcaf) → assombrie juste ce qu'il faut pour rester lisible
  // (couleur vive : luminance ramenée à 165, un jaune reste jaune au lieu de virer au kaki ; couleur terne : 120)
  const readable = c => {
    const m = /^#([0-9a-f]{6})$/i.exec(c || '');
    if (!m) return c || 'inherit';
    const n = parseInt(m[1], 16), r = n >> 16, g = n >> 8 & 255, b = n & 255;
    const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b, hi = Math.max(r, g, b);
    const target = hi && (hi - Math.min(r, g, b)) / hi > 0.6 ? 165 : 120, k = lum > target ? target / lum : 1;
    return 'rgb(' + [r, g, b].map(v => Math.round(v * k)).join(',') + ')';
  };
  function load() {
    loadStaff().then(st => {
      $('staff').innerHTML = st.list.map(m =>
        `<div class="staff">${roleBadge(m)}<div style="min-width:0"><b>${esc(m.name)}</b><small>${m.sub ? esc(m.sub) + ' · ' : ''}<span style="color:${esc(readable(m.color))}; font-weight:600">${esc(roleLabel(m.role))}</span></small></div></div>`
      ).join('');
    });

    loadStats().then(s => {
      const byName = Object.fromEntries(s.pilots.map(p => [p.callsign.toLowerCase(), p]));

      // Serveur : état réel d'après le live du bot (et non l'export des scores, qui ne bouge qu'aux atterrissages)
      loadServer().then(srv => {
        const online = srv.online;
        $('heroOnline').textContent = online.length;
        num($('nowOnline'), online.length);
        const mission = srv.mission || s.server.mission;
        if (mission) $('heroMission').textContent = mission;
        $('nowList').innerHTML = online.slice(0, 4).map(n => {
          const p = byName[n.toLowerCase()];
          return `<div><span style="font-weight:600">${esc(n)}</span><span class="mono" style="font-size:12px; color:#4a556b">${p ? esc(p.grade.name) : 'Nouveau pilote'}</span></div>`;
        }).join('') || `<div><span style="color:#8a91a3">${srv.up ? 'Personne en ligne pour le moment' : 'Serveur DCS éteint'}</span></div>`;
        const live = srv.online.length > 0;
        // « EN DIRECT » seulement avec des joueurs connectés
        $('heroBadge').innerHTML = live ? '<i></i>EN DIRECT' : srv.up ? 'SERVEUR VIDE' : 'HORS LIGNE';
        $('heroBadge').classList.toggle('off', !live);
        if (!srv.up) $('heroMission').textContent = 'Serveur DCS éteint';
        $('srvState').innerHTML = live ? '<span class="dot"></span>En ligne' : srv.up ? '<span class="dot off"></span>Personne en ligne' : '<span class="dot off"></span>Hors ligne';
        $('srvState').style.color = live ? '#0b7d75' : '#8a91a3';
      });
      $('lastExport').innerHTML = (s.demo ? demoBadge() + ' ' : '') + 'Export serveur ' + (s.server.updated ? fmt.ago(s.server.updated) : '—');

      $('top3').innerHTML = [...s.pilots].sort((a, b) => b.points - a.points).slice(0, 3).map((p, i) => `
        <div class="top3">
          <span class="display" style="font-weight:700; font-size:28px; width:20px; color:#2a5ca8">${i + 1}</span>
          <span style="display:flex; flex-direction:column; flex:1; min-width:0"><span style="font-weight:600; font-size:16px">${esc(p.callsign)}</span><span style="font-size:12px; color:#4a556b">${esc(p.grade.name)}</span></span>
          <span class="mono" style="font-size:14px; font-weight:600" data-count="${p.points}">${fmt.n(p.points)}</span>
        </div>`).join('');
      if (s.demo) $('top3Demo').innerHTML = demoBadge();
    });

    loadDiscord().then(d => {
      ['heroMembers', 'ctaMembers'].forEach(id => num($(id), d.members));
      ['heroDcOnline', 'ctaOnline'].forEach(id => num($(id), d.online));
    });

    loadServer().then(srv => { srvClock = srv.clock; srvDemo = srv.demo; });
    loadEvents().then(x => {
      ev = x;
      if (ev.demo) $('nextDemo').innerHTML = demoBadge('Exemple');
      tick();
    });
  }

  let srvClock = null, srvDemo = false;
  setInterval(() => ($('heroClock').textContent = fmt.gameClock(srvClock, srvDemo)), 1000);

  let ev = null;
  function tick() {
    if (!ev) return;
    const now = Date.now();
    const e = ev.list.find(x => x.date.getTime() > now - 3 * 3600e3) || ev.list[ev.list.length - 1];
    if (!e) { $('nextTitle').textContent = 'Rien de prévu'; return; }
    $('nextTitle').textContent = e.title;
    $('nextWhen').textContent = [fmt.dateLong(e.date), fmt.hour(e.date), e.map].filter(Boolean).join(' · ');
    $('nextCount').textContent = fmt.countdown(e.date.getTime() - now);
    $('nextFill').style.width = (e.slots ? Math.min(100, Math.round(e.registered / e.slots * 100)) : e.registered ? 100 : 0) + '%';
    $('nextReg').textContent = e.slots ? e.registered + ' / ' + e.slots + ' inscrits' : e.registered + ' intéressé' + (e.registered > 1 ? 's' : '') + ' sur Discord';
  }
  // Tout est relu à chaque rafraîchissement (toutes les 30 s, layout.js) : plus besoin de F5
  load();
  document.addEventListener('bs:refresh', load);
  setInterval(tick, 1000);
})();
