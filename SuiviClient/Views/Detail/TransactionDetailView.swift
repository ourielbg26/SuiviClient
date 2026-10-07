import SwiftUI

struct TransactionDetailView: View {
    let clientID: UUID
    let transactionID: UUID
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var askDelete = false

    private var transaction: TransactionEntry? {
        store.entry(clientID: clientID, transactionID: transactionID)
    }

    var body: some View {
        Group {
            if let transaction {
                content(transaction)
            } else {
                VStack(spacing: 8) {
                    Text("Cette fiche n'existe plus.").font(AppFont.montserrat(15, weight: .semibold))
                    BackButton()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.background)
                .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    private func heroColors(_ transaction: TransactionEntry) -> (bg: Color, fg: Color, muted: Color) {
        switch transaction.status {
        case .enCours: return (Theme.Colors.statusEnCoursBg, Color(hex: "8A5A22"), Theme.Colors.statusEnCoursText)
        case .pret: return (Theme.Colors.statusPretBg, Theme.Colors.paidText, Color(hex: "5E8F74"))
        default:
            return transaction.isPaid
                ? (Theme.Colors.paidBg, Theme.Colors.paidText, Color(hex: "6FAF8F"))
                : (Theme.Colors.unpaidBg, Theme.Colors.lateAlertText, Color(hex: "B58080"))
        }
    }

    @ViewBuilder
    private func content(_ transaction: TransactionEntry) -> some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Fiche \(transaction.ref)") {
                NavigationLink(value: AppRoute.editTransactionForm(clientID: clientID, transactionID: transactionID)) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Modifier")
                    }
                    .font(AppFont.montserrat(12, weight: .semibold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().strokeBorder(Theme.Colors.border, lineWidth: 1))
                    .foregroundStyle(Theme.Colors.textPrimary)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(spacing: 12) {
                    hero(transaction)
                    suivi(transaction)
                    details(transaction)
                    paiement(transaction)
                    note(transaction)
                    if [.reparation, .couleur, .vente].contains(transaction.category) {
                        card {
                            PersistedPhotoGridSection(
                                title: transaction.category == .vente ? "Photos après" : "Photo avant",
                                addLabel: transaction.category == .vente ? "Après" : "Avant",
                                transactionID: transaction.id,
                                kind: transaction.category == .vente ? .apres : .avant
                            )
                        }
                    }
                    deleteSection(transaction)
                }
                .padding(.horizontal, Theme.Spacing.contentMargin)
                .screenBottomPadding()
            }
        }
        .background(Theme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func hero(_ transaction: TransactionEntry) -> some View {
        let colors = heroColors(transaction)
        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.category.rawValue)
                    .font(AppFont.montserrat(12, weight: .medium))
                    .foregroundStyle(colors.muted)
                Text(transaction.clientName)
                    .font(AppFont.playfair(26, weight: .bold))
                    .tracking(AppTracking.clientName)
                    .foregroundStyle(colors.fg)
                Text(transaction.item)
                    .font(AppFont.montserrat(13, weight: .medium))
                    .foregroundStyle(colors.fg)
            }
            HStack(alignment: .bottom) {
                Text(Formatters.money(transaction.price))
                    .font(AppFont.playfair(38, weight: .bold))
                    .tracking(AppTracking.heroAmount)
                    .foregroundStyle(colors.fg)
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    translucentPill(paymentLabelShort(transaction), fg: colors.fg)
                    translucentPill(transaction.status.rawValue, fg: colors.fg)
                }
            }
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.hero).fill(colors.bg))
    }

    private func paymentLabelShort(_ transaction: TransactionEntry) -> String {
        switch transaction.payState {
        case .paye: return "Payé"
        case .echelonne: return "En cours de paiement"
        case .impaye: return "Pas encore payé"
        }
    }

    private func translucentPill(_ text: String, fg: Color) -> some View {
        Text(text)
            .font(AppFont.montserrat(11, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.72)))
            .foregroundStyle(fg)
    }

    private func suivi(_ transaction: TransactionEntry) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Suivi").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                FlowLayout(spacing: 7) {
                    ForEach(WorkStatus.allCases) { st in
                        let active = st == transaction.status
                        Button { setStatus(st) } label: {
                            Text(st.rawValue)
                                .font(AppFont.montserrat(12, weight: .semibold))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(active ? st.textColor : Color(hex: "FAF7F5")))
                                .overlay(Capsule().strokeBorder(active ? Color.clear : Theme.Colors.border, lineWidth: 1))
                                .foregroundStyle(active ? .white : Theme.Colors.chipInactiveText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    setStatus(transaction.status.next)
                } label: {
                    Text("Passer en « \(transaction.status.next.rawValue.lowercased()) »")
                        .font(AppFont.montserrat(13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.secondaryBackground))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func setStatus(_ new: WorkStatus) {
        store.setStatus(clientID: clientID, transactionID: transactionID, to: new)
    }

    private func details(_ transaction: TransactionEntry) -> some View {
        card(padding: EdgeInsets(top: 4, leading: 18, bottom: 8, trailing: 18)) {
            VStack(spacing: 0) {
                detailRow("Détail", transaction.item)
                if transaction.category == .vente, let origine = transaction.origine {
                    detailRow("Provenance", origine.rawValue, color: origine == .commande ? Theme.Colors.statusEnCoursText : nil)
                }
                detailRow("Déposé le", Formatters.shortDate(transaction.dropDate))
                if let pickup = transaction.pickupDate {
                    detailRow("Rendu le", Formatters.shortDate(pickup))
                }
                if let ret = transaction.returnDate {
                    detailRow("Retour le", Formatters.shortDate(ret), color: Theme.Colors.unpaidText)
                    detailRow("Récupéré (2ᵉ fois)", transaction.pickup2Date.map(Formatters.shortDate) ?? "en attente", color: transaction.pickup2Date == nil ? Theme.Colors.unpaidText : nil)
                }
                detailRow("Référence", transaction.ref, showDivider: false)
            }
        }
    }

    private func detailRow(_ key: String, _ value: String, color: Color? = nil, showDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(key).font(AppFont.montserrat(13)).foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text(value)
                    .font(AppFont.montserrat(14, weight: .semibold))
                    .foregroundStyle(color ?? Theme.Colors.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 13)
            if showDivider {
                Rectangle().fill(Theme.Colors.separator).frame(height: 1)
            }
        }
    }

    private func paiement(_ transaction: TransactionEntry) -> some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Paiement").font(AppFont.montserrat(14, weight: .semibold))
                    Spacer()
                    Text(paymentDetail(transaction))
                        .font(AppFont.montserrat(13, weight: .semibold))
                        .foregroundStyle(transaction.isPaid ? Theme.Colors.paidText : Theme.Colors.unpaidText)
                }
                if let plan = transaction.plan, !transaction.isPaid, let left = transaction.planLeft {
                    let late = transaction.planIsLate
                    VStack(spacing: 8) {
                        planRow("Déjà versé", Formatters.money(plan.paid), color: late ? Theme.Colors.lateAlertText : Theme.Colors.textPrimary)
                        planRow("Reste à payer", Formatters.money(left), bold: true, color: late ? Theme.Colors.lateAlertText : Theme.Colors.textPrimary)
                        planRow("Prochaine échéance", Formatters.shortDate(plan.due) + (late ? " · en retard" : ""), color: late ? Theme.Colors.lateAlertText : Theme.Colors.textPrimary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(late ? Theme.Colors.unpaidBg : Theme.Colors.secondaryBackground))
                }
                if !transaction.isPaid {
                    PrimaryButton(title: "Marquer comme payé") {
                        store.markPaid(clientID: clientID, transactionID: transactionID)
                    }
                }
            }
        }
    }

    private func paymentDetail(_ transaction: TransactionEntry) -> String {
        switch transaction.payState {
        case .paye: return "Payé · \(transaction.method.rawValue)"
        case .echelonne: return "Échelonné · \(transaction.plan?.method.rawValue.lowercased() ?? "")"
        case .impaye: return "Pas encore payé"
        }
    }

    private func planRow(_ label: String, _ value: String, bold: Bool = false, color: Color) -> some View {
        HStack {
            Text(label).font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(color)
            Spacer()
            Text(value).font(AppFont.montserrat(bold ? 15 : 13, weight: bold ? .bold : .semibold)).foregroundStyle(color)
        }
    }

    private func note(_ transaction: TransactionEntry) -> some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Note").font(AppFont.montserrat(14, weight: .semibold))
                Text(transaction.note.isEmpty ? "Aucune note pour cette fiche." : transaction.note)
                    .font(AppFont.montserrat(14))
                    .lineSpacing(6)
                    .foregroundStyle(transaction.note.isEmpty ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                NavigationLink(value: AppRoute.clientDetail(clientID: clientID)) {
                    Text("Voir la fiche de \(transaction.firstName) →")
                        .font(AppFont.montserrat(13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primaryButtonPressed)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func deleteSection(_ transaction: TransactionEntry) -> some View {
        Group {
            if askDelete {
                VStack(spacing: 12) {
                    Text("Supprimer cette fiche ? Elle disparaîtra des listes et des statistiques.")
                        .font(AppFont.montserrat(13))
                        .foregroundStyle(Theme.Colors.lateAlertText)
                    HStack(spacing: 8) {
                        Button {
                            store.deleteTransaction(clientID: clientID, transactionID: transactionID)
                            dismiss()
                        } label: {
                            Text("Supprimer")
                                .font(AppFont.montserrat(13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(13)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Colors.lateAlert))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        Button {
                            askDelete = false
                        } label: {
                            Text("Annuler")
                                .font(AppFont.montserrat(13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(13)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.75)))
                                .foregroundStyle(Theme.Colors.lateAlertText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.Colors.unpaidBg))
            } else {
                Button {
                    askDelete = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                        Text("Supprimer la fiche")
                    }
                    .font(AppFont.montserrat(13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).strokeBorder(Color(hex: "EBC9C9"), lineWidth: 1))
                    .foregroundStyle(Theme.Colors.unpaidText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func card(padding: EdgeInsets = EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18), @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(.white))
            .cardShadow()
    }
}
