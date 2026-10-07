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
// Embarque Playfair Display (600/700) et Montserrat (400/500/600) — voir Fonts/README.md.

enum AppFont {
    static func playfair(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name = weight == .semibold ? "PlayfairDisplay-SemiBold" : "PlayfairDisplay-Bold"
        return .custom(name, size: size)
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
    static let bigNumber: CGFloat = -1.2   // -.035em @ 44pt
    static let heroAmount: CGFloat = -1.0  // -.035em @ 38pt
    static let screenTitle: CGFloat = -0.4 // -.02em @ ~22pt
    static let clientName: CGFloat = -0.45
}

// MARK: - Design tokens

enum Theme {
    enum Colors {
        static let background = Color(hex: "FAF7F5")
        static let card = Color.white
        static let secondaryBackground = Color(hex: "F7EDEF")
        static let tabBackground = Color(hex: "F1E6E8")
        static let pressedSecondary = Color(hex: "EFE0E4")
        static let separator = Color(hex: "F2E7E9")
        static let border = Color(hex: "E8DADA")
        static let dashedBorder = Color(hex: "DFC9D2")

        static let textPrimary = Color(hex: "3A2E2B")
        static let textSecondary = Color(hex: "8B7D7A")
        static let chipInactiveText = Color(hex: "6E5F5C")

        static let primaryButton = Color(hex: "B88AA2")
        static let primaryButtonPressed = Color(hex: "A77791")
        static let accentTint = Color(hex: "F3E3EA")
        static let accentTintPressed = Color(hex: "DCB6C8")
        static let accentText = Color(hex: "8A5F79")

        static let disabledBg = Color(hex: "EBDDE3")
        static let disabledText = Color(hex: "8B7D7A")

        static let photoStripeA = Color(hex: "EFE2E5")
        static let photoStripeB = Color(hex: "FAF5F6")

        // Statut du travail
        static let statusEnCoursDot = Color(hex: "F0B77E")
        static let statusEnCoursBg = Color(hex: "FDEFE0")
        static let statusEnCoursText = Color(hex: "A9702F")
        static let statusPretDot = Color(hex: "A7C9B4")
        static let statusPretBg = Color(hex: "E7F1EB")
        static let statusPretText = Color(hex: "4F7E66")
        static let statusRenduDot = Color(hex: "D9D9D9")
        static let statusRenduBg = Color(hex: "EFEFEF")
        static let statusRenduText = Color(hex: "6B6B6B")
        static let statusRetourDot = Color(hex: "D67B7B")
        static let statusRetourBg = Color(hex: "F7E3E3")
        static let statusRetourText = Color(hex: "A85252")

        // Paiement
        static let paidBg = Color(hex: "E4F0EA")
        static let paidText = Color(hex: "3F7A5F")
        static let installmentBg = Color(hex: "FAF1DE")
        static let installmentText = Color(hex: "8A6B24")
        static let unpaidBg = Color(hex: "F7E3E3")
        static let unpaidText = Color(hex: "A85252")
        static let lateAlert = Color(hex: "D67B7B")
        static let lateAlertText = Color(hex: "8F4444")

        // Catégories
        static let venteLine = Color(hex: "C79BC8")
        static let venteBg = Color(hex: "F3E6F3")
        static let venteText = Color(hex: "7E5480")
        static let reparationLine = Color(hex: "E1A487")
        static let reparationBg = Color(hex: "FAEAE2")
        static let reparationText = Color(hex: "9C5F44")
        static let couleurLine = Color(hex: "C89CB8")
        static let couleurBg = Color(hex: "F5E7EF")
        static let couleurText = Color(hex: "8A5F79")
        static let lavageLine = Color(hex: "9CC9E8")
        static let lavageBg = Color(hex: "E7F1F9")
        static let lavageText = Color(hex: "3F6B87")
        static let produitLine = Color(hex: "B9A7D9")
        static let produitBg = Color(hex: "EEE9F7")
        static let produitText = Color(hex: "5F5288")
        static let coupeLine = Color(hex: "D9B45C")
        static let coupeBg = Color(hex: "F7F0DD")
        static let coupeText = Color(hex: "8A6D2F")
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
        content.shadow(color: Color(hex: "3A2E2B").opacity(0.06), radius: 1, x: 0, y: 1)
    }
}

struct PrimaryButtonShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color(hex: "B88AA2").opacity(0.26), radius: 10, x: 0, y: 8)
    }
}

struct StatCardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color(hex: "B88AA2").opacity(0.30), radius: 13, x: 0, y: 10)
    }
}

struct TabBarShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color(hex: "3A2E2B").opacity(0.16), radius: 15, x: 0, y: 12)
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
