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

function doGet(e) { return handle(e); }
function doPost(e) { return handle(e); }

function handle(e) {
  try {
    var params = (e && e.parameter) || {};
    if (params.secret !== SECRET) {
      return json({ error: 'unauthorized' });
    }

    var root = DriveApp.getFolderById(FOLDER_ID);
    var clientsFolder = getOrCreateFolder(root, 'Clients');
    var photosFolder = getOrCreateFolder(root, 'Photos');
    var backupsFolder = getOrCreateFolder(root, 'Backups');

    var action = params.action;
    var body = {};
    if (e.postData && e.postData.contents) {
      body = JSON.parse(e.postData.contents);
    }

    switch (action) {
      case 'pull':
        return json(pull(root, clientsFolder, photosFolder));
      case 'pushClient':
        return json(pushClient(clientsFolder, backupsFolder, body));
      case 'deleteClient':
        return json(deleteClient(clientsFolder, body.id));
      case 'pushCatalog':
        return json(pushCatalog(root, backupsFolder, body));
      case 'uploadPhoto':
        return json(uploadPhoto(photosFolder, body));
      case 'downloadPhoto':
        return downloadPhoto(photosFolder, params.name);
      case 'deletePhotos':
        return json(deletePhotos(photosFolder, body.transactionId));
      default:
        return json({ error: 'unknown action: ' + action });
    }
  } catch (err) {
    return json({ error: String(err) });
  }
}

// ───────────────────────── Dossiers & fichiers JSON ─────────────────────────

function getOrCreateFolder(parent, name) {
  var it = parent.getFoldersByName(name);
  return it.hasNext() ? it.next() : parent.createFolder(name);
}

function json(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

function readJSON(folder, name) {
  var it = folder.getFilesByName(name);
  if (!it.hasNext()) return null;
  try { return JSON.parse(it.next().getBlob().getDataAsString()); } catch (err) { return null; }
}

function writeJSON(folder, backupsFolder, name, obj) {
  var it = folder.getFilesByName(name);
  if (it.hasNext()) {
    var existing = it.next();
    var backupName = name.replace(/\.json$/, '') + '.bak.json';
    var bIt = backupsFolder.getFilesByName(backupName);
    if (bIt.hasNext()) bIt.next().setTrashed(true);
    backupsFolder.createFile(existing.getBlob().copyBlob().setName(backupName));
    existing.setContent(JSON.stringify(obj));
  } else {
    folder.createFile(name, JSON.stringify(obj), MimeType.PLAIN_TEXT);
  }
}

// ───────────────────────────────── Actions ──────────────────────────────────

function pull(root, clientsFolder, photosFolder) {
  var clients = [];
  var files = clientsFolder.getFiles();
  while (files.hasNext()) {
    var f = files.next();
    if (f.getName().indexOf('.bak.json') !== -1) continue;
    if (f.getName().slice(-5) !== '.json') continue;
    try { clients.push(JSON.parse(f.getBlob().getDataAsString())); } catch (err) {}
  }
  var catalog = readJSON(root, 'Catalog.json') || { reparation: [], couleur: [], typeCouleur: [], produit: [], version: 0 };
  var photoNames = [];
  var pf = photosFolder.getFiles();
  while (pf.hasNext()) { photoNames.push(pf.next().getName()); }
  return { clients: clients, catalog: catalog, photoNames: photoNames };
}

function pushClient(clientsFolder, backupsFolder, client) {
  client.version = (client.version || 0) + 1;
  client.updatedAt = new Date().toISOString();
  writeJSON(clientsFolder, backupsFolder, client.id + '.json', client);
  return client;
}

function deleteClient(clientsFolder, id) {
  var it = clientsFolder.getFilesByName(id + '.json');
  if (it.hasNext()) it.next().setTrashed(true);
  return { ok: true };
}

function pushCatalog(root, backupsFolder, catalog) {
  catalog.version = (catalog.version || 0) + 1;
  writeJSON(root, backupsFolder, 'Catalog.json', catalog);
  return catalog;
}

function uploadPhoto(photosFolder, body) {
  var bytes = Utilities.base64Decode(body.dataBase64);
  var blob = Utilities.newBlob(bytes, 'image/jpeg', body.name);
  var it = photosFolder.getFilesByName(body.name);
  if (it.hasNext()) it.next().setTrashed(true);
  photosFolder.createFile(blob);
  return { ok: true, name: body.name };
}

function downloadPhoto(photosFolder, name) {
  var it = photosFolder.getFilesByName(name);
  if (!it.hasNext()) return json({ error: 'not found' });
  return it.next().getBlob();
}

function deletePhotos(photosFolder, transactionId) {
  var prefix = transactionId + '_';
  var files = photosFolder.getFiles();
  while (files.hasNext()) {
    var f = files.next();
    if (f.getName().indexOf(prefix) === 0) f.setTrashed(true);
  }
  return { ok: true };
}
