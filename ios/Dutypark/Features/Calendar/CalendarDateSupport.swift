import Foundation
import SwiftUI

nonisolated struct CalendarCell: Identifiable, Equatable, Sendable {
    let date: DateOnly
    let year: Int
    let month: Int
    let day: Int
    let isCurrentMonth: Bool

    var id: String { date.rawValue }
}

nonisolated enum CalendarDateSupport {
    static let calendar: Foundation.Calendar = {
        var value = Foundation.Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = .current
        value.firstWeekday = 1
        return value
    }()

    static func cells(year: Int, month: Int, serverDays: [TeamDayDTO]) -> [CalendarCell] {
        guard serverDays.count == 42 else { return [] }
        return serverDays.map {
            CalendarCell(
                date: DateOnly(rawValue: String(format: "%04d-%02d-%02d", $0.year, $0.month, $0.day)),
                year: $0.year,
                month: $0.month,
                day: $0.day,
                isCurrentMonth: $0.year == year && $0.month == month
            )
        }
    }

    static func date(from value: DateOnly) -> Date? {
        let parts = value.rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func localDateTime(_ date: Date) -> LocalDateTimeValue {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return LocalDateTimeValue(rawValue: String(
            format: "%04d-%02d-%02dT%02d:%02d:%02d",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
            parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0
        ))
    }

    static func date(from value: LocalDateTimeValue) -> Date? {
        let value = String(value.rawValue.prefix(19))
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: value)
    }
}

enum CalendarLocalization {
    static var selectedLocale: Locale {
        let language = UserDefaults.standard.string(forKey: SettingsPreference.languageKey) ?? ""
        return locale(languageCode: language)
    }

    static func locale(languageCode: String) -> Locale {
        AppLanguage(rawValue: languageCode).map { Locale(identifier: $0.rawValue) } ?? .current
    }

    static func text(_ key: String, table: String = "Calendar") -> String {
        String(
            localized: String.LocalizationValue(key),
            table: table,
            locale: selectedLocale
        )
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: selectedLocale, arguments: arguments)
    }
}

/// Layout and contrast rules mirrored from the mobile web calendar.
/// Kept value-only so the visual contract can be covered without SwiftUI snapshots.
nonisolated enum CalendarVisualLogic {
    static let compactCellMinimumHeight: CGFloat = 60
    static let regularCellMinimumHeight: CGFloat = 80
    static let maximumSchedulesPerCell = 3
    static let maximumTodosPerCell = 2

    static func usesLightForeground(on hex: String?) -> Bool {
        guard let components = rgb(hex) else { return false }
        let luminance = (Double(components.red) * 299 + Double(components.green) * 587 + Double(components.blue) * 114) / 1_000
        return luminance <= 127.5
    }

    static func rgb(_ hex: String?) -> (red: UInt8, green: UInt8, blue: UInt8)? {
        guard var value = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        return (
            UInt8((number >> 16) & 0xFF),
            UInt8((number >> 8) & 0xFF),
            UInt8(number & 0xFF)
        )
    }
}

nonisolated enum CalendarPublicLink {
    static func url(memberID: MemberID) -> URL {
        URL(string: "https://dutypark.o-r.kr/duty/\(memberID)")!
    }
}
