import SwiftUI

/// Création / modification d'un rendez-vous : type (avec sa durée proposée), cliente,
/// jour, heure (selon le découpage choisi dans les Paramètres), durée, note.
struct AppointmentEditorView: View {
    @State var appointment: Appointment
    let isNew: Bool

    @Environment(AppointmentStore.self) private var agenda
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool
    @State private var askDelete = false

    private var trimmedName: String { appointment.clientName.trimmingCharacters(in: .whitespaces) }

    private var suggestions: [Client] {
        guard nameFocused, !trimmedName.isEmpty else { return [] }
        return Array(store.clients
            .filter { $0.name.localizedCaseInsensitiveContains(trimmedName) && $0.name != trimmedName }
            .sorted { $0.name < $1.name }
            .prefix(4))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isNew ? "Nouveau rendez-vous" : "Rendez-vous")
                    .font(AppFont.display(20, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Theme.Colors.card))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    typePicker
                    clientField
                    whenFields
                    noteField

                    PrimaryButton(title: "Enregistrer", isEnabled: !trimmedName.isEmpty || appointment.typeID != nil) {
                        appointment.clientName = trimmedName
                        agenda.save(appointment)
                        dismiss()
                    }

                    if !isNew {
                        Button(role: .destructive) {
                            askDelete = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                Text("Supprimer le rendez-vous")
                            }
                            .font(AppFont.montserrat(13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .foregroundStyle(Theme.Colors.unpaidText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .background(PaperBackground())
        .alert("Supprimer ce rendez-vous ?", isPresented: $askDelete) {
            Button("Supprimer", role: .destructive) {
                agenda.delete(id: appointment.id)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    // MARK: Type

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Type de rendez-vous")
            FlowLayout(spacing: 7) {
                ForEach(agenda.settings.types) { type in
                    let active = appointment.typeID == type.id
                    Button {
                        appointment.typeID = type.id
                        appointment.durationMinutes = type.durationMinutes
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(type.color).frame(width: 8, height: 8)
                            Text(type.name).font(AppFont.montserrat(12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(active ? type.color.opacity(0.28) : Theme.Colors.chipInactiveBg))
                        .overlay(Capsule().strokeBorder(active ? type.color : Theme.Colors.border, lineWidth: 1))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Cliente

    private var clientField: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Cliente")
            TextField("Nom de la cliente", text: Binding(
                get: { appointment.clientName },
                set: {
                    appointment.clientName = $0
                    appointment.clientID = nil
                }
            ))
            .font(AppFont.montserrat(14))
            .focused($nameFocused)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))

            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { c in
                        Button {
                            appointment.clientName = c.name
                            appointment.clientID = c.id
                            nameFocused = false
                        } label: {
                            HStack {
                                Text(c.name).font(AppFont.montserrat(13, weight: .medium))
                                Spacer()
                                Text(c.phone).font(AppFont.montserrat(11)).foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.card))
            } else if let id = appointment.clientID, let client = store.client(id: id) {
                Text("Cliente de l'app · \(client.phone)")
                    .font(AppFont.montserrat(11))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: Jour, heure, durée

    private var whenFields: some View {
        VStack(spacing: 12) {
            HStack {
                label("Jour")
                Spacer()
                DatePicker("", selection: Binding(
                    get: { appointment.start },
                    set: { newDay in
                        // Garde l'heure, change le jour.
                        let cal = CalendarFormat.calendar
                        let time = cal.dateComponents([.hour, .minute], from: appointment.start)
                        appointment.start = cal.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: newDay) ?? newDay
                    }
                ), displayedComponents: .date)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "fr_FR"))
            }
            HStack {
                label("Heure")
                Spacer()
                Picker("Heure", selection: Binding(get: { minutesOfDay }, set: { setMinutesOfDay($0) })) {
                    ForEach(timeChoices, id: \.self) { m in
                        Text(String(format: "%02d:%02d", m / 60, m % 60)).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.Colors.textPrimary)
            }
            HStack {
                label("Durée")
                Spacer()
                Stepper(value: $appointment.durationMinutes, in: 15...480, step: 15) {
                    Text(CalendarFormat.durationLabel(appointment.durationMinutes))
                        .font(AppFont.montserrat(14, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .fixedSize()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.card))
    }

    private var minutesOfDay: Int {
        let cal = CalendarFormat.calendar
        return cal.component(.hour, from: appointment.start) * 60 + cal.component(.minute, from: appointment.start)
    }

    private func setMinutesOfDay(_ minutes: Int) {
        let cal = CalendarFormat.calendar
        appointment.start = cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: appointment.start) ?? appointment.start
    }

    /// Heures proposées, au pas du découpage choisi (de 6 h à 22 h), plus l'heure actuelle
    /// du rendez-vous si elle tombe entre deux.
    private var timeChoices: [Int] {
        let step = agenda.settings.slotMinutes
        var choices = Array(stride(from: 6 * 60, through: 22 * 60, by: step))
        if !choices.contains(minutesOfDay) { choices.append(minutesOfDay); choices.sort() }
        return choices
    }

    // MARK: Note

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Note")
            TextField("Détails…", text: $appointment.note, axis: .vertical)
                .font(AppFont.montserrat(14))
                .lineLimit(2...)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.card))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
    }
}
