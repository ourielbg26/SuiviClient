import Foundation
import Observation

/// Le magasin central de l'app. Toujours utilisable hors ligne (copie locale dans le
/// bac à sable de l'app) ; si `DriveConfig` est renseigné, synchronise avec Google Drive
/// (via `DriveBridge`) au lancement et pousse chaque modification en arrière-plan.
///
/// Règle d'arbitrage en cas de conflit (§ pas de fusion automatique — voir LISEZ-MOI) :
/// le fichier ayant le `version` le plus haut gagne ; l'autre est simplement remplacé
/// (une copie `.bak` locale et une copie dans `Backups/` sur Drive restent récupérables
/// à la main).
@Observable
final class DataStore {
    private(set) var clients: [Client] = []
    private(set) var catalog: CatalogData = CatalogData()
    private(set) var photoManifest: Set<String> = []
    private(set) var isSyncing = false
    /// false jusqu'à la fin de la première synchro du lancement (réussie ou non) — tant
    /// que c'est false, l'app affiche l'écran de chargement (`SplashView`).
    private(set) var hasFinishedLaunchSync = false
    private(set) var lastSyncError: String?

    private var pendingDeletes: Set<UUID>
    private let fileStore: FileStore

    init(fileStore: FileStore = FileStore()) {
        self.fileStore = fileStore
        self.clients = fileStore.loadAllClients()
        self.catalog = fileStore.loadCatalog()
        self.pendingDeletes = fileStore.loadPendingDeletes()
        syncAtLaunch()
    }

    // MARK: - Synchro Drive

    private var syncTask: Task<Void, Never>?

    func syncAtLaunch() {
        Task { @MainActor in await sync() }
    }

    /// Envoie les suppressions/photos restées en attente, puis réconcilie chaque cliente
    /// et le catalogue avec Drive (le `version` le plus haut gagne). Si Drive n'est pas
    /// joignable, l'app continue avec la copie locale — rien ne bloque. Appelée au
    /// lancement, au retour dans l'app et par "tirer pour rafraîchir" ; si une synchro
    /// est déjà en cours, on attend simplement sa fin au lieu d'en lancer une deuxième.
    @MainActor
    func sync() async {
        guard DriveConfig.isConfigured else {
            hasFinishedLaunchSync = true
            return
        }
        if let syncTask {
            await syncTask.value
            return
        }
        let task = Task { @MainActor in await performSync() }
        syncTask = task
        await task.value
        syncTask = nil
    }

