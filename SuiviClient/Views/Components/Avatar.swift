import SwiftUI

/// Vignette carrée 42×42, rayon 14, initiales — utilisée dans les listes de transactions.
struct SquareAvatar: View {
    let initials: String
    let bg: Color
    let fg: Color
    var size: CGFloat = 42

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.thumbnail)
            .fill(bg)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(AppFont.montserrat(14, weight: .semibold))
                    .foregroundStyle(fg)
            )
    }
}

/// Avatar rond — utilisé dans Contacts et la fiche cliente.
struct RoundAvatar: View {
    let initials: String
    let bg: Color
    let fg: Color
    var size: CGFloat = 42

    var body: some View {
        Circle()
            .fill(bg)
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(AppFont.montserrat(size > 40 ? 18 : 14, weight: .semibold))
                    .foregroundStyle(fg)
            )
    }
}

/// Palette d'avatar dérivée du nom — même heuristique que le prototype
/// (couleur de catégorie choisie via la longueur du nom, stable et sans état).
enum AvatarPalette {
    static func colors(for name: String) -> (bg: Color, fg: Color) {
        let categories = Category.allCases
        let index = name.count % categories.count
        let cat = categories[index]
        return (cat.backgroundColor, cat.textColor)
    }
}
