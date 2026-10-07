import Foundation

/// Une transaction accompagnée du nom/téléphone de sa cliente — la forme "à plat" utilisée
/// par tous les écrans qui mélangent des clientes différentes (Accueil, Transactions, Stats).
/// `@dynamicMemberLookup` renvoie vers `AppTransaction` : `entry.category`, `entry.price`,
/// `entry.status`, etc. marchent directement, comme avant avec le modèle SwiftData.
@dynamicMemberLookup
struct TransactionEntry: Identifiable, Hashable {
    var clientID: UUID
    var clientName: String
    var phone: String
    var transaction: AppTransaction

    var id: UUID { transaction.id }

    subscript<T>(dynamicMember keyPath: KeyPath<AppTransaction, T>) -> T {
        transaction[keyPath: keyPath]
    }

    var firstName: String {
        clientName.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? clientName
    }

    var initials: String {
        let parts = clientName.trimmingCharacters(in: .whitespaces).split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? "?"
        let second = parts.count > 1 ? (parts[1].first.map(String.init) ?? "") : ""
        return (first + second).uppercased()
    }
}
