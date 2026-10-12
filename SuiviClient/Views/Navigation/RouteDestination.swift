import SwiftUI

/// Résout une `AppRoute` en vue (pile Accueil). `path` sert à l'écran Contacts pour
/// ouvrir une fiche cliente. `store` est passé explicitement (pas via @Environment) car `TransactionFormView`
/// en a besoin dès son `init` pour préremplir le brouillon en mode édition.
@ViewBuilder
func routeDestination(_ route: AppRoute, path: Binding<[AppRoute]>, store: DataStore) -> some View {
    switch route {
    case .transactionsList:
        TransactionsListView()
    case .transactionDetail(let clientID, let transactionID):
        TransactionDetailView(clientID: clientID, transactionID: transactionID)
    case .newTransactionForm(let name, let phone, let clientID):
        TransactionFormView(mode: .create(prefillName: name, prefillPhone: phone, clientID: clientID), store: store)
    case .editTransactionForm(let clientID, let transactionID):
        TransactionFormView(mode: .edit(clientID: clientID, transactionID: transactionID), store: store)
    case .contacts:
        ContactsView(path: path)
    case .clientDetail(let clientID):
        ClientDetailView(clientID: clientID)
    case .newContact:
        NewContactView()
    }
}
