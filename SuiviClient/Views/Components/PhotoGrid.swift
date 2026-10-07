import SwiftUI
import PhotosUI

/// Grille de photos 4:5 + tuile pointillée d'ajout — utilisée en fiche et en formulaire
/// (§6.3, §6.4). Remplace le placeholder rayé du prototype par un vrai `PhotosPicker`.
struct PhotoGridSection: View {
    let title: String
    let countLabel: String
    let addLabel: String
    @Binding var photos: [Data]
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text(title).font(AppFont.montserrat(14, weight: .semibold))
                Spacer()
                Text(countLabel).font(AppFont.montserrat(11)).foregroundStyle(Theme.Colors.textSecondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(photos.enumerated()), id: \.offset) { _, data in
                    photoTile(data: data)
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                        Text(addLabel).font(AppFont.montserrat(12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4.0 / 5.0, contentMode: .fit)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.photoSlot).fill(Theme.Colors.background))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.photoSlot)
                            .strokeBorder(Theme.Colors.dashedBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    photos.append(data)
                }
                pickerItem = nil
            }
        }
    }

    private func photoTile(data: Data) -> some View {
        Group {
            if let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Rectangle().fill(Theme.Colors.photoStripeA)
            }
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.photoSlot))
    }
}

/// Même présentation, mais pour des photos qui vivent sur Drive (fiche transaction) :
/// chaque ajout est mis en attente puis envoyé via `DataStore` (pas de binding en mémoire),
/// et chaque vignette se télécharge (ou se relit du cache) à l'affichage.
struct PersistedPhotoGridSection: View {
    let title: String
    let addLabel: String
    let transactionID: UUID
    let kind: PhotoKind

    @Environment(DataStore.self) private var store
    @State private var pickerItem: PhotosPickerItem?
    @State private var refreshToken = 0

    private var names: [String] {
        _ = refreshToken
        return store.photoNames(transactionID: transactionID, kind: kind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text(title).font(AppFont.montserrat(14, weight: .semibold))
                Spacer()
                Text(names.isEmpty ? "aucune" : "\(names.count) photo(s)").font(AppFont.montserrat(11)).foregroundStyle(Theme.Colors.textSecondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(names, id: \.self) { name in
                    RemotePhotoTile(name: name)
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                        Text(addLabel).font(AppFont.montserrat(12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4.0 / 5.0, contentMode: .fit)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.photoSlot).fill(Theme.Colors.background))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.photoSlot)
                            .strokeBorder(Theme.Colors.dashedBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    store.addPhoto(data, transactionID: transactionID, kind: kind)
                    refreshToken += 1
                }
                pickerItem = nil
            }
        }
    }
}

/// Une vignette qui se charge elle-même (attente locale → cache → téléchargement Drive).
private struct RemotePhotoTile: View {
    let name: String
    @Environment(DataStore.self) private var store
    @State private var data: Data?

    var body: some View {
        Group {
            if let data, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Rectangle().fill(Theme.Colors.photoStripeA)
            }
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.photoSlot))
        .task(id: name) {
            data = await store.loadPhotoData(name: name)
        }
    }
}
