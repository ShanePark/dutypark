import SwiftUI
import UIKit

/// Shared colors and measurements for the flat month calendar grids, mirrored from
/// the web `CalendarGrid.vue`.
///
/// A duty colour is drawn as its raw hex in both appearances, so everything painted
/// on a duty tile uses fixed colours and looks identical in light and dark. Only
/// tiles without a duty follow the theme.
nonisolated enum DPCalendarCellStyle {
    /// How a tile's ink is chosen.
    enum Tone: Equatable {
        /// No duty fill: the theme decides.
        case theme
        /// A light duty fill (fixed dark ink).
        case onLight
        /// A dark duty fill (fixed light ink).
        case onDark
    }

    static let weekdayFontSize: CGFloat = 12
    static let dayNumberFontSize: CGFloat = 13
    static let weekdayHeaderHeight: CGFloat = 24
    /// The gutters between tiles are the only separators, so equal duty colours on
    /// neighbouring days still read as separate days.
    static let gutterWidth: CGFloat = 2
    static let cornerRadius: CGFloat = 8
    static let cellMinimumHeight: CGFloat = 64
    static let cellHorizontalPadding: CGFloat = 3
    static let todayCircleDiameter: CGFloat = 20
    static let outsideDutyWeight = 0.6

    static let gutterColor = DPColor.borderPrimary
    static let todayColor = DPColor.dangerHover
    /// The header sits on the card surface in dark mode and on the soft surface in light.
    static let weekdayHeaderBackground = DPColor.backgroundSecondary
    static let currentMonthBackground = DPColor.backgroundCard
    static let outsideMonthBackground = dynamic(light: 0xF9FAFB, dark: 0x111827)

    static let sundayInk = dynamic(light: 0xDC2626, dark: 0xF87171)
    static let saturdayInk = dynamic(light: 0x2563EB, dark: 0x60A5FA)

    static let inkOnLight = DPColor.textOnLight
    static let mutedInkOnLight = fixed(0x1F2937, opacity: 0.72)
    static let outsideInkOnLight = fixed(0x1F2937, opacity: 0.82)
    static let outsideMutedInkOnLight = fixed(0x1F2937, opacity: 0.58)
    static let ruleOnLight = fixed(0x1F2937, opacity: 0.22)
    static let inkOnDark = DPColor.textOnDark
    static let mutedInkOnDark = DPColor.textOnDarkMuted
    static let ruleOnDark = fixed(0xFFFFFF, opacity: 0.30)

    /// `DutyTypeColorPalette.sundayHex` / `saturdayHex`: AA contrast on every palette fill.
    static let sundayOnLightFill = fixed(0x991B1B)
    static let saturdayOnLightFill = fixed(0x1E40AF)
    static let sundayOnDarkFill = fixed(0xFCA5A5)
    static let saturdayOnDarkFill = fixed(0x93C5FD)

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

    /// Out-of-month days fade their duty toward fixed white rather than a theme
    /// surface, so the faded tile is also the same in light and dark.
    static func fadedOutsideHex(_ hex: String?) -> String? {
        guard let components = rgb(hex) else { return nil }
        func fade(_ value: UInt8) -> Int {
            Int((Double(value) * outsideDutyWeight + 255 * (1 - outsideDutyWeight)).rounded())
        }
        return String(
            format: "#%02X%02X%02X",
            fade(components.red),
            fade(components.green),
            fade(components.blue)
        )
    }

    /// The hex a tile is filled with, or `nil` when the tile follows the theme.
    static func fillHex(dutyColor: String?, isCurrentMonth: Bool) -> String? {
        guard let components = rgb(dutyColor) else { return nil }
        guard isCurrentMonth else { return fadedOutsideHex(dutyColor) }
        return String(format: "#%02X%02X%02X", components.red, components.green, components.blue)
    }

    static func tone(dutyColor: String?, isCurrentMonth: Bool) -> Tone {
        guard let fill = fillHex(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth) else { return .theme }
        return usesLightForeground(on: fill) ? .onDark : .onLight
    }

    static func cellBackground(dutyColor: String?, isCurrentMonth: Bool) -> Color {
        guard let components = rgb(fillHex(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)) else {
            return isCurrentMonth ? currentMonthBackground : outsideMonthBackground
        }
        return Color(
            red: Double(components.red) / 255,
            green: Double(components.green) / 255,
            blue: Double(components.blue) / 255
        )
    }

    static func primaryForeground(dutyColor: String?, isCurrentMonth: Bool = true) -> Color {
        switch tone(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth) {
        case .theme: DPColor.textPrimary
        case .onLight: isCurrentMonth ? inkOnLight : outsideInkOnLight
        case .onDark: inkOnDark
        }
    }

    static func secondaryForeground(dutyColor: String?, isCurrentMonth: Bool = true) -> Color {
        switch tone(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth) {
        case .theme: DPColor.textMuted
        case .onLight: isCurrentMonth ? mutedInkOnLight : outsideMutedInkOnLight
        case .onDark: mutedInkOnDark
        }
    }

    /// The hairline between items inside a tile.
    static func ruleColor(dutyColor: String?, isCurrentMonth: Bool = true) -> Color {
        switch tone(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth) {
        case .theme: DPColor.borderPrimary
        case .onLight: ruleOnLight
        case .onDark: ruleOnDark
        }
    }

    static func dayNumberColor(
        dutyColor: String?,
        isCurrentMonth: Bool = true,
        weekdayIndex: Int,
        hasHoliday: Bool
    ) -> Color {
        guard isCurrentMonth else { return secondaryForeground(dutyColor: dutyColor, isCurrentMonth: false) }
        if weekdayIndex == 0 || hasHoliday {
            return holidayForeground(dutyColor: dutyColor)
        }
        if weekdayIndex == 6 {
            switch tone(dutyColor: dutyColor, isCurrentMonth: true) {
            case .theme: return saturdayInk
            case .onLight: return saturdayOnLightFill
            case .onDark: return saturdayOnDarkFill
            }
        }
        return primaryForeground(dutyColor: dutyColor)
    }

    static func holidayForeground(dutyColor: String?, isCurrentMonth: Bool = true) -> Color {
        switch tone(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth) {
        case .theme: sundayInk
        case .onLight: sundayOnLightFill
        case .onDark: sundayOnDarkFill
        }
    }

    static func weekdayColor(_ index: Int) -> Color {
        if index == 0 { return sundayInk }
        if index == 6 { return saturdayInk }
        return DPColor.textSecondary
    }

    /// The weekday header column filled red for today, only while today's month is shown.
    static func todayWeekdayIndex(
        year: Int,
        month: Int,
        today: Date,
        calendar: Foundation.Calendar
    ) -> Int? {
        let components = calendar.dateComponents([.year, .month, .weekday], from: today)
        guard components.year == year, components.month == month, let weekday = components.weekday else {
            return nil
        }
        return weekday - 1
    }

    private static func fixed(_ hex: UInt32, opacity: CGFloat = 1) -> Color {
        Color(uiColor: UIColor(calendarHex: hex, alpha: opacity))
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(calendarHex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    nonisolated convenience init(calendarHex hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

nonisolated struct DPCalendarDayNumber: View {
    let day: Int
    let weekdayIndex: Int
    let dutyColor: String?
    let hasHoliday: Bool
    let isCurrentMonth: Bool
    let isToday: Bool

    init(
        day: Int,
        weekdayIndex: Int,
        dutyColor: String?,
        hasHoliday: Bool = false,
        isCurrentMonth: Bool = true,
        isToday: Bool = false
    ) {
        self.day = day
        self.weekdayIndex = weekdayIndex
        self.dutyColor = dutyColor
        self.hasHoliday = hasHoliday
        self.isCurrentMonth = isCurrentMonth
        self.isToday = isToday
    }

    var body: some View {
        if isToday {
            Text(verbatim: String(day))
                .font(DPFont.bold(size: 12, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .frame(
                    width: DPCalendarCellStyle.todayCircleDiameter,
                    height: DPCalendarCellStyle.todayCircleDiameter
                )
                .background(Circle().fill(DPCalendarCellStyle.todayColor))
                .padding(.leading, -1)
        } else {
            Text(verbatim: String(day))
                .font(DPFont.bold(size: DPCalendarCellStyle.dayNumberFontSize, relativeTo: .caption))
                .monospacedDigit()
                .foregroundStyle(
                    DPCalendarCellStyle.dayNumberColor(
                        dutyColor: dutyColor,
                        isCurrentMonth: isCurrentMonth,
                        weekdayIndex: weekdayIndex,
                        hasHoliday: hasHoliday
                    )
                )
        }
    }
}

nonisolated struct DPCalendarWeekdayHeaderCell: View {
    let label: String
    let weekdayIndex: Int
    var isToday = false

    var body: some View {
        Text(verbatim: label)
            .font(DPFont.bold(size: DPCalendarCellStyle.weekdayFontSize, relativeTo: .caption))
            .foregroundStyle(isToday ? Color.white : DPCalendarCellStyle.weekdayColor(weekdayIndex))
            .frame(maxWidth: .infinity, minHeight: DPCalendarCellStyle.weekdayHeaderHeight)
            .background(isToday ? DPCalendarCellStyle.todayColor : DPCalendarCellStyle.weekdayHeaderBackground)
    }
}

/// The weekday header row of a flat month grid.
nonisolated struct DPCalendarWeekdayRow: View {
    let labels: [String]
    var todayIndex: Int?

    var body: some View {
        HStack(spacing: DPCalendarCellStyle.gutterWidth) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                DPCalendarWeekdayHeaderCell(label: label, weekdayIndex: index, isToday: index == todayIndex)
            }
        }
    }
}

/// One day tile of a flat month grid: the fill, the date number with its accessory,
/// the day's content, and the today ring that is drawn over the surrounding gutter.
nonisolated struct DPCalendarDayTile<Accessory: View, Content: View>: View {
    let day: Int
    let weekdayIndex: Int
    let dutyColor: String?
    let isCurrentMonth: Bool
    let isToday: Bool
    var hasHoliday = false
    /// A border for a selected, highlighted or focused day. It wins over today's ring;
    /// today stays recognisable by the red date circle.
    var highlight: Color?
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                DPCalendarDayNumber(
                    day: day,
                    weekdayIndex: weekdayIndex,
                    dutyColor: dutyColor,
                    hasHoliday: hasHoliday,
                    isCurrentMonth: isCurrentMonth,
                    isToday: isToday
                )
                Spacer(minLength: 0)
                accessory()
            }
            .frame(minHeight: 18)
            .padding(.bottom, 2)
            content()
                .environment(\.dpCalendarWeekdayIndex, weekdayIndex)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .padding(.horizontal, DPCalendarCellStyle.cellHorizontalPadding)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, minHeight: DPCalendarCellStyle.cellMinimumHeight, alignment: .topLeading)
        .background(DPCalendarCellStyle.cellBackground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth))
        .overlay {
            switch ring {
            case .highlight:
                if let highlight {
                    Rectangle().strokeBorder(highlight, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            case .today:
                DPCalendarTodayRing()
            case .none:
                EmptyView()
            }
        }
        // Today's ring reaches over the gutter, so it must sit above its neighbours.
        .zIndex(ring == .today ? 2 : ring == .highlight ? 1 : 0)
    }

    private var ring: DPCalendarTileRing {
        DPCalendarTileRing(isToday: isToday, hasHighlight: highlight != nil)
    }
}

/// The one ring a tile draws. A selection border wins over today's ring, so a selected
/// today still reads as selected; the red date circle keeps marking today.
nonisolated enum DPCalendarTileRing: Equatable {
    case none
    case today
    case highlight

    init(isToday: Bool, hasHighlight: Bool) {
        self = hasHighlight ? .highlight : isToday ? .today : .none
    }
}

/// The weekday column (0 = Sunday) of the tile an item is drawn in.
private nonisolated struct DPCalendarWeekdayIndexKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    nonisolated var dpCalendarWeekdayIndex: Int? {
        get { self[DPCalendarWeekdayIndexKey.self] }
        set { self[DPCalendarWeekdayIndexKey.self] = newValue }
    }
}

/// Today's marker on an unselected tile: a red ring over the gutter with a thin
/// white inner line that keeps it legible on any fill.
nonisolated struct DPCalendarTodayRing: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(DPCalendarCellStyle.todayColor, lineWidth: 2)
            RoundedRectangle(cornerRadius: 1.5)
                .strokeBorder(Color.white, lineWidth: 1.5)
                .padding(2)
        }
        .padding(-DPCalendarCellStyle.gutterWidth)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One item line inside a tile (a schedule or a D-Day marker). Items after the first
