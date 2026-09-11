import SwiftUI
import UIKit
import WidgetKit

private enum DutyparkWidgetConstants {
    static let appURL = "https://dutypark.o-r.kr/duty/"
    static let weekdaysKorean = ["일", "월", "화", "수", "목", "금", "토"]
    static let weekdaysEnglish = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
}

/// A WidgetKit entry contains only presentation values. Keeping the shared snapshot
/// out of the entry makes placeholder data independent from the app target and keeps
/// the view safe when an older snapshot is missing or has an invalid shape.
nonisolated struct DutyparkWidgetDayPresentation: Identifiable, Hashable, Sendable {
    let date: String
    let weekday: Int
    let isCurrentMonth: Bool
    let abbreviation: String?
    let colorHex: String?
    let isOff: Bool

    var id: String { date }

    init(
        date: String,
        weekday: Int,
        isCurrentMonth: Bool,
        abbreviation: String?,
        colorHex: String?,
        isOff: Bool
    ) {
        self.date = date
        self.weekday = weekday
        self.isCurrentMonth = isCurrentMonth
        self.abbreviation = abbreviation
        self.colorHex = colorHex
        self.isOff = isOff
    }
}

nonisolated struct DutyparkWidgetEntry: TimelineEntry {
    let date: Date
    let year: Int
    let month: Int
    let accountID: Int64?
    let days: [DutyparkWidgetDayPresentation]
    let updatedAt: Date?
    let isPlaceholder: Bool
    let hasCurrentMonthData: Bool

    var hasRenderableData: Bool {
        hasCurrentMonthData && days.count == 42
    }
}

struct DutyparkWidgetProvider: TimelineProvider {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale.current
        calendar.timeZone = .current
        calendar.firstWeekday = 1
        return calendar
    }

    func placeholder(in context: Context) -> DutyparkWidgetEntry {
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        return DutyparkWidgetEntry(
            date: now,
            year: components.year ?? 2026,
            month: components.month ?? 1,
            accountID: nil,
            days: [],
            updatedAt: nil,
            isPlaceholder: true,
            hasCurrentMonthData: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DutyparkWidgetEntry) -> Void) {
        let now = Date()
        if context.isPreview {
            let sample = DutyparkWidgetPreviewData.snapshot
            let sampleDate = calendar.date(
                from: DateComponents(year: sample.year, month: sample.month, day: 15)
            ) ?? now
            completion(makeEntry(at: sampleDate, snapshot: sample))
        } else {
            completion(makeEntry(at: now, snapshot: snapshot(for: now)))
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<DutyparkWidgetEntry>) -> Void
    ) {
        let now = Date()
        let currentSnapshot = snapshot(for: now)
        let entry = makeEntry(at: now, snapshot: currentSnapshot)

        // A new entry at local midnight updates the today outline and moves the
        // displayed month forward. The app explicitly reloads timelines after a
        // successful sync, so this timeline never needs to authenticate or fetch.
        let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime,
            direction: .forward
        ) ?? now.addingTimeInterval(60 * 60 * 24)
        // A monthly store can contain both sides of the boundary. Read the month
        // represented by each entry so January 1 (and every month rollover) does
        // not accidentally reuse the current month's snapshot.
        let midnightSnapshot = snapshot(for: nextMidnight)
        let midnightEntry = makeEntry(at: nextMidnight, snapshot: midnightSnapshot)
        completion(
            Timeline(
                entries: [entry, midnightEntry],
                policy: .after(nextMidnight)
            )
        )
    }

    private func snapshot(for date: Date) -> DutyparkWidgetSnapshot? {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else { return nil }
        return DutyparkWidgetSnapshotStore.shared.load(year: year, month: month)
    }

    private func makeEntry(
        at date: Date,
        snapshot: DutyparkWidgetSnapshot?
    ) -> DutyparkWidgetEntry {
        let displayedComponents = calendar.dateComponents([.year, .month], from: date)
        let displayedYear = displayedComponents.year ?? 2026
        let displayedMonth = displayedComponents.month ?? 1
        let matchesCurrentMonth = snapshot?.year == displayedYear && snapshot?.month == displayedMonth
        let days = snapshot?.days.map { day in
            DutyparkWidgetDayPresentation(
                date: day.date,
                weekday: day.weekday,
                isCurrentMonth: day.isCurrentMonth,
                abbreviation: day.abbreviation,
                colorHex: day.colorHex,
                isOff: day.isOff
            )
        } ?? []

        return DutyparkWidgetEntry(
            date: date,
            year: displayedYear,
            month: displayedMonth,
            accountID: snapshot?.accountID,
            days: days,
            updatedAt: snapshot?.updatedAt,
            isPlaceholder: false,
            hasCurrentMonthData: matchesCurrentMonth
        )
    }
}

