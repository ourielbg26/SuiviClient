import SwiftUI

/// Petite pastille capsule 10/500 (statut, paiement…).
struct Pill: View {
    let label: String
    let bg: Color
    let fg: Color

    var body: some View {
        Text(label)
            .font(AppFont.montserrat(10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
    }
}

struct StatusPill: View {
    let status: WorkStatus
    var body: some View { Pill(label: status.rawValue, bg: status.backgroundColor, fg: status.textColor) }
}

struct PaymentPill: View {
    let payState: PayState

    private var label: String {
        switch payState {
        case .paye: return "Payé"
        case .echelonne: return "En cours de paiement"
        case .impaye: return "Impayé"
        }
    }

    private var colors: (bg: Color, fg: Color) {
        switch payState {
        case .paye: return (Theme.Colors.paidBg, Theme.Colors.paidText)
        case .echelonne: return (Theme.Colors.installmentBg, Theme.Colors.installmentText)
        case .impaye: return (Theme.Colors.unpaidBg, Theme.Colors.unpaidText)
        }
    }

    var body: some View { Pill(label: label, bg: colors.bg, fg: colors.fg) }
}

struct LateBadge: View {
    var body: some View {
        Text("Retard")
            .font(AppFont.montserrat(10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.Colors.lateAlert))
            .foregroundStyle(.white)
    }
}
