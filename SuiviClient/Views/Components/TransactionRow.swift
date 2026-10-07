import SwiftUI

/// Ligne d'Accueil (par statut) : vignette, nom, libellé, sous-titre coloré, montant [+ badge Retard].
struct HomeTransactionRow: View {
    let transaction: TransactionEntry
    let metaText: String
    let metaColor: Color
    let showLateBadge: Bool

    var body: some View {
        HStack(spacing: 12) {
            SquareAvatar(initials: transaction.initials, bg: transaction.swatch.bg, fg: transaction.swatch.fg)
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.clientName)
                    .font(AppFont.montserrat(15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(transaction.item)
                    .font(AppFont.montserrat(12, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                Text(metaText)
                    .font(AppFont.montserrat(11, weight: .medium))
                    .foregroundStyle(metaColor)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                Text(Formatters.money(transaction.price))
                    .font(AppFont.montserrat(15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                if showLateBadge {
                    LateBadge()
                }
            }
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}

/// Ligne de la liste complète des transactions : vignette, nom, libellé, pastilles, montant, date.
struct FullTransactionRow: View {
    let transaction: TransactionEntry

    var body: some View {
        HStack(spacing: 12) {
            SquareAvatar(initials: transaction.initials, bg: transaction.swatch.bg, fg: transaction.swatch.fg)
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.clientName)
                    .font(AppFont.montserrat(15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(transaction.item)
                    .font(AppFont.montserrat(12, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    StatusPill(status: transaction.status)
                    PaymentPill(payState: transaction.payState)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                Text(Formatters.money(transaction.price))
                    .font(AppFont.montserrat(15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(Formatters.shortDate(transaction.dropDate))
                    .font(AppFont.montserrat(11, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}

/// Ligne de l'historique d'une cliente : barre verticale colorée au lieu de la vignette.
struct ClientHistoryRow: View {
    let transaction: TransactionEntry

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(transaction.swatch.bg == Theme.Colors.lateAlert ? Theme.Colors.lateAlert : transaction.swatch.bg)
                .frame(width: 8, height: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.item)
                    .font(AppFont.montserrat(14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    StatusPill(status: transaction.status)
                    PaymentPill(payState: transaction.payState)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.money(transaction.price))
                    .font(AppFont.montserrat(14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(Formatters.shortDate(transaction.dropDate))
                    .font(AppFont.montserrat(11, weight: .regular))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}