struct DutyparkMonthlyWidgetView: View {
    let entry: DutyparkWidgetEntry

    @Environment(\.colorScheme) private var colorScheme

    private var isKorean: Bool {
        Locale.current.language.languageCode?.identifier == "ko"
    }

    private var weekdayLabels: [String] {
        isKorean
            ? DutyparkWidgetConstants.weekdaysKorean
            : DutyparkWidgetConstants.weekdaysEnglish
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                header
                    .frame(height: 34)
                if entry.isPlaceholder {
                    placeholderCalendar
                } else if entry.hasRenderableData {
                    calendarGrid(rowHeight: rowHeight(for: proxy.size.height))
                } else {
                    unavailableState
                }
            }
            .padding(8)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .containerBackground(for: .widget) {
            WidgetPalette.background(for: colorScheme)
        }
        .widgetURL(widgetURL)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var widgetURL: URL? {
        guard let accountID = entry.accountID, accountID > 0 else { return nil }
        return URL(string: "\(DutyparkWidgetConstants.appURL)\(accountID)")
    }

    private var accessibilityLabel: String {
        let month = String(format: "%04d-%02d", entry.year, entry.month)
        if entry.hasRenderableData {
            return isKorean ? "\(month) 내 근무 달력" : "My duty calendar for \(month)"
        }
        return isKorean ? "\(month) 근무표 없음" : "No duty schedule for \(month)"
    }

    private var header: some View {
        ZStack {
            Text(String(format: "%04d-%02d", entry.year, entry.month))
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(WidgetPalette.primaryText(for: colorScheme))
                .minimumScaleFactor(0.8)
        }
    }

