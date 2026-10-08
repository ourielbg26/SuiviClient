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
      return downloadPhoto(params.name);
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
  var photoNames = [];
  var pf = photosFolder().getFiles();
  while (pf.hasNext()) {
    var p = pf.next();
    if (!p.isTrashed()) photoNames.push(p.getName());
  }
  return { clients: clients, catalog: catalog, photoNames: photoNames };
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

function downloadPhoto(name) {
  var f = findFile(photosFolder(), name);
  if (!f) return json({ error: 'not found' });
  return f.getBlob();
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
