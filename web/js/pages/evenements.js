// Page Événements : planning des vols (événements Discord exportés par le bot), inscrits, prochain vol.
(function () {
  const { C, esc, fmt, loadEvents, demoBadge } = window.BS;
  const $ = id => document.getElementById(id);

  let ev = { list: [] }, loaded = false;
  let evSig = null;   // null : le 1er rendu se fait même sans événement (« Aucun vol prévu »)
  function renderEvents() {
    const now = Date.now();
    const list = ev.list.filter(e => e.date.getTime() > now - 3 * 3600e3);
    const sig = list.map(e => e.title + dayDiff(e.date) + JSON.stringify(e.signups || '')).join('|');
    if (sig === evSig) return;
    evSig = sig;
    $('events').innerHTML = list.map(e => {
      const full = !!e.slots && e.registered >= e.slots;
      const fill = e.slots ? Math.min(100, Math.round(e.registered / e.slots * 100)) : e.registered ? 100 : 0;
      const days = dayDiff(e.date);
      const s = e.signups, wait = (s && s.waiting) || [];
      // Sondage d'inscription. Sans limite : « 5 présents ». Avec limite : « 2 retenus / 8 · 3 en attente »
      // (le staff choisit parmi les « Présent »). Sinon le compteur « Intéressé » de l'événement Discord.
      const plural = (n, w) => n + ' ' + w + (n > 1 ? 's' : '');
      const count = s ? (e.slots ? plural(s.yes.length, 'retenu') + ' / ' + e.slots : plural(s.yes.length, 'présent'))
          + (wait.length ? ' · ' + wait.length + ' en attente' : '') + (s.maybe.length ? ' · ' + s.maybe.length + ' peut-être' : '')
        : e.slots ? e.registered + ' / ' + e.slots + ' pilotes' : plural(e.registered, 'intéressé');
      const chip = (n, cls, title) => `<span class="${cls}"${title ? ' title="' + title + '"' : ''}>${esc(n)}</span>`;
      const who = s && (s.yes.length || wait.length || s.maybe.length) ? `<div class="who-list">${s.yes.map(n => chip(n, 'yes', e.slots ? 'Retenu' : 'Présent')).join('')}${wait.map(n => chip(n, 'wait', e.slots && !s.yes.length ? 'Candidat : choix du staff à venir' : 'Liste d\'attente')).join('')}${s.maybe.map(n => chip(n, 'maybe', 'Peut-être')).join('')}</div>` : '';
      // Photo de fond : bannière de l'événement Discord, sinon 1re photo du briefing ; lien expiré → carte blanche
      const bg = e.image ? `<img class="ev-bg" src="${esc(e.image)}" alt="" loading="lazy" onerror="this.parentElement.classList.remove('has-img'); this.remove()">` : '';
      return `<div class="card event${e.image ? ' has-img' : ''}">${bg}
        <div class="date"><span class="mono" style="font-size:11px; letter-spacing:.1em; text-transform:uppercase; color:#2a5ca8">${fmt.dayShort(e.date)}</span><b>${e.date.getDate()}</b><span class="mono" style="font-size:11px; text-transform:uppercase; color:#4a556b">${fmt.month(e.date)}</span></div>
        <div style="flex:1 1 280px; display:flex; flex-direction:column; gap:8px; min-width:0">
          <div style="display:flex; flex-wrap:wrap; align-items:center; gap:8px"><span class="kind">${esc(e.type)}</span><span class="mono ev-meta" style="font-size:12px">${[fmt.hour(e.date), esc(e.map), e.host && 'par ' + esc(e.host)].filter(Boolean).join(' · ')}</span></div>
          <span style="font-size:19px; font-weight:600">${esc(e.title)}</span>
          ${who}
        </div>
        <div style="flex:0 1 200px; display:flex; flex-direction:column; gap:8px; min-width:160px">
          <div class="mono ev-count" style="display:flex; justify-content:space-between; gap:8px; font-size:12px"><span>${count}</span><span style="white-space:nowrap">${days <= 0 ? "Aujourd'hui" : days === 1 ? 'Demain' : 'Dans ' + days + ' j'}</span></div>
          <div class="bar"><div style="width:${fill}%; background:${full ? '#d0342c' : '#2a5ca8'}"></div></div>
        </div>
        <div class="ev-actions">
          ${e.mission && e.id ? '<a class="btn outline" href="mission.html?id=' + esc(e.id) + '">Voir la mission</a>'
            : e.link ? '<a class="btn outline" href="' + esc(e.link) + '" target="_blank" rel="noopener">' + (/discord\.com\/channels\//.test(e.link) ? 'Voir le salon' : 'Ouvrir le lien') + '</a>' : ''}
          ${full && !s ? '<span class="btn muted">Complet</span>'
            : '<a class="btn' + (full ? ' outline' : '') + '" href="' + esc(signupUrl(e)) + '" target="_blank" rel="noopener">' + (full ? 'Liste d\'attente' : 'S\'inscrire') + '</a>'}
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
  // Jours calendaires (pas des tranches de 24 h) : un vol ce soir = « Aujourd'hui », pas « Demain »
  const dayDiff = d => {
    const a = new Date(d), b = new Date();
    a.setHours(0, 0, 0, 0); b.setHours(0, 0, 0, 0);
    return Math.round((a - b) / 86400000);
  };
  function tick() {
    if (!loaded) return;
    const ne = ev.list.find(e => e.date.getTime() > Date.now() - 3 * 3600e3);
    $('nCount').textContent = ne ? fmt.countdown(ne.date.getTime() - Date.now()) : '—';
  }
  const load = () => loadEvents().then(x => {
    ev = x; loaded = true;
    if (ev.demo) $('evNote').innerHTML = demoBadge('Exemple') + ' Planning à remplir dans data/evenements.js';
    else if (ev.source === 'discord') $('evNote').textContent = 'Événements du Discord · inscription par sondage dans #inscriptions';
    renderEvents(); tick();
  });
  load();
  document.addEventListener('bs:refresh', load);   // inscrits / nouveaux événements sans F5
  setInterval(tick, 1000);
  setInterval(renderEvents, 60000);
})();
