import SwiftUI

/// Le "champ à suggestions" réutilisable du formulaire (§6.4) : champ texte qui ouvre un
/// panneau de suggestions à la mise au point, avec possibilité d'enregistrer une nouvelle
/// entrée dans le catalogue. En multi-sélection, les entrées choisies s'affichent en chips
/// retirables au-dessus du champ.
struct SuggestionField: View {
    let label: String
    let placeholder: String
    let catalogType: CatalogType
    let multi: Bool
    let accentBg: Color
    let accentFg: Color
    let entries: [CatalogItem]
    let usageCount: (String) -> Int
    let onSaveNewEntry: (String) -> Void

    @Binding var query: String
    @Binding var selection: [String]
    @FocusState private var focused: Bool

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }

    private var suggestions: [CatalogItem] {
        entries.filter { e in
            (trimmedQuery.isEmpty || e.name.localizedCaseInsensitiveContains(trimmedQuery)) && !selection.contains(e.name)
        }
    }

    private var canSave: Bool {
        trimmedQuery.count > 1 && !entries.contains { $0.name.caseInsensitiveCompare(trimmedQuery) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)

            if !selection.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(selection, id: \.self) { v in
                        RemovableChip(label: v, bg: accentBg, fg: accentFg) {
                            selection.removeAll { $0 == v }
                        }
                    }
                }
            }

            TextField(placeholder, text: $query)
                .font(AppFont.montserrat(14))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
                .focused($focused)

            if focused {
                VStack(alignment: .leading, spacing: 4) {
                    Text(multi ? "Choisis une ou plusieurs entrées" : "Liste enregistrée")
                        .font(AppFont.montserrat(10, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 6)

                    ForEach(suggestions.prefix(6)) { entry in
                        Button {
                            select(entry.name)
                        } label: {
                            HStack(spacing: 9) {
                                Circle().fill(catalogType.dotColor).frame(width: 8, height: 8)
                                Text(entry.name).font(AppFont.montserrat(13, weight: .medium)).foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                let count = usageCount(entry.name)
                                if count > 0 {
                                    Text("\(count)×").font(AppFont.montserrat(11)).foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }

                    if suggestions.isEmpty {
                        Text("Rien d'enregistré ici pour l'instant.")
                            .font(AppFont.montserrat(12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .padding(8)
                    }

                    if canSave {
                        Button {
                            saveNewEntry()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                                Text("Enregistrer « \(trimmedQuery) » dans la liste")
                                    .font(AppFont.montserrat(12, weight: .semibold))
                            }
                            .foregroundStyle(Theme.Colors.accentText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 11).fill(Theme.Colors.accentTint))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.background))
            }
        }
    }

    private func select(_ value: String) {
        if multi {
            if !selection.contains(value) { selection.append(value) }
            query = ""
        } else {
            selection = [value]
            query = value
        }
        focused = false
    }

    private func saveNewEntry() {
        let name = trimmedQuery
        onSaveNewEntry(name)
        select(name)
    }
}
