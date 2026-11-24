// BLUE SKY - Apps Script (a coller dans Extensions > Apps Script de la feuille "BS Stats")
// Relais entre le serveur (bot Discord plugin bluesky, ou hook BS_site.lua) et le site :
// recoit stats / positions live / activite Discord / changelog, sert le JSON au site.
// Les lectures du site passent par le cache (CacheService) : le quota « Properties » (50 000 lectures/ecritures
// par jour en compte gratuit) et la lecture de la feuille ne servent plus qu'en secours.

const CACHE_S = 21600;   // duree max d'une entree du cache (6 h)
const LIVE_SAVE_S = 300; // copie du live dans les proprietes au plus toutes les 5 min (secours si le cache est vide)

// Token partagé avec le hook et publier_maj : Paramètres du projet > Propriétés du script > TOKEN
// (lu seulement a la reception d'un envoi, et garde en cache : les visites du site ne le lisent jamais)
function token_() {
  const cache = CacheService.getScriptCache();
  let t = cache.get('TOKEN');
  if (!t) {
    t = PropertiesService.getScriptProperties().getProperty('TOKEN');
    if (t) cache.put('TOKEN', t, CACHE_S);
  }
  return t;
}

const COLS = ['name', 'grade', 'points', 'totalFlightTime', 'completedFlightTime', 'maxFlightTime',
  'flights', 'airair', 'airsol', 'airmer', 'traps', 'deaths', 'teamkills', 'refuelTime', 'rang', 'landings', 'bsFlightTime',
  'maxKillsFlight', 'maxKillDistance', 'minKillDistance', 'maxAltitude', 'maxSpeed',  // records (0 = pas encore de record)
  'maxFlightTimeAt', 'maxKillsFlightAt', 'maxKillDistanceAt', 'minKillDistanceAt', 'maxAltitudeAt', 'maxSpeedAt',
  'maxRefuel', 'maxRefuelAt',  // ravitaillement le plus long (s) et sa date, ajoutés en fin pour ne pas décaler les colonnes  // dates AAAAMMJJ
  'maxKillDistanceAS', 'minKillDistanceAS', 'maxKillDistanceASAt', 'minKillDistanceASAt',  // kills air-sol, en fin pour la même raison ; maxKillDistance / minKillDistance = air-air
  'maxKillsFlightAA', 'maxKillsFlightAS', 'maxKillsFlightAAAt', 'maxKillsFlightASAt',  // kills en un vol séparés ; maxKillsFlight (ancien cumul) n'est plus affiché
  // avion de chaque record (texte, vide si inconnu ; 24/11), en fin pour ne pas décaler les colonnes
  'maxFlightTimeAc', 'maxRefuelAc', 'maxKillsFlightAAAc', 'maxKillsFlightASAc', 'maxKillDistanceAc', 'minKillDistanceAc',
  'maxKillDistanceASAc', 'minKillDistanceASAc', 'maxAltitudeAc', 'maxSpeedAc'];
const HEADERS = ['Pilote', 'Niveau', 'Points', 'Heures totales (s)', 'Heures completes (s)', 'Vol le plus long (s)',
  'Vols', 'Kills A/A', 'Kills A/S', 'Kills A/M', 'Appontages', 'Morts', 'Teamkills', 'Ravitaillement (s)', 'Grade', 'Atterrissages',
  'Heures Blue Sky (s)', 'Max kills en un vol', 'Kill air-air le plus loin (m)', 'Kill air-air le plus proche (m)', 'Altitude max (m)', 'Vitesse max (m/s)',
  'Date vol le plus long', 'Date max kills', 'Date kill le plus loin', 'Date kill le plus proche', 'Date altitude max', 'Date vitesse max', 'Ravitaillement le plus long (s)', 'Date ravitaillement le plus long',
  'Kill air-sol le plus loin (m)', 'Kill air-sol le plus proche (m)', 'Date kill air-sol le plus loin', 'Date kill air-sol le plus proche',
  'Max kills air-air en un vol', 'Max kills air-sol en un vol', 'Date max kills air-air', 'Date max kills air-sol',
  'Avion vol le plus long', 'Avion ravitaillement le plus long', 'Avion max kills air-air', 'Avion max kills air-sol', 'Avion kill air-air le plus loin',
  'Avion kill air-air le plus proche', 'Avion kill air-sol le plus loin', 'Avion kill air-sol le plus proche', 'Avion altitude max', 'Avion vitesse max'];

