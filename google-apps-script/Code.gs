/**
 * Pont entre l'app "Suivi Client" et ton Google Drive.
 * Ce script tourne sur les serveurs de Google, avec TON compte — l'app iPhone ne se
 * connecte jamais à Google, elle parle juste à ce script par une adresse web.
 *
 * ═══ À FAIRE AVANT DE DÉPLOYER ═══
 * 1. Remplace FOLDER_ID ci-dessous par l'identifiant du dossier Drive partagé
 *    (voir le LISEZ-MOI du dossier google-apps-script pour savoir où le trouver).
 * 2. Ne change PAS SECRET — il doit rester identique à celui codé dans l'app iOS.
 */
var FOLDER_ID = '1UCzMyRq1BvCr3QEKDLVAXPsSCbdRzG-g';
var SECRET = 'ZlwXB5TyT0ivTI_IG9-0_NbFtcWjArU5Rtlvowl-m4U';

// À changer à chaque modification du script (voir l'action 'version').
var SCRIPT_VERSION = 'photos-base64 · 2026-10-15';

function doGet(e) { return handle(e); }
function doPost(e) { return handle(e); }

function handle(e) {
  try {
    var params = (e && e.parameter) || {};
    if (params.secret !== SECRET) {
      return json({ error: 'unauthorized' });
    }

    var action = params.action;
    var body = {};
    if (e.postData && e.postData.contents) {
      body = JSON.parse(e.postData.contents);
    }

    // Un seul appel à la fois pour ce qui RÉÉCRIT l'index des clientes (voir plus bas) :
    // deux iPhone ne doivent pas l'écraser en même temps. Le `pull` ne fait que lire :
    // il ne fait pas la queue derrière les écritures.
    if (['pushClient', 'deleteClient'].indexOf(action) === -1) {
      return route(action, params, body);
    }
    var lock = LockService.getScriptLock();
    lock.waitLock(30000);
    try {
      return route(action, params, body);
    } finally {
      lock.releaseLock();
    }
  } catch (err) {
    return json({ error: String(err) });
  }
}

function route(action, params, body) {
  switch (action) {
    case 'pull':
      return json(pull());
    case 'pushClient':
      return json(pushClient(body));
    case 'deleteClient':
      return json(deleteClient(body.id));
    case 'pushCatalog':
      return json(pushCatalog(body));
    case 'uploadPhoto':
      return json(uploadPhoto(body));
    case 'downloadPhoto':
      return json(downloadPhoto(params.name));
    case 'version':
      // Pour vérifier depuis un navigateur que c'est bien ce code-là qui est déployé.
      return json({ version: SCRIPT_VERSION });
    case 'deletePhotos':
      return json(deletePhotos(body.transactionId));
    default:
      return json({ error: 'unknown action: ' + action });
  }
}

// ───────────────────────── Dossiers & fichiers JSON ─────────────────────────

// Chercher un fichier par son nom sur Drive est lent (plusieurs secondes, et de plus en
// plus avec les fichiers mis à la corbeille, que la recherche compte aussi). On retient
// donc l'identifiant de chaque dossier et fichier trouvé dans les propriétés du script :
// les appels suivants l'ouvrent directement. Si le fichier a disparu entre-temps (mis
// à la corbeille à la main…), on le recherche à nouveau par son nom.
var PROPS = PropertiesService.getScriptProperties();

// Dossiers déjà ouverts pendant cet appel (remis à zéro à chaque appel du script).
var openedFolders = {};

function rootFolder() {
  if (!openedFolders.root) openedFolders.root = DriveApp.getFolderById(FOLDER_ID);
  return openedFolders.root;
}
function clientsFolder() { return subFolder('Clients'); }
function photosFolder() { return subFolder('Photos'); }
function backupsFolder() { return subFolder('Backups'); }

function subFolder(name) {
  if (!openedFolders[name]) openedFolders[name] = findOrCreateSubFolder(name);
  return openedFolders[name];
}

