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

nonisolated enum CalendarLocalization {
    static var selectedLocale: Locale {
        AppLocalization.locale
    }

    static func locale(languageCode: String) -> Locale {
        AppLocalization.supportedLocale(languageCode: languageCode)
    }

    static func text(_ key: String, table: String = "Calendar", locale: Locale? = nil) -> String {
        AppLocalization.string(key, table: table, locale: locale)
    }

    static func format(_ key: String, _ arguments: CVarArg..., locale: Locale? = nil) -> String {
        // These placeholders are calendar identifiers and counts, not display numbers.
        // A Korean formatting locale groups a four-digit year (for example, `2,026`).
        String(
            format: text(key, locale: locale),
            locale: Locale(identifier: "en_US_POSIX"),
            arguments: arguments
        )
    }
}

/// Layout and contrast rules mirrored from the mobile web calendar.
/// Kept value-only so the visual contract can be covered without SwiftUI snapshots.
nonisolated enum CalendarVisualLogic {
    static let compactCellMinimumHeight: CGFloat = 60
    static let maximumSchedulesPerCell = 3
    static let maximumTodosPerCell = 2

    /// Korean form labels are all two-character words ("공개 범위", "첨부파일"), so a
    /// two-character column wraps the four-character ones into an even block and leaves the date
    /// and time controls beside them the room a phone cannot spare. Latin labels have no such
    /// break point inside a word, so they keep a column wide enough for the longest of them.
    static func formLabelWidth(locale: Locale) -> CGFloat {
        locale.language.languageCode?.identifier == "ko" ? 28 : 88
    }

    /// The pinned D-day is drawn next to the day number, where only a few characters fit,
    /// so it carries the counter alone as the web calendar does. Its title is already
    /// shown as a bubble on the D-day's own date.
    static func pinnedDDayLabel(cell: DateOnly, target: DateOnly) -> String? {
        guard let cellDate = CalendarDateSupport.date(from: cell),
              let targetDate = CalendarDateSupport.date(from: target),
              let difference = CalendarDateSupport.calendar
                  .dateComponents([.day], from: cellDate, to: targetDate).day
        else { return nil }
        if difference == 0 { return "D-Day" }
        return difference > 0 ? "D-\(difference)" : "D+\(-difference)"
    }

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

/// Type sizes for the dense calendar surface, kept in one place so the
/// 375-point layout stays compact without falling below the mobile web scale.
nonisolated enum CalendarTypography {
    static let weekday: CGFloat = 14
    static let dayNumber: CGFloat = 12
    static let cellContent: CGFloat = 10
    static let cellMicro: CGFloat = 9
    static let detailTitle: CGFloat = 16
    static let detailMetadata: CGFloat = 14
}
