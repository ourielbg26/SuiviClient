import Foundation

/// Jeu de données d'exemple — uniquement pour le débogage (README §7 : "l'app
/// livrée démarre vide"). Activé via `DebugFlags.useSampleData`.
enum DebugFlags {
    #if DEBUG
    static let useSampleData = true
    #else
    static let useSampleData = false
    #endif
}

enum SampleData {
    static func makeClients() -> [Client] {
        func daysAgo(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: -n, to: .now) ?? .now }
        func daysFromNow(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: .now) ?? .now }

        func t(_ ref: String, _ category: Category, _ item: String, _ price: Decimal,
               origine: Origine? = nil, isPaid: Bool = false, method: PayMethod = .especes, plan: Installments? = nil,
               status: WorkStatus = .enCours, drop: Date, pickup: Date? = nil, ret: Date? = nil, note: String = "") -> AppTransaction {
            AppTransaction(ref: ref, category: category, item: item, origine: origine, price: price, isPaid: isPaid,
                           method: method, plan: plan, status: status, dropDate: drop, pickupDate: pickup, returnDate: ret, note: note)
        }

        var clients: [String: Client] = [:]
        func add(_ name: String, _ phone: String, _ transaction: AppTransaction) {
            clients[name, default: Client(name: name, phone: phone)].transactions.append(transaction)
        }

        add("Aïcha Diallo", "06 12 44 08 71", t("T-042", .reparation, "Lace frontale + Densification", 120, status: .enCours, drop: daysAgo(18), note: "Lace décollée sur 4 cm, deux rangées à densifier."))
        add("Fatou Bamba", "07 55 21 90 03", t("T-041", .couleur, "Balayage · Miel 27", 95, status: .enCours, drop: daysAgo(14), note: "Éviter les longueurs trop claires."))
        add("Sarah Mensah", "06 78 32 15 44", t("T-040", .lavage, "Lavage + coiffage · Wavy", 60, isPaid: true, method: .carte, status: .enCours, drop: daysAgo(8), note: "Cheveux fins, chaleur basse."))
        add("Nadia Chérif", "07 01 88 26 19", t("T-039", .vente, "Bouclé 40-45 · Blond 613 · Bonnet M · Commande", 280, origine: .commande, status: .pret, drop: daysAgo(23), note: "Prévenir dès que la commande arrive."))
        add("Kadiatou Sow", "06 44 70 12 58", t("T-038", .reparation, "Bonnet + élastique", 35, isPaid: true, method: .especes, status: .pret, drop: daysAgo(11), note: "Élastique remplacé, bonnet resserré."))
        add("Leïla Haddad", "07 22 65 47 30", t("T-037", .couleur, "Racine · Noir 1B", 70, status: .pret, drop: daysAgo(7), note: "Retouche racines uniquement."))
        add("Mariam Traoré", "06 90 03 55 12", t("T-036", .vente, "Raide 45-50 · Châtain 4 · Bonnet L", 320, origine: .stock, status: .rendu, drop: daysAgo(35), pickup: daysAgo(27), note: "Doit régler le solde en septembre."))
        add("Chloé Bernard", "07 66 11 74 82", t("T-035", .produit, "Colle waterproof", 22, status: .rendu, drop: daysAgo(15), pickup: daysAgo(15)))
        add("Awa Ndiaye", "06 31 09 62 47", t("T-034", .vente, "Ondulé 40-45 · Miel 27 · Bonnet M · Commande", 300, origine: .commande, plan: Installments(paid: 150, due: daysAgo(11), method: .especes), status: .rendu, drop: daysAgo(60), pickup: daysAgo(53), note: "Paiement en trois fois, en espèces."))
        add("Inès Rossi", "07 40 58 33 26", t("T-033", .vente, "Raide 35-40 · Noir 1B · Bonnet S", 260, origine: .stock, plan: Installments(paid: 130, due: daysFromNow(14), method: .cheque), status: .rendu, drop: daysAgo(45), pickup: daysAgo(41), note: "Chèques échelonnés sur deux mois."))
        add("Rokia Cissé", "06 07 92 41 15", t("T-032", .lavage, "Lavage seul", 40, isPaid: true, method: .especes, status: .rendu, drop: daysAgo(32), pickup: daysAgo(31)))
        add("Yasmine Belkacem", "07 84 26 70 91", t("T-031", .reparation, "Ajout de franges", 50, isPaid: true, method: .carte, status: .rendu, drop: daysAgo(36), pickup: daysAgo(35), note: "Frange rideau, dégradé léger."))
        add("Aïcha Diallo", "06 12 44 08 71", t("T-030", .vente, "Ondulé 30-35 · Roux 350 · Bonnet M", 205, origine: .stock, isPaid: true, method: .especes, status: .rendu, drop: daysAgo(50), pickup: daysAgo(50), note: "Deuxième achat de l'année."))
        add("Leïla Haddad", "07 22 65 47 30", t("T-027", .vente, "Bouclé 50+ · Gris argenté · Bonnet L", 340, origine: .stock, isPaid: true, method: .carte, status: .retour, drop: daysAgo(27), pickup: daysAgo(25), ret: daysAgo(6), note: "Trame qui lâche, reprise en atelier."))

        // Deux contacts sans transaction, pour tester l'état "Pas encore de transaction".
        for (name, phone) in [("Mariam Traoré", "06 90 03 55 12"), ("Chloé Bernard", "07 66 11 74 82")] where clients[name] == nil {
            clients[name] = Client(name: name, phone: phone)
        }

        return Array(clients.values)
    }

    static func makeCatalog() -> CatalogData {
        var catalog = CatalogData()
        catalog.reparation = ["Lace frontale", "Trame arrière", "Densification", "Nœuds blanchis", "Bonnet + élastique", "Ajout de franges"].map { CatalogItem(name: $0) }
        catalog.couleur = ["Noir 1B", "Châtain 4", "Miel 27", "Blond 613", "Roux 350", "Gris argenté"].map { CatalogItem(name: $0) }
        catalog.typeCouleur = ["Racine", "Balayage", "Ombré", "Couleur complète", "Mèches"].map { CatalogItem(name: $0) }
        catalog.produit = ["Shampoing doux", "Colle waterproof", "Spray brillance", "Filet à perruque", "Sérum sans rinçage"].map { CatalogItem(name: $0) }
        return catalog
    }
}