    private func calendarGrid(rowHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            weekdayRow
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                spacing: 0
            ) {
                ForEach(entry.days) { day in
                    DutyparkWidgetDayCell(
                        day: day,
                        isCurrentMonth: day.isCurrentMonth,
                        isToday: isToday(day),
                        colorScheme: colorScheme,
                        rowHeight: rowHeight
                    )
                }
            }
            .frame(height: rowHeight * 6)
        }
        .background(WidgetPalette.cardBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(WidgetPalette.cardBorder(for: colorScheme), lineWidth: 1)
        }
    }

    private func rowHeight(for totalHeight: CGFloat) -> CGFloat {
        // The eight-point outer inset, centred month header and weekday row leave
        // the remaining height for the six calendar rows.
        let reservedHeight: CGFloat = 16 + 34 + 24 + 2
        return max(26, (totalHeight - reservedHeight) / 6)
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.system(size: isKorean ? 12 : 10, weight: .bold, design: .rounded))
                    .foregroundStyle(weekdayColor(index))
                    .frame(maxWidth: .infinity, minHeight: 24)
                    .background(WidgetPalette.weekdayBackground(for: colorScheme))
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(WidgetPalette.gridLine(for: colorScheme))
                            .frame(width: 0.5)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.bottom, 2)
    }

    private var placeholderCalendar: some View {
        VStack(spacing: 5) {
            ProgressView()
                .tint(WidgetPalette.secondaryText(for: colorScheme))
            Text(isKorean ? "근무표를 불러오는 중" : "Loading duty schedule")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(WidgetPalette.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unavailableState: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(WidgetPalette.secondaryText(for: colorScheme))
                .accessibilityHidden(true)
            Text(isKorean ? "저장된 근무표가 없습니다" : "No saved duty schedule")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetPalette.primaryText(for: colorScheme))
                .multilineTextAlignment(.center)
            Text(isKorean ? "앱을 열어 근무표를 동기화해 주세요" : "Open Dutypark to sync your schedule")
                .font(.system(size: 10, weight: .regular, design: .rounded))
                .foregroundStyle(WidgetPalette.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }

    private func isToday(_ day: DutyparkWidgetDayPresentation) -> Bool {
        guard let value = dayDate(day) else { return false }
        return calendar.isDate(value, inSameDayAs: entry.date)
    }

    private func dayDate(_ day: DutyparkWidgetDayPresentation) -> Date? {
        let parts = day.date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private func weekdayColor(_ index: Int) -> Color {
        if index == 0 { return WidgetPalette.sunday(for: colorScheme) }
        if index == 6 { return WidgetPalette.saturday(for: colorScheme) }
        return WidgetPalette.primaryText(for: colorScheme)
    }

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale.current
        value.timeZone = .current
        value.firstWeekday = 1
        return value
    }
}

private struct DutyparkWidgetDayCell: View {
    let day: DutyparkWidgetDayPresentation
    let isCurrentMonth: Bool
    let isToday: Bool
    let colorScheme: ColorScheme
    let rowHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(dayNumber)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(dayNumberColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            if let abbreviation = displayAbbreviation {
                Text(abbreviation)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(dutyForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 3)
                    .background(
                        colorScheme == .dark ? .clear : dutyTint.opacity(0.11),
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: rowHeight, alignment: .topLeading)
        .background(cellBackground)
        .opacity(isCurrentMonth ? 1 : 0.45)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(WidgetPalette.gridLine(for: colorScheme))
                .frame(width: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WidgetPalette.gridLine(for: colorScheme))
                .frame(height: 0.5)
        }
        .overlay {
            if isToday {
                Rectangle()
                    .stroke(WidgetPalette.today(for: colorScheme), lineWidth: 1)
            }
        }
        .overlay(alignment: .top) {
            if isToday {
                Capsule(style: .continuous)
                    .fill(WidgetPalette.today(for: colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 3, maxHeight: 3)
                    .padding(.horizontal, 4)
                    .padding(.top, 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var dayNumber: String {
        let parts = day.date.split(separator: "-")
        guard let value = parts.last, let number = Int(value) else { return "" }
        return String(number)
    }

    private var accessibilityLabel: String {
        if let abbreviation = displayAbbreviation {
            return "\(day.date), \(abbreviation)"
        }
        return day.date
    }

    private var displayAbbreviation: String? {
        if let abbreviation = day.abbreviation, !abbreviation.isEmpty {
            return abbreviation
        }
        return day.isOff ? "off" : nil
    }

    private var dutyTint: Color {
        WidgetHexColor.color(day.colorHex)
            ?? (day.isOff
                ? WidgetPalette.off(for: colorScheme)
                : WidgetPalette.emptyDuty(for: colorScheme))
    }

    private var cellBackground: Color {
        guard colorScheme == .light else {
            return WidgetPalette.emptyCell(for: colorScheme)
        }
        guard displayAbbreviation != nil else {
            return day.isOff
                ? WidgetPalette.off(for: colorScheme).opacity(0.08)
                : WidgetPalette.emptyCell(for: colorScheme)
        }
        return dutyTint.opacity(0.09)
    }

    private var dayNumberColor: Color {
        if !isCurrentMonth { return WidgetPalette.secondaryText(for: colorScheme) }
        if day.weekday == 1 { return WidgetPalette.sunday(for: colorScheme) }
        if day.weekday == 7 { return WidgetPalette.saturday(for: colorScheme) }
        return WidgetPalette.primaryText(for: colorScheme)
    }

    private var dutyForeground: Color {
        if day.isOff, day.colorHex == nil { return WidgetPalette.off(for: colorScheme) }
        return WidgetHexColor.readableColor(day.colorHex, for: colorScheme)
            ?? (day.isOff
                ? WidgetPalette.off(for: colorScheme)
                : WidgetPalette.emptyDuty(for: colorScheme))
    }
}

private enum WidgetPalette {
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.067, green: 0.094, blue: 0.153)
            : .white
    }

    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.122, green: 0.161, blue: 0.216)
            : .white
    }

    static func cardBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.216, green: 0.255, blue: 0.318)
            : Color(red: 0.82, green: 0.835, blue: 0.86)
    }

    static func gridLine(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.176, green: 0.216, blue: 0.282)
            : Color(red: 0.82, green: 0.835, blue: 0.86)
    }

    static func emptyCell(for _: ColorScheme) -> Color {
        .clear
    }

    static func weekdayBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.153, green: 0.204, blue: 0.286)
            : Color(red: 0.90, green: 0.906, blue: 0.922)
    }

    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.976, green: 0.98, blue: 0.984) : Color(red: 0.067, green: 0.094, blue: 0.153)
    }

    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.82, green: 0.835, blue: 0.86) : Color(red: 0.294, green: 0.337, blue: 0.388)
    }

    static func sunday(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.98, green: 0.45, blue: 0.49)
            : Color(red: 0.86, green: 0.15, blue: 0.20)
    }

    static func saturday(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.44, green: 0.67, blue: 1.0)
            : Color(red: 0.15, green: 0.39, blue: 0.86)
    }

    static func today(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.98, green: 0.45, blue: 0.49)
            : Color(red: 0.86, green: 0.15, blue: 0.20)
    }

    static func off(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.42, blue: 0.46)
            : Color(red: 0.86, green: 0.15, blue: 0.20)
    }

    static func emptyDuty(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.82, green: 0.835, blue: 0.86)
            : Color(red: 0.42, green: 0.45, blue: 0.50)
    }

}

private enum WidgetHexColor {
    static func color(_ hex: String?) -> Color? {
        guard let value = rgb(hex) else { return nil }
        return Color(red: value.red, green: value.green, blue: value.blue)
    }

