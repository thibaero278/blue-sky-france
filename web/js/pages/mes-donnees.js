// Mes données : envoie la demande de suppression au relais Apps Script (circuit_site/Code.gs, type « suppression »).
(function () {
  const { C } = window.BS;
  const form = document.getElementById('supprForm');
  const msg = document.getElementById('supprMsg');
  const btn = document.getElementById('supprBtn');
  const show = (ok, text) => { msg.hidden = false; msg.className = 'msg ' + (ok ? 'ok' : 'err'); msg.textContent = text; };
  const FALLBACK = " Envoie plutôt un message privé au rôle « Fondateur » sur le Discord.";

  form.addEventListener('submit', e => {
    e.preventDefault();
    const f = new FormData(form);
    const d = { type: 'suppression', pseudo: f.get('pseudo').trim(), discord: f.get('discord').trim(), message: f.get('message').trim(), site: f.get('site') };
    if (!d.pseudo || !d.discord) return show(false, 'Indique ton pseudo en jeu et ton pseudo Discord.');
    if (!C.statsUrl) return show(false, "Le formulaire n'est pas encore branché." + FALLBACK);
    btn.disabled = true;
    // Corps en texte brut : requête « simple », sans pré-vérification CORS, acceptée par Apps Script
    fetch(C.statsUrl, { method: 'POST', body: JSON.stringify(d) })
      .then(r => r.text())
      .then(t => {
        if (t === 'ok') { form.reset(); show(true, "Demande reçue. On efface tes données sous un mois et on te prévient sur Discord."); }
        else if (t === 'busy') show(false, 'Trop de demandes en ce moment, réessaie dans une heure.' + FALLBACK);
        else show(false, "La demande n'est pas passée." + FALLBACK);
      })
      .catch(() => show(false, "La demande n'est pas passée (connexion)." + FALLBACK))
      .finally(() => { btn.disabled = false; });
  });
})();
