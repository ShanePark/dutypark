import SwiftUI
import WidgetKit

private enum DutyparkWidgetConstants {
    static let appURL = "https://dutypark.o-r.kr/duty/"
    static let todoAppURL = "https://dutypark.o-r.kr/todo"
    static let weekdaysKorean = ["일", "월", "화", "수", "목", "금", "토"]
    static let weekdaysEnglish = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
}

private enum DutyparkWidgetLocalization {
    static var isKorean: Bool {
        if let languageCode = DutyparkWidgetLanguageStore.shared.loadLanguageCode() {
            switch languageCode {
            case "ko": return true
            case "en": return false
            default: break
            }
        }
        return Locale.current.language.languageCode?.identifier == "ko"
    }
}

private enum DutyparkWidgetLayout {
    static let monthHeaderHeight: CGFloat = 30
    static let weekdayHeaderHeight: CGFloat = 20
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
    let holidayName: String?

    var id: String { date }

    init(
        date: String,
        weekday: Int,
        isCurrentMonth: Bool,
        abbreviation: String?,
        colorHex: String?,
        isOff: Bool,
        holidayName: String? = nil
    ) {
        self.date = date
        self.weekday = weekday
        self.isCurrentMonth = isCurrentMonth
        self.abbreviation = abbreviation
        self.colorHex = colorHex
        self.isOff = isOff
        self.holidayName = holidayName
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
                isOff: day.isOff,
                holidayName: day.holidayName
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
        DutyparkWidgetLocalization.isKorean
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
                    .frame(height: DutyparkWidgetLayout.monthHeaderHeight)
                if entry.isPlaceholder {
                    placeholderCalendar
                } else if entry.hasRenderableData {
                    calendarGrid(rowHeight: rowHeight(for: proxy.size.height, weekCount: visibleWeekCount))
                } else {
                    unavailableState
                }
            }
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
        let visibleRange = visibleDayRange
        let daysPerWeek = DutyparkWidgetMonthGridLayout.daysPerWeek
        let weekCount = visibleRange.count / daysPerWeek
        let visibleDays = Array(entry.days[visibleRange])

