import SwiftUI

private enum PayFilter: String, CaseIterable { case tous = "Tous", paye = "Payé", impaye = "Impayé" }
private enum PeriodFilter: String, CaseIterable { case tout = "Tout", semaine = "Cette semaine", mois = "Ce mois", troisMois = "3 derniers mois", periode = "Période…" }

struct TransactionsListView: View {
    @Environment(DataStore.self) private var store

    @State private var query = ""
    @State private var showFilters = false
    @State private var fPay: PayFilter = .tous
    @State private var fStatus: WorkStatus?
    @State private var fCategory: Category?
    @State private var fPeriod: PeriodFilter = .tout
    @State private var customFrom = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var customTo = Date.now

    private var all: [TransactionEntry] { store.allEntries.sorted { AppTransaction.byArrivalNewestFirst($0.transaction, $1.transaction) } }

    private var filtered: [TransactionEntry] {
        all.filter { t in
            let q = query.trimmingCharacters(in: .whitespaces).lowercased()
            let matchesQuery = q.isEmpty || t.clientName.lowercased().contains(q) || t.item.lowercased().contains(q) || t.note.lowercased().contains(q)
            let matchesPay: Bool
            switch fPay {
            case .tous: matchesPay = true
            case .paye: matchesPay = t.isPaid
            case .impaye: matchesPay = !t.isPaid
            }
            let matchesStatus = fStatus == nil || fStatus == t.status
            let matchesCategory = fCategory == nil || fCategory == t.category
            let matchesPeriod: Bool
            switch fPeriod {
            case .tout: matchesPeriod = true
            case .semaine: matchesPeriod = Formatters.days(from: t.dropDate) <= 7
            case .mois: matchesPeriod = Calendar.current.isDate(t.dropDate, equalTo: .now, toGranularity: .month)
            case .troisMois: matchesPeriod = Formatters.days(from: t.dropDate) <= 92
            case .periode:
                let start = Calendar.current.startOfDay(for: customFrom)
                let end = Calendar.current.startOfDay(for: customTo)
                matchesPeriod = t.dropDate >= start && t.dropDate <= end
            }
            return matchesQuery && matchesPay && matchesStatus && matchesCategory && matchesPeriod
        }
    }

    private var total: Decimal { filtered.reduce(0) { $0 + $1.price } }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Transactions")

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.Colors.textSecondary)
                        TextField("Nom, prestation, note…", text: $query)
                            .font(AppFont.montserrat(14))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(.white))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))

                    Button {
                        showFilters.toggle()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "line.3.horizontal.decrease")
                            Text(showFilters ? "Fermer" : "Filtrer")
                        }
                        .font(AppFont.montserrat(13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(showFilters ? Theme.Colors.primaryButton : .white))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(showFilters ? Color.clear : Theme.Colors.border, lineWidth: 1))
                        .foregroundStyle(showFilters ? .white : Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.contentMargin)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 12) {
                    if showFilters {
                        filterPanel
                    }

                    HStack(alignment: .lastTextBaseline) {
                        Text("\(filtered.count) résultat\(filtered.count > 1 ? "s" : "")")
                            .font(AppFont.montserrat(13, weight: .semibold))
                        Spacer()
                        Text(Formatters.money(total))
                            .font(AppFont.montserrat(12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        if filtered.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Aucun résultat").font(AppFont.montserrat(16, weight: .semibold))
                                Text("Essaie un autre nom ou enlève un filtre.")
                                    .font(AppFont.montserrat(13))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(32)
                        } else {
                            ForEach(filtered) { t in
                                NavigationLink(value: AppRoute.transactionDetail(clientID: t.clientID, transactionID: t.id)) {
                                    FullTransactionRow(transaction: t)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(.white))
                    .cardShadow()
                }
                .padding(.horizontal, Theme.Spacing.contentMargin)
                .screenBottomPadding()
            }
            .refreshable { await store.sync() }
        }
        .background(Theme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            filterGroup("Paiement", options: PayFilter.allCases.map(\.rawValue), isActive: { $0 == fPay.rawValue }) { label in
                fPay = PayFilter(rawValue: label) ?? .tous
            }
            filterGroup("Statut du travail", options: ["Tous"] + WorkStatus.allCases.map(\.rawValue), isActive: { $0 == (fStatus?.rawValue ?? "Tous") }) { label in
                fStatus = WorkStatus(rawValue: label)
            }
            filterGroup("Catégorie", options: ["Tous"] + Category.allCases.map(\.rawValue), isActive: { $0 == (fCategory?.rawValue ?? "Tous") }) { label in
                fCategory = Category(rawValue: label)
            }
            filterGroup("Période", options: PeriodFilter.allCases.map(\.rawValue), isActive: { $0 == fPeriod.rawValue }) { label in
                fPeriod = PeriodFilter(rawValue: label) ?? .tout
            }

            if fPeriod == .periode {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Du").font(AppFont.montserrat(11, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                        DatePicker("", selection: $customFrom, displayedComponents: .date)
                            .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Au").font(AppFont.montserrat(11, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                        DatePicker("", selection: $customTo, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.background))
            }

            Button("Réinitialiser") {
                fPay = .tous; fStatus = nil; fCategory = nil; fPeriod = .tout; query = ""
            }
            .font(AppFont.montserrat(13, weight: .semibold))
            .foregroundStyle(Theme.Colors.primaryButtonPressed)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.Colors.border, lineWidth: 1))
    }

    private func filterGroup(_ label: String, options: [String], isActive: @escaping (String) -> Bool, select: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
            FlowLayout(spacing: 7) {
                ForEach(options, id: \.self) { opt in
                    ChipButton(label: opt, isActive: isActive(opt)) { select(opt) }
                }
            }
        }
    }
}