    /// Duty colors are chosen by each team and often use very pale fills. The
    /// calendar keeps the hue while nudging those colors toward a readable text
    /// value for the current widget surface. This avoids replacing pastel duties
    /// with black in light mode and keeps dark duties visible in dark mode.
    static func readableColor(_ hex: String?, for colorScheme: ColorScheme) -> Color? {
        guard let value = uiColor(hex) else { return nil }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        if value.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            guard value.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
                return Color(uiColor: value)
            }
            let luminance = (red * 299 + green * 587 + blue * 114) / 1_000
            if colorScheme == .light, luminance > 0.48 {
                brightness = min(brightness, 0.62)
                // A very small saturation is still a purposeful pastel duty
                // color. Only true neutrals (roughly zero saturation) bypass
                // the hue-preserving boost.
                if saturation > 0.01 { saturation = max(saturation, 0.72) }
            } else if colorScheme == .dark {
                // Dark widgets use color as a quiet text accent. Lift every hue
                // above the slate card and soften saturated team colors so a
                // month full of duties does not become a patchwork of badges.
                brightness = max(brightness, 0.90)
                if saturation > 0.01 {
                    saturation = min(saturation, 0.48)
                }
            }
            return Color(
                hue: Double(hue),
                saturation: Double(saturation),
                brightness: Double(brightness),
                opacity: Double(alpha)
            )
        }

        var white: CGFloat = 0
        guard value.getWhite(&white, alpha: &alpha) else {
            return Color(uiColor: value)
        }
        if colorScheme == .light, white > 0.48 {
            white = min(white, 0.52)
        } else if colorScheme == .dark {
            white = max(white, 0.90)
        }
        return Color(white: Double(white), opacity: Double(alpha))
    }

    private static func uiColor(_ hex: String?) -> UIColor? {
        guard var value = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        return UIColor(
            red: CGFloat((number >> 16) & 0xFF) / 255,
            green: CGFloat((number >> 8) & 0xFF) / 255,
            blue: CGFloat(number & 0xFF) / 255,
            alpha: 1
        )
    }

    private static func rgb(_ hex: String?) -> (red: Double, green: Double, blue: Double)? {
        guard var value = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        return (
            Double((number >> 16) & 0xFF) / 255,
            Double((number >> 8) & 0xFF) / 255,
            Double(number & 0xFF) / 255
        )
    }
}

@main
struct DutyparkWidgets: WidgetBundle {
    var body: some Widget {
        DutyparkMonthlyWidget()
    }
}

struct DutyparkMonthlyWidget: Widget {
    let kind = DutyparkWidgetKind.monthly

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DutyparkWidgetProvider()) { entry in
            DutyparkMonthlyWidgetView(entry: entry)
        }
        .configurationDisplayName("근무 달력")
        .description("이번 달 내 근무를 한눈에 확인합니다.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemLarge) {
    DutyparkMonthlyWidget()
} timeline: {
    DutyparkWidgetEntry(
        date: Date(),
        year: 2026,
        month: 9,
        accountID: 1,
        days: DutyparkWidgetPreviewData.days,
        updatedAt: Date().addingTimeInterval(-60 * 60),
        isPlaceholder: false,
        hasCurrentMonthData: true
    )
}

private enum DutyparkWidgetPreviewData {
    static let snapshot: DutyparkWidgetSnapshot = {
        DutyparkWidgetSnapshot(
            accountID: 1,
            year: 2026,
            month: 9,
            days: days.map { day in
                DutyparkWidgetDay(
                    date: day.date,
                    weekday: day.weekday,
                    isCurrentMonth: day.isCurrentMonth,
                    abbreviation: day.abbreviation,
                    colorHex: day.colorHex,
                    isOff: day.isOff
                )
            },
            updatedAt: Date().addingTimeInterval(-60 * 60)
        )
    }()

    static let days: [DutyparkWidgetDayPresentation] = {
        let calendar: Calendar = {
            var value = Calendar(identifier: .gregorian)
            value.timeZone = .current
            value.firstWeekday = 1
            return value
        }()
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 30)) ?? Date()
        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
            guard let year = parts.year, let month = parts.month, let day = parts.day, let weekday = parts.weekday else {
                return nil
            }
            let dateString = String(format: "%04d-%02d-%02d", year, month, day)
            let abbreviation: String?
            let color: String?
            switch day % 6 {
            case 0:
                abbreviation = "N"
                color = "#A855F7"
            case 1:
                abbreviation = "E"
                color = "#22C55E"
            case 2:
                abbreviation = "off"
                color = nil
            default:
                abbreviation = nil
                color = nil
            }
            return DutyparkWidgetDayPresentation(
                date: dateString,
                weekday: weekday,
                isCurrentMonth: year == 2026 && month == 9,
                abbreviation: abbreviation,
                colorHex: color,
                isOff: abbreviation == "off"
            )
        }
    }()
}