function findOrCreateSubFolder(name) {
  var key = 'dir:' + FOLDER_ID + ':' + name;
  var id = PROPS.getProperty(key);
  if (id) {
    try {
      var cached = DriveApp.getFolderById(id);
      if (!cached.isTrashed()) return cached;
    } catch (err) {}
  }
  var root = rootFolder();
  var it = root.getFoldersByName(name);
  var folder = null;
  while (it.hasNext()) {
    var f = it.next();
    if (!f.isTrashed()) { folder = f; break; }
  }
  if (!folder) folder = root.createFolder(name);
  PROPS.setProperty(key, folder.getId());
  return folder;
}

function fileKey(folder, name) { return 'file:' + folder.getId() + ':' + name; }

function findFile(folder, name) {
  var key = fileKey(folder, name);
  var id = PROPS.getProperty(key);
  if (id) {
    try {
      var cached = DriveApp.getFileById(id);
      if (!cached.isTrashed()) return cached;
    } catch (err) {}
    PROPS.deleteProperty(key);
  }
  var it = folder.getFilesByName(name);
  while (it.hasNext()) {
    var f = it.next();
    if (!f.isTrashed()) {
      PROPS.setProperty(key, f.getId());
      return f;
    }
  }
  return null;
}

function createFile(folder, name, content) {
  var f = folder.createFile(name, content, MimeType.PLAIN_TEXT);
  PROPS.setProperty(fileKey(folder, name), f.getId());
  return f;
}

function trashFile(folder, name) {
  var f = findFile(folder, name);
  if (f) f.setTrashed(true);
  PROPS.deleteProperty(fileKey(folder, name));
}

