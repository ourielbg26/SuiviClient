import SwiftUI

/// Calendrier des rendez-vous : journée, semaine ou mois, et "+" pour en ajouter un.
struct CalendarView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case day = "Jour"
        case week = "Semaine"
        case month = "Mois"
        var id: String { rawValue }
    }

    @Environment(AppointmentStore.self) private var agenda
    @State private var mode: Mode = .day
    @State private var selectedDate = Date.now
    /// Rendez-vous ouvert dans l'éditeur (nouveau ou existant).
    @State private var editing: Appointment?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 12) {
                    switch mode {
                    case .day: DayAgenda(date: selectedDate, onOpen: { editing = $0 })
                    case .week: WeekAgenda(date: selectedDate, onOpen: { editing = $0 }) { day in
                            selectedDate = day
                            mode = .day
                        }
                    case .month: MonthAgenda(selectedDate: $selectedDate, onOpen: { editing = $0 })
                    }
                }
                .padding(.horizontal, Theme.Spacing.contentMargin)
                .screenBottomPadding()
            }
        }
        .background(PaperBackground())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editing) { appointment in
            AppointmentEditorView(appointment: appointment,
                                  isNew: !agenda.appointments.contains { $0.id == appointment.id })
        }
    }

    // MARK: En-tête : titre, +, Jour / Semaine / Mois, navigation

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Calendrier").font(AppFont.display(22, weight: .semibold)).tracking(AppTracking.screenTitle).textCase(.uppercase)
                Spacer()
                Button {
                    editing = newAppointment()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.Colors.primaryButton))
                }
                .buttonStyle(.plain)
                .primaryButtonShadow()
            }

            HStack(spacing: 4) {
                ForEach(Mode.allCases) { m in
                    Button {
                        mode = m
                    } label: {
                        Text(m.rawValue)
                            .font(AppFont.montserrat(13, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(mode == m ? Theme.Colors.primaryButton : Color.clear))
                            .foregroundStyle(mode == m ? .white : Theme.Colors.chipInactiveText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Capsule().fill(Theme.Colors.card))
            .overlay(Capsule().strokeBorder(Theme.Colors.border, lineWidth: 1))

            HStack(spacing: 8) {
                navButton("chevron.left") { move(-1) }
                Text(periodTitle)
                    .font(AppFont.display(17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                navButton("chevron.right") { move(1) }
            }
            if !CalendarFormat.calendar.isDate(selectedDate, inSameDayAs: .now) {
                Button("Revenir à aujourd'hui") { selectedDate = .now }
                    .font(AppFont.montserrat(12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primaryButtonPressed)
            }
        }
        .padding(.horizontal, Theme.Spacing.contentMargin)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    private func navButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.Colors.card))
                .overlay(Circle().strokeBorder(Theme.Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var periodTitle: String {
        switch mode {
        case .day: return CalendarFormat.dayTitle(selectedDate)
        case .week: return CalendarFormat.weekTitle(selectedDate)
        case .month: return CalendarFormat.monthTitle(selectedDate)
        }
    }

    private func move(_ step: Int) {
        let unit: Calendar.Component = mode == .day ? .day : (mode == .week ? .weekOfYear : .month)
        selectedDate = CalendarFormat.calendar.date(byAdding: unit, value: step, to: selectedDate) ?? selectedDate
    }

    /// Nouveau rendez-vous sur le jour affiché, à la prochaine tranche horaire libre.
    private func newAppointment() -> Appointment {
        let cal = CalendarFormat.calendar
        let slot = agenda.settings.slotMinutes
        var start = cal.date(bySettingHour: agenda.settings.dayStartHour, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        if cal.isDateInToday(selectedDate) {
            let minutes = cal.component(.hour, from: .now) * 60 + cal.component(.minute, from: .now)
            let rounded = (minutes / slot + 1) * slot
            start = cal.date(bySettingHour: 0, minute: 0, second: 0, of: selectedDate)!.addingTimeInterval(TimeInterval(rounded * 60))
        }
        let type = agenda.settings.types.first
        return Appointment(typeID: type?.id, clientName: "", start: start, durationMinutes: type?.durationMinutes ?? slot)
    }
}

// MARK: - Mode journée : grille horaire

private struct DayAgenda: View {
    let date: Date
    let onOpen: (Appointment) -> Void
    @Environment(AppointmentStore.self) private var agenda

    private let hourHeight: CGFloat = 64
    private let labelWidth: CGFloat = 46

    private var appointments: [Appointment] { agenda.appointments(on: date) }

    /// Plage affichée : celle des réglages, élargie si un rendez-vous en sort.
    private var hours: ClosedRange<Int> {
        let cal = CalendarFormat.calendar
        var first = agenda.settings.dayStartHour
        var last = agenda.settings.dayEndHour
        for a in appointments {
            first = min(first, cal.component(.hour, from: a.start))
            last = max(last, cal.component(.hour, from: a.end) + (cal.component(.minute, from: a.end) > 0 ? 1 : 0))
        }
        return first...max(first + 1, last)
    }

    var body: some View {
        VStack(spacing: 10) {
            HolidayBanner(date: date)
            ZStack(alignment: .topLeading) {
                grid
                ForEach(layout, id: \.appointment.id) { item in
                    block(item)
                }
                nowLine
            }
            .frame(height: CGFloat(hours.count - 1) * hourHeight + 10)
            .padding(.top, 8)
        }
    }

    private var slotsPerHour: Int { 60 / agenda.settings.slotMinutes }

    /// Tranches de la journée : une ligne par heure, des pointillés pour les demi-heures
    /// / quarts d'heure ; toucher une tranche vide ouvre un nouveau rendez-vous à cette heure.
    private var grid: some View {
        VStack(spacing: 0) {
            ForEach(Array(hours.dropLast()), id: \.self) { hour in
                VStack(spacing: 0) {
                    ForEach(0..<slotsPerHour, id: \.self) { slot in
                        Button {
                            onOpen(newAppointment(hour: hour, minute: slot * agenda.settings.slotMinutes))
                        } label: {
                            HStack(alignment: .top, spacing: 6) {
                                Text(slot == 0 ? String(format: "%02d:00", hour) : "")
                                    .font(AppFont.montserrat(10, weight: .medium))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .frame(width: labelWidth - 6, alignment: .trailing)
                                    .offset(y: -6)
                                VStack(spacing: 0) {
                                    if slot == 0 {
                                        Rectangle().fill(Theme.Colors.border).frame(height: 1)
                                    } else {
                                        Rectangle()
                                            .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                            .foregroundStyle(Theme.Colors.border)
                                            .frame(height: 0.5)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(height: hourHeight / CGFloat(slotsPerHour))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 6) {
                Text(String(format: "%02d:00", hours.upperBound))
                    .font(AppFont.montserrat(10, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: labelWidth - 6, alignment: .trailing)
                    .offset(y: -6)
                Rectangle().fill(Theme.Colors.border).frame(height: 1)
            }
        }
    }

    private func newAppointment(hour: Int, minute: Int) -> Appointment {
        let start = CalendarFormat.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
        let type = agenda.settings.types.first
        return Appointment(typeID: type?.id, clientName: "", start: start, durationMinutes: type?.durationMinutes ?? agenda.settings.slotMinutes)
    }

    // Rendez-vous qui se chevauchent : côte à côte.
    private struct Placed {
        let appointment: Appointment
        let column: Int
        let columns: Int
    }

    private var layout: [Placed] {
        var placed: [Placed] = []
        var group: [(Appointment, Int)] = []
        var groupEnd = Date.distantPast
        func flush() {
            let count = (group.map(\.1).max() ?? 0) + 1
            placed += group.map { Placed(appointment: $0.0, column: $0.1, columns: count) }
            group = []
        }
        for a in appointments {
            if a.start >= groupEnd { flush(); groupEnd = .distantPast }
            var column = 0
            while group.contains(where: { $0.1 == column && $0.0.end > a.start }) { column += 1 }
            group.append((a, column))
            groupEnd = max(groupEnd, a.end)
        }
        flush()
        return placed
    }

    private func offset(for date: Date) -> CGFloat {
        let cal = CalendarFormat.calendar
        let minutes = (cal.component(.hour, from: date) - hours.lowerBound) * 60 + cal.component(.minute, from: date)
        return CGFloat(minutes) / 60 * hourHeight
    }

    private func block(_ item: Placed) -> some View {
        let a = item.appointment
        let type = agenda.type(of: a)
        let color = type?.color ?? Theme.Colors.textSecondary
        let height = max(CGFloat(a.durationMinutes) / 60 * hourHeight - 2, 22)
        return GeometryReader { geo in
            let width = (geo.size.width - labelWidth) / CGFloat(item.columns)
            Button { onOpen(a) } label: {
                HStack(spacing: 0) {
                    Rectangle().fill(color).frame(width: 3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(a.clientName.isEmpty ? (type?.name ?? "Rendez-vous") : a.clientName)
                            .font(AppFont.montserrat(12, weight: .semibold))
                            .lineLimit(1)
                        if height > 34 {
                            Text("\(CalendarFormat.time(a.start)) · \(type?.name ?? "")")
                                .font(AppFont.montserrat(10))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 3)
                }
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: width - 3, height: height)
                .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.22)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .offset(x: labelWidth + CGFloat(item.column) * width, y: offset(for: a.start) + 1)
        }
    }

    @ViewBuilder
    private var nowLine: some View {
        let cal = CalendarFormat.calendar
        if cal.isDateInToday(date), hours.contains(cal.component(.hour, from: .now)) {
            HStack(spacing: 0) {
                Circle().fill(Theme.Colors.lateAlert).frame(width: 7, height: 7)
                Rectangle().fill(Theme.Colors.lateAlert).frame(height: 1)
            }
            .padding(.leading, labelWidth - 3)
            .offset(y: offset(for: .now) - 3)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Mode semaine : la semaine jour par jour

private struct WeekAgenda: View {
    let date: Date
    let onOpen: (Appointment) -> Void
    let onSelectDay: (Date) -> Void
    @Environment(AppointmentStore.self) private var agenda

    var body: some View {
        VStack(spacing: 10) {
            ForEach(CalendarFormat.weekDays(containing: date), id: \.self) { day in
                let items = agenda.appointments(on: day)
                let holidays = Holidays.names(on: day, jewish: agenda.settings.showsJewishHolidays, israeli: agenda.settings.showsIsraeliHolidays)
                VStack(alignment: .leading, spacing: 8) {
                    Button { onSelectDay(day) } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Text(CalendarFormat.weekdayTitle(day))
                                .font(AppFont.display(16, weight: .semibold))
                                .foregroundStyle(CalendarFormat.calendar.isDateInToday(day) ? Theme.Colors.accentText : Theme.Colors.textPrimary)
                            if !holidays.isEmpty {
                                Text(holidays.joined(separator: " · "))
                                    .font(AppFont.montserrat(11, weight: .medium))
                                    .foregroundStyle(Theme.Colors.accentText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .light))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    if items.isEmpty {
                        Text("Aucun rendez-vous")
                            .font(AppFont.montserrat(12))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    } else {
                        ForEach(items) { a in
                            AppointmentRow(appointment: a) { onOpen(a) }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
                .cardShadow()
            }
        }
    }
}

// MARK: - Mode mois : grille + rendez-vous du jour choisi

private struct MonthAgenda: View {
    @Binding var selectedDate: Date
    let onOpen: (Appointment) -> Void
    @Environment(AppointmentStore.self) private var agenda

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let cal = CalendarFormat.calendar
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                LazyVGrid(columns: columns, spacing: 4) {
                    // Mardi et mercredi ont la même lettre : on identifie par position.
                    ForEach(Array(CalendarFormat.weekdaySymbols.enumerated()), id: \.offset) { _, s in
                        Text(s)
                            .font(AppFont.montserrat(10, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    ForEach(Array(CalendarFormat.monthGrid(for: selectedDate).enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day, cal: cal)
                        } else {
                            Color.clear.frame(height: 46)
                        }
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
            .cardShadow()

            VStack(alignment: .leading, spacing: 8) {
                Text(CalendarFormat.dayTitle(selectedDate))
                    .font(AppFont.display(16, weight: .semibold))
                HolidayBanner(date: selectedDate)
                let items = agenda.appointments(on: selectedDate)
                if items.isEmpty {
                    Text("Aucun rendez-vous")
                        .font(AppFont.montserrat(12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                } else {
                    ForEach(items) { a in
                        AppointmentRow(appointment: a) { onOpen(a) }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Colors.card))
            .cardShadow()
        }
    }

    private func dayCell(_ day: Date, cal: Calendar) -> some View {
        let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
        let isToday = cal.isDateInToday(day)
        let items = agenda.appointments(on: day)
        let isHoliday = !Holidays.names(on: day, jewish: agenda.settings.showsJewishHolidays, israeli: agenda.settings.showsIsraeliHolidays).isEmpty
        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .font(AppFont.montserrat(13, weight: isToday || isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : (isHoliday ? Theme.Colors.accentText : Theme.Colors.textPrimary))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(isSelected ? Theme.Colors.primaryButton : Color.clear))
                    .overlay(Circle().strokeBorder(isToday && !isSelected ? Theme.Colors.primaryButton : Color.clear, lineWidth: 1))
                HStack(spacing: 2) {
                    ForEach(items.prefix(3)) { a in
                        Circle().fill(agenda.type(of: a)?.color ?? Theme.Colors.textSecondary).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Éléments communs

/// Ligne d'un rendez-vous (semaine, mois, fiche cliente).
struct AppointmentRow: View {
    let appointment: Appointment
    var showsDate = false
    let onTap: () -> Void
    @Environment(AppointmentStore.self) private var agenda

    var body: some View {
        let type = agenda.type(of: appointment)
        Button(action: onTap) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(type?.color ?? Theme.Colors.textSecondary)
                    .frame(width: 4, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appointment.clientName.isEmpty ? (type?.name ?? "Rendez-vous") : appointment.clientName)
                        .font(AppFont.montserrat(14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text([type?.name, CalendarFormat.durationLabel(appointment.durationMinutes)].compactMap { $0 }.joined(separator: " · "))
                        .font(AppFont.montserrat(11))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if showsDate {
                        Text(CalendarFormat.shortDay(appointment.start))
                            .font(AppFont.montserrat(11))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Text(CalendarFormat.time(appointment.start))
                        .font(AppFont.montserrat(13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Fêtes du jour (selon les réglages).
private struct HolidayBanner: View {
    let date: Date
    @Environment(AppointmentStore.self) private var agenda

    var body: some View {
        let names = Holidays.names(on: date, jewish: agenda.settings.showsJewishHolidays, israeli: agenda.settings.showsIsraeliHolidays)
        if !names.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "star")
                    .font(.system(size: 12, weight: .light))
                Text(names.joined(separator: " · "))
                    .font(AppFont.montserrat(12, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(Theme.Colors.accentText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.innerTile).fill(Theme.Colors.accentTint))
        }
    }
}

/// Dates en français, semaine commençant le dimanche.
enum CalendarFormat {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "fr_FR")
        c.firstWeekday = 1
        return c
    }()

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.calendar = calendar
        f.dateFormat = format
        return f
    }

    private static let dayFormatter = formatter("EEEE d MMMM")
    private static let weekdayFormatter = formatter("EEEE d")
    private static let monthFormatter = formatter("LLLL yyyy")
    private static let shortFormatter = formatter("d MMM")
    private static let shortDayFormatter = formatter("EEE d MMM")
    private static let timeFormatter = formatter("HH:mm")

    static func dayTitle(_ d: Date) -> String { dayFormatter.string(from: d).capitalizedFirst }
    static func weekdayTitle(_ d: Date) -> String { weekdayFormatter.string(from: d).capitalizedFirst }
    static func monthTitle(_ d: Date) -> String { monthFormatter.string(from: d).capitalizedFirst }
    static func shortDay(_ d: Date) -> String { shortDayFormatter.string(from: d) }
    static func time(_ d: Date) -> String { timeFormatter.string(from: d) }

    static func weekTitle(_ d: Date) -> String {
        let days = weekDays(containing: d)
        return "\(shortFormatter.string(from: days.first!)) – \(shortFormatter.string(from: days.last!))"
    }

    static func weekDays(containing d: Date) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: d) else { return [d] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    /// D L M M J V S
    static var weekdaySymbols: [String] { calendar.veryShortWeekdaySymbols.map { $0.uppercased() } }

    /// Jours du mois, précédés de cases vides pour aligner le 1er sur son jour de semaine.
    static func monthGrid(for d: Date) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: d),
              let count = calendar.range(of: .day, in: .month, for: d)?.count else { return [] }
        let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        let days = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        return Array(repeating: nil, count: leading) + days.map { Optional($0) }
    }

    static func durationLabel(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(String(format: "%02d", m))"
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
