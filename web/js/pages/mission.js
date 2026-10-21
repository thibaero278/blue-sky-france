// Page mission : briefing publié depuis #missions-dcs (clic droit > Applications > Publier sur le site).
// mission.html?id=<id de l'événement Discord>
(function () {
  const { C, esc, fmt, loadMission } = window.BS;
  const $ = id => document.getElementById(id);
  const id = new URLSearchParams(location.search).get('id');

  // Mise en forme Discord (gras, italique, titres, listes, citations, code, spoilers, liens, dates <t:…>)
  function inline(s) {
    // code, liens et émojis mis de côté pour que * et _ dans une URL ne soient pas pris pour du gras/italique
    const kept = [];
    const keep = html => '\u0000' + (kept.push(html) - 1) + '\u0000';
    const link = (url, label) => keep(`<a href="${url}" target="_blank" rel="noopener">${label || url}</a>`);
    s = s
      .replace(/`([^`\n]+)`/g, (_, c) => keep('<code>' + c + '</code>'))
      .replace(/&lt;t:(\d+)(?::([tTdDfFR]))?&gt;/g, (_, t, f) => {
        const d = new Date(Number(t) * 1000);
        return f === 't' || f === 'T' ? fmt.hour(d) : f === 'd' || f === 'D' ? d.toLocaleDateString('fr-FR') : fmt.dateLong(d) + ' à ' + fmt.hour(d);
      })
      .replace(/&lt;(a?):(\w+):(\d+)&gt;/g, (_, a, name, n) => keep(`<img class="emoji" alt=":${name}:" src="https://cdn.discordapp.com/emojis/${n}.${a ? 'gif' : 'webp'}?size=48">`))
      .replace(/\[([^\]\n]+)\]\((https?:\/\/[^\s)]+)\)/g, (_, label, url) => link(url, label))
      .replace(/&lt;(https?:\/\/[^\s]+?)&gt;/g, (_, url) => link(url))
      .replace(/https?:\/\/[^\s<\u0000]+/g, url => link(url))
      .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
      .replace(/__([^_]+)__/g, '<u>$1</u>')
      .replace(/(^|[^*])\*([^*\n]+)\*/g, '$1<em>$2</em>')
      .replace(/(^|[^\w])_([^_\n]+)_(?!\w)/g, '$1<em>$2</em>')
      .replace(/~~([^~]+)~~/g, '<s>$1</s>')
      .replace(/\|\|([^|]+)\|\|/g, '<span class="spoiler" title="Cliquer pour afficher">$1</span>');
    return s.replace(/\u0000(\d+)\u0000/g, (_, i) => kept[i]);
  }
  function markdown(text) {
    const out = [];
    let list = false, para = [];
    const flush = () => {
      if (para.length) out.push('<p>' + para.map(inline).join('<br>') + '</p>');
      if (list) out.push('</ul>');
      para = []; list = false;
    };
    esc(text).split(/```(?:\w*\n)?/).forEach((block, i) => {
      if (i % 2) { flush(); out.push('<pre><code>' + block.replace(/\n$/, '') + '</code></pre>'); return; }
      block.split('\n').forEach(line => {
        let m;
        if (!line.trim()) { flush(); return; }
        if ((m = line.match(/^(#{1,3}) (.+)/))) { flush(); out.push(`<h${m[1].length + 1}>${inline(m[2])}</h${m[1].length + 1}>`); return; }
        if ((m = line.match(/^\s*[-*] (.+)/))) {
          if (para.length) { const l = list; list = false; flush(); list = l; }
          if (!list) { out.push('<ul>'); list = true; }
          out.push('<li>' + inline(m[1]) + '</li>'); return;
        }
        if ((m = line.match(/^&gt; ?(.*)/))) { flush(); out.push('<blockquote>' + inline(m[1]) + '</blockquote>'); return; }
        if ((m = line.match(/^-# (.+)/))) { flush(); out.push('<p><small style="color:#8a91a3">' + inline(m[1]) + '</small></p>'); return; }
        if (list) { out.push('</ul>'); list = false; }
        para.push(line);
      });
      flush();
    });
    return out.join('');
  }

  function notFound() {
    $('mTitle').textContent = 'Mission introuvable';
    $('mText').innerHTML = 'Ce briefing n\'est plus en ligne (événement passé ou supprimé), ou le bot ne l\'a pas encore envoyé. ' +
      'Les missions sont annoncées sur le <a href="' + esc(C.discordInvite) + '" target="_blank" rel="noopener">Discord Blue Sky</a>.';
    $('mActs').innerHTML = '<a class="btn outline" href="discord.html">Voir le planning</a>';
  }

  loadMission(id).then(m => {
    if (!m) return notFound();
    document.title = m.title + ' · Blue Sky France';
    $('mTitle').textContent = m.title;
    $('mMeta').innerHTML = [m.type && `<span class="tag">${esc(m.type)}</span>`,
      fmt.dateLong(m.date) + ' · ' + fmt.hour(m.date), m.map && esc(m.map), m.author && 'Briefing de ' + esc(m.author)]
      .filter(Boolean).join('<span>·</span>');
    $('mText').innerHTML = m.text ? markdown(m.text) : '<span style="color:#8a91a3">Pas de texte : voir les photos.</span>';
    // Liens d'images Discord valables environ 24 h, renouvelés par le bot quand il tourne
    $('mPhotos').innerHTML = (m.images || []).map(img =>
      `<a href="${esc(img.url)}" target="_blank" rel="noopener"><img src="${esc(img.url)}" alt="${esc(img.name || 'Photo du briefing')}" loading="lazy"></a>`).join('');
    $('mPhotos').querySelectorAll('img').forEach(el => el.addEventListener('error', () => {
      el.parentElement.outerHTML = `<a href="${esc(m.messageUrl)}" target="_blank" rel="noopener"><span class="lost">Photo visible sur le Discord →</span></a>`;
    }, { once: true }));
    $('mActs').innerHTML = (m.signupUrl ? `<a class="btn" href="${esc(m.signupUrl)}" target="_blank" rel="noopener">S'inscrire (sondage Discord)</a>` : '') +
      `<a class="btn outline" href="${esc(m.messageUrl)}" target="_blank" rel="noopener">Voir sur Discord</a>` +
      '<a class="btn outline" href="discord.html">Planning</a>';
  });

  $('mText').addEventListener('click', e => { const s = e.target.closest('.spoiler'); if (s) s.classList.toggle('on'); });
})();
