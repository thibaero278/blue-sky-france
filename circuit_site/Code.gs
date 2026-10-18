// BLUE SKY - Apps Script (a coller dans Extensions > Apps Script de la feuille "BS Stats")
// Recoit les stats du hook BS_site.lua et le changelog, sert la page classement.

// Token partagé avec le hook et publier_maj : Paramètres du projet > Propriétés du script > TOKEN
const TOKEN = PropertiesService.getScriptProperties().getProperty('TOKEN');

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
  if (d.token !== TOKEN) return text_('forbidden');

  if (d.type === 'scores') {
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
    return text_('ok');
  }

  if (d.type === 'changelog') {
    sheet_('Changelog', ['Date', 'Fichier', 'Version', 'Hash', 'Notes'])
      .appendRow([new Date(), d.file || '', d.version || '', d.hash || '', d.notes || '']);
    return text_('ok');
  }
  return text_('unknown type');
}

// Page publique : ?format=json pour les donnees brutes, sinon la page HTML (a integrer dans Google Sites)
function doGet(e) {
  const data = getData_();
  if (e && e.parameter.format === 'json') {
    return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(ContentService.MimeType.JSON);
  }
  const t = HtmlService.createTemplateFromFile('Page');
  t.data = JSON.stringify(data);
  return t.evaluate().setTitle('Blue Sky - Classement')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL)
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
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
  return { pilots, server, changelog };
}

function text_(s) { return ContentService.createTextOutput(s); }
