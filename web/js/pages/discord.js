(function () {
  const { esc, fmt, loadDiscord, loadActivity, demoBadge } = window.BS;
  const $ = id => document.getElementById(id);
  let A = null, D = null;

  const fmtD = d => d.toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short' });

  function renderKpis() {
    if (!A || !D) return;
    const days = A.days, today = days[days.length - 1].value;
    const avg = arr => Math.round(arr.reduce((s, a) => s + a.value, 0) / Math.max(1, arr.length));
    const avg30 = avg(days.slice(-30)), prev30 = avg(days.slice(-60, -30));
    const delta = prev30 ? Math.round((avg30 / prev30 - 1) * 100) : 0;
    const kpis = [
      ['Membres', D.members, !A.demo && A.newMembers30d != null ? '+' + A.newMembers30d + ' ce mois-ci' : 'Discord · temps réel', '#0b7d75', false, D.demo],
      ['En ligne', D.online, Math.round(D.online / D.members * 100) + ' % des membres', '#4a556b', true, D.demo],
      ["Messages aujourd'hui", today, 'Depuis minuit', '#4a556b', true, A.demo],
      ['Moyenne / jour', avg30, (delta >= 0 ? '+' : '') + delta + ' % vs 30 j précédents', delta >= 0 ? '#0b7d75' : '#d0342c', false, A.demo]
    ];
    $('kpis').innerHTML = kpis.map(([l, v, note, col, live, demo], i) => `
      <div class="card kpi">
        <span class="label" style="display:flex; align-items:center; gap:8px">${live ? '<span class="dot"></span>' : ''}${l}${demo ? ' ' + demoBadge() : ''}</span>
        <b style="font-size:56px" data-count="${v}" data-key="kpi-${i}">${fmt.n(v)}</b><small style="color:${col}">${note}</small>
      </div>`).join('');
    $('actLabel').innerHTML = 'Activité du serveur' + (A.demo ? ' ' + demoBadge() : '') +
      (!A.demo && A.since ? ' <span class="mono" style="font-size:11px; color:#8a91a3; text-transform:none; letter-spacing:0">· comptée par le bot depuis le ' + fmt.dateShort(A.since) + '</span>' : '');
  }

  // Les barres poussent depuis le bas la première fois qu'on les voit
  function growOnView(el) {
    if (!window.BSMotion || BSMotion.reduced) return;
    el.classList.add('pre');
    BSMotion.onVisible(el, () => { el.classList.remove('pre'); el.classList.add('grow'); }, 0.3);
  }

  // Graphique en barres par jour (messages, temps en vocal) : p = préfixe des id dans discord.html
  function barChart(p, opts) {
    const el = id => $(p + id);
    const st = { days: null, period: 30, hover: null };
    const color = (a, i, n) => st.hover === i ? '#13213a' : i === n - 1 ? '#2a5ca8' : [5, 6].includes(a.date.getDay()) ? '#9fb6d8' : '#c9d6ea';

    function render() {
      const days = st.days, slice = days.slice(-st.period);
      const top = opts.top(Math.max(...slice.map(a => a.value)));
      el('periods').querySelectorAll('button').forEach(b => b.classList.toggle('on', Number(b.dataset.p) === st.period));
      el('axis').innerHTML = `<span>${opts.axis(top)}</span><span>${opts.axis(top / 2)}</span><span>0</span>`;
      el('bars').style.gap = st.period > 60 ? '1px' : st.period > 20 ? '3px' : '8px';
      el('bars').innerHTML = slice.map((a, i) =>
        `<div data-i="${i}" style="--i:${i}"><i style="height:${(a.value / top * 100).toFixed(1)}%; background:${color(a, i, slice.length)}"></i></div>`).join('');
      renderHover();
      el('xlabels').innerHTML = Array.from({ length: 5 }, (_, k) => {
        const idx = Math.round(k * (slice.length - 1) / 4);
        return '<span>' + (idx === slice.length - 1 ? "Aujourd'hui" : slice[idx].date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })) + '</span>';
      }).join('');
      const total = slice.reduce((s, a) => s + a.value, 0);
      const pk = slice.reduce((m, a) => a.value > m.value ? a : m, slice[0]);
      const dowS = Array(7).fill(0), dowN = Array(7).fill(0);
      days.forEach(a => { dowS[a.date.getDay()] += a.value; dowN[a.date.getDay()]++; });
      const best = dowS.map((s, i) => s / (dowN[i] || 1)).reduce((b, v, i, arr) => v > arr[b] ? i : b, 0);
      const dows = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
      el('summary').innerHTML = [
        ['Total sur ' + st.period + ' jours', opts.total(total)], ['Pic', opts.value(pk.value) + ' · ' + fmtD(pk.date)], ['Jour le plus actif', dows[best]]
      ].map(([l, v]) => `<div style="display:flex; flex-direction:column; gap:4px"><span class="label" style="letter-spacing:.1em">${l}</span><span style="font-size:17px; font-weight:600">${v}</span></div>`).join('');
    }

    // Survol : on recolore les barres existantes au lieu de tout reconstruire
    function renderHover() {
      const slice = st.days.slice(-st.period), tip = el('tip');
      el('bars').querySelectorAll('i').forEach((b, i) => (b.style.background = color(slice[i], i, slice.length)));
      if (st.hover != null && slice[st.hover]) {
        tip.hidden = false;
        tip.style.left = ((st.hover + 0.5) / slice.length * 100) + '%';
        tip.innerHTML = `<span class="mono" style="font-size:11px; color:#9aa6ba">${fmtD(slice[st.hover].date)}</span><span style="font-weight:600; font-size:15px">${opts.value(slice[st.hover].value)}</span>`;
      } else tip.hidden = true;
    }

    el('periods').innerHTML = [7, 30, 90].map(n => `<button data-p="${n}"${n === st.period ? ' class="on"' : ''}>${n} j</button>`).join('');
    el('periods').addEventListener('click', e => { const b = e.target.closest('[data-p]'); if (b && st.days && Number(b.dataset.p) !== st.period) { st.period = Number(b.dataset.p); st.hover = null; render(); } });
    el('bars').addEventListener('mouseover', e => { const b = e.target.closest('[data-i]'); if (b && Number(b.dataset.i) !== st.hover) { st.hover = Number(b.dataset.i); renderHover(); } });
    el('chart').addEventListener('mouseleave', () => { st.hover = null; if (st.days) renderHover(); });
    growOnView(el('bars'));
    return { set(days) { st.days = days; render(); } };
  }

  // Durée en minutes → « 3 h 20 », « 45 min »
  const dur = m => m < 60 ? Math.round(m) + ' min' : Math.floor(m / 60) + ' h' + (m % 60 ? ' ' + String(Math.round(m % 60)).padStart(2, '0') : '');
  const msgChart = barChart('', {
    top: max => Math.ceil(max / 100) * 100 || 100, axis: v => fmt.n(v),
    value: v => fmt.n(v) + ' messages', total: v => fmt.n(v) + ' messages'
  });
  const voiceChart = barChart('v', {
    top: max => Math.ceil(max / 120) * 120 || 120, axis: v => Math.round(v / 60) + ' h',   // graduations en heures
    value: dur, total: dur
  });
  function renderVoice() {
    const V = A.voice;
    $('vLabel').innerHTML = 'Salons vocaux' + (V.demo ? ' ' + demoBadge() : '') +
      (!V.demo && V.since ? ' <span class="mono" style="font-size:11px; color:#8a91a3; text-transform:none; letter-spacing:0">· tous membres confondus, compté par le bot depuis le ' + fmt.dateShort(V.since) + '</span>' : '');
    voiceChart.set(V.days);
  }

  function renderHours() {
    const h24 = A.online24h, max = Math.max(...h24.map(h => h.value)) || 1, cur = new Date().getHours();
    $('hours').innerHTML = h24.map((h, i) => `<div title="${String(h.hour).padStart(2, '0')} h · ${h.value} en ligne" style="--i:${i * 2}; flex:1; min-height:3px; border-radius:3px 3px 0 0; height:${(h.value / max * 100).toFixed(1)}%; background:${h.hour === cur ? '#2a5ca8' : h.hour >= 20 && h.hour <= 23 ? '#9fb6d8' : '#c9d6ea'}"></div>`).join('');
    const pk = h24.reduce((m, h) => h.value > m.value ? h : m, h24[0]);
    $('peak').textContent = 'Pic : ' + pk.value + ' à ' + String(pk.hour).padStart(2, '0') + ' h';
  }

  growOnView($('hours'));
  loadDiscord().then(d => { D = d; BS.num($('cMembers'), d.members); BS.num($('cOnline'), d.online); renderKpis(); });
  loadActivity().then(a => { A = a; renderKpis(); msgChart.set(A.days); renderVoice(); renderHours(); });
})();
