import Foundation
import SwiftUI

/// Une prestation. Vit imbriquée dans le fichier JSON de sa cliente (`Client.transactions`) —
/// voir `Support/FileStore.swift`. Les photos ne sont pas ici : ce sont des fichiers à part
/// dans `Photos/`, nommés `<id>_avant_n.jpg` / `<id>_apres_n.jpg` (voir `PhotoKind`).
struct AppTransaction: Identifiable, Codable, Hashable {
    var id: UUID
    var ref: String
    var category: Category
    /// Libellé calculé selon la catégorie (voir `TransactionFormDraft.itemLabel`).
    var item: String
    var origine: Origine?
    var price: Decimal
    var isPaid: Bool
    var method: PayMethod
    var plan: Installments?
    var status: WorkStatus
    var dropDate: Date
    var pickupDate: Date?
    var returnDate: Date?
    var pickup2Date: Date?
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        ref: String,
        category: Category,
        item: String,
        origine: Origine? = nil,
        price: Decimal,
        isPaid: Bool = false,
        method: PayMethod = .especes,
        plan: Installments? = nil,
        status: WorkStatus = .enCours,
        dropDate: Date = .now,
        pickupDate: Date? = nil,
        returnDate: Date? = nil,
        pickup2Date: Date? = nil,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.ref = ref
        self.category = category
        self.item = item
        self.origine = origine
        self.price = price
        self.isPaid = isPaid
        self.method = method
        self.plan = plan
        self.status = status
        self.dropDate = dropDate
        self.pickupDate = pickupDate
        self.returnDate = returnDate
        self.pickup2Date = pickup2Date
        self.note = note
        self.createdAt = createdAt
    }

    var payState: PayState {
        if isPaid { return .paye }
        if plan != nil { return .echelonne }
        return .impaye
    }

    /// Jours entre dépôt et aujourd'hui.
    var ageDays: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: dropDate), to: Calendar.current.startOfDay(for: .now)).day ?? 0
    }

    var isOld: Bool { ageDays > 14 }

    /// Reste à payer si échéancier en cours.
    var planLeft: Decimal? {
        guard let plan else { return nil }
        return price - plan.paid
    }

    var planIsLate: Bool {
        guard let plan else { return false }
        return plan.due < Calendar.current.startOfDay(for: .now)
    }

    /// Couleur de vignette selon l'état (règle Accueil §6.1).
    var swatch: (bg: Color, fg: Color) {
        switch status {
        case .enCours: return (Theme.Colors.statusEnCoursBg, Theme.Colors.statusEnCoursText)
        case .pret: return (Theme.Colors.statusPretBg, Theme.Colors.statusPretText)
        case .retour: return (Theme.Colors.statusRetourBg, Theme.Colors.statusRetourText)
        case .rendu: return isPaid ? (Theme.Colors.paidBg, Theme.Colors.paidText) : (Theme.Colors.lateAlert, .white)
        }
    }
}
