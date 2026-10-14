import SwiftUI

struct HomeView: View {
    @Binding var path: [AppRoute]
    @Environment(DataStore.self) private var store
    @State private var expanded: Set<String> = []

    private var allEntries: [TransactionEntry] { store.allEntries.sorted { $0.dropDate < $1.dropDate } }
    private var enCours: [TransactionEntry] { allEntries.filter { $0.status == .enCours || $0.isVenteBackInWork } }
    private var pret: [TransactionEntry] { allEntries.filter { $0.status == .pret || ($0.status == .retour && !$0.isVenteBackInWork) } }
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

                // En haut, pour rester accessibles même quand les listes sont longues.
                HStack(spacing: 10) {
                    shortcut("Toutes les transactions", count: allEntries.count, route: .transactionsList)
                    shortcut("Tous les contacts", count: store.clients.count, route: .contacts)
                }
                .fixedSize(horizontal: false, vertical: true)

                section(key: "enCours", title: "En cours", dot: Theme.Colors.statusEnCoursDot, items: enCours,
                        emptyLabel: "Rien en atelier.") { t in
                    if t.isVenteBackInWork, let r = t.returnDate {
                        return (returnLabel(t, since: r), Theme.Colors.unpaidText, false)
                    }
                    let d = t.ageDays
                    return ("\(t.category == .vente ? "Commandé" : "Déposé") le \(Formatters.shortDate(t.dropDate)) · \(d) j", d > 14 ? Theme.Colors.unpaidText : Theme.Colors.textSecondary, false)
                }

                section(key: "pret", title: "Prêt à rendre", dot: Theme.Colors.statusPretDot, items: pret,
                        emptyLabel: "Rien à rendre.") { t in
                    if t.status == .retour, let r = t.returnDate {
                        return (returnLabel(t, since: r), Theme.Colors.unpaidText, false)
                    }
                    return ("Prêt · \(t.category == .vente ? "commandé" : "déposé") le \(Formatters.shortDate(t.dropDate))", Theme.Colors.statusPretText, false)
                }

                section(key: "impaye", title: "Non payé", dot: Theme.Colors.statusRetourDot, items: impaye,
                        emptyLabel: "Tout est réglé.") { t in
                    if t.plan != nil, let left = t.planLeft {
                        let since = t.nextInstallmentDate.map { " depuis le \(Formatters.shortDate($0))" } ?? ""
                        return ("Mensualité en retard\(since) · reste \(Formatters.money(left))", Theme.Colors.unpaidText, true)
                    }
                    var label = t.pickupDate.map { "Rendu le \(Formatters.shortDate($0))" } ?? "Rendu"
                    if let left = t.leftAfterDeposit { label += " · reste \(Formatters.money(left))" }
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

            }
            .padding(.horizontal, Theme.Spacing.contentMargin)
            .padding(.top, 8)
            .screenBottomPadding()
        }
        .refreshable { await store.sync() }
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func shortcut(_ title: String, count: Int, route: AppRoute) -> some View {
        Button {
            path.append(route)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppFont.montserrat(13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack {
                    Text("\(count)")
                        .font(AppFont.display(18, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.Colors.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).strokeBorder(Theme.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// "Retour reçu le 12 oct. · Bonnet trop serré · 2 à arranger".
    private func returnLabel(_ t: TransactionEntry, since date: Date) -> String {
        var bits = ["Retour reçu le \(Formatters.shortDate(date))"]
        if let reason = t.returnReason, !reason.isEmpty { bits.append(reason) }
        if t.pendingReturnFixes > 0 { bits.append("\(t.pendingReturnFixes) à arranger") }
        return bits.joined(separator: " · ")
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
