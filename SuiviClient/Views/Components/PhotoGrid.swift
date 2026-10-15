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
                Text(title).font(AppFont.display(16, weight: .semibold))
                Spacer()
                Text(countLabel).font(AppFont.montserrat(11)).foregroundStyle(Theme.Colors.textSecondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(photos.enumerated()), id: \.offset) { _, data in
                    photoTile(data: data)
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    AddPhotoTile(label: addLabel)
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
            if let ui = ImageCompressor.displayImage(from: data) {
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

/// Tuile pointillée "+ Avant / + Après". Sa taille vient de la forme (toute la largeur de
/// la colonne, au format 4:5 des photos) et non de son texte — sinon elle se réduit à une
/// petite pastille autour du "+".
private struct AddPhotoTile: View {
    let label: String

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.photoSlot)
            .fill(Theme.Colors.background)
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.photoSlot)
                    .strokeBorder(Theme.Colors.dashedBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 26, weight: .regular))
                    Text("+ \(label)").font(AppFont.montserrat(14, weight: .semibold))
                }
                .foregroundStyle(Theme.Colors.textPrimary)
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.photoSlot))
    }
}

/// Même présentation, mais pour des photos qui vivent sur Drive (fiche transaction) :
/// chaque ajout passe par `DataStore` (le nom de la photo est enregistré dans la fiche,
/// puis la photo est envoyée), et chaque vignette se télécharge à l'ouverture de la fiche.
struct PersistedPhotoGridSection: View {
    let title: String
    let addLabel: String
    let clientID: UUID
    let transactionID: UUID
    let kind: PhotoKind

    @Environment(DataStore.self) private var store
    @State private var pickerItem: PhotosPickerItem?

    private var names: [String] { store.photoNames(transactionID: transactionID, kind: kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text(title).font(AppFont.display(16, weight: .semibold))
                Spacer()
                Text(names.isEmpty ? "aucune" : "\(names.count) photo(s)").font(AppFont.montserrat(11)).foregroundStyle(Theme.Colors.textSecondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(names, id: \.self) { name in
                    RemotePhotoTile(name: name)
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    AddPhotoTile(label: addLabel)
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    store.addPhoto(data, clientID: clientID, transactionID: transactionID, kind: kind)
                }
                pickerItem = nil
            }
        }
    }
}

/// Une vignette qui se télécharge elle-même, avec son état : en cours, affichée, ou échec
/// (avec un bouton pour relancer le téléchargement). Un badge signale aussi une photo
/// prise sur ce téléphone qui n'est pas encore partie sur Drive.
private struct RemotePhotoTile: View {
    let name: String
    @Environment(DataStore.self) private var store

    private enum LoadState {
        case loading
        case loaded(UIImage)
        case failed(String)
    }

    @State private var state: LoadState = .loading
    @State private var attempt = 0

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.Colors.photoStripeA)
            switch state {
            case .loading:
                VStack(spacing: 8) {
                    ProgressView().tint(Theme.Colors.textSecondary)
                    Text("Téléchargement…")
                        .font(AppFont.montserrat(11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            case .loaded(let image):
                Image(uiImage: image).resizable().scaledToFill()
            case .failed(let reason):
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.Colors.unpaidText)
                    Text("Pas pu être téléchargée")
                        .font(AppFont.montserrat(11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Text(reason)
                        .font(AppFont.montserrat(9))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    Button {
                        attempt += 1
                    } label: {
                        Label("Réessayer", systemImage: "arrow.clockwise")
                            .font(AppFont.montserrat(12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Capsule().fill(Theme.Colors.card))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
            }
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.photoSlot))
        .overlay(alignment: .bottomLeading) {
            if store.pendingPhotoNames.contains(name) {
                Label("Pas encore envoyée", systemImage: "icloud.and.arrow.up")
                    .font(AppFont.montserrat(10, weight: .semibold))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Capsule().fill(.white.opacity(0.9)))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(6)
            }
        }
        .task(id: "\(name)#\(attempt)") {
            state = .loading
            do {
                let data = try await store.loadPhotoData(name: name)
                guard !Task.isCancelled else { return }
                if let image = ImageCompressor.displayImage(from: data) {
                    state = .loaded(image)
                } else {
                    state = .failed("Photo illisible (\(data.count / 1024) Ko reçus).")
                }
            } catch {
                // Vignette sortie de l'écran pendant le téléchargement : rien à afficher.
                guard !Task.isCancelled else { return }
                state = .failed(error.localizedDescription)
            }
        }
    }
}
