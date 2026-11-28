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

    /// Today's column header is inked like body text and underlined, rather than filled
    /// with a colour a duty could also use.
    static let todayWeekdayUnderlineWidth: CGFloat = 2

    static func weekdayHeaderInk(_ index: Int, isToday: Bool) -> Color {
        isToday ? DPColor.textPrimary : weekdayColor(index)
    }

    /// The weekday header column marked for today, only while today's month is shown.
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

    fileprivate static func dynamic(light: UInt32, dark: UInt32) -> Color {
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
                // The circle overhangs the header by a point each way, so today's header is
                // as tall as every other and ribbon lanes stay level across the row.
                .padding(.vertical, -1)
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
            .foregroundStyle(DPCalendarCellStyle.weekdayHeaderInk(weekdayIndex, isToday: isToday))
            .frame(maxWidth: .infinity, minHeight: DPCalendarCellStyle.weekdayHeaderHeight)
            .background(DPCalendarCellStyle.weekdayHeaderBackground)
            .overlay(alignment: .bottom) {
                if isToday {
                    DPColor.textPrimary
                        .frame(height: DPCalendarCellStyle.todayWeekdayUnderlineWidth)
                        .accessibilityHidden(true)
                }
            }
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
/// and the day's content. Today is the same tile lifted off the grid as a card, its
/// numeral in a red circle.
nonisolated struct DPCalendarDayTile<Accessory: View, Content: View>: View {
    let day: Int
    let weekdayIndex: Int
    let dutyColor: String?
    let isCurrentMonth: Bool
    let isToday: Bool
    var hasHoliday = false
    /// A border for a selected, highlighted or focused day.
    var highlight: Color?
    /// The tile's column when it draws a ribbon that reaches over the next tiles of its row.
    var ribbonColumn: Int?
    /// Where the grid's edges are, so a lifted today grows away from them.
    var isFirstRow = false
    var isLastRow = false
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
        .background {
            if isToday {
                DPCalendarTodayLift.Card(fill: fill)
            } else {
                fill
            }
        }
        .overlay {
            if ring == .highlight, let highlight {
                RoundedRectangle(cornerRadius: isToday ? DPCalendarTodayLift.cornerRadius : 0)
                    .strokeBorder(highlight, lineWidth: DPCalendarTileRing.highlightWidth)
                    .allowsHitTesting(false)
            }
        }
        .modifier(DPCalendarTodayLift.Effect(isActive: isToday, placement: liftPlacement))
        // Today's own slot keeps its fill under the card, where the card stands off an edge.
        .background { if isToday { fill } }
        .zIndex(DPCalendarTileRing.zIndex(ring: ring, ribbonColumn: ribbonColumn, isToday: isToday))
    }

    private var fill: Color {
        DPCalendarCellStyle.cellBackground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
    }

    private var liftPlacement: DPCalendarTodayLift.Placement {
        DPCalendarTodayLift.placement(column: weekdayIndex, isFirstRow: isFirstRow, isLastRow: isLastRow)
    }

    private var ring: DPCalendarTileRing {
        DPCalendarTileRing(hasHighlight: highlight != nil)
    }
}

/// The one ring a tile draws: a selection border. Today is marked by its lift instead.
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
    /// stays on top of the tiles it crosses. Today sits above everything, so its shadow
    /// falls on its neighbours; it redraws its stretch of any ribbon that crosses it.
    static func zIndex(ring: DPCalendarTileRing, ribbonColumn: Int?, isToday: Bool = false) -> Double {
        if isToday { return DPCalendarTodayLift.zIndex }
        if let ribbonColumn { return 3 + Double(6 - ribbonColumn) }
        return ring == .highlight ? 1 : 0
    }
}

