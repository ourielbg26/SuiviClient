import SwiftUI

// MARK: - Hex color helper

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Fonts
// Titres : Cormorant Garamond (400/500/600), serif fin proche du « NAOMIE » du logo.
// Texte : Montserrat (400/500/600). Licences OFL dans Fonts/.

enum AppFont {
    /// Serif des titres et montants. Cormorant dessine plus petit que la plupart des
    /// polices à taille égale : la taille est agrandie pour garder la même présence.
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "CormorantGaramond-SemiBold"
        case .semibold, .medium: name = "CormorantGaramond-Medium"
        default: name = "CormorantGaramond-Regular"
        }
        return .custom(name, size: size * 1.18)
    }

    static func montserrat(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .semibold, .bold: name = "Montserrat-SemiBold"
        case .medium: name = "Montserrat-Medium"
        default: name = "Montserrat-Regular"
        }
        return .custom(name, size: size)
    }
}

// Tracking (letter-spacing) approximatif des tailles clé, en pt.
enum AppTracking {
    static let bigNumber: CGFloat = -0.4
    static let heroAmount: CGFloat = -0.3
    /// Titres d'écran en capitales espacées, comme « N A O M I E » sur le logo.
    static let screenTitle: CGFloat = 3
    static let clientName: CGFloat = 0.2
}

// MARK: - Design tokens

enum Theme {
    /// Palette tirée du logo : papier aquarelle rose, encre noire, rose poudré.
    enum Colors {
        static let background = Color(hex: "FBF1EE")
        /// Lavis plus soutenu du fond aquarelle (`PaperBackground`).
        static let watercolor = Color(hex: "EFC6BC")
        static let card = Color(hex: "FFFCFB")
        static let secondaryBackground = Color(hex: "F7E6E1")
        static let tabBackground = Color(hex: "F4E1DC")
        static let pressedSecondary = Color(hex: "F0D8D2")
        static let separator = Color(hex: "F2E2DE")
        static let border = Color(hex: "EAD2CC")
        static let dashedBorder = Color(hex: "D9B6AE")

        static let textPrimary = Color(hex: "2B2422")
        static let textSecondary = Color(hex: "8E7A75")
        static let chipInactiveText = Color(hex: "6B5A56")
        static let chipInactiveBg = Color(hex: "FFFCFB")

        /// Encre : boutons principaux et choix actifs, comme le trait du logo.
        static let primaryButton = Color(hex: "2B2422")
        /// Rose profond des liens ("Voir tout", "Voir la fiche…").
        static let primaryButtonPressed = Color(hex: "A8655C")
        static let accentTint = Color(hex: "F6E0DA")
        static let accentTintPressed = Color(hex: "E7C2B9")
        static let accentText = Color(hex: "A2625A")

        static let disabledBg = Color(hex: "EFDCD7")
        static let disabledText = Color(hex: "9C8A86")

        static let photoStripeA = Color(hex: "F4E2DD")
        static let photoStripeB = Color(hex: "FBF3F1")

        // Statut du travail
        static let statusEnCoursDot = Color(hex: "E9B07C")
        static let statusEnCoursBg = Color(hex: "FCEEE2")
        static let statusEnCoursText = Color(hex: "A06B34")
        static let statusPretDot = Color(hex: "A3C2AE")
        static let statusPretBg = Color(hex: "E8F0EA")
        static let statusPretText = Color(hex: "4D7A62")
        static let statusRenduDot = Color(hex: "D6CCCA")
        static let statusRenduBg = Color(hex: "F0EBEA")
        static let statusRenduText = Color(hex: "6E6361")
        static let statusRetourDot = Color(hex: "D47C78")
        static let statusRetourBg = Color(hex: "F8E2E0")
        static let statusRetourText = Color(hex: "A44F4B")