// « = + - @ » en tête de cellule : Sheets lirait une formule (pseudo DCS « =Demandes!C2 » → une demande RGPD
// affichée sur le site, tag « =JTF= » → #ERROR!). L'apostrophe force le texte, getValues la retire.
const cell_ = v => typeof v === 'string' && /^[=+\-@]/.test(v) ? "'" + v : v;

function sheet_(name, headers) {
  const ss = SpreadsheetApp.getActive();
  let sh = ss.getSheetByName(name);
  if (!sh) {
    sh = ss.insertSheet(name);
    if (headers) sh.appendRow(headers).setFrozenRows(1);
  }
  return sh;
}

function doPost(e) {
  let d;
  try { d = JSON.parse(e.postData.contents); } catch (err) { return text_('bad json'); }
  // Seul envoi sans token : le formulaire public « Mes données » du site
  if (d.type === 'suppression') return suppression_(d);
  if (!d.token || d.token !== token_()) return text_('forbidden');

  if (d.type === 'scores' || d.type === 'stats') {
    const sh = sheet_('Pilotes', HEADERS);
    const rows = (d.pilots || []).map(p => COLS.map(c => cell_(p[c] ?? (c === 'grade' ? 'ROOKIE' : c === 'rang' ? 'Aspirant' : c.endsWith('Ac') ? '' : 0))));
    rows.sort((a, b) => b[2] - a[2]);
    if (sh.getMaxColumns() < HEADERS.length) sh.insertColumnsAfter(sh.getMaxColumns(), HEADERS.length - sh.getMaxColumns());  // 24/11 : 48 colonnes
    sh.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);  // en-tetes a jour si une colonne a ete ajoutee
    if (sh.getLastRow() > 1) sh.getRange(2, 1, sh.getLastRow() - 1, COLS.length).clearContent();
    if (rows.length) sh.getRange(2, 1, rows.length, COLS.length).setValues(rows);

    const srv = sheet_('Serveur', ['Cle', 'Valeur']);
    srv.getRange(2, 1, 4, 2).setValues([
      ['Derniere mise a jour', new Date()],
      ['Serveur', cell_(d.server || '')],
      ['Mission', cell_(d.mission || '')],
      ['En ligne', cell_((d.online || []).map(o => o.name).join(', '))],
    ]);
    CacheService.getScriptCache().remove('JSON');
    return text_('ok');
  }

  // Envois frequents (carte live toutes les ~30 s, Discord toutes les ~15 min) : gardes en propriete de script,
  // pas dans la feuille (plus rapide, limite 9 ko par valeur -> on coupe la liste si besoin).
  if (d.type === 'live' || d.type === 'discord') {
    delete d.token;
    // le cache accepte 100 ko : on retire d'abord les IA, puis des joueurs, seulement si on dépasse
    const fit = (obj, max) => {
      let s = JSON.stringify(obj);
      while (s.length > max && obj.ai && obj.ai.length) { obj.ai.pop(); s = JSON.stringify(obj); }
      while (s.length > max && obj.players && obj.players.length) { obj.players.pop(); s = JSON.stringify(obj); }
      return s;
    };
    let json = d.type === 'discord' ? JSON.stringify(shrinkDiscord_(d)) : fit(d, 90000);
    const key = d.type.toUpperCase(), cache = CacheService.getScriptCache();
    cache.put(key, json, CACHE_S);
    if (d.type === 'discord') {
      PropertiesService.getScriptProperties().setProperty(key, json);
      cache.remove('JSON');
    } else if (!cache.get('LIVE_SAVED')) {
      PropertiesService.getScriptProperties().setProperty(key, fit(d, 9000));  // secours : 9 ko max par propriété
      cache.put('LIVE_SAVED', '1', LIVE_SAVE_S);
    }
    return text_('ok');
  }

  // Trajectoires des avions en vol (~30 s), seulement en cache : perdues au pire, le bot les renvoie
  if (d.type === 'trails') {
    delete d.token;
    try { CacheService.getScriptCache().put('TRAILS', JSON.stringify(d), CACHE_S); } catch (err) { return text_('trop gros'); }
    return text_('ok');
  }

  // Missions publiees depuis Discord (clic droit « Publier sur le site ») : une propriete par mission
  // (MISSION_<id evenement>, 9 ko max chacune) + la liste MISSIONS. Les missions retirees sont effacees.
  if (d.type === 'missions') {
    const props = PropertiesService.getScriptProperties(), cache = CacheService.getScriptCache();
    const ids = [];
    (d.missions || []).forEach(m => {
      if (!/^\d+$/.test(String(m.id))) return;
      const json = JSON.stringify(shrinkMission_(m));
      props.setProperty('MISSION_' + m.id, json);
      cache.put('MISSION_' + m.id, json, CACHE_S);  // lu par mission_() sans toucher au quota Properties
      ids.push(String(m.id));
    });
    Object.keys(props.getProperties())
      .filter(k => k.indexOf('MISSION_') === 0 && ids.indexOf(k.slice(8)) < 0)
      .forEach(k => { props.deleteProperty(k); cache.remove(k); });
    props.setProperty('MISSIONS', JSON.stringify(ids));
    cache.put('MISSIONS', JSON.stringify(ids), CACHE_S);
    return text_('ok');
  }

  if (d.type === 'changelog') {
    sheet_('Changelog', ['Date', 'Fichier', 'Version', 'Hash', 'Notes'])
      .appendRow([new Date(), d.file || '', d.version || '', d.hash || '', d.notes || ''].map(cell_));
    CacheService.getScriptCache().remove('JSON');
    return text_('ok');
  }
  return text_('unknown type');
}

