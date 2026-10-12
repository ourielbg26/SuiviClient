import Foundation
import SwiftUI

/// Une prestation. Vit imbriquée dans le fichier JSON de sa cliente (`Client.transactions`) —
/// voir `Support/FileStore.swift`. Les photos elles-mêmes vivent sur Drive (`Photos/`,
/// nommées `<id>_avant_n.jpg` / `<id>_apres_n.jpg`, voir `PhotoKind`) ; la fiche ne garde
/// que leurs noms (`photoNames`), pour savoir sans réseau s'il y a des photos à télécharger.
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
    /// Vente : acompte versé à la commande. Gardé une fois la vente payée en totalité,
    /// pour garder la trace de ce que la cliente a donné au départ.
    var deposit: Decimal?
    var status: WorkStatus
    var dropDate: Date
    var pickupDate: Date?
    var returnDate: Date?
    var pickup2Date: Date?
    var note: String
    /// Dernière modification de la note — absente des fiches dont la note n'a pas été
    /// touchée depuis l'ajout de ce champ.
    var noteUpdatedAt: Date?
    var createdAt: Date
    /// Absent des fiches enregistrées avant l'ajout de ce champ — d'où l'optionnel ;
    /// passer par `photoNames`.
    private var photos: [String]?

    /// Noms des photos de la fiche sur Drive, dans l'ordre d'ajout.
    var photoNames: [String] {
        get { photos ?? [] }
        set { photos = newValue.isEmpty ? nil : newValue }
    }

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
        if plan != nil { return isBehindOnCashInstallments ? .impaye : .echelonne }
        return .impaye
    }

    /// Numéro de fiche tiré de `ref` ("T-012" → 12).
    var ficheNumber: Int? { Int(ref.drop { !$0.isNumber }) }

    /// "Fiche nº 12" — affichage de `ref`, qui reste stocké sous la forme "T-012".
    var ficheLabel: String { ficheNumber.map { "Fiche nº \($0)" } ?? "Fiche \(ref)" }

    /// Ordre d'arrivée, le plus récent en premier : date de dépôt, puis numéro de fiche
    /// pour départager les fiches déposées le même jour.
    static func byArrivalNewestFirst(_ a: AppTransaction, _ b: AppTransaction) -> Bool {
        if a.dropDate != b.dropDate { return a.dropDate > b.dropDate }
        return (a.ficheNumber ?? 0) > (b.ficheNumber ?? 0)
    }

    /// Jours entre dépôt et aujourd'hui.
    var ageDays: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: dropDate), to: Calendar.current.startOfDay(for: .now)).day ?? 0
    }

    var isOld: Bool { ageDays > 14 }

    /// Acompte d'une vente — pour les ventes enregistrées avant le champ `deposit`, le
    /// montant déjà versé de l'échéancier, s'il y en a un.
    var depositAmount: Decimal? {
        guard category == .vente else { return nil }
        return deposit ?? plan?.paid
    }

    // MARK: Paiement en plusieurs fois

    /// Total déjà reçu : acompte + paiements en espèces notés depuis.
    var planReceived: Decimal? {
        guard let plan else { return nil }
        return (plan.received ?? []).reduce(plan.paid) { $0 + $1.amount }
    }

    /// Reste à payer si échéancier en cours.
    var planLeft: Decimal? {
        planReceived.map { price - $0 }
    }

    /// Montant d'une mensualité : le reste après l'acompte, réparti à parts égales.
    var installmentAmount: Decimal? {
        guard let plan, let count = plan.count, count > 0 else { return nil }
        return (price - plan.paid) / Decimal(count)
    }

    /// Dates de toutes les mensualités (vide pour un ancien échéancier sans nombre).
    var installmentDates: [Date] {
        guard let plan, let count = plan.count, count > 0 else { return [] }
        return (0..<count).compactMap { Calendar.current.date(byAdding: .month, value: $0, to: plan.due) }
    }

    /// Nombre de mensualités dont la date est passée.
    var installmentsElapsed: Int {
        let today = Calendar.current.startOfDay(for: .now)
        return installmentDates.filter { Calendar.current.startOfDay(for: $0) < today }.count
    }

    /// Espèces : mensualités couvertes par ce qui a été reçu (une avance compte pour les
    /// mois suivants).
    var installmentsCovered: Int {
        guard let amount = installmentAmount, amount > 0, let plan, let received = planReceived else { return 0 }
        let paidMonths = NSDecimalNumber(decimal: (received - plan.paid) / amount).doubleValue
        return min(plan.count ?? 0, Int((paidMonths + 0.0001).rounded(.down)))
    }

    /// Espèces : une mensualité passée n'est pas (entièrement) payée.
    var isBehindOnCashInstallments: Bool {
        guard !isPaid, let plan, plan.method == .especes, plan.count != nil else { return false }
        return installmentsCovered < installmentsElapsed
    }

    /// Prochaine mensualité attendue : la première pas encore couverte (espèces), ou la
    /// prochaine à tomber (chèque / carte). Ancien échéancier : sa date d'échéance.
    var nextInstallmentDate: Date? {
        guard let plan else { return nil }
        let dates = installmentDates
        guard !dates.isEmpty else { return plan.due }
        if plan.method == .especes {
            return installmentsCovered < dates.count ? dates[installmentsCovered] : nil
        }
        return installmentsElapsed < dates.count ? dates[installmentsElapsed] : nil
    }

    /// En retard : une mensualité en espèces non couverte, ou (ancien échéancier sans
    /// mensualités) date d'échéance passée. Un chèque ou une carte n'est jamais en retard.
    var planIsLate: Bool {
        guard let plan else { return false }
        if plan.count != nil { return isBehindOnCashInstallments }
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
