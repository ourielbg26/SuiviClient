import SwiftUI

/// Réglages du calendrier : découpage de la journée, heures affichées, fêtes juives /
/// jours fériés israéliens, et types de rendez-vous (couleur, durée proposée).
struct CalendarSettingsCard: View {
    @Environment(AppointmentStore.self) private var agenda
    @State private var editingType: AppointmentType?

    var body: some View {
        @Bindable var agenda = agenda
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendrier").font(AppFont.display(16, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                label("Découpage de la journée")
                FlowLayout(spacing: 7) {
                    ForEach([60, 30, 15], id: \.self) { m in
                        ChipButton(label: m == 60 ? "1 heure" : "\(m) min", isActive: agenda.settings.slotMinutes == m) {
                            agenda.settings.slotMinutes = m
                        }
                    }
                }
            }

            HStack {
                label("Heures affichées")
                Spacer()
                Stepper("De \(agenda.settings.dayStartHour) h", value: $agenda.settings.dayStartHour, in: 0...(agenda.settings.dayEndHour - 1))
                    .font(AppFont.montserrat(13, weight: .medium))
                    .fixedSize()
            }
            HStack {
                Spacer()
                Stepper("à \(agenda.settings.dayEndHour) h", value: $agenda.settings.dayEndHour, in: (agenda.settings.dayStartHour + 1)...24)
                    .font(AppFont.montserrat(13, weight: .medium))
                    .fixedSize()
            }

            Toggle(isOn: $agenda.settings.showsJewishHolidays) {
                Text("Fêtes juives").font(AppFont.montserrat(14, weight: .medium))
            }
            .tint(Theme.Colors.primaryButton)
            Toggle(isOn: $agenda.settings.showsIsraeliHolidays) {
                Text("Jours fériés (Israël)").font(AppFont.montserrat(14, weight: .medium))
            }
            .tint(Theme.Colors.primaryButton)

            VStack(alignment: .leading, spacing: 0) {
                label("Types de rendez-vous").padding(.bottom, 6)
                ForEach(agenda.settings.types) { type in
                    Button {
                        editingType = type
                    } label: {
                        HStack(spacing: 10) {
                            Circle().fill(type.color).frame(width: 12, height: 12)
                            Text(type.name).font(AppFont.montserrat(14, weight: .medium))
                            Spacer()
                            Text(CalendarFormat.durationLabel(type.durationMinutes))
                                .font(AppFont.montserrat(12))
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .light))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.separator).frame(height: 1) }
                }
                Button {
                    editingType = AppointmentType(name: "", durationMinutes: 30,
                                                  colorHex: AppointmentType.palette[agenda.settings.types.count % AppointmentType.palette.count])
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .regular))
                        Text("Ajouter un type").font(AppFont.montserrat(13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Colors.accentText)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.separator).frame(height: 1) }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
        .cardShadow()
        .sheet(item: $editingType) { type in
            AppointmentTypeEditor(type: type, isNew: !agenda.settings.types.contains { $0.id == type.id })
                .presentationDetents([.medium, .large])
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
    }
}

/// Nom, durée proposée et couleur d'un type de rendez-vous.
private struct AppointmentTypeEditor: View {
    @State var type: AppointmentType
    let isNew: Bool

    @Environment(AppointmentStore.self) private var agenda
    @Environment(\.dismiss) private var dismiss
    @State private var askDelete = false

    private var trimmedName: String { type.name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(isNew ? "Nouveau type" : "Type de rendez-vous").font(AppFont.display(20, weight: .semibold))

            TextField("Nom (ex. Essayage perruque)", text: $type.name)
                .font(AppFont.montserrat(14))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.field).fill(Theme.Colors.card))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Theme.Colors.border, lineWidth: 1))

            HStack {
                Text("Durée proposée").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Stepper(value: $type.durationMinutes, in: 15...480, step: 15) {
                    Text(CalendarFormat.durationLabel(type.durationMinutes)).font(AppFont.montserrat(14, weight: .semibold))
                }
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Couleur").font(AppFont.montserrat(12, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                HStack(spacing: 10) {
                    ForEach(AppointmentType.palette, id: \.self) { hex in
                        Button {
                            type.colorHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().strokeBorder(Theme.Colors.primaryButton, lineWidth: type.colorHex == hex ? 2 : 0).padding(-3))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 0)

            PrimaryButton(title: "Enregistrer", isEnabled: !trimmedName.isEmpty) {
                type.name = trimmedName
                agenda.saveType(type)
                dismiss()
            }
            if !isNew {
                Button("Supprimer ce type") { askDelete = true }
                    .font(AppFont.montserrat(13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.unpaidText)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(22)
        .background(PaperBackground())
        .alert("Supprimer « \(type.name) » ?", isPresented: $askDelete) {
            Button("Supprimer", role: .destructive) {
                agenda.deleteType(id: type.id)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les rendez-vous déjà pris gardent leur horaire, mais n'auront plus de type ni de couleur.")
        }
    }
}
