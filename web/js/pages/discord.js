(function () {
  const { esc, fmt, loadDiscord, loadActivity, events, demoBadge } = window.BS;
  const $ = id => document.getElementById(id);
  let A = null, D = null, period = 30, hover = null;

  const fmtD = d => d.toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short' });

  function renderKpis() {
    if (!A || !D) return;
    const days = A.days, today = days[days.length - 1].value;
    const avg = arr => Math.round(arr.reduce((s, a) => s + a.value, 0) / Math.max(1, arr.length));
    const avg30 = avg(days.slice(-30)), prev30 = avg(days.slice(-60, -30));
    const delta = prev30 ? Math.round((avg30 / prev30 - 1) * 100) : 0;
    const badge = A.demo ? ' ' + demoBadge() : '';
    const kpis = [
      ['Membres', D.members, !A.demo && A.newMembers30d != null ? '+' + A.newMembers30d + ' ce mois-ci' : 'Discord · temps réel', '#0b7d75', false, D.demo],
      ['En ligne', D.online, Math.round(D.online / D.members * 100) + ' % des membres', '#4a556b', true, D.demo],
      ["Messages aujourd'hui", fmt.n(today), 'Depuis minuit', '#4a556b', true, A.demo],
      ['Moyenne / jour', fmt.n(avg30), (delta >= 0 ? '+' : '') + delta + ' % vs 30 j précédents', delta >= 0 ? '#0b7d75' : '#d0342c', false, A.demo]
    ];
    $('kpis').innerHTML = kpis.map(([l, v, note, col, live, demo]) => `
      <div class="card kpi">
        <span class="label" style="display:flex; align-items:center; gap:8px">${live ? '<span class="dot"></span>' : ''}${l}${demo ? ' ' + demoBadge() : ''}</span>
        <b style="font-size:56px">${v}</b><small style="color:${col}">${note}</small>
      </div>`).join('');
    $('actLabel').innerHTML = 'Activité du serveur' + badge;
  }

  function renderChart() {
    const days = A.days, slice = days.slice(-period);
    const top = Math.ceil(Math.max(...slice.map(a => a.value)) / 100) * 100 || 100;
    $('periods').innerHTML = [7, 30, 90].map(p => `<button data-p="${p}"${p === period ? ' class="on"' : ''}>${p} j</button>`).join('');
    $('axis').innerHTML = `<span>${fmt.n(top)}</span><span>${fmt.n(top / 2)}</span><span>0</span>`;
    $('bars').style.gap = period > 60 ? '1px' : period > 20 ? '3px' : '8px';
    $('bars').innerHTML = slice.map((a, i) => {
      const last = i === slice.length - 1, wk = [5, 6].includes(a.date.getDay());
      const c = hover === i ? '#13213a' : last ? '#2a5ca8' : wk ? '#9fb6d8' : '#c9d6ea';
      return `<div data-i="${i}"><i style="height:${(a.value / top * 100).toFixed(1)}%; background:${c}"></i></div>`;
    }).join('');
    const tip = $('tip');
    if (hover != null && slice[hover]) {
      tip.hidden = false;
      tip.style.left = ((hover + 0.5) / slice.length * 100) + '%';
      tip.innerHTML = `<span class="mono" style="font-size:11px; color:#9aa6ba">${fmtD(slice[hover].date)}</span><span style="font-weight:600; font-size:15px">${fmt.n(slice[hover].value)} messages</span>`;
    } else tip.hidden = true;
    $('xlabels').innerHTML = Array.from({ length: 5 }, (_, k) => {
      const idx = Math.round(k * (slice.length - 1) / 4);
      return '<span>' + (idx === slice.length - 1 ? "Aujourd'hui" : slice[idx].date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })) + '</span>';
    }).join('');
    const total = slice.reduce((s, a) => s + a.value, 0);
    const pk = slice.reduce((m, a) => a.value > m.value ? a : m, slice[0]);
    const dowS = Array(7).fill(0), dowN = Array(7).fill(0);
    days.forEach(a => { dowS[a.date.getDay()] += a.value; dowN[a.date.getDay()]++; });
    const best = dowS.map((s, i) => s / (dowN[i] || 1)).reduce((b, v, i, arr) => v > arr[b] ? i : b, 0);
    const dows = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    $('summary').innerHTML = [
      ['Total sur ' + period + ' jours', fmt.n(total) + ' messages'], ['Pic', fmt.n(pk.value) + ' · ' + fmtD(pk.date)], ['Jour le plus actif', dows[best]]
    ].map(([l, v]) => `<div style="display:flex; flex-direction:column; gap:4px"><span class="label" style="letter-spacing:.1em">${l}</span><span style="font-size:17px; font-weight:600">${v}</span></div>`).join('');
  }

  function renderHours() {
    const h24 = A.online24h, max = Math.max(...h24.map(h => h.value)) || 1, cur = new Date().getHours();
    $('hours').innerHTML = h24.map(h => `<div title="${String(h.hour).padStart(2, '0')} h · ${h.value} en ligne" style="flex:1; min-height:3px; border-radius:3px 3px 0 0; height:${(h.value / max * 100).toFixed(1)}%; background:${h.hour === cur ? '#2a5ca8' : h.hour >= 20 && h.hour <= 23 ? '#9fb6d8' : '#c9d6ea'}"></div>`).join('');
    const pk = h24.reduce((m, h) => h.value > m.value ? h : m, h24[0]);
    $('peak').textContent = 'Pic : ' + pk.value + ' à ' + String(pk.hour).padStart(2, '0') + ' h';
  }

  $('periods').addEventListener('click', e => { const b = e.target.closest('[data-p]'); if (b) { period = Number(b.dataset.p); hover = null; renderChart(); } });
  $('bars').addEventListener('mouseover', e => { const b = e.target.closest('[data-i]'); if (b && Number(b.dataset.i) !== hover) { hover = Number(b.dataset.i); renderChart(); } });
  $('chart').addEventListener('mouseleave', () => { hover = null; renderChart(); });

  loadDiscord().then(d => { D = d; $('cMembers').textContent = d.members; $('cOnline').textContent = d.online; renderKpis(); });
  loadActivity().then(a => { A = a; renderKpis(); renderChart(); renderHours(); });

  // ---------- planning ----------
  const ev = events();
  if (ev.demo) $('evNote').innerHTML = demoBadge('Exemple') + ' Planning à remplir dans data/evenements.js';
  function renderEvents() {
    const now = Date.now();
    const list = ev.list.filter(e => e.date.getTime() > now - 3 * 3600e3);
    $('events').innerHTML = list.map(e => {
      const full = e.registered >= e.slots;
      const days = Math.ceil((e.date.getTime() - now) / 86400000);
      return `<div class="card event">
        <div class="date"><span class="mono" style="font-size:11px; letter-spacing:.1em; text-transform:uppercase; color:#2a5ca8">${fmt.dayShort(e.date)}</span><b>${e.date.getDate()}</b><span class="mono" style="font-size:11px; text-transform:uppercase; color:#4a556b">${fmt.month(e.date)}</span></div>
        <div style="flex:1 1 280px; display:flex; flex-direction:column; gap:8px; min-width:0">
          <div style="display:flex; flex-wrap:wrap; align-items:center; gap:8px"><span class="kind">${esc(e.type)}</span><span class="mono" style="font-size:12px; color:#8a91a3">${fmt.hour(e.date)} · ${esc(e.map)} · par ${esc(e.host)}</span></div>
          <span style="font-size:19px; font-weight:600">${esc(e.title)}</span>
        </div>
        <div style="flex:0 1 200px; display:flex; flex-direction:column; gap:8px; min-width:160px">
          <div class="mono" style="display:flex; justify-content:space-between; font-size:12px; color:#4a556b"><span>${e.registered} / ${e.slots} pilotes</span><span>${days <= 0 ? "Aujourd'hui" : days === 1 ? 'Demain' : 'Dans ' + days + ' j'}</span></div>
          <div class="bar"><div style="width:${Math.min(100, Math.round(e.registered / e.slots * 100))}%; background:${full ? '#d0342c' : '#2a5ca8'}"></div></div>
        </div>
        ${full ? '<span class="btn muted">Complet</span>' : '<a class="btn outline" href="https://discord.gg/zVEsRbm8h2" target="_blank" rel="noopener">S\'inscrire</a>'}
      </div>`;
    }).join('') || '<div class="card empty">Aucun vol prévu pour le moment. Les annonces arrivent sur le Discord.</div>';
    const ne = list[0];
    $('nTitle').textContent = ne ? ne.title : 'Rien de prévu';
    $('nWhen').textContent = ne ? fmt.dateLong(ne.date) + ' · ' + fmt.hour(ne.date) + ' · ' + ne.map : '';
  }
  function tick() {
    const ne = ev.list.find(e => e.date.getTime() > Date.now() - 3 * 3600e3);
    $('nCount').textContent = ne ? fmt.countdown(ne.date.getTime() - Date.now()) : '—';
  }
  renderEvents(); tick();
  setInterval(tick, 1000);
  setInterval(renderEvents, 60000);
})();