/// Today (web `F`): the day's own tile, scaled up a little, rounded, with a drop shadow
/// and a thin halo in the page colour. Nothing about it is a colour a duty could share.
nonisolated enum DPCalendarTodayLift {
    static let scale: CGFloat = 1.07
    static let cornerRadius: CGFloat = 8
    /// The web's `0 8px 20px rgb(0 0 0 / 35%)`.
    static let shadowOpacity = 0.35
    static let shadowRadius: CGFloat = 10
    static let shadowY: CGFloat = 4
    static let haloWidth: CGFloat = 1.5
    static let haloColor = DPCalendarCellStyle.dynamic(light: 0xFFFFFF, dark: 0x111827)
    /// How far a card on a grid edge stands in from it: the halo then sits flush on the
    /// edge, and the grid's rounded clip never cuts it or the card's corners.
    static let edgeInset = haloWidth
    /// Above every ribbon tile (at most 9).
    static let zIndex: Double = 10
    /// Today's unscaled tile, which the ribbons inside it measure against.
    static let tileSpace = "DPCalendarTodayLiftTile"

    /// How the card is lifted: scaled about `anchor`, then moved by `shift`.
    struct Placement: Equatable {
        let anchor: UnitPoint
        let shift: CGSize
    }

    /// The card grows away from the grid's outer edges and stands in from them by
    /// `edgeInset`, where the grid's clip would otherwise cut it.
    static func placement(column: Int, isFirstRow: Bool, isLastRow: Bool) -> Placement {
        let x: CGFloat = column == 0 ? 0 : column == 6 ? 1 : 0.5
        let y: CGFloat = isFirstRow == isLastRow ? 0.5 : isFirstRow ? 0 : 1
        return Placement(
            anchor: UnitPoint(x: x, y: y),
            shift: CGSize(width: (1 - 2 * x) * edgeInset, height: (1 - 2 * y) * edgeInset)
        )
    }

    /// Where the lifted card is drawn for a tile laid out at `frame`.
    static func liftedFrame(_ frame: CGRect, placement: Placement) -> CGRect {
        let anchor = placement.anchor
        let pivot = CGPoint(x: frame.minX + frame.width * anchor.x, y: frame.minY + frame.height * anchor.y)
        return CGRect(
            x: pivot.x + (frame.minX - pivot.x) * scale + placement.shift.width,
            y: pivot.y + (frame.minY - pivot.y) * scale + placement.shift.height,
            width: frame.width * scale,
            height: frame.height * scale
        )
    }

    /// Lifts today's tile and tells its ribbons how. Other tiles are left untouched: the
    /// coordinate space and transform pixel-round a tile's layout, which would wrap time
    /// ranges that otherwise fit.
    struct Effect: ViewModifier {
        let isActive: Bool
        let placement: Placement

        func body(content: Content) -> some View {
            if isActive {
                content
                    .coordinateSpace(.named(DPCalendarTodayLift.tileSpace))
                    .environment(\.dpCalendarTodayLift, placement)
                    .scaleEffect(DPCalendarTodayLift.scale, anchor: placement.anchor)
                    .offset(placement.shift)
            } else {
                content
            }
        }
    }

    /// The card under today's content: its fill clipped to the rounded shape, the shadow,
    /// and the halo just outside it.
    struct Card: View {
        let fill: Color

        var body: some View {
            let lift = DPCalendarTodayLift.self
            RoundedRectangle(cornerRadius: lift.cornerRadius)
                .fill(fill)
                .shadow(color: .black.opacity(lift.shadowOpacity), radius: lift.shadowRadius, y: lift.shadowY)
                .overlay {
                    RoundedRectangle(cornerRadius: lift.cornerRadius + lift.haloWidth)
                        .strokeBorder(lift.haloColor, lineWidth: lift.haloWidth)
                        .padding(-lift.haloWidth)
                }
                .accessibilityHidden(true)
        }
    }
}

extension EnvironmentValues {
    /// How today's tile is lifted, inside today's tile only.
    @Entry var dpCalendarTodayLift: DPCalendarTodayLift.Placement?
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
