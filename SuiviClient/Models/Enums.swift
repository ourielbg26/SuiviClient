import SwiftUI

enum Category: String, CaseIterable, Codable, Identifiable {
    case vente = "Vente"
    case reparation = "Réparation"
    case coupe = "Coupe"
    case couleur = "Couleur"
    case lavage = "Lavage"
    case produit = "Produit"

    var id: String { rawValue }

    /// Catégories proposées pour une nouvelle fiche et dans les filtres. "Coupe" n'en fait
    /// plus partie (les coupes sont des réparations) ; le cas reste pour pouvoir relire
    /// une éventuelle ancienne fiche.
    static let selectable: [Category] = [.vente, .reparation, .couleur, .lavage, .produit]

    /// Pas de paiement en plusieurs fois pour un produit ou un lavage.
    var allowsInstallments: Bool { self != .produit && self != .lavage }

    var lineColor: Color {
        switch self {
        case .vente: return Theme.Colors.venteLine
        case .reparation: return Theme.Colors.reparationLine
        case .coupe: return Theme.Colors.coupeLine
        case .couleur: return Theme.Colors.couleurLine
        case .lavage: return Theme.Colors.lavageLine
        case .produit: return Theme.Colors.produitLine
        }
    }

    var backgroundColor: Color {
        switch self {
        case .vente: return Theme.Colors.venteBg
        case .reparation: return Theme.Colors.reparationBg
        case .coupe: return Theme.Colors.coupeBg
        case .couleur: return Theme.Colors.couleurBg
        case .lavage: return Theme.Colors.lavageBg
        case .produit: return Theme.Colors.produitBg
        }
    }

    var textColor: Color {
        switch self {
        case .vente: return Theme.Colors.venteText
        case .reparation: return Theme.Colors.reparationText
        case .coupe: return Theme.Colors.coupeText
        case .couleur: return Theme.Colors.couleurText
        case .lavage: return Theme.Colors.lavageText
        case .produit: return Theme.Colors.produitText
        }
    }
}

enum WorkStatus: String, CaseIterable, Codable, Identifiable {
    case enCours = "En cours"
    case pret = "Prêt"
    case rendu = "Rendu"
    case retour = "Retour"

    var id: String { rawValue }

    var dotColor: Color {
        switch self {
        case .enCours: return Theme.Colors.statusEnCoursDot
        case .pret: return Theme.Colors.statusPretDot
        case .rendu: return Theme.Colors.statusRenduDot
        case .retour: return Theme.Colors.statusRetourDot
        }
    }

    var backgroundColor: Color {
        switch self {
        case .enCours: return Theme.Colors.statusEnCoursBg
        case .pret: return Theme.Colors.statusPretBg
        case .rendu: return Theme.Colors.statusRenduBg
        case .retour: return Theme.Colors.statusRetourBg
        }
    }

    var textColor: Color {
        switch self {
        case .enCours: return Theme.Colors.statusEnCoursText
        case .pret: return Theme.Colors.statusPretText
        case .rendu: return Theme.Colors.statusRenduText
        case .retour: return Theme.Colors.statusRetourText
        }
    }

    /// Ordre de rotation du bouton "Passer en …" : En cours → Prêt → Rendu → Retour → En cours
    var next: WorkStatus {
        switch self {
        case .enCours: return .pret
        case .pret: return .rendu
        case .rendu: return .retour
        case .retour: return .enCours
        }
    }
}

enum PayMethod: String, CaseIterable, Codable, Identifiable {
    case especes = "Espèces"
    case carte = "Carte"
    case cheque = "Chèque"
    case bit = "Bit"
    case revolut = "Revolut"

    var id: String { rawValue }

    /// Moyens proposés pour un paiement en une fois. Le chèque n'est plus proposé (le cas
    /// reste pour les anciennes fiches réglées par chèque).
    static let choices: [PayMethod] = [.especes, .carte, .bit, .revolut]
    /// Moyens proposés pour un paiement en plusieurs fois.
    static let installmentChoices: [PayMethod] = [.especes, .carte]

    var label: String { self == .carte ? "Carte bleue" : rawValue }
}

enum Origine: String, Codable, CaseIterable, Identifiable {
    case stock = "Stock"
    case commande = "Commande"

    var id: String { rawValue }
}

/// État de paiement dérivé (pas persisté tel quel — calculé depuis isPaid/plan).
enum PayState {
    case paye, echelonne, impaye
}

/// Les quatre catalogues de Paramètres.
enum CatalogType: String, CaseIterable, Codable, Identifiable {
    case reparation = "Réparation"
    case couleur = "Couleur"
    case typeCouleur = "TypeCouleur"
    case produit = "Produit"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reparation: return "Types de réparation"
        case .couleur: return "Teintes"
        case .typeCouleur: return "Colorimétrie"
        case .produit: return "Produits à vendre"
        }
    }

    var tabLabel: String {
        switch self {
        case .reparation: return "Réparations"
        case .couleur: return "Teintes"
        case .typeCouleur: return "Colorimétrie"
        case .produit: return "Produits"
        }
    }

    var entryPlaceholder: String {
        switch self {
        case .reparation: return "Nouveau type"
        case .couleur: return "Nouvelle teinte"
        case .typeCouleur: return "Racine, balayage…"
        case .produit: return "Nouveau produit"
        }
    }

    var dotColor: Color {
        switch self {
        case .reparation: return Theme.Colors.reparationLine
        case .couleur, .typeCouleur: return Theme.Colors.couleurLine
        case .produit: return Theme.Colors.produitLine
        }
    }
}

/// Paiement en plusieurs fois (espèces, chèque ou carte).
/// - Chèque / carte : les mensualités tombent toutes seules ; la fiche reste "en cours de
///   paiement" jusqu'à la date de la dernière, puis passe en payé
///   (`DataStore.settleFinishedInstallments`).
/// - Espèces : chaque paiement reçu est noté dans `received` ; la fiche passe en "non
///   payé" dès qu'une mensualité passée n'est pas couverte, et en payé quand tout est reçu.
struct Installments: Codable, Hashable {
    /// Versé à la création (acompte).
    var paid: Decimal
    /// Date de la 1ʳᵉ mensualité — les suivantes tombent le même jour des mois suivants.
    /// Pour les échéanciers créés avant les mensualités (`count` nil) : simple date de la
    /// prochaine échéance.
    var due: Date
    var method: PayMethod
    /// Nombre de mensualités — nil pour les échéanciers créés avant ce champ.
    var count: Int?
    /// Espèces : paiements reçus après la création, dans l'ordre où ils ont été notés.
    var received: [InstallmentReceipt]?
}

/// Un paiement en espèces reçu pendant un échelonnement.
struct InstallmentReceipt: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var amount: Decimal
}
