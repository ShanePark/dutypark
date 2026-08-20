import Foundation

/// One cell of the date picker's month grid.
nonisolated struct DatePickerDay: Identifiable, Equatable, Sendable {
    let date: DateOnly
    let day: Int
    let isCurrentMonth: Bool
    let isDisabled: Bool
    let isToday: Bool

    var id: String { date.rawValue }
}

nonisolated struct DatePickerMonth: Equatable, Sendable {
    let year: Int
    /// 1-12.
    let month: Int
}

/// How one day sits inside the previewed span; drives the continuous hotel-style block.
nonisolated enum DatePickerRangeState: Equatable, Sendable {
    case none
    case start
    case middle
    case end
    case single
}

/// Date picking policy mirrored from `frontend/src/components/common/datePickerGrid.ts`,
/// so the native picker and the web picker answer identically. Kept value-only so the
/// whole contract can be covered without SwiftUI snapshots.
///
/// The web module passes ISO `YYYY-MM-DD` strings around; this one passes `DateOnly`, which
/// is the same text but is already the app's currency for a calendar day — every calendar
/// cell, schedule bound and Todo due date is one. All arithmetic and ordering still runs
/// through `CalendarDateSupport.calendar`, never over the text, so a month boundary or a DST
/// switch is the calendar's problem rather than this module's.
nonisolated enum DatePickerGridLogic {
    /// Every grid is six weeks, so the popover keeps one height all year.
    static let weeksPerGrid = 6
    static let daysPerWeek = 7

    private static var calendar: Foundation.Calendar { CalendarDateSupport.calendar }

    // MARK: - Day values

    /// The calendar day a point in time falls on, in the calendar's own time zone.
    static func day(from date: Date) -> DateOnly {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return DateOnly(rawValue: String(
            format: "%04d-%02d-%02d",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0
        ))
    }

    /// True only for a value that names a real day. `Foundation.Calendar` rolls an overflow
    /// such as `2026-02-30` forward to a valid date instead of rejecting it, so the round trip
    /// back to text is what catches it — the same guard the web module makes.
    static func isValidDay(_ value: DateOnly?) -> Bool {
        resolve(value) != nil
    }

    private static func resolve(_ value: DateOnly?) -> Date? {
        guard let value,
              let date = CalendarDateSupport.date(from: value),
              day(from: date) == value
        else { return nil }
        return date
    }

    static func addingDays(_ amount: Int, to value: DateOnly) -> DateOnly? {
        guard let date = resolve(value),
              let moved = calendar.date(byAdding: .day, value: amount, to: date)
        else { return nil }
        return day(from: moved)
    }

    /// `Foundation.Calendar` already clamps the day of month onto a shorter target month, so
    /// the web module's explicit clamp has no counterpart here.
    static func addingMonths(_ amount: Int, to value: DateOnly) -> DateOnly? {
        guard let date = resolve(value),
              let moved = calendar.date(byAdding: .month, value: amount, to: date)
        else { return nil }
        return day(from: moved)
    }

    static func startOfWeek(_ value: DateOnly) -> DateOnly? {
        guard let date = resolve(value),
              let moved = calendar.date(byAdding: .day, value: -weekOffset(of: date), to: date)
        else { return nil }
        return day(from: moved)
    }

    static func endOfWeek(_ value: DateOnly) -> DateOnly? {
        guard let date = resolve(value),
              let moved = calendar.date(
                  byAdding: .day,
                  value: daysPerWeek - 1 - weekOffset(of: date),
                  to: date
              )
        else { return nil }
        return day(from: moved)
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: first)
        else { return 0 }
        return range.count
    }

    static func month(of value: DateOnly) -> DatePickerMonth? {
        guard let date = resolve(value) else { return nil }
        return month(ofDate: date)
    }

    static func firstDay(of month: DatePickerMonth) -> DateOnly {
        DateOnly(rawValue: String(format: "%04d-%02d-01", month.year, month.month))
    }

    // MARK: - Grid

    /// The six-week grid for one month: the days of the month itself plus however many
    /// leading and trailing days from its neighbours it takes to fill whole weeks.
    ///
    /// The web builds bare cells and decorates them in the component; the flags are folded in
    /// here instead so the SwiftUI view can stay a plain `ForEach` over finished cells and the
    /// decoration is covered by the same tests as the shape.
    static func monthGrid(
        year: Int,
        month: Int,
        minimum: DateOnly? = nil,
        maximum: DateOnly? = nil,
        today: Date = Date()
    ) -> [DatePickerDay] {
        guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let start = calendar.date(byAdding: .day, value: -weekOffset(of: first), to: first)
        else { return [] }

        let todayValue = day(from: today)
        let lower = resolve(minimum)
        let upper = resolve(maximum)

        return (0..<(weeksPerGrid * daysPerWeek)).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: start) else { return nil }
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            let value = day(from: date)
            return DatePickerDay(
                date: value,
                day: parts.day ?? 0,
                isCurrentMonth: parts.year == year && parts.month == month,
                isDisabled: isOutside(date, lower: lower, upper: upper),
                isToday: value == todayValue
            )
        }
    }

    /// Weekday names in the grid's own column order, taken from the strings the calendar
    /// screen's header already uses so the two surfaces cannot drift apart.
    static func weekdayLabels(locale: Locale = AppLocalization.locale) -> [String] {
        let keys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        return (0..<daysPerWeek).map { index in
            let key = keys[(calendar.firstWeekday - 1 + index) % daysPerWeek]
            return CalendarLocalization.text("calendar.weekday.\(key)", locale: locale)
        }
    }

    // MARK: - Bounds

    /// `minimum` and `maximum` are inclusive; a bound that is not a real day is ignored
    /// rather than disabling everything.
    static func isDisabled(
        _ value: DateOnly,
        minimum: DateOnly? = nil,
        maximum: DateOnly? = nil
    ) -> Bool {
        guard let date = resolve(value) else { return false }
        return isOutside(date, lower: resolve(minimum), upper: resolve(maximum))
    }

    static func clamped(
        _ value: DateOnly,
        minimum: DateOnly? = nil,
        maximum: DateOnly? = nil
    ) -> DateOnly {
        guard let date = resolve(value) else { return value }
        if let minimum, let lower = resolve(minimum), date < lower { return minimum }
        if let maximum, let upper = resolve(maximum), date > upper { return maximum }
        return value
    }

    // MARK: - Range mode

    /// The floor of a range-mode grid: the anchor the range is measured from, or the caller's
    /// `minimum` when that is even later. Feeding it to `isDisabled` is what makes every day
    /// before the anchor untappable rather than merely invalid on submit. An unusable bound
    /// normalises to `nil` so callers can keep testing it with `isValidDay`.
    static func rangeMinimum(_ minimum: DateOnly?, anchor: DateOnly?) -> DateOnly? {
        let floor = isValidDay(minimum) ? minimum : nil
        guard let anchor, let anchorDate = resolve(anchor) else { return floor }
        guard let floor, let floorDate = resolve(floor) else { return anchor }
        return floorDate > anchorDate ? floor : anchor
    }

    /// Where `value` falls in the span between the anchor and the day being previewed. The
    /// ends are ordered defensively so a caller that hands over an end before the anchor still
    /// paints a span rather than nothing.
    static func rangeDayState(
        _ value: DateOnly,
        anchor: DateOnly?,
        end: DateOnly?
    ) -> DatePickerRangeState {
        guard let date = resolve(value),
              let anchorDate = resolve(anchor),
              let endDate = resolve(end)
        else { return .none }

        let from = Swift.min(anchorDate, endDate)
        let to = Swift.max(anchorDate, endDate)
        if date < from || date > to { return .none }
        if from == to { return .single }
        if date == from { return .start }
        return date == to ? .end : .middle
    }

    /// Length of a span counting both ends, so a same-day range is 1. Counted in calendar days
    /// rather than elapsed time, because a span containing a DST switch is not a whole number
    /// of 24-hour days.
    static func inclusiveDayCount(from: DateOnly?, to: DateOnly?) -> Int {
        guard let start = resolve(from), let end = resolve(to) else { return 0 }
        let difference = calendar.dateComponents(
            [.day],
            from: Swift.min(start, end),
            to: Swift.max(start, end)
        ).day
        guard let difference else { return 0 }
        return difference + 1
    }

    // MARK: - Opening month

    /// The month the picker opens on: the selected day when there is one, otherwise today
    /// pulled inside the bounds so a picker whose range excludes today still opens somewhere
    /// selectable.
    static func initialMonth(
        selected: DateOnly?,
        minimum: DateOnly? = nil,
        maximum: DateOnly? = nil,
        today: Date = Date()
    ) -> DatePickerMonth {
        if let selected, let month = month(of: selected) { return month }
        let reachable = clamped(day(from: today), minimum: minimum, maximum: maximum)
        return month(of: reachable) ?? month(ofDate: today)
    }

    // MARK: - Labels

    static func monthLabel(
        year: Int,
        month: Int,
        locale: Locale = AppLocalization.locale
    ) -> String {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return ""
        }
        return formatted(date, template: "yyyyMMMM", locale: locale)
    }

    /// The text on the field itself; empty for an unset or unusable value.
    static func fieldLabel(_ value: DateOnly?, locale: Locale = AppLocalization.locale) -> String {
        guard let date = resolve(value) else { return "" }
        return formatted(date, template: "yyyyMMdd", locale: locale)
    }

    /// The spoken name of a day button, so VoiceOver reads more than a bare number.
    static func dayAccessibilityLabel(
        _ value: DateOnly,
        locale: Locale = AppLocalization.locale
    ) -> String {
        guard let date = resolve(value) else { return value.rawValue }
        return formatted(date, template: "yyyyMMMMdEEEE", locale: locale)
    }

    // MARK: - Internals

    /// How far `date` sits from the start of its displayed week, honouring the first weekday
    /// the calendar screen is built on rather than assuming Sunday.
    private static func weekOffset(of date: Date) -> Int {
        (calendar.component(.weekday, from: date) - calendar.firstWeekday + daysPerWeek) % daysPerWeek
    }

    private static func isOutside(_ date: Date, lower: Date?, upper: Date?) -> Bool {
        if let lower, date < lower { return true }
        if let upper, date > upper { return true }
        return false
    }

    private static func month(ofDate date: Date) -> DatePickerMonth {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return DatePickerMonth(year: parts.year ?? 0, month: parts.month ?? 1)
    }

    // The web caches one `Intl.DateTimeFormat` per locale because a month of accessible day
    // labels builds 42 of them. `DateFormatter` is not safe to hold in shared static storage
    // under Swift 6 strict concurrency, so each label builds its own; the calendar screen
    // formats its dates the same way.
    private static func formatted(_ date: Date, template: String, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
