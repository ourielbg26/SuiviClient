import SwiftUI

struct HomeView: View {
    @Binding var path: [AppRoute]
    @Environment(DataStore.self) private var store
    @State private var expanded: Set<String> = []

    private var allEntries: [TransactionEntry] { store.allEntries.sorted { $0.dropDate < $1.dropDate } }
    private var enCours: [TransactionEntry] { allEntries.filter { $0.status == .enCours } }
    private var pret: [TransactionEntry] { allEntries.filter { $0.status == .pret || $0.status == .retour } }
    /// Rendu sans être payé, ou paiement en espèces avec une mensualité en retard.
    private var impaye: [TransactionEntry] {
        allEntries.filter { $0.plan == nil ? ($0.status == .rendu && !$0.isPaid) : $0.payState == .impaye }
    }
    private var echelonne: [TransactionEntry] { allEntries.filter { $0.plan != nil && $0.payState == .echelonne } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Atelier")
                        .font(AppFont.display(24, weight: .semibold))
                        .tracking(AppTracking.screenTitle)
                        .textCase(.uppercase)
                    Spacer()
                    CapsuleActionButton(title: "Nouvelle fiche", systemImage: "plus") {
                        path.append(.newTransactionForm(prefillName: "", prefillPhone: ""))
                    }
                }

                section(key: "enCours", title: "En cours", dot: Theme.Colors.statusEnCoursDot, items: enCours,
                        emptyLabel: "Rien en atelier.") { t in
                    let d = t.ageDays
                    return ("\(t.category == .vente ? "Commandé" : "Déposé") le \(Formatters.shortDate(t.dropDate)) · \(d) j", d > 14 ? Theme.Colors.unpaidText : Theme.Colors.textSecondary, false)
                }

                section(key: "pret", title: "Prêt à rendre", dot: Theme.Colors.statusPretDot, items: pret,
                        emptyLabel: "Rien à rendre.") { t in
                    if t.status == .retour, let r = t.returnDate {
                        return ("Retour reçu le \(Formatters.shortDate(r))", Theme.Colors.unpaidText, false)
                    }
                    return ("Prêt · \(t.category == .vente ? "commandé" : "déposé") le \(Formatters.shortDate(t.dropDate))", Theme.Colors.statusPretText, false)
                }

                section(key: "impaye", title: "Non payé", dot: Theme.Colors.statusRetourDot, items: impaye,
                        emptyLabel: "Tout est réglé.") { t in
                    if t.plan != nil, let left = t.planLeft {
                        let since = t.nextInstallmentDate.map { " depuis le \(Formatters.shortDate($0))" } ?? ""
                        return ("Mensualité en retard\(since) · reste \(Formatters.money(left))", Theme.Colors.unpaidText, true)
                    }
                    let label = t.pickupDate.map { "Rendu le \(Formatters.shortDate($0))" } ?? "Rendu"
                    return (label, Theme.Colors.unpaidText, false)
                }

                section(key: "echeance", title: "En cours de paiement", dot: Color(hex: "D6B76E"), items: echelonne,
                        emptyLabel: "Aucun paiement échelonné.") { t in
                    guard let plan = t.plan, let left = t.planLeft else { return ("", Theme.Colors.textSecondary, false) }
                    let late = t.planIsLate
                    let next = t.nextInstallmentDate.map { " · \(Formatters.shortDate($0))" } ?? ""
                    let text = "Reste \(Formatters.money(left)) · \(plan.method.rawValue.lowercased())\(next)"
                    return (text, late ? Theme.Colors.unpaidText : Theme.Colors.installmentText, late)
                }

                Button {
                    path.append(.transactionsList)
                } label: {
                    HStack {
                        Text("Toutes les transactions")
                            .font(AppFont.montserrat(14, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text("\(allEntries.count) →")
                            .font(AppFont.montserrat(13, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.Colors.card))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).strokeBorder(Theme.Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.contentMargin)
            .padding(.top, 8)
            .screenBottomPadding()
        }
        .refreshable { await store.sync() }
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func section(key: String, title: String, dot: Color, items: [TransactionEntry], emptyLabel: String,
                          meta: @escaping (TransactionEntry) -> (String, Color, Bool)) -> some View {
        let isOpen = expanded.contains(key)
        let shown = isOpen ? items : Array(items.prefix(5))

        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Circle().fill(dot).frame(width: 9, height: 9)
                Text(title)
                    .font(AppFont.display(17, weight: .semibold))
                Spacer()
                if !items.isEmpty {
                    Text("\(items.count)")
                        .font(AppFont.montserrat(12, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                if items.isEmpty {
                    Text(emptyLabel)
                        .font(AppFont.montserrat(13, weight: .regular))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(shown) { t in
                        let (text, color, late) = meta(t)
                        Button {
                            path.append(.transactionDetail(clientID: t.clientID, transactionID: t.id))
                        } label: {
                            HomeTransactionRow(transaction: t, metaText: text, metaColor: color, showLateBadge: late)
                        }
                        .buttonStyle(.plain)
                    }
                    if items.count > 5 {
                        Button {
                            if isOpen { expanded.remove(key) } else { expanded.insert(key) }
                        } label: {
                            Text(isOpen ? "Réduire" : "Afficher les \(items.count)")
                                .font(AppFont.montserrat(12, weight: .semibold))
                                .foregroundStyle(Theme.Colors.primaryButtonPressed)
                                .frame(maxWidth: .infinity)
                                .padding(11)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.secondaryBackground))
                        }
                        .buttonStyle(.plain)
                        .padding([.horizontal, .bottom], 6)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
            .cardShadow()
        }
    }
}
