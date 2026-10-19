(function () {
  const { C, esc, fmt, insignia, GRADES, loadStats, demoBadge } = window.BS;
  const $ = id => document.getElementById(id);

  const METRICS = [
    { id: 'points', label: 'Points', unit: 'points' },
    { id: 'hours', label: 'Heures de vol', unit: 'heures' },
    { id: 'airKills', label: 'Kills air', unit: 'kills air' },
    { id: 'groundKills', label: 'Kills sol', unit: 'kills sol' },
    { id: 'traps', label: 'Appontages', unit: 'appontages' }
  ];
  const COLS = [['hours', 'Heures'], ['airKills', 'Kills air'], ['groundKills', 'Kills sol'], ['traps', 'Appont.'], ['deaths', 'Morts'], ['points', 'Points']];
  const val = (p, m) => m === 'hours' ? fmt.h1(p.hours) + ' h' : fmt.n(p[m]);
  const num = (p, m) => m === 'hours' ? fmt.h1(p.hours) : fmt.n(p[m]);

  const params = new URLSearchParams(location.search);
  let S = null, metric = METRICS.some(m => m.id === params.get('tri')) ? params.get('tri') : 'points', q = '';

  // animate : le tri a changé → les lignes glissent vers leur nouvelle place
  function render(animate) {
    if (animate && window.BSMotion) {
      BSMotion.flip('#table .tr.row', 'data-id', () => render(false));
      BSMotion.replay($('podium'), 'podium-swap');
      return;
    }
    const ranked = [...S.pilots].sort((a, b) => b[metric] - a[metric] || b.points - a.points);
    const unit = METRICS.find(m => m.id === metric).unit;

    $('metrics').innerHTML = METRICS.map(m => `<button data-m="${m.id}"${m.id === metric ? ' class="on"' : ''}>${m.label}</button>`).join('');

    $('podium').innerHTML = ranked.slice(0, 3).map((p, i) => `
      <button class="podium${i === 0 ? ' first' : ''}" data-id="${p.id}">
        <span class="rk" style="color:${['#5fe3d6', '#2a5ca8', '#d0342c'][i]}">${i + 1}</span>
        <span style="display:flex; flex-direction:column; gap:4px; flex:1; min-width:0"><span class="cs">${esc(p.callsign)}</span><span style="font-size:13px; opacity:.75">${esc(p.grade.name)}</span></span>
        <span style="display:flex; flex-direction:column; align-items:flex-end; gap:2px">
          <span class="mono" style="font-size:20px; font-weight:600">${val(p, metric)}</span>
          <span class="mono" style="font-size:10px; letter-spacing:.12em; text-transform:uppercase; opacity:.6">${unit}</span>
        </span>
      </button>`).join('');

    const ql = q.trim().toLowerCase();
    const rows = ranked.map((p, i) => ({ p, rank: i + 1 })).filter(({ p }) => !ql || p.callsign.toLowerCase().includes(ql));
    $('table').innerHTML = `
      <div class="tr th"><span>#</span><span>Pilote</span><span>Grade</span>
        ${COLS.map(([k, l]) => k === 'deaths' ? `<span style="text-align:right">${l}</span>` : `<button data-m="${k}"${k === metric ? ' class="on"' : ''}>${l}</button>`).join('')}
      </div>
      ${rows.map(({ p, rank }) => `
        <div class="tr row" data-id="${p.id}" tabindex="0">
          <span class="rank">${rank}</span>
          <span class="who"><b>${esc(p.callsign)}</b><small>${fmt.n(p.flights)} vol${p.flights > 1 ? 's' : ''}</small></span>
          <span class="gr">${insignia(p.grade, 'xs')}<span>${esc(p.grade.name)}</span></span>
          ${COLS.map(([k]) => `<span class="n${k === metric ? ' on' : ''}">${num(p, k)}</span>`).join('')}
        </div>`).join('')}
      ${rows.length ? '' : `<div class="empty">${S.pilots.length ? 'Aucun pilote ne correspond à « ' + esc(q) + ' ».' : 'Aucun pilote classé pour le moment.'}</div>`}`;
  }

  function renderStatic() {
    const sum = k => S.pilots.reduce((a, p) => a + p[k], 0);
    const totals = [
      ['Heures de vol cumulées', fmt.n(Math.round(sum('hours')))],
      ['Kills air', fmt.n(sum('airKills'))],
      ['Kills sol & mer', fmt.n(sum('groundKills') + sum('navalKills'))],
      ['Appontages', fmt.n(sum('traps'))],
      ['Pilotes classés', S.pilots.length]
    ];
    $('totals').innerHTML = totals.map(([l, v]) => `<div class="card kpi"><span class="label">${l}</span><b data-count="${String(v).replace(/\D/g, '')}">${v}</b></div>`).join('');

    $('grades').innerHTML = GRADES.map(g => `
      <div class="card grade-card">${insignia(g, 'md')}
        <span style="flex:1; min-width:0"><b>${esc(g.name)}</b><span class="mono" style="font-size:12px; color:#8a91a3">dès ${fmt.n(g.min)} pts</span></span>
        <span class="cnt">${S.pilots.filter(p => p.grade === g).length}</span>
      </div>`).join('');

    const st = $('status');
    const upd = S.server.updated;
    st.innerHTML = (S.demo ? demoBadge() : '<span class="dot"></span>') + ' Dernier export · ' + (upd ? fmt.ago(upd) : '—');
    if (S.error) st.title = 'Stats injoignables : ' + S.error;
    if (S.legacy) st.innerHTML += ' · ancien format : heures = vol le plus long';
    if (S.server.mission) $('srvLabel').textContent = 'Serveur ' + S.server.mission;

    if (S.changelog.length) {
      $('logSec').hidden = false;
      $('log').innerHTML = S.changelog.slice(0, 8).map(c => `
        <div><span class="mono" style="color:#8a91a3">${isNaN(c.date) ? '' : fmt.dateShort(c.date)}</span><span class="mono" style="font-weight:600">${esc(c.version)}</span><span style="color:#4a556b">${esc(c.notes)}</span></div>`).join('');
    }
  }

  // ---------- fiche pilote ----------
  function openPilot(id) {
    const p = S.pilots.find(x => x.id === id);
    if (!p) return;
    const byPts = [...S.pilots].sort((a, b) => b.points - a.points);
    const g = p.grade, nx = g.next;
    const progress = nx ? Math.round((p.points - g.min) / (nx.min - g.min) * 100) : 100;
    const role = C.staff.find(m => (m.pseudo || m.callsign).toLowerCase() === p.callsign.toLowerCase());
    const stats = [
      ['Points', fmt.n(p.points)], ['Heures', fmt.h1(p.hours)], ['Vols', fmt.n(p.flights)],
      ['Kills air', p.airKills], ['Kills sol', p.groundKills], ['Kills mer', p.navalKills],
      ['Appontages', p.traps], ['Morts', p.deaths], ['Teamkills', p.teamkills]
    ];
    const details = [
      ['Heures complètes (atterri)', fmt.h1(p.completedHours) + ' h'],
      ['Vol le plus long', fmt.dur(p.longest)],
      ['Temps au ravitaillement', fmt.dur(p.refuel)],
      ['Niveau des bots (F10)', p.level || '—']
    ];
    $('drawerRoot').innerHTML = `
      <div class="overlay" data-close></div>
      <aside class="drawer" role="dialog" aria-label="Fiche pilote ${esc(p.callsign)}">
        <div class="drawer-head">
          <div style="display:flex; justify-content:space-between; align-items:center">
            <span class="label" style="color:#9aa6ba">Fiche pilote · #${byPts.indexOf(p) + 1} aux points</span>
            <button class="xbtn" data-close aria-label="Fermer">✕</button>
          </div>
          <div style="display:flex; align-items:center; gap:18px">
            ${insignia(g, 'xl')}
            <span style="display:flex; flex-direction:column; gap:4px; min-width:0">
              <span class="cs">${esc(p.callsign)}</span>
              <span style="font-size:14px; color:#c9d1de">${esc(g.name)}${role ? ' · ' + esc(role.role) : ''}</span>
            </span>
          </div>
          <div style="display:flex; flex-direction:column; gap:8px">
            <div class="mono" style="display:flex; justify-content:space-between; font-size:12px; color:#c9d1de">
              <span>${fmt.n(p.points)} pts</span><span>${nx ? fmt.n(nx.min - p.points) + ' pts avant ' + esc(nx.name) : 'Grade maximum'}</span>
            </div>
            <div class="bar dark"><div style="width:${progress}%; background:#5fe3d6"></div></div>
          </div>
        </div>
        <div style="padding:24px 28px 40px; display:flex; flex-direction:column; gap:28px">
          <div class="stat-grid">${stats.map(([l, v]) => `<div><span class="label">${l}</span><b>${v}</b></div>`).join('')}</div>
          <div class="rows">${details.map(([l, v]) => `<div><span style="color:#4a556b">${l}</span><span class="mono" style="font-weight:600">${esc(v)}</span></div>`).join('')}</div>
        </div>
      </aside>`;
    document.body.style.overflow = 'hidden';
    $('drawerRoot').querySelector('.xbtn').focus();
  }
  function closePilot() {
    const r = $('drawerRoot');
    if (!r.firstChild || r.classList.contains('closing')) return;
    const end = () => { r.innerHTML = ''; r.classList.remove('closing'); document.body.style.overflow = ''; };
    if (window.BSMotion && !BSMotion.reduced) { r.classList.add('closing'); setTimeout(end, 230); } else end();
  }

  document.addEventListener('click', e => {
    if (!S) return;
    const m = e.target.closest('[data-m]');
    if (m) { if (m.dataset.m !== metric) { metric = m.dataset.m; render(true); } return; }
    if (e.target.closest('[data-close]')) { closePilot(); return; }
    const r = e.target.closest('[data-id]');
    if (r) openPilot(Number(r.dataset.id));
  });
  document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closePilot();
    if (e.key === 'Enter' && e.target.matches('.tr.row')) openPilot(Number(e.target.dataset.id));
  });
  $('q').addEventListener('input', e => { q = e.target.value; if (S) render(); });

  loadStats().then(s => {
    S = s;
    renderStatic(); render();
    const pilot = params.get('pilote');
    if (pilot) { const p = s.pilots.find(x => x.callsign.toLowerCase() === pilot.toLowerCase()); if (p) openPilot(p.id); }
  });
})();