        return VStack(spacing: 0) {
            weekdayRow
            LazyVGrid(columns: calendarColumns, spacing: 0) {
                ForEach(Array(visibleDays.enumerated()), id: \.element.id) { index, day in
                    DutyparkWidgetDayCell(
                        day: day,
                        isCurrentMonth: day.isCurrentMonth,
                        isToday: isToday(day),
                        colorScheme: colorScheme,
                        hasRightDivider: index % daysPerWeek < daysPerWeek - 1,
                        hasBottomDivider: index / daysPerWeek < weekCount - 1,
                        rowHeight: rowHeight
                    )
                }
            }
            .frame(height: rowHeight * CGFloat(weekCount))
        }
        .background(WidgetPalette.cardBackground(for: colorScheme))
    }

    private func rowHeight(for totalHeight: CGFloat, weekCount: Int) -> CGFloat {
        let reservedHeight = DutyparkWidgetLayout.monthHeaderHeight
            + DutyparkWidgetLayout.weekdayHeaderHeight
        return max(0, (totalHeight - reservedHeight) / CGFloat(max(1, weekCount)))
    }

    private var visibleWeekCount: Int {
        visibleDayRange.count / DutyparkWidgetMonthGridLayout.daysPerWeek
    }

    private var visibleDayRange: Range<Int> {
        DutyparkWidgetMonthGridLayout.visibleDayRange(
            isCurrentMonth: entry.days.map(\.isCurrentMonth)
        )
    }

    private var weekdayRow: some View {
        LazyVGrid(columns: calendarColumns, spacing: 0) {
            ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.system(size: isKorean ? 12 : 10, weight: .bold, design: .rounded))
                    .foregroundStyle(weekdayColor(index))
                    .frame(maxWidth: .infinity, minHeight: DutyparkWidgetLayout.weekdayHeaderHeight)
                    .overlay(alignment: .trailing) {
                        if index < 6 {
                            Rectangle()
                                .fill(WidgetPalette.gridLine(for: colorScheme))
                                .frame(width: 0.5)
                        }
                    }
            }
        }
        .background(WidgetPalette.weekdayBackground(for: colorScheme))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WidgetPalette.gridLine(for: colorScheme))
                .frame(height: 0.5)
        }
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
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
    private enum Layout {
        static let maximumTextFontSize: CGFloat = 12
        static let minimumTextFontSize: CGFloat = 8
        static let dateAndDutyLineHeight: CGFloat = 1.25
        static let holidayFontSize: CGFloat = 9
        static let holidayHeight: CGFloat = 11
        static let verticalSpacing: CGFloat = 1
        static let topInset: CGFloat = 4
        static let bottomInset: CGFloat = 3
    }

    let day: DutyparkWidgetDayPresentation
    let isCurrentMonth: Bool
    let isToday: Bool
    let colorScheme: ColorScheme
    let hasRightDivider: Bool
    let hasBottomDivider: Bool
    let rowHeight: CGFloat

    var body: some View {
        VStack(alignment: .center, spacing: Layout.verticalSpacing) {
            Text(dayNumber)
                .font(.system(size: dayNumberFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(dayNumberColor)
                .padding(.horizontal, needsDayNumberContrastBacking ? 3 : 0)
                .background {
                    if needsDayNumberContrastBacking {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white)
                    }
                }
                .frame(height: dayNumberHeight)
                .frame(maxWidth: .infinity)
            dutySlot
            if showsHolidayName {
                Text(displayHolidayName ?? " ")
                    .font(.system(size: Layout.holidayFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(holidayForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: Layout.holidayHeight)
                    .frame(maxWidth: .infinity)
            }
        }
        .opacity(isCurrentMonth ? 1 : 0.45)
        .padding(.horizontal, 2)
        .padding(.top, Layout.topInset)
        .padding(.bottom, Layout.bottomInset)
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight, alignment: .top)
        .background(cellBackground)
        .overlay(alignment: .trailing) {
            if hasRightDivider {
                Rectangle()
                    .fill(WidgetPalette.gridLine(for: colorScheme))
                    .frame(width: 0.5)
            }
        }
        .overlay(alignment: .bottom) {
            if hasBottomDivider {
                Rectangle()
                    .fill(WidgetPalette.gridLine(for: colorScheme))
                    .frame(height: 0.5)
            }
        }
        .overlay(alignment: .top) {
            if isToday {
                todayMarker
            }
        }
        .overlay {
            if isToday {
                Rectangle()
                    .stroke(WidgetPalette.todayHalo(for: colorScheme), lineWidth: 2.5)
                    .padding(1)
            }
        }
        .overlay {
            if isToday {
                Rectangle()
                    .stroke(WidgetPalette.today(for: colorScheme), lineWidth: 1.5)
                    .padding(1)
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

    private var displayHolidayName: String? {
        guard let holidayName = day.holidayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !holidayName.isEmpty
        else { return nil }
        return holidayName
    }

    private var accessibilityLabel: String {
        var labels = [day.date]
        if let holidayName = displayHolidayName {
            labels.append(holidayName)
        }
        if let abbreviation = displayAbbreviation {
            labels.append(abbreviation)
        }
        return labels.joined(separator: ", ")
    }

    private var displayAbbreviation: String? {
        if let abbreviation = day.abbreviation, !abbreviation.isEmpty {
            return abbreviation
        }
        return day.isOff ? "off" : nil
    }

    private var dutySlot: some View {
        Text(displayAbbreviation ?? " ")
            .font(.system(size: dutyFontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(dutyForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(height: dutyHeight)
            .frame(maxWidth: .infinity)
            .opacity(displayAbbreviation == nil ? 0 : 1)
    }

    private var todayMarker: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(WidgetPalette.today(for: colorScheme))
                .frame(width: proxy.size.width * 0.7, height: 4)
                .position(x: proxy.size.width / 2, y: 2)
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private var cellBackground: Color {
        guard displayAbbreviation != nil else {
            return day.isOff
                ? WidgetPalette.offBackground(for: colorScheme)
                : WidgetPalette.emptyCell(for: colorScheme)
        }
        return WidgetHexColor.backgroundColor(day.colorHex)
            ?? (day.isOff
                ? WidgetPalette.offBackground(for: colorScheme)
                : WidgetPalette.emptyDutyBackground(for: colorScheme))
    }

    private var dayNumberColor: Color {
        switch dayNumberStyle {
        case .sundayOrHoliday:
            return WidgetPalette.sunday(for: colorScheme)
        case .saturday:
            return WidgetPalette.saturday(for: colorScheme)
        case .duty:
            return dutyForeground
        case .secondary:
            return WidgetPalette.secondaryText(for: colorScheme)
        case .primary:
            return WidgetPalette.primaryText(for: colorScheme)
        }
    }

    private var dayNumberStyle: DutyparkWidgetDayNumberStyle {
        DutyparkWidgetDayNumberStyle.resolve(
            weekday: day.weekday,
            holidayName: day.holidayName,
            isCurrentMonth: isCurrentMonth,
            hasConfiguredDutyColor: hasConfiguredDutyColor
        )
    }

    private var needsDayNumberContrastBacking: Bool {
        guard hasConfiguredDutyColor,
              let background = DutyparkWidgetColorComponents(hex: day.colorHex)
        else { return false }
        return background.needsDateNumberContrastBacking(for: dayNumberStyle)
    }

    private var holidayForeground: Color {
        WidgetPalette.holiday(for: colorScheme)
    }

    private var dutyForeground: Color {
        if day.isOff, day.colorHex == nil { return WidgetPalette.off(for: colorScheme) }
        return WidgetHexColor.readableColor(day.colorHex)
            ?? (day.isOff
                ? WidgetPalette.off(for: colorScheme)
                : WidgetPalette.emptyDuty(for: colorScheme))
    }

    private var hasConfiguredDutyColor: Bool {
        displayAbbreviation != nil && DutyparkWidgetColorComponents(hex: day.colorHex) != nil
    }

    private var dayNumberHeight: CGFloat {
        let reservedHeight = Layout.topInset + Layout.bottomInset
            + 2 * Layout.verticalSpacing + Layout.holidayHeight
        return min(15, max(10, (rowHeight - reservedHeight) / 2))
    }

    private var dutyHeight: CGFloat {
        dayNumberHeight
    }

    private var showsHolidayName: Bool {
        guard displayHolidayName != nil else { return false }
        let dateAndDutyHeight = Layout.topInset + Layout.bottomInset
            + dayNumberHeight + dutyHeight + Layout.verticalSpacing
        let holidayHeightNeeded = Layout.holidayHeight + Layout.verticalSpacing
        return rowHeight - dateAndDutyHeight >= holidayHeightNeeded
    }

    private var dayNumberFontSize: CGFloat {
        min(Layout.maximumTextFontSize, max(Layout.minimumTextFontSize, dayNumberHeight / Layout.dateAndDutyLineHeight))
    }

    private var dutyFontSize: CGFloat {
        dayNumberFontSize
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

    static func sunday(for _: ColorScheme) -> Color {
        Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)
    }

    static func saturday(for _: ColorScheme) -> Color {
        Color(red: 0x25 / 255, green: 0x63 / 255, blue: 0xEB / 255)
    }

    static func today(for _: ColorScheme) -> Color {
        Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255)
    }

    static func todayHalo(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.122, green: 0.161, blue: 0.216)
            : .white
    }

    static func off(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.42, blue: 0.46)
            : Color(red: 0.86, green: 0.15, blue: 0.20)
    }

    static func holiday(for _: ColorScheme) -> Color {
        Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)
    }

    static func emptyDuty(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.82, green: 0.835, blue: 0.86)
            : Color(red: 0.42, green: 0.45, blue: 0.50)
    }

    static func offBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.42, green: 0.10, blue: 0.12)
            : Color(red: 1.0, green: 0.89, blue: 0.90)
    }

    static func emptyDutyBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.22, green: 0.27, blue: 0.35)
            : Color(red: 0.91, green: 0.92, blue: 0.94)
    }

    static func todoStatus(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.38, green: 0.65, blue: 1.0)
            : Color(red: 0.145, green: 0.388, blue: 0.922)
    }

    static func inProgressStatus(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.73, blue: 0.23)
            : Color(red: 0.84, green: 0.42, blue: 0.02)
    }

    static func todoStatusBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.23, blue: 0.37)
            : Color(red: 0.86, green: 0.92, blue: 1.0)
    }

    static func inProgressStatusBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.35, green: 0.19, blue: 0.02)
            : Color(red: 1.0, green: 0.95, blue: 0.82)
    }

    static func countBadgeBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.216, green: 0.255, blue: 0.318)
            : Color(red: 0.90, green: 0.906, blue: 0.922)
    }

}

