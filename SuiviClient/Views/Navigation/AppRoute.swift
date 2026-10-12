import Foundation

/// Toutes les destinations push de la pile Accueil (Contacts compris)
/// (§5 du README : la fiche transaction est atteignable depuis les deux, et
/// le retour doit revenir à l'écran d'origine — géré nativement par la pile).
/// On route par identifiants (pas par objet) : la vue relit toujours l'état
/// courant depuis `DataStore`, donc elle reste à jour après une modification.
enum AppRoute: Hashable {
    case transactionsList
    case transactionDetail(clientID: UUID, transactionID: UUID)
    case newTransactionForm(prefillName: String, prefillPhone: String, clientID: UUID? = nil)
    case editTransactionForm(clientID: UUID, transactionID: UUID)
    case contacts
    case clientDetail(clientID: UUID)
    case newContact
}