// Page publique : ?format=json (stats + Discord), ?format=live (carte), ?format=trails (trajectoires), ?format=mission&id=… (briefing)
function doGet(e) {
  const fmt = e && e.parameter.format;
  if (fmt === 'mission') {
    const id = String(e.parameter.id || '');
    const json = /^\d+$/.test(id) && mission_(id);
    return ContentService.createTextOutput(json || '{"error":"not found"}').setMimeType(ContentService.MimeType.JSON);
  }
  const cache = CacheService.getScriptCache();
  if (fmt === 'live') {
    let live = cache.get('LIVE');
    if (!live) {  // serveur éteint depuis plus de 6 h : une lecture du secours, remise en cache (pas une par visite)
      live = PropertiesService.getScriptProperties().getProperty('LIVE') || '{"players":[]}';
      cache.put('LIVE', live, CACHE_S);
    }
    return ContentService.createTextOutput(live).setMimeType(ContentService.MimeType.JSON);
  }
  if (fmt === 'trails') {
    return ContentService.createTextOutput(cache.get('TRAILS') || '{"trails":{}}').setMimeType(ContentService.MimeType.JSON);
  }
  if (fmt === 'json') {
    let json = cache.get('JSON');
    if (!json) {
      json = JSON.stringify(getData_());
      try { cache.put('JSON', json, CACHE_S); } catch (err) { /* plus de 100 ko : servi sans cache */ }
    }
    return ContentService.createTextOutput(json).setMimeType(ContentService.MimeType.JSON);
  }
  return text_('Relais Blue Sky France : https://thibaero278.github.io/blue-sky-france/');
}

// Briefing publié : cache d'abord ; Properties seulement pour un id de la liste MISSIONS, une fois par 6 h
// (une boucle de GET sur des id au hasard épuisait le quota Properties de la journée, 20/11)
function mission_(id) {
  const cache = CacheService.getScriptCache(), props = PropertiesService.getScriptProperties();
  const hit = cache.get('MISSION_' + id);
  if (hit) return hit;
  let ids = cache.get('MISSIONS');
  if (!ids) {
    ids = props.getProperty('MISSIONS') || '[]';
    cache.put('MISSIONS', ids, CACHE_S);
  }
  if (JSON.parse(ids).indexOf(id) < 0) return null;
  const json = props.getProperty('MISSION_' + id);
  if (json) cache.put('MISSION_' + id, json, CACHE_S);
  return json;
}

