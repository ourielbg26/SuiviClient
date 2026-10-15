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
    /// Photos prises sur ce téléphone et pas encore envoyées sur Drive.
    private(set) var pendingPhotoNames: Set<String>
    private(set) var isSyncing = false
    /// false jusqu'à la fin de la première synchro du lancement (réussie ou non) — tant
    /// que c'est false, l'app affiche l'écran de chargement (`SplashView`).
    private(set) var hasFinishedLaunchSync = false
    private(set) var lastSyncError: String?

    private var pendingDeletes: Set<UUID>
    private let fileStore: FileStore

    init(fileStore: FileStore = FileStore()) {
        self.fileStore = fileStore
        self.clients = fileStore.loadAllClients().filter { $0.mergedInto == nil }
        self.catalog = fileStore.loadCatalog()
        self.pendingDeletes = fileStore.loadPendingDeletes()
        self.pendingPhotoNames = Set(fileStore.pendingPhotoNames())
        fileStore.removeLegacyPhotoCache()
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
        defer { settleFinishedInstallments() }
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

            await uploadPendingPhotos(Array(pendingPhotoNames))

            let remote = try await DriveBridge.pull()

            var merged = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0) })
            for remoteClient in remote.clients {
                // Doublon fusionné : la version de Drive fait foi, même si ce téléphone l'a
                // enregistré avant de savoir lire `mergedInto`.
                if remoteClient.mergedInto != nil {
                    merged[remoteClient.id] = remoteClient
                    fileStore.save(remoteClient)
                    continue
                }
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
            clients = merged.values.filter { $0.mergedInto == nil }

            if catalog.version > remote.catalog.version {
                if let pushed = try? await DriveBridge.pushCatalog(catalog) {
                    catalog = pushed
                    fileStore.save(pushed)
                }
            } else if remote.catalog.version > catalog.version {
                catalog = remote.catalog
                fileStore.save(remote.catalog)
            }

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
        let deposit: Decimal? = (draft.category == .vente && draft.acompteValue > 0) || draft.hasRepairDeposit ? draft.acompteValue : nil
        if draft.priceValue == 0 {
            // Rien à payer : la fiche ne doit pas apparaître dans "Non payé".
            (isPaid, plan) = (true, nil)
        } else if draft.category == .vente {
            let reste = draft.priceValue - draft.acompteValue
            if reste <= 0 || draft.venteSoldePaye {
                (isPaid, plan) = (true, nil)
            } else if draft.acompteValue > 0 || draft.planCountValue != nil {
                (isPaid, plan) = (false, Installments(paid: draft.acompteValue, due: draft.planDue, method: draft.planMethod, count: draft.planCountValue))
            } else {
                (isPaid, plan) = (false, nil)
            }
        } else if draft.pay == .plusieursFois && draft.category.allowsInstallments {
            (isPaid, plan) = (false, Installments(paid: Decimal(string: draft.planPaid) ?? 0, due: draft.planDue, method: draft.planMethod, count: draft.planCountValue))
        } else {
            // Un acompte qui couvre tout le prix vaut paiement.
            let depositCoversPrice = draft.hasRepairDeposit && draft.acompteValue >= draft.priceValue
            (isPaid, plan) = (draft.pay == .paye || depositCoversPrice, nil)
        }

        if let editing, var client = client(id: editing.clientID),
           let idx = client.transactions.firstIndex(where: { $0.id == editing.transactionID }) {
            var t = client.transactions[idx]
            t.category = draft.category
            t.item = draft.itemLabel
            t.origine = draft.category == .vente ? draft.origine : nil
            t.price = draft.priceValue
            t.isPaid = isPaid
            t.method = draft.paymentMethod
            // Les paiements en espèces déjà notés restent attachés à l'échelonnement ; une
            // fiche passée en "Payé" garde son échelonnement comme historique.
            if var newPlan = plan {
                newPlan.received = t.plan?.received
                t.plan = newPlan
            } else {
                t.plan = isPaid ? t.plan : nil
            }
            t.deposit = deposit
            t.status = draft.status
            t.dropDate = draft.dropDate
            t.pickupDate = draft.pickupDate
            t.returnDate = draft.returnDate
            t.returnReason = draft.returnDateReason
            t.pickup2Date = draft.pickup2Date
            if t.note != draft.note {
                t.note = draft.note
                t.noteUpdatedAt = .now
            }
            let newPhotos = stagePhotos(draft.photos, in: &t, kind: PhotoKind(for: draft.category))
            client.transactions[idx] = t
            client.name = name
            client.phone = phone
            persist(client)
            uploadInBackground(newPhotos)
            return (client.id, t.id)
        }

        var target = draft.clientID.flatMap { client(id: $0) }
            ?? client(named: name)
            ?? Client(name: name, phone: phone, isSavedContact: draft.saveContact)
        var newTransaction = AppTransaction(
            ref: nextRef(),
            category: draft.category,
            item: draft.itemLabel,
            origine: draft.category == .vente ? draft.origine : nil,
            price: draft.priceValue,
            isPaid: isPaid,
            method: draft.paymentMethod,
            plan: plan,
            status: draft.status,
            dropDate: draft.dropDate,
            pickupDate: draft.pickupDate,
            returnDate: draft.returnDate,
            pickup2Date: draft.pickup2Date,
            note: draft.note
        )
        newTransaction.deposit = deposit
        newTransaction.returnReason = draft.returnDateReason
        if !draft.note.isEmpty { newTransaction.noteUpdatedAt = .now }
        let newPhotos = stagePhotos(draft.photos, in: &newTransaction, kind: PhotoKind(for: draft.category))
        target.phone = phone
        target.transactions.append(newTransaction)
        persist(target)
        uploadInBackground(newPhotos)
        return (target.id, newTransaction.id)
    }

    private func updateTransaction(clientID: UUID, transactionID: UUID, mutate: (inout AppTransaction) -> Void) {
        guard var client = client(id: clientID), let idx = client.transactions.firstIndex(where: { $0.id == transactionID }) else { return }
        mutate(&client.transactions[idx])
        persist(client)
    }

    /// Règles de dates §6.3 : Rendu → remplit "Rendu le" (et "Récupéré après retour" si ça
    /// revenait d'un retour) ; Retour → remplit "Retour le" et vide "Récupéré après retour".
    func setStatus(clientID: UUID, transactionID: UUID, to newStatus: WorkStatus, returnReason: String? = nil) {
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
                if let returnReason { t.returnReason = returnReason }
            }
            t.status = newStatus
        }
    }

    /// Modification de la note directement depuis la fiche (sans passer par Modifier).
    func updateNote(clientID: UUID, transactionID: UUID, note: String) {
        guard entry(clientID: clientID, transactionID: transactionID)?.note != note else { return }
        updateTransaction(clientID: clientID, transactionID: transactionID) { t in
            t.note = note
            t.noteUpdatedAt = .now
        }
    }

    // MARK: Retour : choses à arranger

    func addReturnFix(clientID: UUID, transactionID: UUID, text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        updateTransaction(clientID: clientID, transactionID: transactionID) { t in
            t.returnFixes.append(ReturnFix(text: text))
        }
    }

    func toggleReturnFix(clientID: UUID, transactionID: UUID, fixID: UUID) {
        updateTransaction(clientID: clientID, transactionID: transactionID) { t in
            guard let idx = t.returnFixes.firstIndex(where: { $0.id == fixID }) else { return }
            t.returnFixes[idx].done.toggle()
        }
    }

    func deleteReturnFix(clientID: UUID, transactionID: UUID, fixID: UUID) {
        updateTransaction(clientID: clientID, transactionID: transactionID) { t in
            t.returnFixes.removeAll { $0.id == fixID }
        }
    }

    /// Espèces : note un paiement reçu ; quand tout le prix est couvert, la fiche passe
    /// d'elle-même en payé.
    func recordInstallmentPayment(clientID: UUID, transactionID: UUID, amount: Decimal, date: Date) {
        updateTransaction(clientID: clientID, transactionID: transactionID) { t in
            guard t.plan != nil else { return }
            let received = t.plan?.received ?? []
            t.plan?.received = received + [InstallmentReceipt(date: date, amount: amount)]
            if let left = t.planLeft, left <= 0 { t.isPaid = true }
        }
    }

    /// Retire un paiement noté par erreur (la fiche repasse en cours si elle n'est plus
    /// entièrement payée).
    func deleteInstallmentPayment(clientID: UUID, transactionID: UUID, receiptID: UUID) {
        updateTransaction(clientID: clientID, transactionID: transactionID) { t in
            t.plan?.received?.removeAll { $0.id == receiptID }
            if let left = t.planLeft, left > 0 { t.isPaid = false }
        }
    }

    /// Chèque / carte : une fois la date de la dernière mensualité passée, la fiche est
    /// considérée payée. Lancé après chaque synchro (donc à l'ouverture de l'app).
    @MainActor
    func settleFinishedInstallments() {
        let today = Calendar.current.startOfDay(for: .now)
        for var client in clients {
            var changed = false
            for idx in client.transactions.indices {
                let t = client.transactions[idx]
                guard !t.isPaid, let plan = t.plan, plan.method != .especes,
                      let last = t.installmentDates.last, Calendar.current.startOfDay(for: last) < today else { continue }
                client.transactions[idx].isPaid = true
                changed = true
            }
            if changed { persist(client) }
        }
    }

    func markPaid(clientID: UUID, transactionID: UUID) {
        updateTransaction(clientID: clientID, transactionID: transactionID) { t in
            t.deposit = t.depositAmount
            t.isPaid = true
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

    /// Nom et téléphone d'une cliente (fiche cliente → Modifier).
    func updateClient(id: UUID, name: String, phone: String) {
        guard var client = client(id: id) else { return }
        client.name = name
        client.phone = phone.isEmpty ? "—" : phone
        persist(client)
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

    /// Prix préenregistré d'une entrée (nil pour l'enlever).
    func setCatalogPrice(type: CatalogType, id: UUID, price: Decimal?) {
        var updated = catalog
        guard let idx = updated[type].firstIndex(where: { $0.id == id }) else { return }
        updated[type][idx].price = price
        persistCatalog(updated)
    }

    func catalogItem(type: CatalogType, named name: String) -> CatalogItem? {
        catalog[type].first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Prix proposé dans le formulaire d'après les prix préenregistrés des Paramètres :
    /// somme des réparations choisies (× nombre pour celles à l'unité), prix de la
    /// colorimétrie, ou du lavage. nil si rien de choisi n'a de prix.
    func suggestedPrice(for draft: TransactionFormDraft) -> Decimal? {
        switch draft.category {
        case .reparation:
            let prices = draft.reparations.compactMap { name -> Decimal? in
                guard let unitPrice = catalogItem(type: .reparation, named: name)?.price else { return nil }
                return unitPrice * Decimal(draft.reparationQuantities[name] ?? 1)
            }
            return prices.isEmpty ? nil : prices.reduce(0, +)
        case .couleur:
            return catalogItem(type: .typeCouleur, named: draft.typeCouleur)?.price
        case .lavage:
            let name = draft.lavage == "Lavage seul" ? "Lavage"
                : (draft.finition == "Cranté" ? "Lavage coiffage cranté" : "Lavage coiffage")
            return catalogItem(type: .reparation, named: name)?.price
        case .vente, .produit, .coupe:
            return nil
        }
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

    /// Photos déjà téléchargées pendant cette session — en mémoire seulement, rien n'est
    /// écrit sur le téléphone ; iOS peut les vider s'il manque de mémoire.
    private let downloadedPhotos = NSCache<NSString, NSData>()

    func photoNames(transactionID: UUID, kind: PhotoKind) -> [String] {
        let prefix = Self.photoPrefix(transactionID, kind)
        let transaction = clients.lazy.flatMap(\.transactions).first { $0.id == transactionID }
        return (transaction?.photoNames ?? []).filter { $0.hasPrefix(prefix) }
    }

    /// Ajout depuis la fiche : la photo est enregistrée dans la fiche (son nom), puis
    /// envoyée sur Drive.
    func addPhoto(_ rawData: Data, clientID: UUID, transactionID: UUID, kind: PhotoKind) {
        guard var client = client(id: clientID),
              let idx = client.transactions.firstIndex(where: { $0.id == transactionID }) else { return }
        let newPhotos = stagePhotos([rawData], in: &client.transactions[idx], kind: kind)
        persist(client)
        uploadInBackground(newPhotos)
    }

    /// Compresse chaque photo, la garde sur le téléphone le temps de l'envoyer, et ajoute
    /// son nom à la fiche — c'est ce nom, synchronisé avec la fiche, qui indique aux deux
    /// iPhone qu'il y a une photo à télécharger. Retourne les noms à envoyer.
    private func stagePhotos(_ photos: [Data], in transaction: inout AppTransaction, kind: PhotoKind) -> [String] {
        photos.map { rawData in
            let name = nextPhotoName(in: transaction, kind: kind)
            fileStore.stagePendingPhoto(ImageCompressor.compress(rawData), name: name)
            pendingPhotoNames.insert(name)
            transaction.photoNames.append(name)
            return name
        }
    }

    private func uploadInBackground(_ names: [String]) {
        guard !names.isEmpty else { return }
        Task { @MainActor in await uploadPendingPhotos(names) }
    }

    /// Envoie les photos en attente ; une fois confirmée par Drive, la copie du téléphone
    /// est effacée. Celles qui échouent restent en attente jusqu'à la prochaine synchro.
    @MainActor
    private func uploadPendingPhotos(_ names: [String]) async {
        guard DriveConfig.isConfigured else { return }
        for name in names {
            guard let data = fileStore.pendingPhotoData(name: name) else {
                pendingPhotoNames.remove(name)
                continue
            }
            if (try? await DriveBridge.uploadPhoto(name: name, data: data)) != nil {
                fileStore.removePendingPhoto(name: name)
                pendingPhotoNames.remove(name)
            }
        }
    }

    private static func photoPrefix(_ transactionID: UUID, _ kind: PhotoKind) -> String {
        "\(transactionID.uuidString)_\(kind.rawValue)_"
    }

    /// "<id>_avant_3_1a2b3c.jpg" : le petit code au bout évite de réutiliser le nom d'une
    /// photo supprimée (l'autre iPhone pourrait encore l'avoir en mémoire).
    private func nextPhotoName(in transaction: AppTransaction, kind: PhotoKind) -> String {
        let prefix = Self.photoPrefix(transaction.id, kind)
        let indices = transaction.photoNames.compactMap { name -> Int? in
            guard name.hasPrefix(prefix) else { return nil }
            return Int(name.dropFirst(prefix.count).prefix { $0.isNumber })
        }
        let code = UUID().uuidString.prefix(6).lowercased()
        return "\(prefix)\((indices.max() ?? 0) + 1)_\(code).jpg"
    }

    /// Supprime une photo de la fiche (visionneuse ou poubelle de la vignette) : retirée
    /// de la fiche tout de suite, puis mise à la corbeille sur Drive.
    func deletePhoto(name: String, clientID: UUID, transactionID: UUID) {
        updateTransaction(clientID: clientID, transactionID: transactionID) { t in
            t.photoNames.removeAll { $0 == name }
        }
        if pendingPhotoNames.contains(name) {
            fileStore.removePendingPhoto(name: name)
            pendingPhotoNames.remove(name)
        }
        downloadedPhotos.removeObject(forKey: name as NSString)
        guard DriveConfig.isConfigured else { return }
        Task { @MainActor in try? await DriveBridge.deletePhoto(name: name) }
    }

    private func removePhotos(transactionID: UUID) {
        let prefix = "\(transactionID.uuidString)_"
        for name in pendingPhotoNames where name.hasPrefix(prefix) {
            fileStore.removePendingPhoto(name: name)
            pendingPhotoNames.remove(name)
        }
        guard DriveConfig.isConfigured else { return }
        Task { @MainActor in try? await DriveBridge.deletePhotos(transactionID: transactionID) }
    }

    /// Charge une photo pour l'affichage : pas encore envoyée (sur le téléphone) → déjà
    /// téléchargée pendant cette session → téléchargement Drive. `nil` si le
    /// téléchargement a échoué (hors ligne, photo pas encore arrivée sur Drive…) — l'erreur
    /// dit pourquoi.
    func loadPhotoData(name: String) async throws -> Data {
        if let pending = fileStore.pendingPhotoData(name: name) { return pending }
        if let downloaded = downloadedPhotos.object(forKey: name as NSString) { return downloaded as Data }
        guard DriveConfig.isConfigured else { throw DriveError.notConfigured }
        let data = try await DriveBridge.downloadPhoto(name: name)
        downloadedPhotos.setObject(data as NSData, forKey: name as NSString)
        return data
    }
}
