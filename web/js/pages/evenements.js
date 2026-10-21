// Page Événements : planning des vols (événements Discord exportés par le bot), inscrits, prochain vol.
(function () {
  const { C, esc, fmt, loadEvents, demoBadge } = window.BS;
  const $ = id => document.getElementById(id);

  let ev = { list: [] };
  let evSig = '';
  function renderEvents() {
    const now = Date.now();
    const list = ev.list.filter(e => e.date.getTime() > now - 3 * 3600e3);
    const sig = list.map(e => e.title + Math.ceil((e.date.getTime() - now) / 86400000) + JSON.stringify(e.signups || '')).join('|');
    if (sig === evSig) return;
    evSig = sig;
    $('events').innerHTML = list.map(e => {
      const full = !!e.slots && e.registered >= e.slots;
      const fill = e.slots ? Math.min(100, Math.round(e.registered / e.slots * 100)) : e.registered ? 100 : 0;
      const days = Math.ceil((e.date.getTime() - now) / 86400000);
      const s = e.signups;
      // Sondage d'inscription : « 5 présents · 2 peut-être », sinon le compteur « Intéressé » de l'événement Discord
      const count = s ? s.yes.length + ' présent' + (s.yes.length > 1 ? 's' : '') + (e.slots ? ' / ' + e.slots : '') + (s.maybe.length ? ' · ' + s.maybe.length + ' peut-être' : '')
        : e.slots ? e.registered + ' / ' + e.slots + ' pilotes' : e.registered + ' intéressé' + (e.registered > 1 ? 's' : '');
      const who = s && (s.yes.length || s.maybe.length) ? `<div class="who-list">${s.yes.map(n => `<span class="yes">${esc(n)}</span>`).join('')}${s.maybe.map(n => `<span class="maybe" title="Peut-être">${esc(n)}</span>`).join('')}</div>` : '';
      return `<div class="card event">
        <div class="date"><span class="mono" style="font-size:11px; letter-spacing:.1em; text-transform:uppercase; color:#2a5ca8">${fmt.dayShort(e.date)}</span><b>${e.date.getDate()}</b><span class="mono" style="font-size:11px; text-transform:uppercase; color:#4a556b">${fmt.month(e.date)}</span></div>
        <div style="flex:1 1 280px; display:flex; flex-direction:column; gap:8px; min-width:0">
          <div style="display:flex; flex-wrap:wrap; align-items:center; gap:8px"><span class="kind">${esc(e.type)}</span><span class="mono" style="font-size:12px; color:#8a91a3">${[fmt.hour(e.date), esc(e.map), e.host && 'par ' + esc(e.host)].filter(Boolean).join(' · ')}</span></div>
          <span style="font-size:19px; font-weight:600">${esc(e.title)}</span>
          ${who}
        </div>
        <div style="flex:0 1 200px; display:flex; flex-direction:column; gap:8px; min-width:160px">
          <div class="mono" style="display:flex; justify-content:space-between; gap:8px; font-size:12px; color:#4a556b"><span>${count}</span><span style="white-space:nowrap">${days <= 0 ? "Aujourd'hui" : days === 1 ? 'Demain' : 'Dans ' + days + ' j'}</span></div>
          <div class="bar"><div style="width:${fill}%; background:${full ? '#d0342c' : '#2a5ca8'}"></div></div>
        </div>
        <div class="ev-actions">
          ${e.mission && e.id ? '<a class="btn outline" href="mission.html?id=' + esc(e.id) + '">Voir la mission</a>'
            : e.link ? '<a class="btn outline" href="' + esc(e.link) + '" target="_blank" rel="noopener">' + (/discord\.com\/channels\//.test(e.link) ? 'Voir le salon' : 'Ouvrir le lien') + '</a>' : ''}
          ${full ? '<span class="btn muted">Complet</span>' : '<a class="btn" href="' + esc(signupUrl(e)) + '" target="_blank" rel="noopener">S\'inscrire</a>'}
        </div>
      </div>`;
    }).join('') || '<div class="card empty">Aucun vol prévu pour le moment. Les annonces arrivent sur le Discord.</div>';
    const ne = list[0];
    $('nTitle').textContent = ne ? ne.title : 'Rien de prévu';
    $('nWhen').textContent = ne ? [fmt.dateLong(ne.date), fmt.hour(ne.date), ne.map].filter(Boolean).join(' · ') : '';
    if (ne) $('nSignup').href = signupUrl(ne);
  }
  // Sondage de l'événement, sinon le salon #inscriptions, sinon l'événement Discord
  const signupUrl = e => e.signupUrl || ev.signupChannel || C.signupChannel || e.url || C.discordInvite;
  function tick() {
    const ne = ev.list.find(e => e.date.getTime() > Date.now() - 3 * 3600e3);
    $('nCount').textContent = ne ? fmt.countdown(ne.date.getTime() - Date.now()) : '—';
  }
  loadEvents().then(x => {
    ev = x;
    if (ev.demo) $('evNote').innerHTML = demoBadge('Exemple') + ' Planning à remplir dans data/evenements.js';
    else if (ev.source === 'discord') $('evNote').textContent = 'Événements du Discord · inscription par sondage dans #inscriptions';
    renderEvents(); tick();
    setInterval(tick, 1000);
    setInterval(renderEvents, 60000);
  });
})();