function json(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

function readJSON(folder, name) {
  var f = findFile(folder, name);
  if (!f) return null;
  try { return JSON.parse(f.getBlob().getDataAsString()); } catch (err) { return null; }
}

// Avant d'écraser un fichier, son ancien contenu est copié dans `Backups/<nom>.bak.json`
// (le même fichier de sauvegarde est réécrit à chaque fois, plutôt que d'en créer un
// nouveau et de jeter l'ancien à la corbeille).
function writeJSON(folder, name, obj) {
  var existing = findFile(folder, name);
  if (existing) {
    var previous = existing.getBlob().getDataAsString();
    var backups = backupsFolder();
    var backupName = name.replace(/\.json$/, '') + '.bak.json';
    var backup = findFile(backups, backupName);
    if (backup) backup.setContent(previous);
    else createFile(backups, backupName, previous);
    existing.setContent(JSON.stringify(obj));
  } else {
    createFile(folder, name, JSON.stringify(obj));
  }
}

// ───────────────────────────────── Actions ──────────────────────────────────

// Index : un seul fichier `ClientsIndex.json` (à la racine) qui regroupe toutes les
// clientes, tenu à jour à chaque écriture — lire 1 fichier au lieu de 1 par cliente
// rend le `pull` quasi instantané. Les fichiers `Clients/<id>.json` restent la source
// de vérité : si l'index manque, il est reconstruit à partir d'eux.
var INDEX_NAME = 'ClientsIndex.json';

function loadIndex() {
  var index = readJSON(rootFolder(), INDEX_NAME);
  if (index) return index;
  index = {};
  var files = clientsFolder().getFiles();
  while (files.hasNext()) {
    var f = files.next();
    if (f.isTrashed()) continue;
    if (f.getName().indexOf('.bak.json') !== -1) continue;
    if (f.getName().slice(-5) !== '.json') continue;
    try { var c = JSON.parse(f.getBlob().getDataAsString()); index[c.id] = c; } catch (err) {}
  }
  saveIndex(index);
  return index;
}

function saveIndex(index) {
  var root = rootFolder();
  var f = findFile(root, INDEX_NAME);
  if (f) f.setContent(JSON.stringify(index));
  else createFile(root, INDEX_NAME, JSON.stringify(index));
}

function pull() {
  var index = loadIndex();
  var clients = Object.keys(index).map(function (id) { return index[id]; });
  var catalog = readJSON(rootFolder(), 'Catalog.json') || { reparation: [], couleur: [], typeCouleur: [], produit: [], version: 0 };
  // Chaque fiche liste elle-même ses photos (`photos`) : plus besoin de parcourir le
  // dossier Photos. `photoNames` reste, vide, pour les anciennes versions de l'app.
  return { clients: clients, catalog: catalog, photoNames: [] };
}

function pushClient(client) {
  if (!client || !client.id) return { error: 'client sans id' };
  client.version = (client.version || 0) + 1;
  client.updatedAt = new Date().toISOString();
  writeJSON(clientsFolder(), client.id + '.json', client);
  var index = loadIndex();
  index[client.id] = client;
  saveIndex(index);
  return client;
}

function deleteClient(id) {
  trashFile(clientsFolder(), id + '.json');
  var index = loadIndex();
  delete index[id];
  saveIndex(index);
  return { ok: true };
}

function pushCatalog(catalog) {
  catalog.version = (catalog.version || 0) + 1;
  writeJSON(rootFolder(), 'Catalog.json', catalog);
  return catalog;
}

function uploadPhoto(body) {
  var folder = photosFolder();
  var bytes = Utilities.base64Decode(body.dataBase64);
  var blob = Utilities.newBlob(bytes, 'image/jpeg', body.name);
  trashFile(folder, body.name);
  var f = folder.createFile(blob);
  PROPS.setProperty(fileKey(folder, body.name), f.getId());
  return { ok: true, name: body.name };
}

// Une application web Apps Script ne peut pas renvoyer un fichier tel quel (Google
// répond "type de valeur renvoyée non accepté") : la photo part donc en base64 dans du
// JSON, comme à l'envoi.
function downloadPhoto(name) {
  var f = findFile(photosFolder(), name);
  if (!f) return { error: 'not found' };
  return { name: name, dataBase64: Utilities.base64Encode(f.getBlob().getBytes()) };
}

function deletePhotos(transactionId) {
  var folder = photosFolder();
  var prefix = transactionId + '_';
  var files = folder.getFiles();
  while (files.hasNext()) {
    var f = files.next();
    if (f.getName().indexOf(prefix) === 0 && !f.isTrashed()) {
      f.setTrashed(true);
      PROPS.deleteProperty(fileKey(folder, f.getName()));
    }
  }
  return { ok: true };
}

// ───────────────────────────── Liste de secours ─────────────────────────────
//
// Un Google Sheets "Liste de secours" (dans le dossier Drive de l'app) avec toutes les
// fiches, lisible sans l'app. Mis à jour chaque nuit : un onglet par jour, les plus
// récents en premier, les BACKUP_DAYS_KEPT derniers jours gardés — si les données de
// l'app s'abîment un jour, les listes des jours précédents restent intactes.
//
// Mise en route, une seule fois : dans l'éditeur, choisir `installerListeDeSecours` dans
// la liste des fonctions en haut, puis cliquer sur ▶ Exécuter (et autoriser).

var BACKUP_SHEET_NAME = 'Liste de secours';
var BACKUP_DAYS_KEPT = 14;

function installerListeDeSecours() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'mettreAJourListeDeSecours') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('mettreAJourListeDeSecours').timeBased().everyDays(1).atHour(3).create();
  mettreAJourListeDeSecours();
}

