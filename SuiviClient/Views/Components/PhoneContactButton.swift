import SwiftUI
import ContactsUI

/// Bouton "Importer depuis mes contacts" : ouvre le carnet d'adresses du téléphone et
/// renvoie le nom complet et le premier numéro du contact choisi. Aucune autorisation
/// n'est demandée — iOS ne partage avec l'app que le contact sélectionné.
struct PhoneContactButton: View {
    let onPick: (_ name: String, _ phone: String) -> Void

    var body: some View {
        Button {
            PhoneContactPicker.present(onPick: onPick)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 15, weight: .light))
                Text("Importer depuis mes contacts")
                    .font(AppFont.montserrat(12, weight: .semibold))
            }
            .foregroundStyle(Theme.Colors.accentText)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Capsule().fill(Theme.Colors.accentTint))
        }
        .buttonStyle(.plain)
    }
}

/// Présente `CNContactPickerViewController` par-dessus l'écran courant (le présenter
/// dans une `.sheet` SwiftUI le referme aussitôt).
private enum PhoneContactPicker {
    private static var delegate: Delegate?

    @MainActor
    static func present(onPick: @escaping (String, String) -> Void) {
        let window = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
        guard var top = window?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }

        let picker = CNContactPickerViewController()
        let delegate = Delegate { contact in
            let name = CNContactFormatter.string(from: contact, style: .fullName)
                ?? [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
            onPick(name, phone)
        }
        self.delegate = delegate
        picker.delegate = delegate
        top.present(picker, animated: true)
    }

    private final class Delegate: NSObject, CNContactPickerDelegate {
        let onSelect: (CNContact) -> Void
        init(onSelect: @escaping (CNContact) -> Void) { self.onSelect = onSelect }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact)
            PhoneContactPicker.delegate = nil
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            PhoneContactPicker.delegate = nil
        }
    }
}
