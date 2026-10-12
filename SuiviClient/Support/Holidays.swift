import Foundation

/// Fêtes juives et jours fériés israéliens, calculés sur le téléphone à partir du
/// calendrier hébraïque (pas besoin de réseau). Une fête est rattachée à son jour
/// civil (elle commence la veille au soir).
///
/// Numérotation des mois du calendrier hébraïque de Foundation : 1 Tichri, 2 Hechvan,
/// 3 Kislev, 4 Tevet, 5 Chevat, 6 Adar I (années embolismiques), 7 Adar / Adar II,
/// 8 Nissan, 9 Iyar, 10 Sivan, 11 Tamouz, 12 Av, 13 Eloul.
enum Holidays {
    static func names(on date: Date, jewish: Bool, israeli: Bool) -> [String] {
        guard jewish || israeli else { return [] }
        let hebrewYear = hebrew.component(.year, from: date)
        let key = dayKey(date)
        var result: [String] = []
        if jewish { result += table(for: hebrewYear, israeli: false)[key] ?? [] }
        if israeli { result += table(for: hebrewYear, israeli: true)[key] ?? [] }
        return result
    }

    // MARK: - Calcul

    private static let hebrew: Calendar = {
        var c = Calendar(identifier: .hebrew)
        c.timeZone = .current
        return c
    }()

    private static let gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    private static var cache: [String: [String: [String]]] = [:]

    private static func dayKey(_ date: Date) -> String {
        let c = gregorian.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        hebrew.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }

    /// 1 = dimanche … 7 = samedi.
    private static func weekday(_ date: Date) -> Int { gregorian.component(.weekday, from: date) }

    private static func shifted(_ date: Date, days: Int) -> Date {
        gregorian.date(byAdding: .day, value: days, to: date) ?? date
    }

    private static func table(for year: Int, israeli: Bool) -> [String: [String]] {
        let cacheKey = "\(year)-\(israeli)"
        if let cached = cache[cacheKey] { return cached }
        var t: [String: [String]] = [:]
        func add(_ date: Date?, _ name: String) {
            guard let date else { return }
            t[dayKey(date), default: []].append(name)
        }

        if israeli {
            // Yom HaShoah : 27 Nissan, avancé au jeudi s'il tombe un vendredi, repoussé au
            // lundi s'il tombe un dimanche.
            if let shoah = date(year, 8, 27) {
                switch weekday(shoah) {
                case 6: add(shifted(shoah, days: -1), "Yom HaShoah")
                case 1: add(shifted(shoah, days: 1), "Yom HaShoah")
                default: add(shoah, "Yom HaShoah")
                }
            }
            // Yom Haatsmaout : 5 Iyar, avancé au jeudi s'il tombe un vendredi ou un samedi,
            // repoussé au mardi s'il tombe un lundi. Yom Hazikaron est la veille.
            if let independence = date(year, 9, 5) {
                let observed: Date
                switch weekday(independence) {
                case 6: observed = shifted(independence, days: -1)
                case 7: observed = shifted(independence, days: -2)
                case 2: observed = shifted(independence, days: 1)
                default: observed = independence
                }
                add(shifted(observed, days: -1), "Yom Hazikaron")
                add(observed, "Yom Haatsmaout")
            }
            add(date(year, 9, 28), "Yom Yeroushalayim")
        } else {
            add(date(year, 1, 1), "Roch Hachana")
            add(date(year, 1, 2), "Roch Hachana")
            add(date(year, 1, 10), "Yom Kippour")
            add(date(year, 1, 15), "Souccot")
            for d in 16...20 { add(date(year, 1, d), "Hol Hamoed Souccot") }
            add(date(year, 1, 21), "Hochaana Rabba")
            add(date(year, 1, 22), "Simhat Torah")
            if let hanukkah = date(year, 3, 25) {
                for i in 0..<8 { add(shifted(hanukkah, days: i), "Hanoucca (\(i == 0 ? "1ʳᵉ" : "\(i + 1)ᵉ") bougie)") }
            }
            add(date(year, 5, 15), "Tou Bichvat")
            add(date(year, 7, 14), "Pourim")
            add(date(year, 8, 15), "Pessah")
            for d in 16...20 { add(date(year, 8, d), "Hol Hamoed Pessah") }
            add(date(year, 8, 21), "Pessah (7ᵉ jour)")
            add(date(year, 9, 18), "Lag Baomer")
            add(date(year, 10, 6), "Chavouot")
            // Ticha Beav : repoussé au dimanche s'il tombe un chabbat.
            if let av9 = date(year, 12, 9) {
                add(weekday(av9) == 7 ? shifted(av9, days: 1) : av9, "Ticha Beav")
            }
        }
        cache[cacheKey] = t
        return t
    }
}