private enum WidgetHexColor {
    static func readableColor(_ hex: String?) -> Color? {
        guard let components = DutyparkWidgetColorComponents(hex: hex) else { return nil }
        return components.usesLightForeground
            ? .white
            : Color(
                red: Double(0x1F) / 255,
                green: Double(0x29) / 255,
                blue: Double(0x37) / 255
            )
    }

    static func backgroundColor(_ hex: String?) -> Color? {
        guard let components = DutyparkWidgetColorComponents(hex: hex) else { return nil }
        return Color(
            red: Double(components.red) / 255,
            green: Double(components.green) / 255,
            blue: Double(components.blue) / 255
        )
    }
}

nonisolated enum DutyparkTodoWidgetAvailability: Equatable, Sendable {
    case needsSync
    case available
}

nonisolated struct DutyparkTodoWidgetEntry: TimelineEntry {
    let date: Date
    let accountID: Int64?
    let todos: [DutyparkWidgetTodoItem]
    let updatedAt: Date?
    let isPlaceholder: Bool
    let availability: DutyparkTodoWidgetAvailability

    init(
        date: Date,
        accountID: Int64?,
        todos: [DutyparkWidgetTodoItem],
        updatedAt: Date?,
        isPlaceholder: Bool = false,
        availability: DutyparkTodoWidgetAvailability = .available
    ) {
        self.date = date
        self.accountID = accountID
        self.todos = todos
        self.updatedAt = updatedAt
        self.isPlaceholder = isPlaceholder
        self.availability = availability
    }
}

