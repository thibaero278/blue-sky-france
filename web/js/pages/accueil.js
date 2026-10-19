(function () {
  const { C, esc, fmt, num, insignia, gradeFor, loadStats, loadDiscord, events, demoBadge } = window.BS;
  const $ = id => document.getElementById(id);

  loadStats().then(s => {
    const byName = Object.fromEntries(s.pilots.map(p => [p.callsign.toLowerCase(), p]));
    $('staff').innerHTML = C.staff.map(m => {
      const p = byName[(m.pseudo || m.callsign).toLowerCase()];
      const g = p ? p.grade : gradeFor(0);
      return `<div class="staff">${insignia(g, 'lg')}<div style="min-width:0"><b>${esc(m.callsign)}</b><small>${esc(m.name ? m.name + ' · ' + m.role : m.role)}</small></div></div>`;
    }).join('');

    const online = s.server.online;
    $('heroOnline').textContent = online.length;
    num($('nowOnline'), online.length);
    if (s.server.mission) $('heroMission').textContent = s.server.mission;
    $('nowList').innerHTML = online.slice(0, 4).map(n => {
      const p = byName[n.toLowerCase()];
      return `<div><span style="font-weight:600">${esc(n)}</span><span class="mono" style="font-size:12px; color:#4a556b">${p ? esc(p.grade.name) : 'Nouveau pilote'}</span></div>`;
    }).join('') || '<div><span style="color:#8a91a3">Personne en ligne pour le moment</span></div>';
    const fresh = s.server.updated && Date.now() - s.server.updated.getTime() < 15 * 60e3;
    $('srvState').innerHTML = fresh ? '<span class="dot"></span>En ligne' : '<span class="dot off"></span>Hors ligne';
    $('srvState').style.color = fresh ? '#0b7d75' : '#8a91a3';
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

  const ev = events();
  if (ev.demo) $('nextDemo').innerHTML = demoBadge('Exemple');
  function tick() {
    const now = Date.now();
    $('heroClock').textContent = fmt.missionClock(now);
    const e = ev.list.find(x => x.date.getTime() > now - 3 * 3600e3) || ev.list[ev.list.length - 1];
    if (!e) { $('nextTitle').textContent = 'Rien de prévu'; return; }
    $('nextTitle').textContent = e.title;
    $('nextWhen').textContent = fmt.dateLong(e.date) + ' · ' + fmt.hour(e.date) + ' · ' + e.map;
    $('nextCount').textContent = fmt.countdown(e.date.getTime() - now);
    $('nextFill').style.width = Math.round(e.registered / e.slots * 100) + '%';
    $('nextReg').textContent = e.registered + ' / ' + e.slots + ' inscrits';
  }
  tick(); setInterval(tick, 1000);
})();
