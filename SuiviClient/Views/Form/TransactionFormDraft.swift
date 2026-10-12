import Foundation

/// État complet du formulaire (création ET modification) — §6.4 du README.
/// Les champs décomposés par catégorie ne sont pas persistés tels quels : à
/// l'enregistrement ils sont recomposés en un seul `item` (voir `itemLabel`),
/// et à l'édition ils sont redéduits du `item` existant (voir `from(existing:)`).
struct TransactionFormDraft {
    var name: String = ""
    var phone: String = ""
    var saveContact: Bool = true
    var category: Category = .reparation

    // Réparation — multi-sélection
    var reparations: [String] = []
    /// Combien de fois pour les réparations à l'unité (ex. "Ajout ligne" × 3).
    var reparationQuantities: [String: Int] = [:]
    // Couleur
    var typeCouleur: String = ""
    var couleur: String = ""
    // Produit
    var produit: String = ""
    // Vente
    var origine: Origine = .stock
    var taille: String = "M"
    var texture: String = "Ondulé"
    var longueur: String = "40"
    // Lavage
    var lavage: String = FixedOptions.lavageOptions[0]
    var finition: String = FixedOptions.finitions[0]

    var price: String = ""
    var dropDate: Date = .now
    var status: WorkStatus = .enCours
    var pickupDate: Date?
    var returnDate: Date?
    var pickup2Date: Date?

    var note: String = ""
    var photos: [Data] = []

    var pay: PayChoice = .pasEncore
    var method: PayMethod = .especes
    var planPaid: String = ""
    var planDue: Date = .now
    var planMethod: PayMethod = .especes
    /// Nombre de mensualités (paiement en plusieurs fois).
    var planCount: String = ""

    /// Vente uniquement : acompte versé à la commande (gardé même une fois tout payé).
    var venteAcompte: String = ""
    /// Vente uniquement : le reste a été réglé. Sans objet si l'acompte couvre le prix.
    var venteSoldePaye = false

    enum PayChoice: String, CaseIterable, Identifiable {
        case pasEncore = "Pas encore"
        case paye = "Payé"
        case plusieursFois = "En plusieurs fois"
        var id: String { rawValue }
    }

    /// Libellé `item` recomposé selon la catégorie (règles §4 du README).
    var itemLabel: String {
        switch category {
        case .vente:
            let bits = [
                [texture, longueur].filter { !$0.isEmpty }.joined(separator: " "),
                couleur,
                taille.isEmpty ? "" : "Bonnet \(taille)"
            ].filter { !$0.isEmpty }
            let base = bits.isEmpty ? "Vente" : bits.joined(separator: " · ")
            return origine == .commande ? base + " · Commande" : base
        case .reparation:
            guard !reparations.isEmpty else { return "Réparation" }
            return reparations.map { name in
                let qty = reparationQuantities[name] ?? 1
                return qty > 1 ? "\(name) ×\(qty)" : name
            }.joined(separator: " + ")
        case .coupe:
            return "Coupe"
        case .couleur:
            let bits = [typeCouleur, couleur].filter { !$0.isEmpty }
            return bits.isEmpty ? "Couleur" : bits.joined(separator: " · ")
        case .lavage:
            return lavage == "Lavage seul" ? "Lavage seul" : "Lavage + coiffage · \(finition)"
        case .produit:
            return produit.isEmpty ? "Produit" : produit
        }
    }

    /// Prix saisi, converti en Decimal (0 si invalide).
    var priceValue: Decimal {
        let normalized = price.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized, locale: Locale(identifier: "en_US")) ?? 0
    }

    /// Moyen de paiement enregistré : pour une vente, celui choisi avec les mensualités
    /// (la vente n'a plus de choix "Réglé en" séparé).
    var paymentMethod: PayMethod { category == .vente ? planMethod : method }

    /// Nombre de mensualités saisi — nil si vide ou invalide.
    var planCountValue: Int? {
        guard let n = Int(planCount.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n
    }

    /// Acompte saisi (Vente), converti en Decimal (0 si invalide).
    var venteAcompteValue: Decimal {
        let normalized = venteAcompte.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized, locale: Locale(identifier: "en_US")) ?? 0
    }

    /// Bouton d'enregistrement actif : nom + prix + donnée clé de la catégorie.
    var isReady: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, priceValue > 0 else { return false }
        switch category {
        case .reparation: return !reparations.isEmpty
        case .couleur: return !couleur.isEmpty || !typeCouleur.isEmpty
        case .produit: return !produit.isEmpty
        case .vente, .lavage, .coupe: return true
        }
    }

    static func blank() -> TransactionFormDraft { TransactionFormDraft() }

    /// Pré-remplit un brouillon depuis une transaction existante (Modifier). Les photos
    /// déjà enregistrées restent sur disque et se gèrent depuis la fiche ; ce formulaire
    /// ne permet d'en AJOUTER que de nouvelles pendant cette modification.
    static func from(existing t: TransactionEntry) -> TransactionFormDraft {
        var f = TransactionFormDraft()
        f.name = t.clientName
        f.phone = t.phone
        f.saveContact = false
        f.category = t.category
        f.price = "\(t.price)"
        f.dropDate = t.dropDate
        f.status = t.status
        f.pickupDate = t.pickupDate
        f.returnDate = t.returnDate
        f.pickup2Date = t.pickup2Date
        f.note = t.note
        f.method = t.method
        switch t.payState {
        case .paye: f.pay = .paye
        case .echelonne: f.pay = .plusieursFois
        case .impaye: f.pay = .pasEncore
        }
        if let plan = t.plan {
            f.planPaid = "\(plan.paid)"
            f.planDue = plan.due
            f.planMethod = plan.method
            f.planCount = plan.count.map(String.init) ?? ""
        }
        if t.category == .vente {
            f.planMethod = t.plan?.method ?? (PayMethod.installmentChoices.contains(t.method) ? t.method : .especes)
            f.venteAcompte = t.depositAmount.map { "\($0)" } ?? ""
            f.venteSoldePaye = t.isPaid
        }

        let parts = t.item.components(separatedBy: " · ")
        switch t.category {
        case .reparation:
            for part in t.item.components(separatedBy: " + ") {
                let bits = part.components(separatedBy: " ×")
                if bits.count == 2, let qty = Int(bits[1]) {
                    f.reparations.append(bits[0])
                    f.reparationQuantities[bits[0]] = qty
                } else {
                    f.reparations.append(part)
                }
            }
        case .coupe:
            // Ancienne fiche "Coupe" : se modifie comme une réparation.
            f.category = .reparation
            f.reparations = [t.item]
        case .couleur:
            f.typeCouleur = parts.first ?? ""
            f.couleur = parts.count > 1 ? parts[1] : ""
        case .produit:
            f.produit = t.item
        case .lavage:
            f.lavage = t.item.contains("coiffage") ? "Lavage + coiffage" : "Lavage seul"
            f.finition = parts.count > 1 ? parts[1] : FixedOptions.finitions[0]
        case .vente:
            // "Raide haut, ondulé bas 60" : la longueur est le dernier mot, la texture le reste.
            var words = (parts.first ?? "").components(separatedBy: " ")
            if let last = words.last, Int(last) != nil {
                f.longueur = last
                words.removeLast()
            } else {
                f.longueur = ""
            }
            f.texture = words.joined(separator: " ")
            f.couleur = parts.count > 1 ? parts[1] : ""
            f.taille = parts.count > 2 ? parts[2].replacingOccurrences(of: "Bonnet ", with: "") : "M"
            f.origine = t.origine ?? (t.item.contains("Commande") ? .commande : .stock)
        }
        return f
    }
}