        // Paiement
        static let paidBg = Color(hex: "E5EFE8")
        static let paidText = Color(hex: "3E765C")
        static let installmentBg = Color(hex: "F9EFDD")
        static let installmentText = Color(hex: "86682A")
        static let unpaidBg = Color(hex: "F8E2E0")
        static let unpaidText = Color(hex: "A44F4B")
        static let lateAlert = Color(hex: "D47C78")
        static let lateAlertText = Color(hex: "8C4441")

        // Catégories — tons poudrés accordés au rose du fond
        static let venteLine = Color(hex: "BC8DB2")
        static let venteBg = Color(hex: "F4E6F0")
        static let venteText = Color(hex: "7A5070")
        static let reparationLine = Color(hex: "DCA088")
        static let reparationBg = Color(hex: "FAE8E0")
        static let reparationText = Color(hex: "985C43")
        static let couleurLine = Color(hex: "D49A98")
        static let couleurBg = Color(hex: "F8E5E3")
        static let couleurText = Color(hex: "975856")
        static let lavageLine = Color(hex: "9DBBCF")
        static let lavageBg = Color(hex: "E8F0F5")
        static let lavageText = Color(hex: "45677C")
        static let produitLine = Color(hex: "B3A3CF")
        static let produitBg = Color(hex: "EFEAF6")
        static let produitText = Color(hex: "5E5385")
        static let coupeLine = Color(hex: "D6B260")
        static let coupeBg = Color(hex: "F7F0DD")
        static let coupeText = Color(hex: "86692D")
    }

    enum Radius {
        static let card: CGFloat = 24
        static let hero: CGFloat = 26
        static let statCard: CGFloat = 26
        static let button: CGFloat = 18
        static let field: CGFloat = 15
        static let innerTile: CGFloat = 16
        static let photoSlot: CGFloat = 18
        static let backButton: CGFloat = 12
        static let thumbnail: CGFloat = 14
        static let tabBar: CGFloat = 30
    }

    enum Spacing {
        static let contentMargin: CGFloat = 16
        static let cardPadding: CGFloat = 20
        static let cardGap: CGFloat = 12
        static let bottomPadding: CGFloat = 96
    }

    enum Shadows {
        // radius ≈ blur css / 2
        static func card<S: Shape>(_ shape: S) -> some View {
            shape.fill(Color.clear)
        }
    }
}

// MARK: - View helpers for shadows (utilisés via .modifier)

struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color(hex: "B97A6E").opacity(0.10), radius: 12, x: 0, y: 5)
    }
}

struct PrimaryButtonShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Theme.Colors.primaryButton.opacity(0.18), radius: 10, x: 0, y: 6)
    }
}

struct StatCardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Theme.Colors.primaryButton.opacity(0.22), radius: 14, x: 0, y: 10)
    }
}

struct TabBarShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color(hex: "B97A6E").opacity(0.20), radius: 16, x: 0, y: 10)
    }
}

/// Fond "papier aquarelle" inspiré du logo : rose pâle et quelques lavis plus soutenus.
struct PaperBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Theme.Colors.background
                wash(size: w * 0.95, opacity: 0.55).position(x: w * 0.08, y: h * 0.06)
                wash(size: w * 0.75, opacity: 0.32).position(x: w * 0.98, y: h * 0.42)
                wash(size: w * 1.05, opacity: 0.40).position(x: w * 0.25, y: h * 0.97)
            }
        }
        .drawingGroup()
        .ignoresSafeArea()
    }

    private func wash(size: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(Theme.Colors.watercolor.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: size * 0.22)
    }
}

extension View {
    func cardShadow() -> some View { modifier(CardShadow()) }
    func primaryButtonShadow() -> some View { modifier(PrimaryButtonShadow()) }
    func statCardShadow() -> some View { modifier(StatCardShadow()) }
    func tabBarShadow() -> some View { modifier(TabBarShadow()) }

    /// Padding bas standard (96pt) pour laisser la place à la barre d'onglets flottante.
    func screenBottomPadding() -> some View {
        padding(.bottom, Theme.Spacing.bottomPadding)
    }
}
