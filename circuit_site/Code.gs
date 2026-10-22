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
  'flights', 'airair', 'airsol', 'airmer', 'traps', 'deaths', 'teamkills', 'refuelTime', 'rang'];
const HEADERS = ['Pilote', 'Niveau', 'Points', 'Heures totales (s)', 'Heures completes (s)', 'Vol le plus long (s)',
  'Vols', 'Kills A/A', 'Kills A/S', 'Kills A/M', 'Appontages', 'Morts', 'Teamkills', 'Ravitaillement (s)', 'Grade'];

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
    const rows = (d.pilots || []).map(p => COLS.map(c => p[c] ?? (c === 'grade' ? 'ROOKIE' : c === 'rang' ? 'Aspirant' : 0)));
    rows.sort((a, b) => b[2] - a[2]);
    if (sh.getLastRow() > 1) sh.getRange(2, 1, sh.getLastRow() - 1, COLS.length).clearContent();
    if (rows.length) sh.getRange(2, 1, rows.length, COLS.length).setValues(rows);

    const srv = sheet_('Serveur', ['Cle', 'Valeur']);
    srv.getRange(2, 1, 4, 2).setValues([
      ['Derniere mise a jour', new Date()],
      ['Serveur', d.server || ''],
      ['Mission', d.mission || ''],
      ['En ligne', (d.online || []).map(o => o.name).join(', ')],
    ]);
    CacheService.getScriptCache().remove('JSON');
    return text_('ok');
  }

  // Envois frequents (carte live toutes les ~30 s, Discord toutes les ~15 min) : gardes en propriete de script,
  // pas dans la feuille (plus rapide, limite 9 ko par valeur -> on coupe la liste si besoin).
  if (d.type === 'live' || d.type === 'discord') {
    delete d.token;
    let json = JSON.stringify(d);
    while (json.length > 9000 && d.players && d.players.length) { d.players.pop(); json = JSON.stringify(d); }
    if (d.type === 'discord') json = JSON.stringify(shrinkDiscord_(d));
    const key = d.type.toUpperCase(), cache = CacheService.getScriptCache();
    cache.put(key, json, CACHE_S);
    if (d.type === 'discord') {
      PropertiesService.getScriptProperties().setProperty(key, json);
      cache.remove('JSON');
    } else if (!cache.get('LIVE_SAVED')) {
      PropertiesService.getScriptProperties().setProperty(key, json);
      cache.put('LIVE_SAVED', '1', LIVE_SAVE_S);
    }
    return text_('ok');
  }

  // Missions publiees depuis Discord (clic droit « Publier sur le site ») : une propriete par mission
  // (MISSION_<id evenement>, 9 ko max chacune) + la liste MISSIONS. Les missions retirees sont effacees.
  if (d.type === 'missions') {
    const props = PropertiesService.getScriptProperties();
    const ids = [];
    (d.missions || []).forEach(m => {
      if (!/^\d+$/.test(String(m.id))) return;
      props.setProperty('MISSION_' + m.id, JSON.stringify(shrinkMission_(m)));
      ids.push(String(m.id));
    });
    Object.keys(props.getProperties())
      .filter(k => k.indexOf('MISSION_') === 0 && ids.indexOf(k.slice(8)) < 0)
      .forEach(k => props.deleteProperty(k));
    props.setProperty('MISSIONS', JSON.stringify(ids));
    return text_('ok');
  }

  if (d.type === 'changelog') {
    sheet_('Changelog', ['Date', 'Fichier', 'Version', 'Hash', 'Notes'])
      .appendRow([new Date(), d.file || '', d.version || '', d.hash || '', d.notes || '']);
    CacheService.getScriptCache().remove('JSON');
    return text_('ok');
  }
  return text_('unknown type');
}

// Page publique : ?format=json (stats + Discord), ?format=live (carte), ?format=mission&id=… (briefing)
function doGet(e) {
  const fmt = e && e.parameter.format;
  if (fmt === 'mission') {
    const id = String(e.parameter.id || '');
    const json = /^\d+$/.test(id) && PropertiesService.getScriptProperties().getProperty('MISSION_' + id);
    return ContentService.createTextOutput(json || '{"error":"not found"}').setMimeType(ContentService.MimeType.JSON);
  }
  const cache = CacheService.getScriptCache();
  if (fmt === 'live') {
    const live = cache.get('LIVE') || PropertiesService.getScriptProperties().getProperty('LIVE') || '{"players":[]}';
    return ContentService.createTextOutput(live).setMimeType(ContentService.MimeType.JSON);
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
  // « = + - @ » en tete de cellule seraient lus comme une formule par Sheets
  const cell = s => /^[=+\-@]/.test(s) ? "'" + s : s;
  sheet_('Demandes', ['Date', 'Pseudo en jeu', 'Pseudo Discord', 'Message', 'Statut'])
    .appendRow([new Date(), cell(pseudo), cell(discord), cell(message), 'A traiter']);
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