/// are separated by a hairline. A multi-day schedule draws a bar at the top of the item
/// that runs to the tile edges, so the days of one schedule join across the week at the
/// same height; its title sits below the bar only where the run starts or enters a new
/// week row, and the other days show the bar alone.
nonisolated struct DPCalendarItemRow<Content: View>: View {
    let showsRule: Bool
    let rule: Color
    var span: DPCalendarSpan?
    var spanColor: Color = .clear
    @ViewBuilder var content: () -> Content
    @Environment(\.dpCalendarWeekdayIndex) private var weekdayIndex

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let span {
                spanBar(span)
            }
            if showsTitle {
                content()
                    .transformEnvironment(\.lineLimit) { limit in
                        if span != nil { limit = DPCalendarSpan.titleLineLimit }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .overlay(alignment: .top) {
            if showsRule {
                Rectangle().fill(rule).frame(height: 1)
            }
        }
        .modifier(DPCalendarHiddenTitleAccessibility(isHidden: !showsTitle, title: content))
    }

    private var showsTitle: Bool {
        span?.showsTitle(weekdayIndex: weekdayIndex) ?? true
    }

    private func spanBar(_ span: DPCalendarSpan) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: span.isStart ? 2 : 0,
            bottomLeadingRadius: span.isStart ? 2 : 0,
            bottomTrailingRadius: span.isEnd ? 2 : 0,
            topTrailingRadius: span.isEnd ? 2 : 0
        )
        .fill(spanColor)
        .frame(height: 2.5)
        .padding(.leading, span.isStart ? 0 : -DPCalendarCellStyle.cellHorizontalPadding)
        .padding(.trailing, span.isEnd ? 0 : -DPCalendarCellStyle.cellHorizontalPadding)
        .accessibilityHidden(true)
    }
}

