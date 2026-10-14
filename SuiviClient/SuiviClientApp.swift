import SwiftUI
import UIKit

@main
struct SuiviClientApp: App {
    @State private var store = DataStore()
    @State private var agenda = AppointmentStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .background(KeyboardDismissOnTap())
                .environment(store)
                .environment(agenda)
        }
    }
}

/// Toucher l'écran ailleurs que dans un champ de saisie (en haut de l'écran, sur un
/// titre…) ferme le clavier. Le toucher passe quand même aux boutons en dessous.
private struct KeyboardDismissOnTap: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView, UIGestureRecognizerDelegate {
        private weak var installedOn: UIWindow?
        private lazy var tap: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            return tap
        }()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, window !== installedOn else { return }
            installedOn?.removeGestureRecognizer(tap)
            window.addGestureRecognizer(tap)
            installedOn = window
        }

        @objc private func dismissKeyboard() {
            // Après coup, pour laisser le bouton touché (ex. une suggestion) agir d'abord.
            DispatchQueue.main.async { [weak self] in self?.installedOn?.endEditing(true) }
        }

        /// Un toucher dans un champ de saisie ne ferme rien (on passe d'un champ à l'autre).
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}
