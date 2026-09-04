import Foundation

enum AppDateFormatter {
    static func combinedDateString(for date: Date, timeZone: TimeZone = .current) -> String {
        "\(hebrewDateString(for: date, timeZone: timeZone)) - \(gregorianDateString(for: date, timeZone: timeZone))"
    }

    static func gregorianDateString(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = timeZone
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    static func hebrewDateString(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .hebrew)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let day = components.day,
              let month = components.month,
              let year = components.year else {
            return ""
        }
        return "\(day) \(hebrewMonthName(month, isLeapYear: isHebrewLeapYear(year))) \(year)"
    }

    private static func isHebrewLeapYear(_ year: Int) -> Bool {
        ((7 * year + 1) % 19) < 7
    }

    private static func hebrewMonthName(_ month: Int, isLeapYear: Bool) -> String {
        switch month {
        case 1: "Тишрей"
        case 2: "Хешван"
        case 3: "Кислев"
        case 4: "Тевет"
        case 5: "Шват"
        case 6: isLeapYear ? "Адар I" : "Адар"
        case 7: isLeapYear ? "Адар II" : "Нисан"
        case 8: isLeapYear ? "Нисан" : "Ияр"
        case 9: isLeapYear ? "Ияр" : "Сиван"
        case 10: isLeapYear ? "Сиван" : "Тамуз"
        case 11: isLeapYear ? "Тамуз" : "Ав"
        case 12: isLeapYear ? "Ав" : "Элул"
        case 13: "Элул"
        default: ""
        }
    }
}
