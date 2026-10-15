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

/// Photos d'une fiche : "Avant" à gauche, "Après" à droite. Chaque colonne montre la
/// grande tuile "+ Avant / + Après" tant qu'elle est vide ; sinon sa photo (avec une
/// poubelle) ou, s'il y en a plusieurs, une pile avec leur nombre. Un toucher ouvre la
/// visionneuse.
struct BeforeAfterPhotosSection: View {
    let clientID: UUID
    let transactionID: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos").font(AppFont.display(16, weight: .semibold))
            HStack(alignment: .top, spacing: 26) {
                PhotoColumn(title: "Avant", kind: .avant, clientID: clientID, transactionID: transactionID)
                PhotoColumn(title: "Après", kind: .apres, clientID: clientID, transactionID: transactionID)
            }
        }
    }
}

private struct PhotoColumn: View {
    let title: String
    let kind: PhotoKind
    let clientID: UUID
    let transactionID: UUID

    @Environment(DataStore.self) private var store
    @State private var pickerItem: PhotosPickerItem?
    @State private var showViewer = false
    @State private var askDelete = false

    private var names: [String] { store.photoNames(transactionID: transactionID, kind: kind) }

    var body: some View {
        let names = self.names
        VStack(spacing: 10) {
            Text(title)
                .font(AppFont.montserrat(12, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if names.isEmpty {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    AddPhotoTile(label: title)
                }
                .buttonStyle(.plain)
            } else {
                Button { showViewer = true } label: {
                    PhotoStack(names: names)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topTrailing) { corner(names) }

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Ajouter", systemImage: "plus")
                        .font(AppFont.montserrat(12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Capsule().fill(Theme.Colors.secondaryBackground))
                        .foregroundStyle(Theme.Colors.textPrimary)
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
        .fullScreenCover(isPresented: $showViewer) {
            PhotoViewer(title: title, kind: kind, clientID: clientID, transactionID: transactionID)
        }
        .confirmationDialog("Supprimer cette photo ?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                if let name = names.first {
                    store.deletePhoto(name: name, clientID: clientID, transactionID: transactionID)
                }
            }
        }
    }

    /// Une seule photo : la poubelle. Plusieurs : leur nombre dans un rond.
    @ViewBuilder
    private func corner(_ names: [String]) -> some View {
        if names.count == 1 {
            Button { askDelete = true } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.unpaidText)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.white.opacity(0.92)))
            }
            .buttonStyle(.plain)
            .padding(8)
        } else {
            Text("\(names.count)")
                .font(AppFont.montserrat(13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.Colors.primaryButton))
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .offset(x: -4, y: -2)
        }
    }
}

/// La première photo, avec — s'il y en a d'autres — des cartes décalées derrière, pour
/// voir d'un coup d'œil qu'il y en a plusieurs.
private struct PhotoStack: View {
    let names: [String]

    var body: some View {
        ZStack {
            ForEach(Array((1..<min(names.count, 3)).reversed()), id: \.self) { depth in
                RoundedRectangle(cornerRadius: Theme.Radius.photoSlot)
                    .fill(depth == 1 ? Theme.Colors.photoStripeA : Theme.Colors.photoStripeB)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.photoSlot).strokeBorder(Theme.Colors.dashedBorder, lineWidth: 1))
                    .rotationEffect(.degrees(Double(depth) * 5))
                    .offset(x: CGFloat(depth) * 5, y: CGFloat(depth) * -2)
            }
            RemotePhotoTile(name: names[0])
                .shadow(color: .black.opacity(names.count > 1 ? 0.18 : 0), radius: 6, y: 2)
        }
        .aspectRatio(4.0 / 5.0, contentMode: .fit)
        // Place réservée pour les cartes de derrière, qui débordent sur la droite :
        // elles restent dans la colonne au lieu de toucher la colonne voisine.
        .padding(.trailing, names.count > 1 ? 14 : 0)
        .padding(.top, names.count > 1 ? 4 : 0)
    }
}

