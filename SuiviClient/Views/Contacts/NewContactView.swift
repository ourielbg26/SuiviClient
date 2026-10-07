import SwiftUI

struct NewContactView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""

    private var isReady: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Nouvelle cliente")

            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nom et prénom").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                            TextField("Aïcha Diallo", text: $name)
                                .font(AppFont.montserrat(14))
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Téléphone").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                            TextField("06 …", text: $phone)
                                .keyboardType(.phonePad)
                                .font(AppFont.montserrat(14))
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.background))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
                        }
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(.white))
                    .cardShadow()

                    VStack(spacing: 7) {
                        PrimaryButton(title: "Ajouter la cliente", isEnabled: isReady) {
                            store.addContact(name: name.trimmingCharacters(in: .whitespaces), phone: phone.trimmingCharacters(in: .whitespaces))
                            dismiss()
                        }
                        Text(isReady ? "Elle apparaîtra dans les contacts." : "Indique au moins son nom.")
                            .font(AppFont.montserrat(11))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, Theme.Spacing.contentMargin)
                .screenBottomPadding()
            }
        }
        .background(Theme.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
    }
}
