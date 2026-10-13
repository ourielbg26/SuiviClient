import Foundation

/// Une cliente : un fichier JSON (`Clients/<id>.json`) contenant ses coordonnées et
/// TOUTES ses transactions. Un fichier par cliente plutôt qu'une grosse base commune,
/// pour que deux iPhone qui modifient des clientes différentes en même temps (via un
/// dossier partagé, ex. Google Drive) ne se marchent pas dessus.
struct Client: Identifiable, Codable {
    var id: UUID
    var name: String
    var phone: String
    /// true si elle a été ajoutée explicitement via "Ajouter une cliente" (ou le "Oui" du
    /// formulaire) — dans ce cas elle reste dans Contacts même si on supprime sa dernière
    /// transaction. Sinon, une cliente sans aucune transaction est effacée automatiquement.
    var isSavedContact: Bool
    var transactions: [AppTransaction]
    var updatedAt: Date
    /// Compteur incrémenté à chaque écriture — sert à détecter qu'un autre appareil a
    /// modifié ce fichier depuis notre dernière lecture (voir `FileStore`).
    var version: Int
    /// Doublon fusionné dans une autre cliente : le fichier reste sur Drive (vide), pour
    /// qu'aucun iPhone ne le renvoie, mais l'app ne l'affiche plus (voir `DataStore`).
    var mergedInto: UUID?

    init(id: UUID = UUID(), name: String, phone: String, isSavedContact: Bool = true,
         transactions: [AppTransaction] = [], updatedAt: Date = .now, version: Int = 0) {
        self.id = id
        self.name = name
        self.phone = phone
        self.isSavedContact = isSavedContact
        self.transactions = transactions
        self.updatedAt = updatedAt
        self.version = version
    }

    var total: Decimal { transactions.reduce(0) { $0 + $1.price } }
    var unpaidTotal: Decimal { transactions.filter { !$0.isPaid }.reduce(0) { $0 + $1.price } }

    var initials: String {
        let parts = name.trimmingCharacters(in: .whitespaces).split(separator: " ")
        let a = parts.first?.first.map(String.init) ?? "?"
        let b = parts.count > 1 ? (parts[1].first.map(String.init) ?? "") : ""
        return (a + b).uppercased()
    }
}
