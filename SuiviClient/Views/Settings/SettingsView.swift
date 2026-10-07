import SwiftUI

struct SettingsView: View {
    @Environment(DataStore.self) private var store

    @State private var selected: CatalogType = .reparation
    @State private var newEntry = ""

    private var entries: [CatalogItem] { store.catalog[selected] }

    private var trimmedNew: String { newEntry.trimmingCharacters(in: .whitespaces) }
    private var canAdd: Bool { !trimmedNew.isEmpty && !entries.contains { $0.name.caseInsensitiveCompare(trimmedNew) == .orderedSame } }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Paramètres").font(AppFont.playfair(22, weight: .bold)).tracking(AppTracking.screenTitle)
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
                            Text(selected.title).font(AppFont.montserrat(15, weight: .semibold))
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
                                            store.removeCatalogEntry(type: selected, id: e.id)
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
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(.white))
                    .cardShadow()
                }
                .padding(.horizontal, Theme.Spacing.contentMargin)
                .screenBottomPadding()
            }
        }
        .background(Theme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Statut de synchro (rien à régler ici — la connexion Drive est fixée dans l'app)

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.isPreviewingSampleData {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mode test actif").font(AppFont.montserrat(15, weight: .semibold))
                    Text("Tu vois des données d'exemple, pas les vraies. Rien n'est envoyé sur Drive tant que tu es dans ce mode.")
                        .font(AppFont.montserrat(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    PrimaryButton(title: "Revenir aux vraies données") {
                        store.resetLocalCacheAndResync()
                    }
                }
            } else {
                Text("Sauvegarde").font(AppFont.montserrat(15, weight: .semibold))
                HStack(spacing: 8) {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(statusText)
                        .font(AppFont.montserrat(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                if DriveConfig.isConfigured {
                    Button {
                        store.resetLocalCacheAndResync()
                    } label: {
                        Text("Recharger depuis Drive")
                            .font(AppFont.montserrat(13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(.white))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                #if DEBUG
                Button("Charger des données de test (debug)") {
                    store.loadSampleDataForTesting()
                }
                .font(AppFont.montserrat(12, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                #endif
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(.white))
        .cardShadow()
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
