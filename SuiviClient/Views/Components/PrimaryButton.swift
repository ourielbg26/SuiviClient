import SwiftUI

/// Bouton pleine largeur, rayon 18. Désactivé : fond `#EBDDE3` / texte `#8B7D7A`.
struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.montserrat(15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(isEnabled ? Theme.Colors.primaryButton : Theme.Colors.disabledBg))
                .foregroundStyle(isEnabled ? .white : Theme.Colors.disabledText)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .primaryButtonShadow()
    }
}

/// Bouton capsule compact (ex. "+ Nouvelle fiche" en tête d'Accueil).
struct CapsuleActionButton: View {
    let title: String
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).font(.system(size: 12, weight: .bold))
                Text(title).font(AppFont.montserrat(12, weight: .semibold))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(Capsule().fill(Theme.Colors.primaryButton))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .shadow(color: Theme.Colors.primaryButton.opacity(0.24), radius: 8, x: 0, y: 6)
    }
}
