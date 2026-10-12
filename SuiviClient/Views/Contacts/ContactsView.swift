import SwiftUI

struct ContactsView: View {
    @Binding var path: [AppRoute]
    @Environment(DataStore.self) private var store
    @State private var query = ""

    private var allClients: [Client] {
        store.clients.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var clients: [Client] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allClients }
        return allClients.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    BackButton()
                    Text("Contacts").font(AppFont.display(22, weight: .semibold)).tracking(AppTracking.screenTitle).textCase(.uppercase)
                    Spacer()
                    Text("\(allClients.count) clientes")
                        .font(AppFont.montserrat(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.Colors.textSecondary)
                    TextField("Chercher une cliente…", text: $query).font(AppFont.montserrat(14))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.card))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
            }
            .padding(.horizontal, Theme.Spacing.contentMargin)
            .padding(.top, 6)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 12) {
                    NavigationLink(value: AppRoute.newContact) {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                            Text("Ajouter une cliente")
                        }
                        .font(AppFont.montserrat(14, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.Colors.accentTint))
                        .foregroundStyle(Theme.Colors.accentText)
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 0) {
                        if clients.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Aucune cliente").font(AppFont.montserrat(16, weight: .semibold))
                                Text("Essaie un autre nom.").font(AppFont.montserrat(13)).foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(30)
                        } else {
                            ForEach(clients) { c in
                                NavigationLink(value: AppRoute.clientDetail(clientID: c.id)) {
                                    row(c)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
                    .cardShadow()
                }
                .padding(.horizontal, Theme.Spacing.contentMargin)
                .screenBottomPadding()
            }
            .refreshable { await store.sync() }
        }
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func row(_ c: Client) -> some View {
        let colors = AvatarPalette.colors(for: c.name)
        return HStack(spacing: 12) {
            RoundAvatar(initials: c.initials, bg: colors.bg, fg: colors.fg)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(AppFont.montserrat(15, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
                Text(c.transactions.isEmpty ? "Pas encore de transaction" : "\(c.transactions.count) transaction\(c.transactions.count > 1 ? "s" : "")")
                    .font(AppFont.montserrat(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Text(Formatters.money(c.total)).font(AppFont.montserrat(14, weight: .semibold))
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}