function getData_() {
  const ss = SpreadsheetApp.getActive();
  const read = name => {
    const sh = ss.getSheetByName(name);
    return sh && sh.getLastRow() > 1 ? sh.getRange(2, 1, sh.getLastRow() - 1, sh.getLastColumn()).getValues() : [];
  };
  const pilots = read('Pilotes').map(r => Object.fromEntries(COLS.map((c, i) => [c, r[i]])));
  const server = Object.fromEntries(read('Serveur').map(r => [r[0], r[1] instanceof Date ? r[1].toISOString() : r[1]]));
  const changelog = read('Changelog').reverse().slice(0, 20)
    .map(r => ({ date: r[0] instanceof Date ? r[0].toISOString() : r[0], file: r[1], version: r[2], notes: r[4] }));
  const discord = JSON.parse(CacheService.getScriptCache().get('DISCORD')
    || PropertiesService.getScriptProperties().getProperty('DISCORD') || 'null');
  return { pilots, server, changelog, discord };
}

// 90 jours d'activite + planning tiennent dans 9 ko ; sinon on raccourcit les descriptions puis l'historique
function shrinkDiscord_(d) {
  const size = () => JSON.stringify(d).length;
  (d.events || []).forEach(ev => { delete ev.end; });
  while (size() > 9000 && d.activity && d.activity.days.length > 30) {
    d.activity.days.shift();
    if (d.activity.voice) d.activity.voice.shift();   // meme jours que days
  }
  while (size() > 9000 && d.events && d.events.length) d.events.pop();
  return d;
}

// Un briefing tient dans 9 ko : on raccourcit le texte, puis on retire des photos
function shrinkMission_(m) {
  const size = () => JSON.stringify(m).length;
  while (size() > 9000 && m.text && m.text.length > 200) m.text = m.text.slice(0, m.text.length - 500) + '…';
  while (size() > 9000 && m.images && m.images.length) m.images.pop();
  return m;
}

// Demande d'effacement des stats (RGPD art. 17), envoyee par web/mes-donnees.html.
// Rangee dans l'onglet « Demandes » + e-mail au proprietaire du script. Aucune IP n'est connue d'Apps Script.
function suppression_(d) {
  if (d.site) return text_('ok');   // champ piege rempli = robot, on ignore sans le dire
  const clean = (s, max) => String(s || '').replace(/[\r\n\t]+/g, ' ').trim().slice(0, max);
  const pseudo = clean(d.pseudo, 60), discord = clean(d.discord, 60), message = clean(d.message, 500);
  if (!pseudo || !discord) return text_('missing');
  // Anti-abus : 30 demandes par heure au plus, tous visiteurs confondus
  const cache = CacheService.getScriptCache();
  const n = Number(cache.get('suppr') || 0);
  if (n >= 30) return text_('busy');
  cache.put('suppr', String(n + 1), 3600);
  sheet_('Demandes', ['Date', 'Pseudo en jeu', 'Pseudo Discord', 'Message', 'Statut'])
    .appendRow([new Date(), cell_(pseudo), cell_(discord), cell_(message), 'A traiter']);
  try {
    MailApp.sendEmail(Session.getEffectiveUser().getEmail(), 'Blue Sky : demande de suppression de stats',
      'Pseudo en jeu : ' + pseudo + '\nPseudo Discord : ' + discord + '\nMessage : ' + message +
      '\n\nA traiter sous un mois (voir CONFORMITE.md, procedure de suppression).');
  } catch (err) { /* la demande reste dans la feuille */ }
  return text_('ok');
}

function text_(s) { return ContentService.createTextOutput(s); }

// A lancer une fois depuis l'editeur (Executer > testMail) pour autoriser l'envoi des e-mails de demandes
function testMail() {
  MailApp.sendEmail(Session.getEffectiveUser().getEmail(), 'Test Blue Sky', 'Les mails marchent.');
}