/// A continuation day draws only the bar, but VoiceOver still reads the schedule's title there.
private nonisolated struct DPCalendarHiddenTitleAccessibility<Title: View>: ViewModifier {
    let isHidden: Bool
    let title: () -> Title

    func body(content: Content) -> some View {
        if isHidden {
            content.accessibilityRepresentation { title() }
        } else {
            content
        }
    }
}

/// Where a day sits inside a multi-day schedule.
nonisolated struct DPCalendarSpan: Equatable {
    let isStart: Bool
    let isEnd: Bool

    /// `nil` for a single-day schedule.
    init?(daysFromStart: Int?, totalDays: Int?) {
        guard let daysFromStart, let totalDays, totalDays > 1 else { return nil }
        isStart = daysFromStart == 1
        isEnd = daysFromStart == totalDays
    }

    /// A title on every day of a run repeated itself across the week, so it is drawn where
    /// the run starts and again on Sunday (column 0) when it continues into the next week
    /// row. Outside a tile the column is unknown and the title is kept.
    func showsTitle(weekdayIndex: Int?) -> Bool {
        isStart || (weekdayIndex ?? 0) == 0
    }

    /// Where a title is drawn it may wrap, since the neighbouring days no longer repeat it.
    static let titleLineLimit = 2
}

/// The small private-schedule badge drawn before a title. On a duty fill its colours
/// are fixed so it reads the same in light and dark.
nonisolated struct DPCalendarLockBadge: View {
    let onFill: Bool

    var body: some View {
        Image(systemName: "lock")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(DPColor.dangerHover)
            .frame(width: 14, height: 14)
            .background(Circle().fill(onFill ? Self.fillBackground : DPColor.dangerHover.opacity(0.10)))
            .overlay(Circle().stroke(onFill ? Self.fillBorder : DPColor.dangerHover.opacity(0.24), lineWidth: 1))
            .accessibilityHidden(true)
    }

    /// `color-mix(#DC2626 10%, #FFFFFF)` and `color-mix(#DC2626 30%, #FFFFFF)` on the web.
    private static let fillBackground = Color(red: 252 / 255, green: 233 / 255, blue: 233 / 255)
    private static let fillBorder = Color(red: 245 / 255, green: 190 / 255, blue: 190 / 255)
}
