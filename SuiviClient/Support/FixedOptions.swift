import Foundation

/// Listes fixes du formulaire Vente / Lavage (§6.4).
enum FixedOptions {
    static let tailles = ["XS", "S", "M", "L", "XL"]
    static let textures = ["Raide", "Ondulé", "Bouclé", "Raide haut, ondulé bas"]
    static let longueurs = ["30", "35", "40", "45", "50", "55", "60", "65"]
    /// Couleurs des perruques vendues (différentes des teintes de la catégorie Couleur).
    static let venteCouleurs = ["2", "4", "5", "6", "7", "8"]
    static let finitions = ["Raide", "Wavy", "Cranté"]
    static let lavageOptions = ["Lavage seul", "Lavage + coiffage"]
}
