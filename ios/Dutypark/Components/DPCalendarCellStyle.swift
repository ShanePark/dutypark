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
    static let gutterWidth: CGFloat = 1
    static let cornerRadius: CGFloat = 8
    static let cellMinimumHeight: CGFloat = 64
    static let cellTopPadding: CGFloat = 4
    /// Narrow enough that a full "HH:MM~HH:MM" time fits one line at the 375pt width.
    static let cellHorizontalPadding: CGFloat = 1.5
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
        Text(verbatim: String(day))
            .font(DPFont.bold(size: DPCalendarCellStyle.dayNumberFontSize, relativeTo: .caption))
            .monospacedDigit()
            .foregroundStyle(
                isToday
                    ? DPCalendarTodayStrip.ink
                    : DPCalendarCellStyle.dayNumberColor(
                        dutyColor: dutyColor,
                        isCurrentMonth: isCurrentMonth,
                        weekdayIndex: weekdayIndex,
                        hasHoliday: hasHoliday
                    )
            )
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
/// and the day's content. Today's date row is a red strip across the tile's top.
nonisolated struct DPCalendarDayTile<Accessory: View, Content: View>: View {
    let day: Int
    let weekdayIndex: Int
    let dutyColor: String?
    let isCurrentMonth: Bool
    let isToday: Bool
    var hasHoliday = false
    /// A border for a selected, highlighted or focused day, drawn over today's strip.
    var highlight: Color?
    /// The tile's column when it draws a ribbon that reaches over the next tiles of its row.
    var ribbonColumn: Int?
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
            .padding(.horizontal, isToday ? DPCalendarTodayStrip.textInset : 0)
            .padding(.bottom, 2)
            .background {
                if isToday {
                    DPCalendarTodayStrip.Band()
                        .padding(.top, -DPCalendarTodayStrip.bleed.top)
                        .padding(.leading, -DPCalendarTodayStrip.bleed.leading)
                        .padding(.trailing, -DPCalendarTodayStrip.bleed.trailing)
                }
            }
            // The tallest tile of a row is placed at exactly its measured height, and the
            // stack could then propose less than two lines to the first of several wrapping
            // titles, which collapses it to one truncated line. Content keeps its full height.
            content()
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.top, DPCalendarCellStyle.cellTopPadding)
        .padding(.horizontal, DPCalendarCellStyle.cellHorizontalPadding)
        .padding(.bottom, 5)
        .frame(maxWidth: .infinity, minHeight: DPCalendarCellStyle.cellMinimumHeight, alignment: .topLeading)
        .background(DPCalendarCellStyle.cellBackground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth))
        .overlay {
            if ring == .highlight, let highlight {
                Rectangle().strokeBorder(highlight, lineWidth: DPCalendarTileRing.highlightWidth)
                    .allowsHitTesting(false)
            }
        }
        .zIndex(DPCalendarTileRing.zIndex(ring: ring, ribbonColumn: ribbonColumn))
    }

    private var ring: DPCalendarTileRing {
        DPCalendarTileRing(hasHighlight: highlight != nil)
    }
}

/// The one ring a tile draws: a selection border. Today is marked by its strip instead.
nonisolated enum DPCalendarTileRing: Equatable {
    case none
    case highlight

    /// Light beside the 1pt gutters.
    static let highlightWidth: CGFloat = 1.5

    init(hasHighlight: Bool) {
        self = hasHighlight ? .highlight : .none
    }

    /// A selected tile sits above its neighbours. A tile that draws a ribbon over the
    /// following tiles sits above all of them, the earlier column higher, so each ribbon
    /// stays on top of the tiles it crosses.
    static func zIndex(ring: DPCalendarTileRing, ribbonColumn: Int?) -> Double {
        if let ribbonColumn { return 3 + Double(6 - ribbonColumn) }
        return ring == .highlight ? 1 : 0
    }
}

/// Today's date row (web `E2`): a red strip from the tile's top, left and right edges,
/// the same red in light and dark, carrying a white numeral and any pinned D-Day label,
/// with a faint dark hairline beneath it.
nonisolated enum DPCalendarTodayStrip {
    static let background = DPCalendarCellStyle.todayColor
    static let ink = Color.white
    static let hairlineWidth: CGFloat = 1
    static let hairlineOpacity = 0.2
    /// The text sits a little in from the strip's edges.
    static let textInset: CGFloat = 2
    /// How far the strip reaches past the date row to the tile's edges.
    static let bleed = EdgeInsets(
        top: DPCalendarCellStyle.cellTopPadding,
        leading: DPCalendarCellStyle.cellHorizontalPadding,
        bottom: 0,
        trailing: DPCalendarCellStyle.cellHorizontalPadding
    )

    /// The hairline is the strip's last point, so the date row keeps its height.
    nonisolated struct Band: View {
        var body: some View {
            DPCalendarTodayStrip.background
                .overlay(alignment: .bottom) {
                    Color.black.opacity(DPCalendarTodayStrip.hairlineOpacity)
                        .frame(height: DPCalendarTodayStrip.hairlineWidth)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// One item line inside a tile (a schedule or a D-Day marker). Items after the first
/// are separated by a hairline.
nonisolated struct DPCalendarItemRow<Content: View>: View {
    let showsRule: Bool
    let rule: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .overlay(alignment: .top) {
                if showsRule {
                    Rectangle().fill(rule).frame(height: 1)
                }
            }
    }
}

/// The small private-schedule badge drawn before a title. On a duty fill its colours
/// are fixed so it reads the same in light and dark.
nonisolated struct DPCalendarLockBadge: View {
    static let diameter: CGFloat = 14

    let onFill: Bool

    var body: some View {
        Image(systemName: "lock")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(DPColor.dangerHover)
            .frame(width: Self.diameter, height: Self.diameter)
            .background(Circle().fill(onFill ? Self.fillBackground : DPColor.dangerHover.opacity(0.10)))
            .overlay(Circle().stroke(onFill ? Self.fillBorder : DPColor.dangerHover.opacity(0.24), lineWidth: 1))
            .accessibilityHidden(true)
    }

    /// `color-mix(#DC2626 10%, #FFFFFF)` and `color-mix(#DC2626 30%, #FFFFFF)` on the web.
    private static let fillBackground = Color(red: 252 / 255, green: 233 / 255, blue: 233 / 255)
    private static let fillBorder = Color(red: 245 / 255, green: 190 / 255, blue: 190 / 255)
}
