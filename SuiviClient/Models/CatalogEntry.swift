import Foundation

/// Une entrée d'un des quatre catalogues (Réparations, Couleurs, Types couleur, Produits).
/// Alimente les suggestions du formulaire (§6.4 et §6.7 du README).
struct CatalogItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    /// Prix préenregistré — proposé dans le formulaire, modifiable fiche par fiche.
    var price: Decimal?
    /// Prix à l'unité ("ligne") : le formulaire demande alors combien en ajouter.
    var unit: String?

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, price: Decimal? = nil, unit: String? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.price = price
        self.unit = unit
    }
}

/// Le fichier `Catalog.json` : les quatre listes dans un seul petit fichier partagé
/// (peu de risque de conflit, ça change rarement).
struct CatalogData: Codable {
    var reparation: [CatalogItem] = []
    var couleur: [CatalogItem] = []
    var typeCouleur: [CatalogItem] = []
    var produit: [CatalogItem] = []
    var version: Int = 0

    subscript(type: CatalogType) -> [CatalogItem] {
        get {
            switch type {
            case .reparation: return reparation
            case .couleur: return couleur
            case .typeCouleur: return typeCouleur
            case .produit: return produit
            }
        }
        set {
            switch type {
            case .reparation: reparation = newValue
            case .couleur: couleur = newValue
            case .typeCouleur: typeCouleur = newValue
            case .produit: produit = newValue
            }
        }
    }
}
