import SwiftUI

/// Chip capsule générique (filtres, catégories, statuts, options…).
/// Actif : fond `#B88AA2` / texte blanc. Inactif : fond `#FAF7F5` / texte `#6E5F5C` / bordure `#E8DADA`.
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
                    Capsule().fill(isActive ? Theme.Colors.primaryButton : Color(hex: "FAF7F5"))
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
