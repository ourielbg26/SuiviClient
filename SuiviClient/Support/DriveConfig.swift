import Foundation

/// Adresse du pont Google Apps Script (voir `google-apps-script/LISEZ-MOI.md`).
/// Tant que `webAppURL` est vide, l'app fonctionne uniquement en local — aucun réglage
/// n'est proposé à l'utilisatrice, cette valeur est fixée ici une fois le script déployé.
enum DriveConfig {
    static let webAppURL = "https://script.google.com/macros/s/AKfycbzkMsRLZ83Cr_YkSG8qrVSWQ2L3dWDjO0fO8hlGainY8EY96LRa815OWqq-cIqEK6zK/exec"
    static let secret = "ZlwXB5TyT0ivTI_IG9-0_NbFtcWjArU5Rtlvowl-m4U"

    static var isConfigured: Bool { !webAppURL.isEmpty }
}
