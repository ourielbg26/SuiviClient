import SwiftUI

/// Statistiques → toucher le total encaissé : les fiches qui forment ce chiffre, avec
/// pour chacune ce qui a été reçu pendant la période (paiement, acompte, mensualité…).
struct CashBreakdownView: View {
    let interval: DateInterval
    let title: String

    @Environment(DataStore.self) private var store

    private struct Line: Identifiable {
        let entry: TransactionEntry
        let payments: [AppTransaction.Payment]
        var id: UUID { entry.id }
        var amount: Decimal { payments.reduce(0) { $0 + $1.amount } }
        var lastDate: Date { payments.map(\.date).max() ?? entry.dropDate }
    }

    private var lines: [Line] {
        store.allEntries
            .map { Line(entry: $0, payments: $0.transaction.payments(in: interval).sorted { $0.date < $1.date }) }
            .filter { !$0.payments.isEmpty }
            .sorted { $0.lastDate > $1.lastDate }
    }

    var body: some View {
        let lines = self.lines
        let total = lines.reduce(0) { $0 + $1.amount }
        VStack(spacing: 0) {
            ScreenHeader(title: "Encaissé")

            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(title) · \(lines.count) fiche\(lines.count > 1 ? "s" : "")")
                            .font(AppFont.montserrat(13, weight: .medium))
                            .foregroundStyle(.white)
                        Text(Formatters.money(total))
                            .font(AppFont.display(38, weight: .bold))
                            .tracking(AppTracking.bigNumber)
                            .foregroundStyle(.white)
                        Text("Une vente en plusieurs fois compte ici seulement la mensualité de la période.")
                            .font(AppFont.montserrat(11))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.statCard).fill(Theme.Colors.primaryButton))
                    .statCardShadow()

                    VStack(spacing: 0) {
                        if lines.isEmpty {
                            Text("Rien d'encaissé sur cette période.")
                                .font(AppFont.montserrat(13))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(24)
                        } else {
                            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                                NavigationLink(value: AppRoute.transactionDetail(clientID: line.entry.clientID, transactionID: line.entry.id)) {
                                    row(line)
                                }
                                .buttonStyle(.plain)
                                .overlay(alignment: .top) {
                                    if index > 0 { Rectangle().fill(Theme.Colors.separator).frame(height: 1) }
                                }
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
                    .cardShadow()
                }
                .padding(.horizontal, Theme.Spacing.contentMargin)
                .padding(.bottom, 32)
            }
        }
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func row(_ line: Line) -> some View {
        let e = line.entry
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                SquareAvatar(initials: e.initials, bg: e.swatch.bg, fg: e.swatch.fg)
                VStack(alignment: .leading, spacing: 3) {
                    Text(e.clientName)
                        .font(AppFont.montserrat(15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(e.item)
                        .font(AppFont.montserrat(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(Formatters.money(line.amount))
                        .font(AppFont.montserrat(15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if line.amount != e.price {
                        Text("sur \(Formatters.money(e.price))")
                            .font(AppFont.montserrat(11))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(line.payments.enumerated()), id: \.offset) { _, p in
                    HStack {
                        Text("\(p.label) · \(Formatters.shortDate(p.date))")
                        Spacer()
                        Text(Formatters.money(p.amount))
                    }
                    .font(AppFont.montserrat(11))
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(.leading, 56)
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}