    @MainActor
    private func performSync() async {
        isSyncing = true
        defer {
            isSyncing = false
            hasFinishedLaunchSync = true
        }
        do {
            for id in pendingDeletes {
                try? await DriveBridge.deleteClient(id: id)
            }
            pendingDeletes.removeAll()
            fileStore.savePendingDeletes(pendingDeletes)

            for name in fileStore.pendingPhotoNames() {
                if let data = fileStore.pendingPhotoData(name: name),
                   (try? await DriveBridge.uploadPhoto(name: name, data: data)) != nil {
                    fileStore.removePendingPhoto(name: name)
                }
            }

            let remote = try await DriveBridge.pull()

            var merged = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0) })
            for remoteClient in remote.clients {
                if let local = merged[remoteClient.id] {
                    if local.version > remoteClient.version {
                        if let pushed = try? await DriveBridge.pushClient(local) {
                            merged[local.id] = pushed
                            fileStore.save(pushed)
                        }
                    } else if remoteClient.version > local.version {
                        merged[remoteClient.id] = remoteClient
                        fileStore.save(remoteClient)
                    }
                } else {
                    merged[remoteClient.id] = remoteClient
                    fileStore.save(remoteClient)
                }
            }
            let remoteIDs = Set(remote.clients.map(\.id))
            let localOnlyIDs = merged.keys.filter { !remoteIDs.contains($0) }
            for id in localOnlyIDs {
                guard let local = merged[id] else { continue }
                if let pushed = try? await DriveBridge.pushClient(local) {
                    merged[id] = pushed
                    fileStore.save(pushed)
                }
            }
            // Une fiche modifiée sur ce téléphone pendant la synchro (qui peut durer
            // plusieurs secondes) a une version plus récente : on la garde.
            for current in clients where (merged[current.id]?.version ?? -1) < current.version {
                merged[current.id] = current
            }
            clients = Array(merged.values)

            if catalog.version > remote.catalog.version {
                if let pushed = try? await DriveBridge.pushCatalog(catalog) {
                    catalog = pushed
                    fileStore.save(pushed)
                }
            } else if remote.catalog.version > catalog.version {
                catalog = remote.catalog
                fileStore.save(remote.catalog)
            }

            photoManifest = Set(remote.photoNames).union(fileStore.pendingPhotoNames())
            lastSyncError = nil
        } catch {
            lastSyncError = "Hors ligne — synchro à la prochaine ouverture."
        }
    }

    // MARK: - Lecture

    /// Vue "à plat" de toutes les transactions, toutes clientes confondues — utilisée par
    /// Accueil, Transactions et Stats.
    var allEntries: [TransactionEntry] {
        clients.flatMap { client in
            client.transactions.map { TransactionEntry(clientID: client.id, clientName: client.name, phone: client.phone, transaction: $0) }
        }
    }

    func client(id: UUID) -> Client? { clients.first { $0.id == id } }

    func client(named name: String) -> Client? {
        clients.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// La transaction (avec son contexte cliente) — se relit depuis `clients` à chaque
    /// appel, donc toujours à jour après une modification.
    func entry(clientID: UUID, transactionID: UUID) -> TransactionEntry? {
        guard let client = client(id: clientID), let t = client.transactions.first(where: { $0.id == transactionID }) else { return nil }
        return TransactionEntry(clientID: client.id, clientName: client.name, phone: client.phone, transaction: t)
    }

    func usageCount(_ value: String) -> Int {
        allEntries.filter { $0.item.localizedCaseInsensitiveContains(value) }.count
    }

    func nextRef() -> String {
        let numbers = allEntries.compactMap { e -> Int? in
            guard e.ref.hasPrefix("T-") else { return nil }
            return Int(e.ref.dropFirst(2))
        }
        let next = (numbers.max() ?? 0) + 1
        return "T-" + String(format: "%03d", next)
    }

    // MARK: - Écriture : transactions

    /// Enregistre le formulaire — création ou modification. `editing` identifie la fiche
    /// à modifier ; nil pour une nouvelle fiche. Retourne où naviguer ensuite.
    @discardableResult
    func saveTransaction(draft: TransactionFormDraft, editing: (clientID: UUID, transactionID: UUID)?) -> (clientID: UUID, transactionID: UUID) {
        let name = draft.name.trimmingCharacters(in: .whitespaces)
        let phone = draft.phone.trimmingCharacters(in: .whitespaces).isEmpty ? "—" : draft.phone
        let (isPaid, plan): (Bool, Installments?)
        if draft.category == .vente {
            let reste = draft.priceValue - draft.venteAcompteValue
            if draft.venteAcompteValue <= 0 {
                (isPaid, plan) = (false, nil)
            } else if reste <= 0 {
                (isPaid, plan) = (true, nil)
            } else {
                (isPaid, plan) = (false, Installments(paid: draft.venteAcompteValue, due: draft.planDue, method: draft.planMethod))
            }
        } else if draft.pay == .plusieursFois {
            (isPaid, plan) = (false, Installments(paid: Decimal(string: draft.planPaid) ?? 0, due: draft.planDue, method: draft.planMethod))
        } else {
            (isPaid, plan) = (draft.pay == .paye, nil)
        }

        if let editing, var client = client(id: editing.clientID),
           let idx = client.transactions.firstIndex(where: { $0.id == editing.transactionID }) {
            var t = client.transactions[idx]
            t.category = draft.category
            t.item = draft.itemLabel
            t.origine = draft.category == .vente ? draft.origine : nil
            t.price = draft.priceValue
            t.isPaid = isPaid
            t.method = draft.method
            t.plan = plan
            t.status = draft.status
            t.dropDate = draft.dropDate
            t.pickupDate = draft.pickupDate
            t.returnDate = draft.returnDate
            t.pickup2Date = draft.pickup2Date
            t.note = draft.note
            client.transactions[idx] = t
            client.name = name
            client.phone = phone
            persist(client)
            storePhotos(draft.photos, transactionID: t.id, category: draft.category)
            return (client.id, t.id)
        }

        var target = client(named: name) ?? Client(name: name, phone: phone, isSavedContact: draft.saveContact)
        let newTransaction = AppTransaction(
            ref: nextRef(),
            category: draft.category,
            item: draft.itemLabel,
            origine: draft.category == .vente ? draft.origine : nil,
            price: draft.priceValue,
            isPaid: isPaid,
            method: draft.method,
            plan: plan,
            status: draft.status,
            dropDate: draft.dropDate,
            pickupDate: draft.pickupDate,
            returnDate: draft.returnDate,
            pickup2Date: draft.pickup2Date,
            note: draft.note
        )
        target.phone = phone
        target.transactions.append(newTransaction)
        persist(target)
        storePhotos(draft.photos, transactionID: newTransaction.id, category: draft.category)
        return (target.id, newTransaction.id)
    }

    private func storePhotos(_ photos: [Data], transactionID: UUID, category: Category) {
        guard !photos.isEmpty else { return }
        let kind: PhotoKind = category == .vente ? .apres : .avant
        for data in photos { addPhoto(data, transactionID: transactionID, kind: kind) }
    }

    private func updateTransaction(clientID: UUID, transactionID: UUID, mutate: (inout AppTransaction) -> Void) {
        guard var client = client(id: clientID), let idx = client.transactions.firstIndex(where: { $0.id == transactionID }) else { return }
        mutate(&client.transactions[idx])
        persist(client)
    }

    /// Règles de dates §6.3 : Rendu → remplit "Rendu le" (et "Récupéré après retour" si ça
    /// revenait d'un retour) ; Retour → remplit "Retour le" et vide "Récupéré après retour".
    func setStatus(clientID: UUID, transactionID: UUID, to newStatus: WorkStatus) {
        updateTransaction(clientID: clientID, transactionID: transactionID) { t in
            if newStatus == .rendu {
                if t.pickupDate == nil {
                    t.pickupDate = .now
                } else if t.returnDate != nil, t.pickup2Date == nil {
                    t.pickup2Date = .now
                }
            }
            if newStatus == .retour {
                t.returnDate = .now
                t.pickup2Date = nil
            }
            t.status = newStatus
        }
    }

    func markPaid(clientID: UUID, transactionID: UUID) {
        updateTransaction(clientID: clientID, transactionID: transactionID) { t in
            t.isPaid = true
            t.plan = nil
        }
    }

    func deleteTransaction(clientID: UUID, transactionID: UUID) {
        guard var client = client(id: clientID) else { return }
        client.transactions.removeAll { $0.id == transactionID }
        removePhotos(transactionID: transactionID)
        if client.transactions.isEmpty, !client.isSavedContact {
            fileStore.deleteClientFile(id: client.id)
            clients.removeAll { $0.id == client.id }
            pendingDeletes.insert(client.id)
            fileStore.savePendingDeletes(pendingDeletes)
            guard DriveConfig.isConfigured else { return }
            let deletedID = client.id
            Task { @MainActor in
                if (try? await DriveBridge.deleteClient(id: deletedID)) != nil {
                    pendingDeletes.remove(deletedID)
                    fileStore.savePendingDeletes(pendingDeletes)
                }
            }
        } else {
            persist(client)
        }
    }

    /// Écrit en local, met à jour l'état affiché tout de suite, puis pousse sur Drive en
    /// tâche de fond si configuré (best effort — un échec ici est rattrapé à la prochaine
    /// synchro puisque la version locale reste "en avance").
    private func persist(_ client: Client) {
        var updated = client
        updated.version += 1
        updated.updatedAt = .now
        fileStore.save(updated)
        upsert(updated)
        guard DriveConfig.isConfigured else { return }
        let toPush = updated
        Task { @MainActor in
            if let pushed = try? await DriveBridge.pushClient(toPush) {
                fileStore.save(pushed)
                upsert(pushed)
            }
        }
    }

    private func upsert(_ client: Client) {
        if let idx = clients.firstIndex(where: { $0.id == client.id }) {
            clients[idx] = client
        } else {
            clients.append(client)
        }
    }

    // MARK: - Écriture : contacts

    @discardableResult
    func addContact(name: String, phone: String) -> UUID {
        let client = Client(name: name, phone: phone.isEmpty ? "—" : phone, isSavedContact: true)
        persist(client)
        return client.id
    }

    // MARK: - Écriture : catalogues

    func addCatalogEntry(type: CatalogType, name: String) {
        guard !catalog[type].contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        var updated = catalog
        updated[type].append(CatalogItem(name: name))
        persistCatalog(updated)
    }

    func removeCatalogEntry(type: CatalogType, id: UUID) {
        var updated = catalog
        updated[type].removeAll { $0.id == id }
        persistCatalog(updated)
    }

    private func persistCatalog(_ updated: CatalogData) {
        var toSave = updated
        toSave.version += 1
        fileStore.save(toSave)
        catalog = toSave
        guard DriveConfig.isConfigured else { return }
        let toPush = toSave
        Task { @MainActor in
            if let pushed = try? await DriveBridge.pushCatalog(toPush) {
                fileStore.save(pushed)
                catalog = pushed
            }
        }
    }

    // MARK: - Photos (uniquement sur Drive une fois envoyées — voir LISEZ-MOI)

    func photoNames(transactionID: UUID, kind: PhotoKind) -> [String] {
        let prefix = "\(transactionID.uuidString)_\(kind.rawValue)_"
        return photoManifest.filter { $0.hasPrefix(prefix) }.sorted()
    }

    /// Compresse puis met en attente localement (au cas où hors ligne), et tente l'envoi
    /// immédiat sur Drive — une fois confirmé, la copie locale temporaire est effacée.
    func addPhoto(_ rawData: Data, transactionID: UUID, kind: PhotoKind) {
        let data = ImageCompressor.compress(rawData)
        let name = nextPhotoName(transactionID: transactionID, kind: kind)
        photoManifest.insert(name)
        fileStore.stagePendingPhoto(data, name: name)
        guard DriveConfig.isConfigured else { return }
        Task { @MainActor in
            if (try? await DriveBridge.uploadPhoto(name: name, data: data)) != nil {
                fileStore.removePendingPhoto(name: name)
            }
        }
    }

    private func nextPhotoName(transactionID: UUID, kind: PhotoKind) -> String {
        let prefix = "\(transactionID.uuidString)_\(kind.rawValue)_"
        let indices = photoManifest.compactMap { name -> Int? in
            guard name.hasPrefix(prefix) else { return nil }
            let numberPart = name.dropFirst(prefix.count).prefix { $0.isNumber }
            return Int(numberPart)
        }
        return "\(prefix)\((indices.max() ?? 0) + 1).jpg"
    }

    private func removePhotos(transactionID: UUID) {
        let prefix = "\(transactionID.uuidString)_"
        photoManifest = photoManifest.filter { !$0.hasPrefix(prefix) }
        for name in fileStore.pendingPhotoNames() where name.hasPrefix(prefix) {
            fileStore.removePendingPhoto(name: name)
        }
        guard DriveConfig.isConfigured else { return }
        Task { @MainActor in try? await DriveBridge.deletePhotos(transactionID: transactionID) }
    }

    /// Charge les octets d'une photo pour l'affichage : en attente locale → cache local →
    /// téléchargement Drive (mis en cache ensuite). `nil` si rien n'est joignable.
    func loadPhotoData(name: String) async -> Data? {
        if let pending = fileStore.pendingPhotoData(name: name) { return pending }
        if let cached = fileStore.cachedPhotoData(name: name) { return cached }
        guard DriveConfig.isConfigured, let data = try? await DriveBridge.downloadPhoto(name: name) else { return nil }
        fileStore.cachePhotoData(data, name: name)
        return data
    }
}
