import SwiftUI

/// Résout une `AppRoute` en vue — partagé par la pile Accueil et la pile Contacts.
/// `path` est transmis au formulaire : à l'enregistrement il remplace sa propre entrée
/// par la fiche transaction, pour que "retour" revienne à l'écran d'origine (§6.4).
/// `store` est passé explicitement (pas via @Environment) car `TransactionFormView`
/// en a besoin dès son `init` pour préremplir le brouillon en mode édition.
@ViewBuilder
func routeDestination(_ route: AppRoute, path: Binding<[AppRoute]>, store: DataStore) -> some View {
    switch route {
    case .transactionsList:
        TransactionsListView()
    case .transactionDetail(let clientID, let transactionID):
        TransactionDetailView(clientID: clientID, transactionID: transactionID)
    case .newTransactionForm(let name, let phone):
        TransactionFormView(mode: .create(prefillName: name, prefillPhone: phone), path: path, store: store)
    case .editTransactionForm(let clientID, let transactionID):
        TransactionFormView(mode: .edit(clientID: clientID, transactionID: transactionID), path: path, store: store)
    case .clientDetail(let clientID):
        ClientDetailView(clientID: clientID)
    case .newContact:
        NewContactView()
    }
}
