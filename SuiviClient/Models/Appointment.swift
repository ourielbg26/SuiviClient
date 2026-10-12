import SwiftUI

/// Un rendez-vous du calendrier. Gardé seulement sur ce téléphone (pas de synchro Drive).
struct Appointment: Identifiable, Codable, Hashable {
    var id = UUID()
    var typeID: UUID?
    var clientName: String
    /// Cliente de l'app quand le nom a été choisi dans les suggestions.
    var clientID: UUID?
    var start: Date
    var durationMinutes: Int
    var note: String = ""

    var end: Date { start.addingTimeInterval(TimeInterval(durationMinutes * 60)) }
}

/// Type de rendez-vous (essayage, devis…) : nom, durée proposée, couleur.
struct AppointmentType: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var durationMinutes: Int
    var colorHex: String

    var color: Color { Color(hex: colorHex) }

    /// Couleurs proposées pour les types — accordées à la palette de l'app.
    static let palette = ["D49A98", "BC8DB2", "DCA088", "9DBBCF", "A3C2AE", "D6B260", "B3A3CF", "8E7A75"]

    static let defaults: [AppointmentType] = [
        AppointmentType(name: "Essayage perruque", durationMinutes: 60, colorHex: "BC8DB2"),
        AppointmentType(name: "Devis réparation", durationMinutes: 30, colorHex: "DCA088"),
        AppointmentType(name: "Dépôt", durationMinutes: 15, colorHex: "D6B260"),
        AppointmentType(name: "Récupération", durationMinutes: 15, colorHex: "A3C2AE"),
        AppointmentType(name: "Lavage", durationMinutes: 30, colorHex: "9DBBCF"),
        AppointmentType(name: "Lavage + coiffage", durationMinutes: 60, colorHex: "D49A98"),
    ]
}

/// Réglages du calendrier (Paramètres).
struct CalendarSettings: Codable, Hashable {
    /// Découpage d'une journée : 60, 30 ou 15 minutes.
    var slotMinutes = 30
    var showsJewishHolidays = true
    var showsIsraeliHolidays = true
    var types = AppointmentType.defaults
    /// Plage horaire affichée en mode journée.
    var dayStartHour = 8
    var dayEndHour = 20

    func type(id: UUID?) -> AppointmentType? {
        guard let id else { return nil }
        return types.first { $0.id == id }
    }
}
