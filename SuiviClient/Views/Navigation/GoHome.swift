import SwiftUI

/// Ramène au menu principal (Accueil, pile vidée) — après l'enregistrement d'une fiche
/// ou un changement de statut / paiement. Fourni par `RootView`.
struct GoHomeAction {
    let action: () -> Void
    func callAsFunction() { action() }
}

private struct GoHomeKey: EnvironmentKey {
    static let defaultValue = GoHomeAction {}
}

extension EnvironmentValues {
    var goHome: GoHomeAction {
        get { self[GoHomeKey.self] }
        set { self[GoHomeKey.self] = newValue }
    }
}