struct DutyparkTodoWidgetProvider: TimelineProvider {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale.current
        value.timeZone = .current
        return value
    }

    func placeholder(in context: Context) -> DutyparkTodoWidgetEntry {
        DutyparkTodoWidgetEntry(
            date: .now,
            accountID: nil,
            todos: [
                DutyparkWidgetTodoItem(id: "placeholder-todo", title: "할 일을 확인하세요", status: .todo),
                DutyparkWidgetTodoItem(id: "placeholder-progress", title: "진행 중인 할 일", status: .inProgress)
            ],
            updatedAt: nil,
            isPlaceholder: true,
            availability: .available
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (DutyparkTodoWidgetEntry) -> Void
    ) {
        if context.isPreview {
            completion(
                DutyparkTodoWidgetEntry(
                    date: .now,
                    accountID: 1,
                    todos: DutyparkTodoWidgetPreviewData.todos,
                    updatedAt: Date().addingTimeInterval(-60 * 60),
                    availability: .available
                )
            )
        } else {
            completion(makeEntry(at: .now, snapshot: DutyparkWidgetSnapshotStore.loadTodo()))
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<DutyparkTodoWidgetEntry>) -> Void
    ) {
        let now = Date()
        let entry = makeEntry(at: now, snapshot: DutyparkWidgetSnapshotStore.loadTodo())
        let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime,
            direction: .forward
        ) ?? now.addingTimeInterval(60 * 60 * 24)
        let midnightEntry = makeEntry(
            at: nextMidnight,
            snapshot: DutyparkWidgetSnapshotStore.loadTodo()
        )
        completion(
            Timeline(
                entries: [entry, midnightEntry],
                policy: .after(nextMidnight)
            )
        )
    }

    private func makeEntry(
        at date: Date,
        snapshot: DutyparkWidgetTodoSnapshot?
    ) -> DutyparkTodoWidgetEntry {
        DutyparkTodoWidgetEntry(
            date: date,
            accountID: snapshot?.accountID,
            todos: snapshot?.todos ?? [],
            updatedAt: snapshot?.updatedAt,
            availability: snapshot == nil ? .needsSync : .available
        )
    }
}

