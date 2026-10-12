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
                .background(PaperBackground())
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
            ScreenHeader(title: transaction.ficheLabel) {
                NavigationLink(value: AppRoute.editTransactionForm(clientID: clientID, transactionID: transactionID)) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Modifier")
                    }
                    .font(AppFont.montserrat(12, weight: .semibold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.Colors.card))
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
                    card {
                        NoteEditor(clientID: clientID, transactionID: transactionID,
                                   note: transaction.note, updatedAt: transaction.noteUpdatedAt)
                    }
                    if [.reparation, .couleur, .vente].contains(transaction.category) {
                        card {
                            PersistedPhotoGridSection(
                                title: transaction.category == .vente ? "Photos après" : "Photo avant",
                                addLabel: transaction.category == .vente ? "Après" : "Avant",
                                clientID: transaction.clientID,
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
        .background(PaperBackground())
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
                    .font(AppFont.display(26, weight: .bold))
                    .tracking(AppTracking.clientName)
                    .foregroundStyle(colors.fg)
                Text(transaction.item)
                    .font(AppFont.montserrat(13, weight: .medium))
                    .foregroundStyle(colors.fg)
                NavigationLink(value: AppRoute.clientDetail(clientID: clientID)) {
                    HStack(spacing: 4) {
                        Text("Voir la fiche de \(transaction.firstName)")
                        Image(systemName: "chevron.right")
                    }
                    .font(AppFont.montserrat(12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.72)))
                    .foregroundStyle(colors.fg)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            HStack(alignment: .bottom) {
                Text(Formatters.money(transaction.price))
                    .font(AppFont.display(38, weight: .bold))
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
                                .background(Capsule().fill(active ? st.textColor : Theme.Colors.chipInactiveBg))
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
                detailRow(transaction.category == .vente ? "Commandé le" : "Déposé le", Formatters.shortDate(transaction.dropDate))
                if let pickup = transaction.pickupDate {
                    detailRow("Rendu le", Formatters.shortDate(pickup))
                }
                if let ret = transaction.returnDate {
                    detailRow("Retour le", Formatters.shortDate(ret), color: Theme.Colors.unpaidText)
                    detailRow("Récupéré (2ᵉ fois)", transaction.pickup2Date.map(Formatters.shortDate) ?? "en attente", color: transaction.pickup2Date == nil ? Theme.Colors.unpaidText : nil)
                }
                detailRow("Référence", transaction.ficheLabel, showDivider: false)
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
                    Text("Paiement").font(AppFont.display(16, weight: .semibold))
                    Spacer()
                    Text(paymentDetail(transaction))
                        .font(AppFont.montserrat(13, weight: .semibold))
                        .foregroundStyle(transaction.isPaid ? Theme.Colors.paidText : Theme.Colors.unpaidText)
                }
                if transaction.isPaid, let deposit = transaction.depositAmount, deposit > 0 {
                    VStack(spacing: 8) {
                        planRow("Acompte versé", Formatters.money(deposit), color: Theme.Colors.textPrimary)
                        if transaction.price > deposit {
                            planRow("Solde réglé ensuite", Formatters.money(transaction.price - deposit), color: Theme.Colors.textPrimary)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.secondaryBackground))
                }
                if let plan = transaction.plan, !transaction.isPaid, let left = transaction.planLeft {
                    let late = transaction.planIsLate
                    let color = late ? Theme.Colors.lateAlertText : Theme.Colors.textPrimary
                    let receivedSince = (plan.received ?? []).reduce(Decimal(0)) { $0 + $1.amount }
                    VStack(spacing: 8) {
                        planRow(transaction.category == .vente ? "Acompte versé" : "Déjà versé", Formatters.money(plan.paid), color: color)
                        if receivedSince > 0 {
                            planRow("Reçu depuis", Formatters.money(receivedSince), color: color)
                        }
                        planRow("Reste à payer", Formatters.money(left), bold: true, color: color)
                        if transaction.category != .vente, let count = plan.count, let amount = transaction.installmentAmount {
                            planRow("Mensualités", "\(count) × \(Formatters.money(amount)) · \(methodLabel(plan.method))", color: color)
                        }
                        if let next = transaction.nextInstallmentDate {
                            planRow(plan.count == nil ? "Prochaine échéance" : "Prochaine mensualité",
                                    Formatters.shortDate(next) + (late ? " · en retard" : ""), color: color)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(late ? Theme.Colors.unpaidBg : Theme.Colors.secondaryBackground))
                }
                if let plan = transaction.plan, plan.method == .especes, plan.count != nil || !(plan.received ?? []).isEmpty {
                    CashInstallmentsSection(clientID: clientID, transaction: transaction.transaction)
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
        case .paye: return "Payé · \(transaction.plan.map { methodLabel($0.method) } ?? transaction.method.rawValue)"
        case .echelonne: return "Échelonné · \(transaction.plan.map { methodLabel($0.method).lowercased() } ?? "")"
        case .impaye: return transaction.plan != nil ? "Mensualité en retard" : "Pas encore payé"
        }
    }

    private func methodLabel(_ method: PayMethod) -> String { method.label }

    private func planRow(_ label: String, _ value: String, bold: Bool = false, color: Color) -> some View {
        HStack {
            Text(label).font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(color)
            Spacer()
            Text(value).font(AppFont.montserrat(bold ? 15 : 13, weight: bold ? .bold : .semibold)).foregroundStyle(color)
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
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
            .cardShadow()
    }
}

/// La note, modifiable directement dans la fiche : on tape dedans, puis "Enregistrer"
/// apparaît. La date de dernière modification s'affiche en haut à droite.
private struct NoteEditor: View {
    let clientID: UUID
    let transactionID: UUID
    let note: String
    let updatedAt: Date?

    @Environment(DataStore.self) private var store
    @State private var text = ""
    @FocusState private var focused: Bool

    private var isDirty: Bool { text != note }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Note").font(AppFont.display(16, weight: .semibold))
                Spacer()
                if let updatedAt {
                    Text(Formatters.shortDate(updatedAt))
                        .font(AppFont.montserrat(11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            TextField("Ajouter une note…", text: $text, axis: .vertical)
                .font(AppFont.montserrat(14))
                .lineSpacing(6)
                .lineLimit(3...)
                .focused($focused)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.background))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.innerTile)
                        .strokeBorder(focused ? Theme.Colors.primaryButton : Theme.Colors.border, lineWidth: 1)
                )
            if isDirty {
                HStack(spacing: 8) {
                    Button {
                        text = note
                        focused = false
                    } label: {
                        Text("Annuler")
                            .font(AppFont.montserrat(13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.secondaryBackground))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                    Button(action: save) {
                        Text("Enregistrer")
                            .font(AppFont.montserrat(13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.primaryButton))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { text = note }
        // Note changée ailleurs (synchro avec l'autre iPhone, Modifier) : on la reprend,
        // sauf si une modification est en cours ici.
        .onChange(of: note) { old, new in
            if text == old { text = new }
        }
        // En quittant la fiche sans avoir touché "Enregistrer", on garde quand même ce
        // qui a été tapé.
        .onDisappear { if isDirty { save() } }
    }

    private func save() {
        store.updateNote(clientID: clientID, transactionID: transactionID, note: text)
        focused = false
    }
}

/// Paiement en espèces en plusieurs fois : le calendrier des mensualités (couverte, en
/// retard, à venir), les paiements reçus, et le bouton pour en noter un nouveau.
private struct CashInstallmentsSection: View {
    let clientID: UUID
    let transaction: AppTransaction

    @Environment(DataStore.self) private var store
    @State private var showRecord = false

    var body: some View {
        let dates = transaction.installmentDates
        let covered = transaction.installmentsCovered
        let today = Calendar.current.startOfDay(for: .now)
        let receipts = transaction.plan?.received ?? []

        VStack(alignment: .leading, spacing: 12) {
            if !dates.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Mensualités").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.bottom, 6)
                    ForEach(Array(dates.enumerated()), id: \.offset) { i, date in
                        let isCovered = transaction.isPaid || i < covered
                        let isLate = !isCovered && Calendar.current.startOfDay(for: date) < today
                        HStack {
                            Image(systemName: isCovered ? "checkmark.circle.fill" : (isLate ? "exclamationmark.circle.fill" : "circle"))
                                .foregroundStyle(isCovered ? Theme.Colors.paidText : (isLate ? Theme.Colors.unpaidText : Theme.Colors.border))
                            Text("\(i + 1). \(Formatters.shortDate(date))").font(AppFont.montserrat(13, weight: .medium))
                            Spacer()
                            Text(isCovered ? "Reçue" : (isLate ? "En retard" : "À venir"))
                                .font(AppFont.montserrat(12, weight: .semibold))
                                .foregroundStyle(isCovered ? Theme.Colors.paidText : (isLate ? Theme.Colors.unpaidText : Theme.Colors.textSecondary))
                        }
                        .padding(.vertical, 7)
                    }
                }
            }

            if !receipts.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Paiements reçus").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.bottom, 6)
                    ForEach(receipts) { r in
                        HStack {
                            Text(Formatters.shortDate(r.date)).font(AppFont.montserrat(13))
                            Spacer()
                            Text(Formatters.money(r.amount)).font(AppFont.montserrat(13, weight: .semibold))
                            Button {
                                store.deleteInstallmentPayment(clientID: clientID, transactionID: transaction.id, receiptID: r.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !transaction.isPaid {
                PrimaryButton(title: "Noter un paiement reçu") { showRecord = true }
            }
        }
        .sheet(isPresented: $showRecord) {
            RecordPaymentSheet(suggested: suggestedAmount) { amount, date in
                store.recordInstallmentPayment(clientID: clientID, transactionID: transaction.id, amount: amount, date: date)
            }
            .presentationDetents([.medium])
        }
    }

    /// Une mensualité, ou le reste si c'est moins.
    private var suggestedAmount: Decimal {
        let left = transaction.planLeft ?? 0
        guard let amount = transaction.installmentAmount else { return left }
        return min(amount, left)
    }
}

private struct RecordPaymentSheet: View {
    let suggested: Decimal
    let onSave: (Decimal, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var date = Date.now

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Paiement reçu").font(AppFont.display(22, weight: .bold))
            VStack(alignment: .leading, spacing: 6) {
                Text("Montant (₪)").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(AppFont.montserrat(16, weight: .semibold))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
            }
            HStack {
                Text("Reçu le").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date).labelsHidden()
            }
            Spacer()
            PrimaryButton(title: "Enregistrer", isEnabled: amount != nil) {
                guard let amount else { return }
                onSave(amount, date)
                dismiss()
            }
        }
        .padding(22)
        .onAppear {
            let wholeShekels = NSDecimalNumberHandler(roundingMode: .plain, scale: 0, raiseOnExactness: false,
                                                      raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
            amountText = NSDecimalNumber(decimal: suggested).rounding(accordingToBehavior: wholeShekels).stringValue
        }
    }
}
