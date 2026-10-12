import SwiftUI

struct SettingsView: View {
    @Environment(DataStore.self) private var store

    @State private var selected: CatalogType = .reparation
    @State private var newEntry = ""
    /// Entrée dont on a touché la croix — la suppression attend la confirmation.
    @State private var pendingDelete: CatalogItem?
    /// Entrée dont on modifie le prix préenregistré.
    @State private var editingPrice: CatalogItem?
    @State private var priceText = ""

    private var entries: [CatalogItem] { store.catalog[selected] }

    private var trimmedNew: String { newEntry.trimmingCharacters(in: .whitespaces) }
    private var canAdd: Bool { !trimmedNew.isEmpty && !entries.contains { $0.name.caseInsensitiveCompare(trimmedNew) == .orderedSame } }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Paramètres").font(AppFont.display(22, weight: .semibold)).tracking(AppTracking.screenTitle).textCase(.uppercase)
                Text("Les listes proposées quand tu remplis une fiche.")
                    .font(AppFont.montserrat(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.contentMargin)
            .padding(.top, 6)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 12) {
                    storageCard

                    FlowLayout(spacing: 6) {
                        ForEach(CatalogType.allCases) { t in
                            ChipButton(label: t.tabLabel, isActive: selected == t) {
                                selected = t
                                newEntry = ""
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .lastTextBaseline) {
                            Text(selected.title).font(AppFont.display(16, weight: .semibold))
                            Spacer()
                            Text("\(entries.count) entrée\(entries.count > 1 ? "s" : "")")
                                .font(AppFont.montserrat(12))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }

                        HStack(spacing: 8) {
                            TextField(selected.entryPlaceholder, text: $newEntry)
                                .font(AppFont.montserrat(14))
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
                            Button {
                                store.addCatalogEntry(type: selected, name: trimmedNew)
                                newEntry = ""
                            } label: {
                                Text("Ajouter")
                                    .font(AppFont.montserrat(13, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .frame(height: 46)
                                    .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(canAdd ? Theme.Colors.primaryButton : Theme.Colors.disabledBg))
                                    .foregroundStyle(canAdd ? .white : Theme.Colors.disabledText)
                            }
                            .buttonStyle(.plain)
                            .disabled(!canAdd)
                        }

                        VStack(spacing: 0) {
                            if entries.isEmpty {
                                Text("Rien ici pour l'instant. Ajoute ta première entrée au-dessus.")
                                    .font(AppFont.montserrat(13))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .padding(.top, 14)
                            } else {
                                ForEach(entries) { e in
                                    HStack(spacing: 10) {
                                        Circle().fill(selected.dotColor).frame(width: 8, height: 8)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(e.name).font(AppFont.montserrat(14, weight: .medium)).lineLimit(1)
                                            let n = store.usageCount(e.name)
                                            Text(n > 0 ? "utilisé \(n)×" : "jamais utilisé")
                                                .font(AppFont.montserrat(11))
                                                .foregroundStyle(Theme.Colors.textSecondary)
                                        }
                                        Spacer()
                                        Button {
                                            priceText = e.price.map { "\($0)" } ?? ""
                                            editingPrice = e
                                        } label: {
                                            Text(priceLabel(e))
                                                .font(AppFont.montserrat(12, weight: .semibold))
                                                .padding(.horizontal, 10)
                                                .frame(height: 30)
                                                .background(Capsule().fill(e.price == nil ? Theme.Colors.background : Theme.Colors.accentTint))
                                                .foregroundStyle(e.price == nil ? Theme.Colors.textSecondary : Theme.Colors.accentText)
                                        }
                                        .buttonStyle(.plain)
                                        Button {
                                            pendingDelete = e
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(Theme.Colors.unpaidText)
                                                .frame(width: 30, height: 30)
                                                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.Colors.background))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 12)
                                    .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.separator).frame(height: 1) }
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
                    .cardShadow()
                }
                .padding(.horizontal, Theme.Spacing.contentMargin)
                .screenBottomPadding()
            }
            .alert(
                "Supprimer « \(pendingDelete?.name ?? "") » ?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                presenting: pendingDelete
            ) { item in
                Button("Supprimer", role: .destructive) {
                    store.removeCatalogEntry(type: selected, id: item.id)
                }
                Button("Annuler", role: .cancel) {}
            } message: { item in
                Text("Elle ne sera plus proposée quand tu remplis une fiche. Les fiches déjà enregistrées ne changent pas.")
            }
            .alert("Prix de « \(editingPrice?.name ?? "") »", isPresented: Binding(get: { editingPrice != nil }, set: { if !$0 { editingPrice = nil } })) {
                TextField("Prix en ₪", text: $priceText)
                    .keyboardType(.numberPad)
                Button("Enregistrer") {
                    if let item = editingPrice {
                        let value = Decimal(string: priceText.trimmingCharacters(in: .whitespaces))
                        store.setCatalogPrice(type: selected, id: item.id, price: value.flatMap { $0 > 0 ? $0 : nil })
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Proposé automatiquement dans une nouvelle fiche, et toujours modifiable fiche par fiche. Laisse vide pour ne pas avoir de prix.")
            }
        }
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Statut de synchro (rien à régler ici — la connexion Drive est fixée dans l'app)

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sauvegarde").font(AppFont.display(16, weight: .semibold))
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 8, height: 8)
                Text(statusText)
                    .font(AppFont.montserrat(12))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
        .cardShadow()
    }

    private func priceLabel(_ item: CatalogItem) -> String {
        guard let price = item.price else { return "Prix" }
        return Formatters.money(price) + (item.unit.map { " / \($0)" } ?? "")
    }

    private var statusText: String {
        guard DriveConfig.isConfigured else { return "Données gardées sur cet iPhone uniquement." }
        if store.isSyncing { return "Synchronisation avec Google Drive…" }
        if let error = store.lastSyncError { return error }
        return "À jour avec Google Drive."
    }

    private var statusColor: Color {
        guard DriveConfig.isConfigured else { return Theme.Colors.textSecondary }
        if store.lastSyncError != nil { return Theme.Colors.unpaidText }
        return Theme.Colors.paidText
    }
}
