import Foundation
import Observation

/// Rendez-vous et réglages du calendrier. Contrairement aux fiches, rien ne part sur
/// Drive : chaque iPhone a son propre calendrier.
@Observable
final class AppointmentStore {
    private(set) var appointments: [Appointment]
    var settings: CalendarSettings {
        didSet { fileStore.save(settings) }
    }

    private let fileStore: FileStore

    init(fileStore: FileStore = FileStore()) {
        self.fileStore = fileStore
        self.appointments = fileStore.loadAppointments()
        self.settings = fileStore.loadCalendarSettings()
    }

    func save(_ appointment: Appointment) {
        if let idx = appointments.firstIndex(where: { $0.id == appointment.id }) {
            appointments[idx] = appointment
        } else {
            appointments.append(appointment)
        }
        fileStore.save(appointments)
    }

    func delete(id: UUID) {
        appointments.removeAll { $0.id == id }
        fileStore.save(appointments)
    }

    /// Rendez-vous d'une journée, dans l'ordre.
    func appointments(on day: Date) -> [Appointment] {
        appointments
            .filter { Calendar.current.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
    }

    /// Rendez-vous à venir d'une cliente (liée, ou au même nom).
    func upcoming(for client: Client) -> [Appointment] {
        let today = Calendar.current.startOfDay(for: .now)
        return appointments
            .filter { $0.start >= today }
            .filter { $0.clientID == client.id || ($0.clientID == nil && $0.clientName.caseInsensitiveCompare(client.name) == .orderedSame) }
            .sorted { $0.start < $1.start }
    }

    func type(of appointment: Appointment) -> AppointmentType? {
        settings.type(id: appointment.typeID)
    }

    /// La cliente a changé de nom : ses rendez-vous liés suivent.
    func renameClient(id: UUID, to name: String) {
        var changed = false
        for idx in appointments.indices where appointments[idx].clientID == id {
            appointments[idx].clientName = name
            changed = true
        }
        if changed { fileStore.save(appointments) }
    }

    // MARK: Types de rendez-vous

    func saveType(_ type: AppointmentType) {
        if let idx = settings.types.firstIndex(where: { $0.id == type.id }) {
            settings.types[idx] = type
        } else {
            settings.types.append(type)
        }
    }

    func deleteType(id: UUID) {
        settings.types.removeAll { $0.id == id }
    }
}
