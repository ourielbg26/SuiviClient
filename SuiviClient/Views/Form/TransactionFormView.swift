import SwiftUI

enum FormMode {
    case create(prefillName: String, prefillPhone: String)
    case edit(clientID: UUID, transactionID: UUID)

    var editingIDs: (clientID: UUID, transactionID: UUID)? {
        if case .edit(let clientID, let transactionID) = self { return (clientID, transactionID) }
        return nil
    }
}

struct TransactionFormView: View {
    let mode: FormMode
    @Binding var path: [AppRoute]

    @Environment(DataStore.self) private var store

    @State private var draft: TransactionFormDraft
    @State private var repQuery = ""
    @State private var couleurQuery = ""
    @State private var typeQuery = ""
    @State private var produitQuery = ""
    @FocusState private var nameFocused: Bool

    init(mode: FormMode, path: Binding<[AppRoute]>, store: DataStore) {
        self.mode = mode
        self._path = path
        switch mode {
        case .create(let name, let phone):
            var d = TransactionFormDraft.blank()
            d.name = name
            d.phone = phone
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
    private var isKnownClient: Bool { store.clients.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame } }

    private var nameSuggestions: [Client] {
        guard !trimmedName.isEmpty, !isKnownClient else { return [] }
        return Array(store.clients.filter { $0.name.localizedCaseInsensitiveContains(trimmedName) }.prefix(4))
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
        .background(Theme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Cliente

    private var clientCard: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Cliente").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                TextField("Nom et prénom", text: $draft.name)
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
                                draft.phone = c.phone
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
                        ForEach(Category.allCases) { cat in
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
        case .coupe:
            optionGroup("Type de coupe", options: FixedOptions.coupes, selected: draft.coupe) { draft.coupe = $0 }
        case .couleur:
            SuggestionField(label: "Type de coloration", placeholder: "Racine, balayage…", catalogType: .typeCouleur, multi: false,
                             accentBg: Category.couleur.backgroundColor, accentFg: Category.couleur.textColor,
                             entries: store.catalog[.typeCouleur], usageCount: store.usageCount,
                             onSaveNewEntry: { store.addCatalogEntry(type: .typeCouleur, name: $0) },
                             query: $typeQuery, selection: bindingArray(\.typeCouleur))
            SuggestionField(label: "Couleur", placeholder: "Blond 613…", catalogType: .couleur, multi: false,
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
            SuggestionField(label: "Couleur", placeholder: "Blond 613…", catalogType: .couleur, multi: false,
                             accentBg: Category.vente.backgroundColor, accentFg: Category.vente.textColor,
                             entries: store.catalog[.couleur], usageCount: store.usageCount,
                             onSaveNewEntry: { store.addCatalogEntry(type: .couleur, name: $0) },
                             query: $couleurQuery, selection: bindingArray(\.couleur))
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
                        Text("Date de dépôt").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
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
                        }
                        if draft.returnDate != nil {
                            Button("Annuler le retour et effacer la date") {
                                draft.returnDate = nil
                                draft.pickup2Date = nil
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
                    optionGroup("Paiement", options: TransactionFormDraft.PayChoice.allCases.map(\.rawValue), selected: draft.pay.rawValue) {
                        draft.pay = TransactionFormDraft.PayChoice(rawValue: $0) ?? .pasEncore
                    }

                    if draft.pay == .paye {
                        optionGroup("Réglé en", options: PayMethod.allCases.map(\.rawValue), selected: draft.method.rawValue) {
                            draft.method = PayMethod(rawValue: $0) ?? .especes
                        }
                    }

                    if draft.pay == .plusieursFois {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Paiement en plusieurs fois — espèces ou chèque.")
                                .font(AppFont.montserrat(12))
                                .foregroundStyle(Theme.Colors.textSecondary)
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Déjà versé (₪)").font(AppFont.montserrat(11, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                                    TextField("50", text: $draft.planPaid)
                                        .keyboardType(.numberPad)
                                        .font(AppFont.montserrat(13))
                                        .padding(10)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.border, lineWidth: 1))
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Échéance").font(AppFont.montserrat(11, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                                    DatePicker("", selection: $draft.planDue, displayedComponents: .date)
                                        .labelsHidden()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.Colors.border, lineWidth: 1))
                                }
                            }
                            FlowLayout(spacing: 7) {
                                ForEach(["Espèces", "Chèque"], id: \.self) { opt in
                                    ChipButton(label: opt, isActive: draft.planMethod.rawValue == opt) { draft.planMethod = PayMethod(rawValue: opt) ?? .especes }
                                }
                            }
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.background))
                    }
                }
            }
        }
    }

    /// Vente : une seule case "Acompte reçu" — le statut (payé / en attente d'un reste)
    /// se déduit du montant saisi comparé au prix, pas d'un choix Pas encore/Payé séparé.
    private var venteAcompteSection: some View {
        let reste = draft.priceValue - draft.venteAcompteValue
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Acompte reçu (₪)").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                TextField("0", text: $draft.venteAcompte)
                    .keyboardType(.numberPad)
                    .font(AppFont.montserrat(14))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
                if draft.venteAcompteValue > 0 {
                    Text(reste > 0 ? "Reste à payer : \(Formatters.money(reste))" : "Payée en totalité.")
                        .font(AppFont.montserrat(11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            optionGroup("Réglé en", options: PayMethod.allCases.map(\.rawValue), selected: draft.method.rawValue) {
                draft.method = PayMethod(rawValue: $0) ?? .especes
            }

            if draft.venteAcompteValue > 0 && reste > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Échéance du solde").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        DatePicker("", selection: $draft.planDue, displayedComponents: .date).labelsHidden()
                    }
                    FlowLayout(spacing: 7) {
                        ForEach(["Espèces", "Chèque"], id: \.self) { opt in
                            ChipButton(label: opt, isActive: draft.planMethod.rawValue == opt) { draft.planMethod = PayMethod(rawValue: opt) ?? .especes }
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.background))
            }
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
        let result = store.saveTransaction(draft: draft, editing: mode.editingIDs)
        if !path.isEmpty { path.removeLast() }
        path.append(.transactionDetail(clientID: result.clientID, transactionID: result.transactionID))
    }

    @ViewBuilder
    private func card(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(18)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(.white))
            .cardShadow()
    }
}