struct DutyparkTodoWidgetView: View {
    let entry: DutyparkTodoWidgetEntry

    private static let maximumVisibleTodoCount = 3
    private static let statusBadgeWidth: CGFloat = 52
    private static let statusBadgeHeight: CGFloat = 20

    @Environment(\.colorScheme) private var colorScheme

    private var isKorean: Bool {
        DutyparkWidgetLocalization.isKorean
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(WidgetPalette.today(for: colorScheme))
                    .accessibilityHidden(true)
                Text(isKorean ? "할 일" : "Todos")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(WidgetPalette.primaryText(for: colorScheme))
                Spacer(minLength: 4)
                if entry.availability == .available, !entry.todos.isEmpty {
                    Text("\(entry.todos.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WidgetPalette.secondaryText(for: colorScheme))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            WidgetPalette.countBadgeBackground(for: colorScheme),
                            in: Capsule(style: .continuous)
                        )
                }
            }
            if entry.isPlaceholder {
                todoRows
                    .redacted(reason: .placeholder)
            } else if entry.availability == .needsSync {
                syncState
            } else if entry.todos.isEmpty {
                emptyState
            } else {
                todoRows
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            WidgetPalette.background(for: colorScheme)
        }
        .widgetURL(URL(string: DutyparkWidgetConstants.todoAppURL))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var todoRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(entry.todos.prefix(Self.maximumVisibleTodoCount))) { todo in
                HStack(spacing: 7) {
                    statusBadge(for: todo.status)
                    Text(todo.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetPalette.primaryText(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(todo.title), \(statusLabel(for: todo.status))")
            }
            if hiddenTodoCount > 0 {
                Text(isKorean ? "+\(hiddenTodoCount)개 더 보기" : "+\(hiddenTodoCount) more")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetPalette.secondaryText(for: colorScheme))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        isKorean
                            ? "할 일 \(hiddenTodoCount)개 더 있음"
                            : "\(hiddenTodoCount) more todos"
                    )
            }
        }
    }

    private func statusBadge(for status: DutyparkWidgetTodoStatus) -> some View {
        Text(statusLabel(for: status))
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(statusBadgeForeground(for: status))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: Self.statusBadgeWidth, height: Self.statusBadgeHeight)
            .background(
                statusBadgeBackground(for: status),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(statusBadgeForeground(for: status).opacity(0.28), lineWidth: 0.7)
            }
            .accessibilityHidden(true)
    }

    private func statusBadgeForeground(for status: DutyparkWidgetTodoStatus) -> Color {
        switch status {
        case .todo:
            WidgetPalette.todoStatus(for: colorScheme)
        case .inProgress:
            WidgetPalette.inProgressStatus(for: colorScheme)
        }
    }

    private func statusBadgeBackground(for status: DutyparkWidgetTodoStatus) -> Color {
        switch status {
        case .todo:
            WidgetPalette.todoStatusBackground(for: colorScheme)
        case .inProgress:
            WidgetPalette.inProgressStatusBackground(for: colorScheme)
        }
    }

    private var hiddenTodoCount: Int {
        max(0, entry.todos.count - Self.maximumVisibleTodoCount)
    }

    private var syncState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "arrow.clockwise.circle")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(WidgetPalette.secondaryText(for: colorScheme))
                .accessibilityHidden(true)
            Text(isKorean ? "앱을 열어 할 일을 동기화하세요" : "Open Dutypark to sync your todos")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetPalette.secondaryText(for: colorScheme))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(WidgetPalette.secondaryText(for: colorScheme))
                .accessibilityHidden(true)
            Text(isKorean ? "할 일이 없습니다" : "No active todos")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetPalette.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func statusLabel(for status: DutyparkWidgetTodoStatus) -> String {
        switch status {
        case .todo: isKorean ? "할일" : "TODO"
        case .inProgress: isKorean ? "진행중" : "Doing"
        }
    }

    private var accessibilityLabel: String {
        if entry.availability == .needsSync {
            return isKorean
                ? "앱을 열어 할 일을 동기화하세요"
                : "Open Dutypark to sync your todos"
        }
        if entry.todos.isEmpty {
            return isKorean ? "진행 중인 할 일 없음" : "No active todos"
        }
        let items = entry.todos.prefix(Self.maximumVisibleTodoCount).map {
            "\($0.title), \(statusLabel(for: $0.status))"
        }.joined(separator: ", ")
        let remaining = hiddenTodoCount > 0
            ? (isKorean ? ", \(hiddenTodoCount)개 더 있음" : ", \(hiddenTodoCount) more")
            : ""
        return isKorean
            ? "활성 할 일, \(items)\(remaining)"
            : "Active todos, \(items)\(remaining)"
    }
}

