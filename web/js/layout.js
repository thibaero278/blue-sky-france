// Barre de navigation et pied de page communs. La page indique son onglet par <body data-page="...">.
(function () {
  const { C, esc, loadServer, serverLabel } = window.BS;
  const PAGES = [
    ['accueil', 'Accueil', 'index.html'],
    ['aerobatics', 'Aerobatics', 'aerobatics.html'],
    ['carte', 'Carte live', 'carte.html'],
    ['classements', 'Classements', 'classements.html'],
    ['discord', 'Discord', 'discord.html']
  ];
  const active = document.body.dataset.page;

  const nav = document.createElement('div');
  nav.className = 'navwrap';
  nav.innerHTML = `
    <nav class="nav" aria-label="Navigation principale">
      <a class="brand" href="index.html">
        <span class="crest"><img src="assets/ecusson.png" alt="Écusson Blue Sky"></span>
        <img class="script" src="assets/logo-script-navy.png" alt="Blue Sky">
      </a>
      <div class="links" id="navLinks">
        ${PAGES.map(([id, label, href]) => `<a href="${href}"${id === active ? ' class="on" aria-current="page"' : ''}>${label}</a>`).join('')}
      </div>
      <div class="navright">
        <a class="pill" href="carte.html" id="navPill"><span class="dot"></span><span id="navPillTxt">Serveur DCS</span></a>
        <a class="btn sm" href="${esc(C.discordInvite)}" target="_blank" rel="noopener"><span class="cta-long">Rejoindre le Discord</span><span class="cta-short">Discord</span></a>
        <button class="menubtn" id="menuBtn" aria-label="Menu" aria-expanded="false">☰</button>
      </div>
    </nav>`;
  document.body.prepend(nav);
  const links = nav.querySelector('#navLinks'), btn = nav.querySelector('#menuBtn');
  btn.addEventListener('click', () => {
    const open = links.classList.toggle('open');
    btn.textContent = open ? '✕' : '☰';
    btn.setAttribute('aria-expanded', open);
  });

  loadServer().then(srv => {
    nav.querySelector('#navPill .dot').classList.toggle('off', !srv.online.length);
    nav.querySelector('#navPillTxt').textContent = serverLabel(srv);
  });

  const invShort = C.discordInvite.replace(/^https?:\/\//, '');
  const footer = document.createElement('footer');
  footer.className = 'footer';
  footer.innerHTML = `
    <div class="tri3"><div style="background:#2a5ca8"></div><div style="background:#fbfaf7"></div><div style="background:#d0342c"></div></div>
    <div class="cols">
      <div class="col" style="gap:18px">
        <img src="assets/logo-script-clair.png" alt="Blue Sky" style="width:170px; filter:brightness(1.25)">
        <p style="margin:0; font-size:14px; line-height:1.6; color:#9aa6ba; max-width:260px">Communauté francophone de simulation de vol sur DCS World.</p>
      </div>
      <div class="col">
        <span class="label">Le site</span>
        ${PAGES.map(([id, label, href]) => `<a href="${href}">${id === 'aerobatics' ? 'Blue Sky Aerobatics' : label}</a>`).join('')}
      </div>
      <div class="col">
        <span class="label">Nous suivre</span>
        <a href="https://www.tiktok.com/@bluesky.dcs" target="_blank" rel="noopener">TikTok · @bluesky.dcs</a>
        <a href="https://www.youtube.com/@BlueSky_France" target="_blank" rel="noopener">YouTube · @BlueSky_France</a>
        <a href="https://www.instagram.com/" target="_blank" rel="noopener">Instagram · Blue Sky France</a>
      </div>
      <div class="col">
        <span class="label">Infos légales</span>
        <a href="mentions-legales.html">Mentions légales</a>
        <a href="confidentialite.html">Confidentialité</a>
        <a href="cookies.html">Cookies</a>
        <a href="mes-donnees.html">Supprimer mes stats</a>
      </div>
      <div class="col" style="gap:14px">
        <span class="label" style="margin:0">Discord</span>
        <a class="btn sm light" href="${esc(C.discordInvite)}" target="_blank" rel="noopener" style="color:#13213a">Rejoindre le serveur</a>
        <span class="mono" style="font-size:12px; color:#9aa6ba">${esc(invShort)}</span>
      </div>
    </div>
    <div class="bottom">
      <span>© ${new Date().getFullYear()} Blue Sky France · Fondé par Breakdown</span>
      <span class="legal-links">
        <a href="mentions-legales.html">Mentions légales</a>
        <a href="confidentialite.html">Confidentialité</a>
        <a href="cookies.html">Cookies</a>
        <a href="mes-donnees.html">Supprimer mes stats</a>
      </span>
    </div>`;
  document.body.append(footer);

  // Bouton « copier l'invitation » (accueil, discord)
  document.querySelectorAll('[data-copy-invite]').forEach(b => {
    const lbl = b.querySelector('span');
    b.addEventListener('click', () => {
      try { navigator.clipboard.writeText(C.discordInvite); } catch (e) {}
      lbl.textContent = 'Copié ✓';
      clearTimeout(b._t); b._t = setTimeout(() => (lbl.textContent = 'Copier'), 1800);
    });
  });
})();
