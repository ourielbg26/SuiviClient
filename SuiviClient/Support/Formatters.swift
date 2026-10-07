import Foundation

enum Formatters {
    private static let moneyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.groupingSize = 3
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    /// "280 ₪", "17 000 ₪" — sans décimale, espace en séparateur de milliers.
    static func money(_ amount: Decimal) -> String {
        let n = NSDecimalNumber(decimal: amount).rounding(accordingToBehavior: nil)
        let s = moneyFormatter.string(from: n) ?? "0"
        return s + " ₪"
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMM"
        return f
    }()

    /// "24 août"
    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    static func days(from: Date, to: Date = .now) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: to)).day ?? 0
    }
}