@main
struct DutyparkWidgets: WidgetBundle {
    var body: some Widget {
        DutyparkMonthlyWidget()
        DutyparkTodoWidget()
    }
}

struct DutyparkTodoWidget: Widget {
    let kind = DutyparkWidgetKind.todo

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DutyparkTodoWidgetProvider()) { entry in
            DutyparkTodoWidgetView(entry: entry)
        }
        .configurationDisplayName("할 일")
        .description("완료하지 않은 할 일을 확인합니다.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
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

#Preview(as: .systemMedium) {
    DutyparkTodoWidget()
} timeline: {
    DutyparkTodoWidgetEntry(
        date: Date(),
        accountID: 1,
        todos: DutyparkTodoWidgetPreviewData.todos,
        updatedAt: Date().addingTimeInterval(-60 * 60)
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
                    isOff: day.isOff,
                    holidayName: day.holidayName
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
            let holidayName: String?
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
            switch day {
            case 3:
                holidayName = "공휴일"
            case 15:
                holidayName = "추석"
            default:
                holidayName = nil
            }
            return DutyparkWidgetDayPresentation(
                date: dateString,
                weekday: weekday,
                isCurrentMonth: year == 2026 && month == 9,
                abbreviation: abbreviation,
                colorHex: color,
                isOff: abbreviation == "off",
                holidayName: holidayName
            )
        }
    }()
}

private enum DutyparkTodoWidgetPreviewData {
    static let todos = [
        DutyparkWidgetTodoItem(
            id: "preview-todo",
            title: "병동 인수인계 확인",
            status: .todo
        ),
        DutyparkWidgetTodoItem(
            id: "preview-progress",
            title: "이번 주 일정 정리",
            status: .inProgress
        ),
        DutyparkWidgetTodoItem(
            id: "preview-todo-two",
            title: "팀 공지 작성",
            status: .todo
        )
    ]
}