function mettreAJourListeDeSecours() {
  var index = loadIndex();
  var headers = ['Fiche nº', 'Cliente', 'Téléphone', 'Catégorie', 'Article', 'Prix', 'Acompte',
    'Paiement', 'Moyen de paiement', 'Statut', 'Dépôt', 'Rendu le', 'Retour le', 'Récupéré après retour',
    'Note', 'Photos'];
  var rows = [];
  Object.keys(index).forEach(function (id) {
    var c = index[id];
    (c.transactions || []).forEach(function (t) {
      rows.push([
        ficheNumber(t.ref), c.name || '', c.phone || '', t.category || '', t.item || '',
        Number(t.price) || 0, depositAmount(t), paymentLabel(t), t.method || '', t.status || '',
        sheetDate(t.dropDate), sheetDate(t.pickupDate), sheetDate(t.returnDate),
        sheetDate(t.pickup2Date), t.note || '', (t.photos || []).length
      ]);
    });
  });
  rows.sort(function (a, b) { return a[0] - b[0]; });

  var ss = backupSpreadsheet();
  var tabName = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd');
  var sheet = ss.getSheetByName(tabName) || ss.insertSheet(tabName, 0);
  sheet.clear();
  var all = [headers].concat(rows);
  sheet.getRange(1, 1, all.length, headers.length).setValues(all);
  sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold');
  sheet.setFrozenRows(1);
  if (rows.length) {
    sheet.getRange(2, 11, rows.length, 4).setNumberFormat('dd/MM/yyyy');
    sheet.getRange(2, 6, rows.length, 2).setNumberFormat('#,##0 "₪"');
  }
  sheet.autoResizeColumns(1, headers.length);

  // Onglets en trop : la feuille vide créée avec le fichier, et les jours les plus anciens.
  var dated = ss.getSheets().filter(function (s) { return /^\d{4}-\d{2}-\d{2}$/.test(s.getName()); });
  ss.getSheets().forEach(function (s) {
    if (dated.indexOf(s) === -1 && ss.getSheets().length > 1) ss.deleteSheet(s);
  });
  dated.sort(function (a, b) { return a.getName() < b.getName() ? 1 : -1; });
  dated.slice(BACKUP_DAYS_KEPT).forEach(function (s) { ss.deleteSheet(s); });
}

function backupSpreadsheet() {
  var key = 'sheet:' + BACKUP_SHEET_NAME;
  var id = PROPS.getProperty(key);
  if (id) {
    try {
      if (!DriveApp.getFileById(id).isTrashed()) return SpreadsheetApp.openById(id);
    } catch (err) {}
  }
  var ss = SpreadsheetApp.create(BACKUP_SHEET_NAME);
  DriveApp.getFileById(ss.getId()).moveTo(rootFolder());
  PROPS.setProperty(key, ss.getId());
  return ss;
}

function ficheNumber(ref) {
  var n = parseInt(String(ref || '').replace(/\D/g, ''), 10);
  return isNaN(n) ? 0 : n;
}

// Même règle que l'app (`AppTransaction.depositAmount`).
function depositAmount(t) {
  if (t.category === 'Réparation') return t.deposit != null ? Number(t.deposit) : '';
  if (t.category !== 'Vente') return '';
  if (t.deposit != null) return Number(t.deposit);
  return t.plan ? Number(t.plan.paid) : '';
}

function sheetDate(iso) { return iso ? new Date(iso) : ''; }

function paymentLabel(t) {
  if (t.isPaid) return 'Payé';
  if (t.plan) {
    var tz = Session.getScriptTimeZone();
    var due = Utilities.formatDate(new Date(t.plan.due), tz, 'dd/MM/yyyy');
    var received = (t.plan.received || []).reduce(function (sum, r) { return sum + Number(r.amount); }, Number(t.plan.paid));
    if (t.plan.count) {
      return 'Échelonné (' + t.plan.method + ') — ' + t.plan.count + ' mensualités à partir du ' + due +
        ', ' + received + ' ₪ reçus sur ' + t.price + ' ₪';
    }
    return 'Échelonné — ' + received + ' ₪ payés, reste dû le ' + due;
  }
  return 'Non payé';
}
