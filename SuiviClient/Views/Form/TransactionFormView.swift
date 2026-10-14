import SwiftUI

enum FormMode {
    case create(prefillName: String, prefillPhone: String, clientID: UUID?)
    case edit(clientID: UUID, transactionID: UUID)

    var editingIDs: (clientID: UUID, transactionID: UUID)? {
        if case .edit(let clientID, let transactionID) = self { return (clientID, transactionID) }
        return nil
    }
}

struct TransactionFormView: View {
    let mode: FormMode
    @Environment(\.goHome) private var goHome

    @Environment(DataStore.self) private var store

    @State private var draft: TransactionFormDraft
    @State private var repQuery = ""
    @State private var couleurQuery = ""
    @State private var typeQuery = ""
    @State private var produitQuery = ""
    @FocusState private var nameFocused: Bool

    init(mode: FormMode, store: DataStore) {
        self.mode = mode
        switch mode {
        case .create(let name, let phone, let clientID):
            var d = TransactionFormDraft.blank()
            d.name = name
            d.phone = phone
            d.clientID = clientID
            _draft = State(initialValue: d)
        case .edit(let clientID, let transactionID):
            if let entry = store.entry(clientID: clientID, transactionID: transactionID) {
                _draft = State(initialValue: TransactionFormDraft.from(existing: entry))
            } else {
                _draft = State(initialValue: .blank())
            }
        }
    }

    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespaces) }
    private var isKnownClient: Bool {
        draft.clientID != nil || store.clients.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    /// Clientes dont le nom contient ce qui est tapé (sans tenir compte des majuscules ni
    /// des accents) — y compris quand le nom tapé est déjà complet, tant qu'aucune n'a
    /// été choisie.
    private var nameSuggestions: [Client] {
        guard !trimmedName.isEmpty, draft.clientID == nil else { return [] }
        return Array(store.clients
            .filter { $0.name.range(of: trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .prefix(6))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: mode.editingIDs == nil ? "Nouvelle fiche" : "Modifier la fiche")

            ScrollView {
                VStack(spacing: 12) {
                    clientCard
                    categoryCard
                    logisticsCard
                    VStack(spacing: 7) {
                        PrimaryButton(title: mode.editingIDs == nil ? "Enregistrer la fiche" : "Enregistrer les modifications", isEnabled: draft.isReady) {
                            save()
                        }
                        Text(draft.isReady ? "Tu pourras tout modifier depuis la fiche." : "Nom de la cliente, prestation et prix sont nécessaires.")
                            .font(AppFont.montserrat(11))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, Theme.Spacing.contentMargin)
                .screenBottomPadding()
            }
        }
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
        // Choix d'une réparation, d'une colorimétrie ou d'un lavage : le prix se remplit
        // avec le prix préenregistré (toujours modifiable ensuite pour un cas particulier).
        .onChange(of: priceInputs) {
            if let suggested = store.suggestedPrice(for: draft) { draft.price = "\(suggested)" }
        }
    }

    /// Ce qui détermine le prix proposé.
    private var priceInputs: [String] {
        [draft.category.rawValue, draft.typeCouleur, draft.lavage, draft.finition]
            + draft.reparations.map { "\($0)×\(draft.reparationQuantities[$0] ?? 1)" }
    }

    // MARK: Cliente

    private var clientCard: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Cliente").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    PhoneContactButton { name, phone in
                        if !name.isEmpty {
                            draft.name = name
                            draft.clientID = nil
                        }
                        if !phone.isEmpty { draft.phone = phone }
                    }
                }
                TextField("Nom et prénom", text: Binding(
                    get: { draft.name },
                    set: {
                        draft.name = $0
                        draft.clientID = nil
                    }
                ))
                    .font(AppFont.montserrat(14))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
                    .focused($nameFocused)

                if !nameSuggestions.isEmpty {
                    VStack(spacing: 4) {
                        Text("Clientes existantes")
                            .font(AppFont.montserrat(10, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.top, 6)
                        ForEach(nameSuggestions) { c in
                            Button {
                                draft.name = c.name
                                draft.phone = c.phone == "—" ? "" : c.phone
                                draft.clientID = c.id
                                nameFocused = false
                            } label: {
                                let colors = AvatarPalette.colors(for: c.name)
                                HStack(spacing: 9) {
                                    RoundAvatar(initials: c.initials, bg: colors.bg, fg: colors.fg, size: 28)
                                    Text(c.name).font(AppFont.montserrat(13, weight: .medium)).foregroundStyle(Theme.Colors.textPrimary)
                                    Spacer()
                                    Text(c.phone).font(AppFont.montserrat(11)).foregroundStyle(Theme.Colors.textSecondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.background))
                }

                Text("Téléphone").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary).padding(.top, 6)
                TextField("06 …", text: $draft.phone)
                    .keyboardType(.phonePad)
                    .font(AppFont.montserrat(14))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))

                if mode.editingIDs == nil, let id = draft.clientID, let c = store.client(id: id) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 14, weight: .light))
                        Text("Cliente existante : la fiche s'ajoute au dossier de \(c.name) (\(c.transactions.count) fiche\(c.transactions.count > 1 ? "s" : "")).")
                            .font(AppFont.montserrat(12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Theme.Colors.paidText)
                    .padding(.top, 4)
                }

                if mode.editingIDs == nil, trimmedName.count > 1, !isKnownClient {
                    HStack(spacing: 10) {
                        Text("« \(trimmedName) » sera ajoutée aux contacts.")
                            .font(AppFont.montserrat(12))
                            .foregroundStyle(Theme.Colors.statusEnCoursText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button {
                            draft.saveContact.toggle()
                        } label: {
                            Text(draft.saveContact ? "Oui" : "Non")
                                .font(AppFont.montserrat(12, weight: .semibold))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 9)
                                .background(Capsule().fill(draft.saveContact ? Theme.Colors.primaryButton : .white))
                                .foregroundStyle(draft.saveContact ? .white : Theme.Colors.statusEnCoursText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(13)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.statusEnCoursBg))
                }
            }
        }
    }

    // MARK: Catégorie + champs spécifiques

    private var categoryCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Catégorie").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                    FlowLayout(spacing: 7) {
                        ForEach(Category.selectable) { cat in
                            ChipButton(label: cat.rawValue, isActive: draft.category == cat) { draft.category = cat }
                        }
                    }
                }

                categorySpecificFields

                if draft.category != .produit && draft.category != .lavage && draft.category != .coupe {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note / détails").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                        TextEditor(text: $draft.note)
                            .font(AppFont.montserrat(14))
                            .frame(height: 80)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
                    }
                }

                if [.reparation, .couleur].contains(draft.category) {
                    PhotoGridSection(title: "Photo avant", countLabel: "\(draft.photos.count) photo(s)", addLabel: "Avant", photos: $draft.photos)
                } else if draft.category == .vente {
                    PhotoGridSection(title: "Photos après", countLabel: "\(draft.photos.count) photo(s)", addLabel: "Après", photos: $draft.photos)
                }
            }
        }
    }

    @ViewBuilder
    private var categorySpecificFields: some View {
        switch draft.category {
        case .reparation:
            SuggestionField(label: "Réparations (plusieurs possibles)", placeholder: "Lace frontale…", catalogType: .reparation, multi: true,
                             accentBg: Category.reparation.backgroundColor, accentFg: Category.reparation.textColor,
                             entries: store.catalog[.reparation], usageCount: store.usageCount,
                             onSaveNewEntry: { store.addCatalogEntry(type: .reparation, name: $0) },
                             query: $repQuery, selection: $draft.reparations)
            ForEach(draft.reparations.filter { store.catalogItem(type: .reparation, named: $0)?.unit != nil }, id: \.self) { name in
                let unit = store.catalogItem(type: .reparation, named: name)?.unit ?? ""
                let qty = draft.reparationQuantities[name] ?? 1
                Stepper(value: Binding(get: { qty }, set: { draft.reparationQuantities[name] = $0 }), in: 1...50) {
                    Text("\(name) : \(qty) \(unit)\(qty > 1 ? "s" : "")")
                        .font(AppFont.montserrat(13, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
            }
        case .coupe:
            EmptyView()
        case .couleur:
            SuggestionField(label: "Colorimétrie", placeholder: "Racine, balayage…", catalogType: .typeCouleur, multi: false,
                             accentBg: Category.couleur.backgroundColor, accentFg: Category.couleur.textColor,
                             entries: store.catalog[.typeCouleur], usageCount: store.usageCount,
                             onSaveNewEntry: { store.addCatalogEntry(type: .typeCouleur, name: $0) },
                             query: $typeQuery, selection: bindingArray(\.typeCouleur))
            SuggestionField(label: "Teinte", placeholder: "6.1 Châtain foncé cendré…", catalogType: .couleur, multi: false,
                             accentBg: Category.couleur.backgroundColor, accentFg: Category.couleur.textColor,
                             entries: store.catalog[.couleur], usageCount: store.usageCount,
                             onSaveNewEntry: { store.addCatalogEntry(type: .couleur, name: $0) },
                             query: $couleurQuery, selection: bindingArray(\.couleur))
        case .produit:
            SuggestionField(label: "Produit", placeholder: "Shampoing doux…", catalogType: .produit, multi: false,
                             accentBg: Category.produit.backgroundColor, accentFg: Category.produit.textColor,
                             entries: store.catalog[.produit], usageCount: store.usageCount,
                             onSaveNewEntry: { store.addCatalogEntry(type: .produit, name: $0) },
                             query: $produitQuery, selection: bindingArray(\.produit))
        case .lavage:
            VStack(alignment: .leading, spacing: 8) {
                Text("Prestation").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                FlowLayout(spacing: 7) {
                    ForEach(FixedOptions.lavageOptions, id: \.self) { opt in
                        ChipButton(label: opt, isActive: draft.lavage == opt) { draft.lavage = opt }
                    }
                }
            }
            if draft.lavage == "Lavage + coiffage" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Coiffage").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                    FlowLayout(spacing: 7) {
                        ForEach(FixedOptions.finitions, id: \.self) { opt in
                            ChipButton(label: opt, isActive: draft.finition == opt) { draft.finition = opt }
                        }
                    }
                }
            }
        case .vente:
            // Les couleurs des perruques vendues ont leur propre liste (≠ teintes).
            optionGroup("Couleur", options: FixedOptions.venteCouleurs, selected: draft.couleur.replacingOccurrences(of: "Couleur ", with: "")) {
                draft.couleur = "Couleur \($0)"
            }
            optionGroup("Provenance", options: Origine.allCases.map(\.rawValue), selected: draft.origine.rawValue) { draft.origine = Origine(rawValue: $0) ?? .stock }
            optionGroup("Taille du bonnet", options: FixedOptions.tailles, selected: draft.taille) { draft.taille = $0 }
            optionGroup("Texture", options: FixedOptions.textures, selected: draft.texture) { draft.texture = $0 }
            optionGroup("Longueur (cm)", options: FixedOptions.longueurs, selected: draft.longueur) { draft.longueur = $0 }
        }
    }

    /// Adapte un champ String du brouillon en binding `[String]` (0 ou 1 élément) pour SuggestionField.
    private func bindingArray(_ keyPath: WritableKeyPath<TransactionFormDraft, String>) -> Binding<[String]> {
        Binding(
            get: { draft[keyPath: keyPath].isEmpty ? [] : [draft[keyPath: keyPath]] },
            set: { draft[keyPath: keyPath] = $0.first ?? "" }
        )
    }

    private func optionGroup(_ label: String, options: [String], selected: String, select: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
            FlowLayout(spacing: 7) {
                ForEach(options, id: \.self) { opt in
                    ChipButton(label: opt, isActive: selected == opt) { select(opt) }
                }
            }
        }
    }

    // MARK: Prix, statut, paiement

    private var logisticsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prix (₪)").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                        TextField("85", text: $draft.price)
                            .keyboardType(.numberPad)
                            .font(AppFont.montserrat(14))
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.category == .vente ? "Date de commande" : "Date de dépôt").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                        DatePicker("", selection: $draft.dropDate, displayedComponents: .date)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
                    }
                }

                optionGroup("Statut du travail", options: WorkStatus.allCases.map(\.rawValue), selected: draft.status.rawValue) {
                    draft.status = WorkStatus(rawValue: $0) ?? .enCours
                }

                if draft.status == .rendu || draft.status == .retour {
                    VStack(alignment: .leading, spacing: 10) {
                        dateRow("Rendu le", binding: dateBinding(\.pickupDate))
                        if draft.status == .retour {
                            dateRow("Retour reçu le", binding: dateBinding(\.returnDate))
                            dateRow("Récupéré après retour", binding: dateBinding(\.pickup2Date))
                            if draft.category == .vente {
                                TextField("Raison du retour", text: $draft.returnReason, axis: .vertical)
                                    .font(AppFont.montserrat(14))
                                    .lineLimit(1...4)
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.card))
                                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
                            }
                        }
                        if draft.returnDate != nil {
                            Button("Annuler le retour et effacer la date") {
                                draft.returnDate = nil
                                draft.pickup2Date = nil
                                draft.returnReason = ""
                                draft.status = .rendu
                            }
                            .font(AppFont.montserrat(12, weight: .semibold))
                            .foregroundStyle(Theme.Colors.unpaidText)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.background))
                }

                if draft.category == .vente {
                    venteAcompteSection
                } else {
                    optionGroup("Paiement", options: TransactionFormDraft.PayChoice.allCases
                                    .filter { $0 != .plusieursFois || draft.category.allowsInstallments }.map(\.rawValue),
                                selected: draft.pay.rawValue) {
                        draft.pay = TransactionFormDraft.PayChoice(rawValue: $0) ?? .pasEncore
                    }

                    if draft.pay == .pasEncore && draft.category == .reparation {
                        acompteField
                    }

                    if draft.pay == .paye {
                        payMethodGroup
                    }

                    if draft.pay == .plusieursFois && draft.category.allowsInstallments {
                        installmentFields(alreadyPaid: Decimal(string: draft.planPaid) ?? 0, showsAlreadyPaid: true)
                    }
                }
            }
        }
    }

    /// Vente : "Acompte reçu" (gardé même une fois tout payé), puis — s'il ne couvre pas le
    /// prix — si le reste a déjà été réglé ou non.
    private var venteAcompteSection: some View {
        let reste = draft.priceValue - draft.acompteValue
        return VStack(alignment: .leading, spacing: 10) {
            acompteField

            if reste > 0 {
                optionGroup("Le reste", options: ["Pas encore payé", "Payé"], selected: draft.venteSoldePaye ? "Payé" : "Pas encore payé") {
                    draft.venteSoldePaye = $0 == "Payé"
                }
            }

            // Le moyen choisi ici (espèces / carte) vaut pour toute la vente.
            installmentFields(alreadyPaid: draft.acompteValue, showsAlreadyPaid: false)
        }
    }

    /// "Acompte reçu" et ce qu'il reste à payer après (vente, et réparation pas encore payée).
    private var acompteField: some View {
        let reste = draft.priceValue - draft.acompteValue
        return VStack(alignment: .leading, spacing: 6) {
            Text("Acompte reçu (₪)").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
            TextField("0", text: $draft.acompte)
                .keyboardType(.numberPad)
                .font(AppFont.montserrat(14))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
            if draft.acompteValue > 0 {
                Text(reste > 0 ? "Reste après l'acompte : \(Formatters.money(reste))" : "L'acompte couvre tout le prix.")
                    .font(AppFont.montserrat(11))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private var payMethodGroup: some View {
        optionGroup("Réglé en", options: PayMethod.choices.map(\.label), selected: draft.method.label) { label in
            draft.method = PayMethod.choices.first { $0.label == label } ?? .especes
        }
    }

    /// Paiement en plusieurs fois : moyen, nombre de mensualités, date de la 1ʳᵉ — les
    /// suivantes tombent le même jour des mois suivants.
    private func installmentFields(alreadyPaid: Decimal, showsAlreadyPaid: Bool) -> some View {
        let left = draft.priceValue - alreadyPaid
        return VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 7) {
                ForEach(PayMethod.installmentChoices) { m in
                    ChipButton(label: m.label, isActive: draft.planMethod == m) { draft.planMethod = m }
                }
            }
            if showsAlreadyPaid {
                installmentField("Déjà versé (₪)", placeholder: "0", text: $draft.planPaid)
            }
            HStack {
                Text("Mensualités").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Picker("Mensualités", selection: Binding(get: { draft.planCountValue ?? 0 },
                                                         set: { draft.planCount = $0 > 0 ? String($0) : "" })) {
                    Text("—").tag(0)
                    ForEach(1...10, id: \.self) { n in Text("\(n)").tag(n) }
                }
                .pickerStyle(.menu)
                .tint(Theme.Colors.textPrimary)
            }
            HStack {
                Text("1ʳᵉ mensualité le").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                DatePicker("", selection: $draft.planDue, displayedComponents: .date).labelsHidden()
            }
            if let count = draft.planCountValue, left > 0 {
                let last = Calendar.current.date(byAdding: .month, value: count - 1, to: draft.planDue) ?? draft.planDue
                Text("\(count) × \(Formatters.money(left / Decimal(count))) · dernière le \(Formatters.shortDate(last))")
                    .font(AppFont.montserrat(12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.installmentText)
            }
            if draft.planMethod == .especes {
                Text("Espèces : tu noteras chaque paiement reçu dans la fiche. En retard, la fiche passe en « Non payé ».")
                    .font(AppFont.montserrat(11))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.background))
    }

    private func installmentField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(AppFont.montserrat(11, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .font(AppFont.montserrat(13))
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.Colors.card))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.border, lineWidth: 1))
        }
    }

    private func dateRow(_ label: String, binding: Binding<Date>) -> some View {
        HStack {
            Text(label).font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            DatePicker("", selection: binding, displayedComponents: .date).labelsHidden()
        }
    }

    private func dateBinding(_ keyPath: WritableKeyPath<TransactionFormDraft, Date?>) -> Binding<Date> {
        Binding(get: { draft[keyPath: keyPath] ?? .now }, set: { draft[keyPath: keyPath] = $0 })
    }

    // MARK: Enregistrement

    private func save() {
        guard draft.isReady else { return }
        store.saveTransaction(draft: draft, editing: mode.editingIDs)
        goHome()
    }

    @ViewBuilder
    private func card(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(18)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
            .cardShadow()
    }
}
