import SwiftUI

/// Chip capsule générique (filtres, catégories, statuts, options…).
/// Actif : fond encre / texte blanc. Inactif : fond crème / texte brun / bordure rose fine.
struct ChipButton: View {
    let label: String
    let isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.montserrat(12, weight: .medium))
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(isActive ? Theme.Colors.primaryButton : Theme.Colors.chipInactiveBg)
                )
                .overlay(
                    Capsule().strokeBorder(isActive ? Color.clear : Theme.Colors.border, lineWidth: 1)
                )
                .foregroundStyle(isActive ? .white : Theme.Colors.chipInactiveText)
        }
        .buttonStyle(.plain)
    }
}

/// Chip retirable (croix) — utilisé pour les sélections multiples du formulaire.
struct RemovableChip: View {
    let label: String
    let bg: Color
    let fg: Color
    var onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 7) {
                Text(label)
                    .font(AppFont.montserrat(12, weight: .semibold))
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
        }
        .buttonStyle(.plain)
    }
}
