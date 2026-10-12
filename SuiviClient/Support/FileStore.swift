import Foundation

enum PhotoKind: String {
    case avant, apres

    /// Une vente se photographie une fois prête ("après") ; le reste à l'arrivée ("avant").
    init(for category: Category) { self = category == .vente ? .apres : .avant }
}

/// Accès disque local — toujours dans le bac à sable de l'app (aucun dossier choisi par
/// l'utilisatrice). Le partage entre iPhone passe par `DriveBridge` (Google Drive via le
/// petit script) ; ce fichier ne gère que la copie locale + les files d'attente.
///
/// Structure sur disque :
///   Clients/<id>.json     — une cliente + toutes ses transactions
///   Catalog.json           — les 4 catalogues
///   PendingPhotos/…         — photos pas encore envoyées sur Drive (effacées une fois
///                             envoyées : les photos ne restent pas sur le téléphone)
final class FileStore {
    private let fm = FileManager.default

    private func root() -> URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("SuiviClientData", isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func dir(_ name: String) -> URL {
        let url = root().appendingPathComponent(name, isDirectory: true)
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var clientsDir: URL { dir("Clients") }
    private var pendingPhotosDir: URL { dir("PendingPhotos") }
    private var catalogURL: URL { root().appendingPathComponent("Catalog.json") }
    private var pendingDeletesURL: URL { root().appendingPathComponent("PendingDeletes.json") }

    // MARK: - JSON

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Sauvegarde `.bak` de l'ancienne version avant d'écraser — seul filet de sécurité
    /// local contre une écriture ratée (pas de fusion, juste une copie récupérable à la main).
    private func write(_ data: Data, to url: URL, keepBackup: Bool) throws {
        if keepBackup, fm.fileExists(atPath: url.path) {
            let bak = url.deletingPathExtension().appendingPathExtension("bak.json")
            try? fm.removeItem(at: bak)
            try? fm.copyItem(at: url, to: bak)
        }
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Clientes

    func loadAllClients() -> [Client] {
        guard let files = try? fm.contentsOfDirectory(at: clientsDir, includingPropertiesForKeys: nil) else { return [] }
        return files
            .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasSuffix(".bak.json") }
            .compactMap { url in (try? Data(contentsOf: url)).flatMap { try? decoder.decode(Client.self, from: $0) } }
    }

    func save(_ client: Client) {
        guard let data = try? encoder.encode(client) else { return }
        try? write(data, to: clientsDir.appendingPathComponent("\(client.id.uuidString).json"), keepBackup: true)
    }

    func deleteClientFile(id: UUID) {
        try? fm.removeItem(at: clientsDir.appendingPathComponent("\(id.uuidString).json"))
    }

    // MARK: - Catalogue

    func loadCatalog() -> CatalogData {
        guard let data = try? Data(contentsOf: catalogURL), let catalog = try? decoder.decode(CatalogData.self, from: data) else {
            return CatalogData()
        }
        return catalog
    }

    func save(_ catalog: CatalogData) {
        guard let data = try? encoder.encode(catalog) else { return }
        try? write(data, to: catalogURL, keepBackup: true)
    }

    // MARK: - Suppressions en attente (client supprimé hors ligne, à répercuter sur Drive)

    func loadPendingDeletes() -> Set<UUID> {
        guard let data = try? Data(contentsOf: pendingDeletesURL), let ids = try? decoder.decode([UUID].self, from: data) else { return [] }
        return Set(ids)
    }

    func savePendingDeletes(_ ids: Set<UUID>) {
        guard let data = try? encoder.encode(Array(ids)) else { return }
        try? data.write(to: pendingDeletesURL, options: .atomic)
    }

    // MARK: - Photos en attente d'envoi (prises hors ligne)

    func stagePendingPhoto(_ data: Data, name: String) {
        try? data.write(to: pendingPhotosDir.appendingPathComponent(name), options: .atomic)
    }

    func pendingPhotoNames() -> [String] {
        (try? fm.contentsOfDirectory(atPath: pendingPhotosDir.path)) ?? []
    }

    func pendingPhotoData(name: String) -> Data? {
        try? Data(contentsOf: pendingPhotosDir.appendingPathComponent(name))
    }

    func removePendingPhoto(name: String) {
        try? fm.removeItem(at: pendingPhotosDir.appendingPathComponent(name))
    }

    /// Les anciennes versions de l'app gardaient une copie des photos téléchargées : on
    /// l'efface, les photos ne sont plus stockées sur le téléphone.
    func removeLegacyPhotoCache() {
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try? fm.removeItem(at: caches.appendingPathComponent("SuiviClientPhotoCache", isDirectory: true))
    }
}
