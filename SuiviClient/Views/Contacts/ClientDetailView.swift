import SwiftUI

struct ClientDetailView: View {
    let clientID: UUID
    @Environment(DataStore.self) private var store

    private var client: Client {
        store.client(id: clientID) ?? Client(id: clientID, name: "—", phone: "—")
    }

    private var rows: [TransactionEntry] {
        client.transactions
            .sorted(by: AppTransaction.byArrivalNewestFirst)
            .map { TransactionEntry(clientID: client.id, clientName: client.name, phone: client.phone, transaction: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BackButton()
                Text("Fiche cliente")
                    .font(AppFont.montserrat(12, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.contentMargin)
            .padding(.top, 6)
            .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            let colors = AvatarPalette.colors(for: client.name)
                            RoundAvatar(initials: client.initials, bg: colors.bg, fg: colors.fg, size: 56)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(client.name)
                                    .font(AppFont.display(22, weight: .bold))
                                    .tracking(AppTracking.clientName)
                                Text(client.phone)
                                    .font(AppFont.montserrat(13))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                        HStack(spacing: 8) {
                            tile("Total dépensé", Formatters.money(client.total))
                            tile("Travaux", "\(client.transactions.count)")
                            tile("Dernier", rows.first.map { Formatters.shortDate($0.dropDate) } ?? "—")
                        }
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
                    .cardShadow()

                    HStack(alignment: .lastTextBaseline) {
                        Text("Historique").font(AppFont.display(16, weight: .semibold))
                        Spacer()
                        Text(client.unpaidTotal > 0 ? "\(Formatters.money(client.unpaidTotal)) en attente" : "Tout est payé")
                            .font(AppFont.montserrat(12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        if rows.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Pas encore de transaction").font(AppFont.montserrat(15, weight: .semibold))
                                Text("Crée une fiche pour cette cliente.").font(AppFont.montserrat(13)).foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(26)
                        } else {
                            ForEach(rows) { t in
                                NavigationLink(value: AppRoute.transactionDetail(clientID: client.id, transactionID: t.id)) {
                                    ClientHistoryRow(transaction: t)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
                    .cardShadow()

                    NavigationLink(value: AppRoute.newTransactionForm(prefillName: client.name == "—" ? "" : client.name, prefillPhone: client.phone == "—" ? "" : client.phone)) {
                        HStack(spacing: 9) {
                            Image(systemName: "plus")
                            Text("Nouvelle transaction")
                        }
                        .font(AppFont.montserrat(15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.Colors.primaryButton))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .primaryButtonShadow()
                }
                .padding(.horizontal, Theme.Spacing.contentMargin)
                .screenBottomPadding()
            }
        }
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(AppFont.montserrat(11, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
            Text(value).font(AppFont.montserrat(16, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.secondaryBackground))
    }
}
