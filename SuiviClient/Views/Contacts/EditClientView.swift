import SwiftUI

/// Modifier le nom et le téléphone d'une cliente (ou les reprendre du carnet d'adresses).
struct EditClientView: View {
    let clientID: UUID
    @State var name: String
    @State var phone: String

    @Environment(DataStore.self) private var store
    @Environment(AppointmentStore.self) private var agenda
    @Environment(\.dismiss) private var dismiss

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Modifier la cliente").font(AppFont.display(20, weight: .semibold))

            PhoneContactButton { pickedName, pickedPhone in
                if !pickedName.isEmpty { name = pickedName }
                if !pickedPhone.isEmpty { phone = pickedPhone }
            }

            field("Nom et prénom", text: $name)
            field("Téléphone", text: $phone, keyboard: .phonePad)

            Spacer(minLength: 0)

            PrimaryButton(title: "Enregistrer", isEnabled: !trimmedName.isEmpty) {
                let newPhone = phone.trimmingCharacters(in: .whitespaces)
                store.updateClient(id: clientID, name: trimmedName, phone: newPhone)
                agenda.renameClient(id: clientID, to: trimmedName)
                dismiss()
            }
        }
        .padding(22)
        .background(PaperBackground())
    }

    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .font(AppFont.montserrat(14))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.card))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
        }
    }
}