/// Plein écran : toutes les photos d'une colonne, à faire défiler (glisser ou flèches),
/// avec une poubelle pour supprimer celle affichée.
private struct PhotoViewer: View {
    let title: String
    let kind: PhotoKind
    let clientID: UUID
    let transactionID: UUID

    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var askDelete = false

    private var names: [String] { store.photoNames(transactionID: transactionID, kind: kind) }

    var body: some View {
        let names = self.names
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(Array(names.enumerated()), id: \.element) { i, name in
                    RemotePhotoImage(name: name, fill: false, onDark: true)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    roundButton("xmark") { dismiss() }
                    Spacer()
                    Text(names.isEmpty ? title : "\(title) · \(index + 1) / \(names.count)")
                        .font(AppFont.montserrat(14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    roundButton("trash", tint: Color(hex: "FF8A80")) { askDelete = true }
                        .disabled(names.isEmpty)
                }
                Spacer()
                if names.count > 1 {
                    HStack {
                        roundButton("chevron.left") { withAnimation { index -= 1 } }
                            .opacity(index > 0 ? 1 : 0.3)
                            .disabled(index == 0)
                        Spacer()
                        roundButton("chevron.right") { withAnimation { index += 1 } }
                            .opacity(index < names.count - 1 ? 1 : 0.3)
                            .disabled(index >= names.count - 1)
                    }
                }
                Spacer()
            }
            .padding(16)
        }
        .onChange(of: names) { _, new in
            if new.isEmpty { dismiss() } else { index = min(index, new.count - 1) }
        }
        .confirmationDialog("Supprimer cette photo ?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                guard names.indices.contains(index) else { return }
                store.deletePhoto(name: names[index], clientID: clientID, transactionID: transactionID)
            }
        }
    }

    private func roundButton(_ systemImage: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }
}

/// Une vignette qui se télécharge elle-même (voir `RemotePhotoImage`). Un badge signale
/// aussi une photo prise sur ce téléphone qui n'est pas encore partie sur Drive.
private struct RemotePhotoTile: View {
    let name: String
    @Environment(DataStore.self) private var store

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.Colors.photoStripeA)
            RemotePhotoImage(name: name, fill: true, onDark: false)
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
    }
}

/// Une photo qui se télécharge elle-même, avec son état : en cours, affichée, ou échec
/// (avec la raison et un bouton pour relancer le téléchargement).
private struct RemotePhotoImage: View {
    let name: String
    /// true : remplit son cadre (vignette) ; false : photo entière (visionneuse).
    let fill: Bool
    /// Textes clairs, pour le fond noir de la visionneuse.
    let onDark: Bool
    @Environment(DataStore.self) private var store

    private enum LoadState {
        case loading
        case loaded(UIImage)
        case failed(String)
    }

    @State private var state: LoadState = .loading
    @State private var attempt = 0

    private var secondary: Color { onDark ? .white.opacity(0.7) : Theme.Colors.textSecondary }

    var body: some View {
        Group {
            switch state {
            case .loading:
                VStack(spacing: 8) {
                    ProgressView().tint(secondary)
                    Text("Téléchargement…")
                        .font(AppFont.montserrat(11))
                        .foregroundStyle(secondary)
                }
            case .loaded(let image):
                if fill {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(uiImage: image).resizable().scaledToFit()
                }
            case .failed(let reason):
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.Colors.unpaidText)
                    Text("Pas pu être téléchargée")
                        .font(AppFont.montserrat(11))
                        .foregroundStyle(secondary)
                        .multilineTextAlignment(.center)
                    Text(reason)
                        .font(AppFont.montserrat(9))
                        .foregroundStyle(secondary)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                // Photo sortie de l'écran pendant le téléchargement : rien à afficher.
                guard !Task.isCancelled else { return }
                state = .failed(error.localizedDescription)
            }
        }
    }
}
