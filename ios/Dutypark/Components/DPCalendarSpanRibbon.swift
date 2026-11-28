import SwiftUI
import UIKit

/// Multi-day schedules in a month grid: each week row gives every multi-day schedule a lane
/// directly under the date numbers, at the same height in all seven tiles, so the schedule
/// reads as one straight ribbon across the days it covers in that row.
nonisolated enum DPCalendarSpanLanes {
    /// One week-row segment of a multi-day schedule, as seen by every tile it covers.
    struct Placement<Item> {
        /// The schedule as listed on the segment's first day.
        let item: Item
        let lane: Int
        /// The columns (0 = Sunday) the segment covers in its week row.
        let columns: ClosedRange<Int>
        let isTrueStart: Bool
        let isTrueEnd: Bool

        var continuesIntoNextRow: Bool { !isTrueEnd }
    }

    static func isSpan(daysFromStart: Int?, totalDays: Int?) -> Bool {
        guard let daysFromStart, let totalDays else { return false }
        return totalDays > 1 && daysFromStart >= 1
    }

    /// The lanes of every tile in a month grid (seven tiles per row, in order). A tile's
    /// array stops at its last used lane; `nil` keeps an empty lane above a used one.
    ///
    /// Within a row, segments take lanes greedily: earlier start first, then the longer
    /// schedule, then the order they are listed in; each takes the lowest lane free on all
    /// of its days.
    static func layout<Item, ID: Hashable>(
        _ days: [[Item]],
        id: (Item) -> ID,
        daysFromStart: (Item) -> Int?,
        totalDays: (Item) -> Int?
    ) -> [[Placement<Item>?]] {
        var result = Array(repeating: [Placement<Item>?](), count: days.count)
        for rowStart in stride(from: 0, to: days.count, by: 7) {
            var runs: [SpanRun<Item>] = []
            var runIndex: [ID: Int] = [:]
            for column in 0..<min(7, days.count - rowStart) {
                for item in days[rowStart + column] {
                    guard let day = daysFromStart(item), let total = totalDays(item),
                          isSpan(daysFromStart: day, totalDays: total) else { continue }
                    if let index = runIndex[id(item)] {
                        runs[index].lastColumn = column
                        runs[index].lastDay = day
                    } else {
                        runIndex[id(item)] = runs.count
                        runs.append(SpanRun(item: item, order: runs.count, firstColumn: column, lastColumn: column,
                                            firstDay: day, lastDay: day, totalDays: total))
                    }
                }
            }
            let ordered = runs.sorted { lhs, rhs in
                if lhs.startColumn != rhs.startColumn { return lhs.startColumn < rhs.startColumn }
                if lhs.totalDays != rhs.totalDays { return lhs.totalDays > rhs.totalDays }
                return lhs.order < rhs.order
            }
            var occupied: [[Bool]] = []
            for run in ordered {
                let columns = run.firstColumn...run.lastColumn
                let lane = occupied.firstIndex { lane in !columns.contains { lane[$0] } } ?? occupied.count
                if lane == occupied.count { occupied.append(Array(repeating: false, count: 7)) }
                columns.forEach { occupied[lane][$0] = true }
                let placement = Placement(
                    item: run.item,
                    lane: lane,
                    columns: columns,
                    isTrueStart: run.firstDay == 1,
                    isTrueEnd: run.lastDay == run.totalDays
                )
                for column in columns {
                    var lanes = result[rowStart + column]
                    while lanes.count <= lane { lanes.append(nil) }
                    lanes[lane] = placement
                    result[rowStart + column] = lanes
                }
            }
        }
        return result
    }

    /// Whether the tile in `column` draws a ribbon (it holds a segment's first day).
    static func startsRibbon<Item>(_ lanes: [Placement<Item>?], column: Int) -> Bool {
        lanes.contains { $0?.columns.lowerBound == column }
    }
}

nonisolated private struct SpanRun<Item> {
    let item: Item
    let order: Int
    let firstColumn: Int
    var lastColumn: Int
    let firstDay: Int
    var lastDay: Int
    let totalDays: Int

    /// The column the schedule started in, before this row for a continuing schedule.
    var startColumn: Int { firstColumn - (firstDay - 1) }
}

/// Measurements and the horizontal reach of a ribbon segment.
nonisolated enum DPCalendarSpanRibbon {
    static let height: CGFloat = 16
    static let laneGap: CGFloat = 2
    /// A true start or end stands this far in from its tile's edge.
    static let edgeInset: CGFloat = 2
    static let cornerRadius: CGFloat = 4
    static let strokeWidth: CGFloat = 1
    /// A barely-there shadow that lifts the band off its tiles.
    static let shadowOpacity = 0.14
    static let shadowRadius: CGFloat = 1
    static let shadowY: CGFloat = 1

    /// Where the segment's ribbon sits relative to the lane slot of its first tile. The slot
    /// lies inside the tile's horizontal padding; the ribbon bridges the gutters between the
    /// tiles it covers, and a row break runs square to the tile (and row) edge.
    static func extent(
        slotWidth: CGFloat,
        columnCount: Int,
        isTrueStart: Bool,
        isTrueEnd: Bool
    ) -> (x: CGFloat, width: CGFloat) {
        let padding = DPCalendarCellStyle.cellHorizontalPadding
        let tileWidth = slotWidth + padding * 2
        let leading = isTrueStart ? -(padding - edgeInset) : -padding
        let trailing = CGFloat(max(columnCount - 1, 0)) * (tileWidth + DPCalendarCellStyle.gutterWidth)
            + slotWidth + (isTrueEnd ? padding - edgeInset : padding)
        return (leading, trailing - leading)
    }

    /// Where a segment's first lane slot lies, seen from the slot of the tile
    /// `columnsFromStart` columns into the segment.
    static func segmentOrigin(slotWidth: CGFloat, columnsFromStart: Int) -> CGFloat {
        let tileWidth = slotWidth + DPCalendarCellStyle.cellHorizontalPadding * 2
        return -CGFloat(columnsFromStart) * (tileWidth + DPCalendarCellStyle.gutterWidth)
    }

    /// The horizontal stretch of a ribbon that today's lifted tile redraws.
    struct TodaySlice: Equatable {
        let minX: CGFloat
        let maxX: CGFloat
    }

    /// An earlier tile's ribbon runs on beside today, so only its stretch over the card is
    /// redrawn. A ribbon starting today runs on over the next days, but stops at a card
    /// that stands off the grid's edge.
    static func todaySlice(card: CGRect, startsHere: Bool, lift: DPCalendarTodayLift.Placement) -> TodaySlice {
        TodaySlice(
            minX: startsHere && lift.shift.width <= 0 ? -.infinity : card.minX,
            maxX: startsHere && lift.shift.width >= 0 ? .infinity : card.maxX
        )
    }

    /// The stretch of a band each covered day owns, in the band's own coordinates: its
    /// tile and half of the gutter on either side, so the band changes colour in the
    /// middle of a gutter, under the centre of that gutter's divider.
    static func daySpans(
        bandWidth: CGFloat,
        columnCount: Int,
        isTrueStart: Bool,
        isTrueEnd: Bool
    ) -> [Range<CGFloat>] {
        guard columnCount > 0 else { return [] }
        let gutter = DPCalendarCellStyle.gutterWidth
        let splits = gutterStarts(bandWidth: bandWidth, columnCount: columnCount, isTrueStart: isTrueStart, isTrueEnd: isTrueEnd)
            .map { $0 + gutter / 2 }
        // A band not yet measured is narrower than its gutters; its spans collapse to empty
        // rather than form inverted ranges.
        let width = max(0, bandWidth)
        let edges = [0] + splits.map { min(max($0, 0), width) } + [width]
        return (0..<columnCount).map { edges[$0]..<max(edges[$0], edges[$0 + 1]) }
    }

    /// The gutters between the tiles a band covers, in the band's own coordinates: where it
    /// draws a divider, so the gutter line above and below the band runs on through it.
    static func gutters(
        bandWidth: CGFloat,
        columnCount: Int,
        isTrueStart: Bool,
        isTrueEnd: Bool
    ) -> [Range<CGFloat>] {
        let width = max(0, bandWidth)
        return gutterStarts(bandWidth: bandWidth, columnCount: columnCount, isTrueStart: isTrueStart, isTrueEnd: isTrueEnd)
            .map { start in
                let lower = min(max(start, 0), width)
                return lower..<min(max(start + DPCalendarCellStyle.gutterWidth, lower), width)
            }
    }

    private static func gutterStarts(
        bandWidth: CGFloat,
        columnCount: Int,
        isTrueStart: Bool,
        isTrueEnd: Bool
    ) -> [CGFloat] {
        guard columnCount > 1 else { return [] }
        let gutter = DPCalendarCellStyle.gutterWidth
        let leading = isTrueStart ? edgeInset : 0
        let insets = leading + (isTrueEnd ? edgeInset : 0)
        let tileWidth = (bandWidth + insets - CGFloat(columnCount - 1) * gutter) / CGFloat(columnCount)
        return (1..<columnCount).map { CGFloat($0) * (tileWidth + gutter) - gutter - leading }
    }
}

/// The fill of one day a ribbon covers.
nonisolated struct DPCalendarSpanRibbonDay: Equatable {
    let dutyColor: String?
    let isCurrentMonth: Bool

    /// The days of the week row that holds `index` in a month grid of seven-day rows.
    static func week(containing index: Int, in days: [DPCalendarSpanRibbonDay]) -> [DPCalendarSpanRibbonDay] {
        let start = index - index % 7
        return Array(days[start..<min(start + 7, days.count)])
    }
}

/// A tile's ribbon lanes, drawn first under its date number. Only a segment's first tile
/// draws the ribbon, reaching over the rest of the segment; the other tiles keep the lane
/// empty. The ribbon takes no touches, so a tap opens the day under the finger.
///
/// Today's lifted tile sits above every other tile, so it also draws its own stretch of a
/// ribbon that crosses it, and keeps every ribbon it draws out of its lift: the ribbon
/// stays where the unlifted grid puts it, straight and whole across today.
struct DPCalendarSpanLaneStack<Item, Ribbon: View>: View {
    let lanes: [DPCalendarSpanLanes.Placement<Item>?]
    let column: Int
    @ViewBuilder let ribbon: (DPCalendarSpanLanes.Placement<Item>) -> Ribbon
    @Environment(\.dpCalendarTodayLift) private var lift

    var body: some View {
        if !lanes.isEmpty {
            VStack(alignment: .leading, spacing: DPCalendarSpanRibbon.laneGap) {
                ForEach(lanes.indices, id: \.self) { lane in
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: DPCalendarSpanRibbon.height)
                        .overlay(alignment: .topLeading) {
                            if let lift, let placement = lanes[lane] {
                                GeometryReader { proxy in
                                    liftedRibbon(placement, lift: lift, in: proxy)
                                }
                                .allowsHitTesting(false)
                            } else if let placement = lanes[lane], placement.columns.lowerBound == column {
                                GeometryReader { proxy in
                                    let extent = DPCalendarSpanRibbon.extent(
                                        slotWidth: proxy.size.width,
                                        columnCount: placement.columns.count,
                                        isTrueStart: placement.isTrueStart,
                                        isTrueEnd: placement.isTrueEnd
                                    )
                                    ribbon(placement)
                                        .frame(width: extent.width, height: DPCalendarSpanRibbon.height)
                                        .offset(x: extent.x)
                                }
                                .allowsHitTesting(false)
                            }
                        }
                }
            }
            .padding(.bottom, DPCalendarSpanRibbon.laneGap)
        }
    }

    /// The ribbon drawn by today's tile, in its lane slot's coordinates: the whole segment
    /// placed from its first tile, cut to today's card, then moved and scaled back by the lift so it lands where the unlifted grid draws it.
    private func liftedRibbon(
        _ placement: DPCalendarSpanLanes.Placement<Item>,
        lift: DPCalendarTodayLift.Placement,
        in proxy: GeometryProxy
    ) -> some View {
        let slot = proxy.size
        let tile = proxy.bounds(of: .named(DPCalendarTodayLift.tileSpace)) ?? CGRect(origin: .zero, size: slot)
        let anchor = lift.anchor
        let pivot = CGPoint(x: tile.minX + tile.width * anchor.x, y: tile.minY + tile.height * anchor.y)
        let card = DPCalendarTodayLift.liftedFrame(tile, placement: lift)
        let startsHere = placement.columns.lowerBound == column
        let extent = DPCalendarSpanRibbon.extent(
            slotWidth: slot.width,
            columnCount: placement.columns.count,
            isTrueStart: placement.isTrueStart,
            isTrueEnd: placement.isTrueEnd
        )
        let origin = DPCalendarSpanRibbon.segmentOrigin(
            slotWidth: slot.width,
            columnsFromStart: column - placement.columns.lowerBound
        )
        return ribbon(placement)
            .frame(width: extent.width, height: DPCalendarSpanRibbon.height)
            .offset(x: origin + extent.x)
            .frame(width: slot.width, height: slot.height, alignment: .topLeading)
            .clipShape(DPCalendarRibbonSlice(
                slice: DPCalendarSpanRibbon.todaySlice(card: card, startsHere: startsHere, lift: lift)
            ))
            .offset(x: -lift.shift.width, y: -lift.shift.height)
            .scaleEffect(
                1 / DPCalendarTodayLift.scale,
                anchor: UnitPoint(x: pivot.x / max(slot.width, 1), y: pivot.y / max(slot.height, 1))
            )
    }
}

/// A vertical band of the plane between two x positions, unbounded above and below.
private struct DPCalendarRibbonSlice: Shape {
    let slice: DPCalendarSpanRibbon.TodaySlice

    nonisolated func path(in rect: CGRect) -> Path {
        let reach: CGFloat = 100_000
        let lower = max(slice.minX, -reach)
        let upper = min(slice.maxX, reach)
        return Path(CGRect(x: lower, y: -reach, width: max(upper - lower, 0), height: reach * 2))
    }
}

/// The S2 "soft glass" a ribbon is drawn in, day by day over the tiles it covers: white,
/// brighter on a light duty fill and fainter on a dark fill or an empty tile in dark mode,
/// so the ribbon reads as part of the tile rather than a bar laid over it. White would
/// vanish on the white card, so an empty tile in the light theme takes a tint of its ink.
/// Light-theme dividers carry the grid gutter through each day's glass.
nonisolated enum DPCalendarSpanRibbonGlass: Equatable {
    case light
    case dark
    case tinted

    init(tone: DPCalendarCellStyle.Tone, isDarkTheme: Bool) {
        switch tone {
        case .onLight: self = .light
        case .onDark: self = .dark
        case .theme: self = isDarkTheme ? .dark : .tinted
        }
    }

    var fillOpacity: Double {
        switch self {
        case .light: 0.45
        case .dark: 0.10
        case .tinted: 0.06
        }
    }

    var strokeOpacity: Double {
        switch self {
        case .light: 0.32
        case .dark: 0.36
        case .tinted: 0.24
        }
    }

    var dividerOpacity: Double {
        switch self {
        case .light: 0.16
        case .dark: 0.20
        case .tinted: 0.12
        }
    }

    /// A day's stretch of the band: the glass composited over that day's own fill. It is
    /// opaque, so the gutters under the band do not show through as lines.
    static func bandColor(dutyColor: String?, isCurrentMonth: Bool) -> Color {
        let tile = DPCalendarCellStyle.cellBackground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
        return dynamicColor(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth) { glass, tint, traits in
            let under = components(tile, traits)
            let amount = glass.fillOpacity
            return UIColor(
                red: under[0] * (1 - amount) + tint[0] * amount,
                green: under[1] * (1 - amount) + tint[1] * amount,
                blue: under[2] * (1 - amount) + tint[2] * amount,
                alpha: 1
            )
        }
    }

    /// The outline along a day's stretch of the band.
    static func strokeColor(dutyColor: String?, isCurrentMonth: Bool) -> Color {
        inkTint(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth) { $0.strokeOpacity }
    }

    /// The divider over a gutter, on the side of it that lies over this day.
    static func dividerColor(dutyColor: String?, isCurrentMonth: Bool) -> Color {
        let ink = DPCalendarCellStyle.primaryForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
        return dynamicColor(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth) { glass, tint, traits in
            if traits.userInterfaceStyle == .dark {
                let rgb = components(ink, traits)
                return UIColor(red: rgb[0], green: rgb[1], blue: rgb[2], alpha: glass.dividerOpacity)
            }
            let gutter = components(DPCalendarCellStyle.gutterColor, traits)
            let amount = glass.fillOpacity
            return UIColor(
                red: gutter[0] * (1 - amount) + tint[0] * amount,
                green: gutter[1] * (1 - amount) + tint[1] * amount,
                blue: gutter[2] * (1 - amount) + tint[2] * amount,
                alpha: 1
            )
        }
    }

    /// The day's ink at the glass's opacity. The ink's own alpha (a faded outside-month
    /// ink) is dropped so the opacity is not compounded.
    private static func inkTint(
        dutyColor: String?,
        isCurrentMonth: Bool,
        _ opacity: @escaping @Sendable (DPCalendarSpanRibbonGlass) -> Double
    ) -> Color {
        let tone = DPCalendarCellStyle.tone(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
        let ink = DPCalendarCellStyle.primaryForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
        return Color(uiColor: UIColor { traits in
            let glass = DPCalendarSpanRibbonGlass(tone: tone, isDarkTheme: traits.userInterfaceStyle == .dark)
            let rgb = components(ink, traits)
            return UIColor(red: rgb[0], green: rgb[1], blue: rgb[2], alpha: opacity(glass))
        })
    }

    private static func dynamicColor(
        dutyColor: String?,
        isCurrentMonth: Bool,
        _ make: @escaping @Sendable (DPCalendarSpanRibbonGlass, [CGFloat], UITraitCollection) -> UIColor
    ) -> Color {
        let tone = DPCalendarCellStyle.tone(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
        let ink = DPCalendarCellStyle.primaryForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
        return Color(uiColor: UIColor { traits in
            let glass = DPCalendarSpanRibbonGlass(tone: tone, isDarkTheme: traits.userInterfaceStyle == .dark)
            let tint = glass == .tinted ? components(ink, traits) : [1, 1, 1]
            return make(glass, tint, traits)
        })
    }

    private static func components(_ color: Color, _ traits: UITraitCollection) -> [CGFloat] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: nil)
        return [red, green, blue]
    }
}

nonisolated extension DPCalendarSpanRibbon {
    /// The coordinate space of a whole band, the one `daySpans` measures in.
    static let bandSpace = "DPCalendarSpanRibbonBand"

    static func ink(for day: DPCalendarSpanRibbonDay) -> Color {
        DPCalendarCellStyle.primaryForeground(dutyColor: day.dutyColor, isCurrentMonth: day.isCurrentMonth)
    }

    /// The title is inked for the day the band starts in; the end time and chevron at the
    /// trailing end for the last day, the one under them. Each tag item takes the day under
    /// its own centre instead (`dayIndex(atX:in:)`).
    static func inks(for days: [DPCalendarSpanRibbonDay]) -> (title: Color, trailing: Color) {
        let fallback = DPCalendarSpanRibbonDay(dutyColor: nil, isCurrentMonth: true)
        return (ink(for: days.first ?? fallback), ink(for: days.last ?? fallback))
    }

    /// The day, of the spans `daySpans` gives, under a point of the band; a point beyond
    /// either end belongs to the day at that end.
    static func dayIndex(atX x: CGFloat, in spans: [Range<CGFloat>]) -> Int? {
        guard let first = spans.first else { return nil }
        if let index = spans.firstIndex(where: { $0.contains(x) }) { return index }
        return x < first.lowerBound ? 0 : spans.count - 1
    }
}

/// How a ribbon shows its tagged members, from the richest presentation to none. The
/// ribbon draws the first level that fits beside its title and chevron; the day detail
/// still lists every tag.
nonisolated enum DPCalendarSpanTagFit {
    enum Level: Equatable {
        /// The first `shown` members as name chips, then a `+more` pill.
        case chips(shown: Int, more: Int, abbreviated: Bool = false)
        /// The first `shown` members as overlapping avatars, then a `+more` pill.
        case avatars(shown: Int, more: Int)
        /// One pill: the first member's avatar, then `+more` for the others.
        case compact(more: Int)
        /// The first member's avatar alone, with a small `+more` badge on its corner when
        /// there are others. A tagged ribbon falls back to it however narrow it is, unless
        /// the band can't hold it at all.
        case lone(more: Int)
        case none
    }

    /// More name chips than this never fit in a phone's week row; offering them would only
    /// add candidates for the ribbon to build and measure.
    static let maximumChips = 4
    static let maximumStackedAvatars = 2
    static let avatarDiameter: CGFloat = 10
    static let ringWidth: CGFloat = 1.5
    /// How far `.lone`'s badge reaches past the avatar's trailing edge; the rest of the
    /// badge sits over the avatar.
    static let loneBadgeOverhang: CGFloat = 6

    /// The width of `.lone`: a ringed avatar, plus its badge's overhang when there are
    /// other members.
    static func loneWidth(tagCount: Int) -> CGFloat {
        guard tagCount > 0 else { return 0 }
        return avatarDiameter + 2 * ringWidth + (tagCount > 1 ? loneBadgeOverhang : 0)
    }

    static func levels(tagCount: Int) -> [Level] {
        guard tagCount > 0 else { return [] }
        let chips = (1...min(tagCount, maximumChips)).reversed().map { Level.chips(shown: $0, more: tagCount - $0) }
        let avatars = (1...min(tagCount, maximumStackedAvatars)).reversed()
            .map { Level.avatars(shown: $0, more: tagCount - $0) }
        return chips + avatars + [.compact(more: tagCount - 1), .lone(more: tagCount - 1), .none]
    }

    /// `levels(tagCount:)` with each chip count also tried with initials, right after its
    /// full names, whenever one of the chips shown has initials (`initials[i]` belongs to
    /// tag `i`). Fewer chips are offered only once the initials do not fit either.
    static func levels(tagCount: Int, initials: [String?]) -> [Level] {
        levels(tagCount: tagCount).flatMap { level -> [Level] in
            guard case let .chips(shown, more, _) = level,
                  initials.prefix(shown).contains(where: { $0 != nil })
            else { return [level] }
            return [level, .chips(shown: shown, more: more, abbreviated: true)]
        }
    }
}

/// The widths of a ribbon's row. Times show only when the whole title, and a tagged
/// ribbon's lone avatar, fit beside them; the tags then take what is left, never cutting
/// the title below its floor, and the title ellipsizes into the rest. When no tag level
/// fits at the floor, a tagged ribbon still keeps its lone avatar and the title gives way.
nonisolated struct DPCalendarSpanRibbonRowPlan: Equatable {
    static let gap: CGFloat = 3

    let showsTimes: Bool
    let titleWidth: CGFloat
    let tagsWidth: CGFloat

    /// `start`, `end` and `chevron` include their leading gaps; `tagsFitting` gives the width
    /// the tags draw in when offered a width, and `lone` the width of the avatar a tagged
    /// ribbon always keeps (0 when untagged).
    init(
        width: CGFloat,
        title: CGFloat,
        floor: CGFloat,
        start: CGFloat,
        end: CGFloat,
        chevron: CGFloat,
        lone: CGFloat = 0,
        tagsFitting: (CGFloat) -> CGFloat
    ) {
        let withTimes = title + start + Self.gap + end + chevron
        showsTimes = withTimes + lone <= width
        if showsTimes {
            let offered = width - withTimes
            tagsWidth = min(offered, tagsFitting(offered))
            titleWidth = title
            return
        }
        let floor = min(title, floor)
        let offered = max(0, width - floor - Self.gap - chevron)
        let fitted = min(offered, tagsFitting(offered))
        if fitted > 0 || lone == 0 || lone + chevron > width {
            tagsWidth = fitted
            titleWidth = max(floor, min(title, width - Self.gap - tagsWidth - chevron))
        } else {
            // The avatar wins: the title gives up its floor, down to its ellipsis.
            tagsWidth = lone
            titleWidth = max(0, min(title, width - Self.gap - lone - chevron))
        }
    }
}

/// One week-row segment of a multi-day schedule: a soft-glass band, each day of it the glass
/// over that day's fill, outlined in that day's ink with a faint divider over each gutter it
/// bridges, carrying the title once, the true start and end times it holds,
/// the schedule's tags and a chevron when the schedule continues into the next row.
///
/// Times are left out when they would cut the title short. The tags take what is left
/// once the title keeps about two characters and the chevron its place, at the richest
/// level that fits; the title then ellipsizes into the rest. A tagged ribbon too narrow
/// for that keeps the first member's avatar and squeezes the title instead.
struct DPCalendarSpanRibbonBand<Title: View>: View {
    let isTrueStart: Bool
    let isTrueEnd: Bool
    let times: CalendarSpanSegmentTimes
    /// The days the segment covers, in order.
    let days: [DPCalendarSpanRibbonDay]
    var tags: [DPMemberTagItem] = []
    /// Width drawn before the title text, such as a badge, that the title's floor keeps too.
    var titleFloorLeading: CGFloat = 0
    @ViewBuilder let title: () -> Title

    @State private var bandWidth: CGFloat = 0

    var body: some View {
        let radius = DPCalendarSpanRibbon.cornerRadius
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: isTrueStart ? radius : 0,
            bottomLeadingRadius: isTrueStart ? radius : 0,
            bottomTrailingRadius: isTrueEnd ? radius : 0,
            topTrailingRadius: isTrueEnd ? radius : 0
        )
        let inks = DPCalendarSpanRibbon.inks(for: days)
        DPCalendarSpanRibbonRow(
            titleFloorLeading: titleFloorLeading,
            lone: DPCalendarSpanTagFit.loneWidth(tagCount: tags.count)
        ) {
            titleStyle(title(), ink: inks.title)
                .layoutValue(key: DPCalendarSpanRibbonPart.self, value: .title)
            titleStyle(Text(verbatim: "가나…"), ink: inks.title)
                .hidden()
                .layoutValue(key: DPCalendarSpanRibbonPart.self, value: .titleFloor)
            if let start = times.start {
                time(start, ink: inks.title)
                    .layoutValue(key: DPCalendarSpanRibbonPart.self, value: .startTime)
            }
            if !tags.isEmpty {
                ViewThatFits(in: .horizontal) {
                    ForEach(Array(tagLevels.enumerated()), id: \.offset) { _, level in
                        DPCalendarSpanTagCluster(
                            tags: tags,
                            level: level,
                            days: days,
                            spans: daySpans(width: bandWidth).map(\.range)
                        )
                    }
                }
                .layoutValue(key: DPCalendarSpanRibbonPart.self, value: .tags)
            }
            if let end = times.end {
                time(end, ink: inks.trailing)
                    .layoutValue(key: DPCalendarSpanRibbonPart.self, value: .endTime)
            }
            if !isTrueEnd {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(inks.trailing.opacity(0.45))
                    .fixedSize()
                    .padding(.leading, DPCalendarSpanRibbonRowPlan.gap)
                    .layoutValue(key: DPCalendarSpanRibbonPart.self, value: .chevron)
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .coordinateSpace(.named(DPCalendarSpanRibbon.bandSpace))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { bandWidth = $0 }
        .clipShape(shape)
        .background {
            GeometryReader { proxy in
                ForEach(Array(daySpans(width: proxy.size.width).enumerated()), id: \.offset) { _, span in
                    DPCalendarSpanRibbonGlass.bandColor(dutyColor: span.day.dutyColor, isCurrentMonth: span.day.isCurrentMonth)
                        .frame(width: span.range.upperBound - span.range.lowerBound, height: proxy.size.height)
                        .offset(x: span.range.lowerBound)
                }
                ForEach(Array(dividers(width: proxy.size.width).enumerated()), id: \.offset) { _, half in
                    DPCalendarSpanRibbonGlass.dividerColor(dutyColor: half.day.dutyColor, isCurrentMonth: half.day.isCurrentMonth)
                        .frame(
                            width: half.range.upperBound - half.range.lowerBound,
                            height: max(0, proxy.size.height - 2 * DPCalendarSpanRibbon.strokeWidth)
                        )
                        .offset(x: half.range.lowerBound, y: DPCalendarSpanRibbon.strokeWidth)
                }
            }
            .clipShape(shape)
            .compositingGroup()
            .shadow(
                color: .black.opacity(DPCalendarSpanRibbon.shadowOpacity),
                radius: DPCalendarSpanRibbon.shadowRadius,
                y: DPCalendarSpanRibbon.shadowY
            )
        }
        .overlay {
            GeometryReader { proxy in
                ForEach(Array(daySpans(width: proxy.size.width).enumerated()), id: \.offset) { _, span in
                    shape
                        .strokeBorder(
                            DPCalendarSpanRibbonGlass.strokeColor(dutyColor: span.day.dutyColor, isCurrentMonth: span.day.isCurrentMonth),
                            lineWidth: DPCalendarSpanRibbon.strokeWidth
                        )
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: span.range.upperBound - span.range.lowerBound)
                                .offset(x: span.range.lowerBound)
                        }
                }
            }
        }
    }

    private var tagLevels: [DPCalendarSpanTagFit.Level] {
        DPCalendarSpanTagFit.levels(
            tagCount: tags.count,
            initials: tags.prefix(DPCalendarSpanTagFit.maximumChips).map { MemberNameInitials.initials(for: $0.name) }
        )
    }

    private func daySpans(width: CGFloat) -> [(day: DPCalendarSpanRibbonDay, range: Range<CGFloat>)] {
        let ranges = DPCalendarSpanRibbon.daySpans(
            bandWidth: width,
            columnCount: days.count,
            isTrueStart: isTrueStart,
            isTrueEnd: isTrueEnd
        )
        return zip(days, ranges).map { ($0, $1) }
    }

    /// Each gutter's divider in two halves, split at the band's colour seam, each tinted for
    /// the day under it.
    private func dividers(width: CGFloat) -> [(day: DPCalendarSpanRibbonDay, range: Range<CGFloat>)] {
        let seams = daySpans(width: width).map(\.range.upperBound)
        let gutters = DPCalendarSpanRibbon.gutters(
            bandWidth: width,
            columnCount: days.count,
            isTrueStart: isTrueStart,
            isTrueEnd: isTrueEnd
        )
        return gutters.enumerated().flatMap { index, gutter -> [(day: DPCalendarSpanRibbonDay, range: Range<CGFloat>)] in
            guard days.indices.contains(index + 1), seams.indices.contains(index) else { return [] }
            let seam = min(max(seams[index], gutter.lowerBound), gutter.upperBound)
            return [(days[index], gutter.lowerBound..<seam), (days[index + 1], seam..<gutter.upperBound)]
        }
    }

    private func titleStyle(_ content: some View, ink: Color) -> some View {
        content
            .font(DPFont.bold(size: CalendarTypography.cellContent, relativeTo: .caption2))
            .tracking(-0.3)
            .foregroundStyle(ink)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    /// A time the row can fold away to nothing when it would cut the title short.
    private func time(_ text: String, ink: Color) -> some View {
        DPCalendarSpanFoldable {
            Text(verbatim: text)
                .font(DPFont.bold(size: DPCalendarScheduleTime.fontSize, relativeTo: .caption2).monospacedDigit())
                .tracking(DPCalendarScheduleTime.tracking)
                .foregroundStyle(ink.opacity(0.62))
                .lineLimit(1)
                .fixedSize()
                .padding(.leading, DPCalendarSpanRibbonRowPlan.gap)
        }
        .clipped()
    }
}

nonisolated private enum DPCalendarSpanRibbonPart: LayoutValueKey {
    case title
    /// The hidden text whose width the title never gives up to the tags.
    case titleFloor
    case startTime
    case tags
    case endTime
    case chevron

    static let defaultValue = DPCalendarSpanRibbonPart.title
}

/// Lays out a ribbon's row in one pass, as `DPCalendarSpanRibbonRowPlan` decides: the title
/// and start time from the leading edge, the tags, end time and chevron against the
/// trailing edge. Folded times and the floor text get no width.
private struct DPCalendarSpanRibbonRow: Layout {
    let titleFloorLeading: CGFloat
    /// The width of the tags' lone level; 0 when untagged.
    let lone: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        let ideal = plan(width: .infinity, subviews: subviews)
        let idealWidth = ideal.titleWidth + width(.startTime, subviews) + DPCalendarSpanRibbonRowPlan.gap
            + width(.endTime, subviews) + width(.chevron, subviews)
        return CGSize(width: proposal.width ?? idealWidth, height: proposal.height ?? height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = plan(width: bounds.width, subviews: subviews)
        var leading = bounds.minX
        var trailing = bounds.maxX
        func place(_ subview: LayoutSubview, width: CGFloat, at x: CGFloat) {
            subview.place(
                at: CGPoint(x: x, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
        }
        for part in [DPCalendarSpanRibbonPart.title, .titleFloor, .startTime] {
            for subview in subviews where subview[DPCalendarSpanRibbonPart.self] == part {
                let width = switch part {
                case .title: plan.titleWidth
                case .startTime: plan.showsTimes ? subview.sizeThatFits(.unspecified).width : 0
                default: CGFloat(0)
                }
                place(subview, width: width, at: leading)
                leading += width
            }
        }
        for part in [DPCalendarSpanRibbonPart.chevron, .endTime, .tags] {
            for subview in subviews where subview[DPCalendarSpanRibbonPart.self] == part {
                let width = switch part {
                case .tags: plan.tagsWidth
                case .endTime: plan.showsTimes ? subview.sizeThatFits(.unspecified).width : 0
                default: subview.sizeThatFits(.unspecified).width
                }
                trailing -= width
                place(subview, width: width, at: trailing)
            }
        }
    }

    private func plan(width: CGFloat, subviews: Subviews) -> DPCalendarSpanRibbonRowPlan {
        let tags = subviews.first { $0[DPCalendarSpanRibbonPart.self] == .tags }
        return DPCalendarSpanRibbonRowPlan(
            width: width,
            title: self.width(.title, subviews),
            floor: self.width(.titleFloor, subviews) + titleFloorLeading,
            start: self.width(.startTime, subviews),
            end: self.width(.endTime, subviews),
            chevron: self.width(.chevron, subviews),
            lone: lone,
            tagsFitting: { offered in
                guard let tags, offered.isFinite else { return 0 }
                return tags.sizeThatFits(ProposedViewSize(width: offered, height: nil)).width
            }
        )
    }

    private func width(_ part: DPCalendarSpanRibbonPart, _ subviews: Subviews) -> CGFloat {
        subviews.first { $0[DPCalendarSpanRibbonPart.self] == part }?.sizeThatFits(.unspecified).width ?? 0
    }
}

/// Draws its content at its own size but takes no more width than it is offered, so a
/// clipped one offered nothing disappears.
private struct DPCalendarSpanFoldable: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = subviews[0].sizeThatFits(.unspecified)
        return CGSize(width: min(proposal.width ?? ideal.width, ideal.width), height: ideal.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: .unspecified)
    }
}

/// One level of a ribbon's tags, at the month cell's scale. A cluster can run over several
/// days, so each item is inked and ringed for the day under it.
private struct DPCalendarSpanTagCluster: View {
    let tags: [DPMemberTagItem]
    let level: DPCalendarSpanTagFit.Level
    let days: [DPCalendarSpanRibbonDay]
    /// The band's day spans, in the band's coordinate space.
    let spans: [Range<CGFloat>]

    private static let height: CGFloat = 13
    private static let avatarDiameter = DPCalendarSpanTagFit.avatarDiameter
    private static let ringWidth = DPCalendarSpanTagFit.ringWidth
    private static let compactAvatarDiameter: CGFloat = 9

    var body: some View {
        switch level {
        case let .chips(shown, more, abbreviated):
            HStack(spacing: 2) {
                ForEach(tags.prefix(shown)) { chip($0, abbreviated: abbreviated) }
                if more > 0 { pill(Text(verbatim: "+\(more)")) }
            }
        case let .avatars(shown, more):
            HStack(spacing: 2) {
                HStack(spacing: -4) {
                    ForEach(tags.prefix(shown)) { ringedAvatar($0) }
                }
                if more > 0 { pill(Text(verbatim: "+\(more)")) }
            }
        case let .compact(more):
            overDay { day in compactPill(tags[0], more: more, ink: DPCalendarSpanRibbon.ink(for: day)) }
        case let .lone(more):
            overDay { day in loneAvatar(tags[0], more: more, day: day) }
        case .none:
            Color.clear.frame(width: 0, height: 0)
        }
    }

    private func overDay(@ViewBuilder _ content: @escaping (DPCalendarSpanRibbonDay) -> some View) -> some View {
        DPCalendarSpanTagItem(days: days, spans: spans, content: content)
    }

    private func chip(_ item: DPMemberTagItem, abbreviated: Bool) -> some View {
        overDay { day in chip(item, abbreviated: abbreviated, ink: DPCalendarSpanRibbon.ink(for: day)) }
    }

    private func chip(_ item: DPMemberTagItem, abbreviated: Bool, ink: Color) -> some View {
        HStack(spacing: 2) {
            DPMemberAvatar(item: item, diameter: Self.avatarDiameter)
            Text(verbatim: abbreviated ? MemberNameInitials.initials(for: item.name) ?? item.name : item.name)
                .font(DPFont.light(size: 8.5, relativeTo: .caption2))
                .foregroundStyle(ink.opacity(0.8))
                .lineLimit(1)
                .accessibilityLabel(Text(verbatim: item.name))
        }
        .padding(.leading, 1.5)
        .padding(.trailing, 4)
        .frame(height: Self.height)
        .sheen(tint: ink.opacity(0.09))
        .fixedSize()
    }

    /// The ring is the band's colour for the day under the avatar, so it separates the
    /// stacked avatars without drawing a line of its own.
    private func ringedAvatar(_ item: DPMemberTagItem) -> some View {
        overDay { day in ringedAvatar(item, day: day) }
    }

    private func ringedAvatar(_ item: DPMemberTagItem, day: DPCalendarSpanRibbonDay) -> some View {
        DPMemberAvatar(item: item, diameter: Self.avatarDiameter)
            .padding(Self.ringWidth)
            .background {
                Circle().fill(DPCalendarSpanRibbonGlass.bandColor(dutyColor: day.dutyColor, isCurrentMonth: day.isCurrentMonth))
            }
    }

    /// The ringed avatar with a notification-style `+more` badge over its bottom-trailing
    /// corner, overhanging it by `loneBadgeOverhang`. The badge is solid ink lettered and
    /// ringed in the band's colour, so it reads on light and dark fills alike.
    @ViewBuilder
    private func loneAvatar(_ item: DPMemberTagItem, more: Int, day: DPCalendarSpanRibbonDay) -> some View {
        if more > 0 {
            let band = DPCalendarSpanRibbonGlass.bandColor(dutyColor: day.dutyColor, isCurrentMonth: day.isCurrentMonth)
            ringedAvatar(item, day: day)
                .padding(.trailing, DPCalendarSpanTagFit.loneBadgeOverhang)
                .overlay(alignment: .bottomTrailing) {
                    Text(verbatim: "+\(more)")
                        .font(DPFont.bold(size: 6.5, relativeTo: .caption2))
                        .tracking(-0.3)
                        .foregroundStyle(band)
                        .lineLimit(1)
                        .padding(.horizontal, 1)
                        .frame(height: 7.5)
                        .background(DPCalendarSpanRibbon.ink(for: day).opacity(0.85), in: Capsule())
                        .padding(1)
                        .background(band, in: Capsule())
                        .fixedSize()
                        // Down onto the corner, still inside the band's height.
                        .offset(y: 1)
                }
        } else {
            ringedAvatar(item, day: day)
        }
    }

    /// The count pill with the first member's avatar inside it; the avatar alone when
    /// there is no one else, never `+0`.
    private func compactPill(_ item: DPMemberTagItem, more: Int, ink: Color) -> some View {
        HStack(spacing: 1.5) {
            DPMemberAvatar(item: item, diameter: Self.compactAvatarDiameter)
            if more > 0 {
                Text(verbatim: "+\(more)")
                    .font(DPFont.bold(size: 8, relativeTo: .caption2))
                    .foregroundStyle(ink.opacity(0.76))
                    .lineLimit(1)
            }
        }
        .padding(.leading, 2)
        .padding(.trailing, more > 0 ? 3 : 2)
        .frame(height: Self.height)
        .sheen(tint: ink.opacity(0.10))
        .fixedSize()
    }

    private func pill(_ label: Text) -> some View {
        overDay { day in pill(label, ink: DPCalendarSpanRibbon.ink(for: day)) }
    }

    private func pill(_ label: Text, ink: Color) -> some View {
        label
            .font(DPFont.bold(size: 8, relativeTo: .caption2))
            .foregroundStyle(ink.opacity(0.76))
            .lineLimit(1)
            .padding(.horizontal, 3)
            .frame(height: Self.height)
            .sheen(tint: ink.opacity(0.10))
            .fixedSize()
    }
}

/// The web's mini "A" gloss on a ribbon tag: the ink tint stays underneath, a white sheen
/// fades out toward the bottom and a hairline highlight runs along the top. Ribbon tags
/// sit on the band, so they cast no shadow.
nonisolated enum DPCalendarSpanTagSheen {
    static let top = Color(white: 1, opacity: 0.30)
    static let fadeEnd: CGFloat = 0.85
    static let highlight = Color(white: 1, opacity: 0.70)
}

private extension View {
    func sheen(tint: Color) -> some View {
        background {
            Capsule().fill(tint)
            Capsule().fill(LinearGradient(
                stops: [
                    .init(color: DPCalendarSpanTagSheen.top, location: 0),
                    .init(color: DPCalendarSpanTagSheen.top.opacity(0), location: DPCalendarSpanTagSheen.fadeEnd),
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        .overlay {
            Capsule().strokeBorder(
                LinearGradient(
                    colors: [DPCalendarSpanTagSheen.highlight, DPCalendarSpanTagSheen.highlight.opacity(0)],
                    startPoint: .top,
                    endPoint: .center
                ),
                lineWidth: 0.5
            )
        }
    }
}

/// One tag item, drawn for the day of the band under its centre. Until it has been placed
/// it takes the band's last day, where the cluster usually sits.
private struct DPCalendarSpanTagItem<Content: View>: View {
    let days: [DPCalendarSpanRibbonDay]
    let spans: [Range<CGFloat>]
    let content: (DPCalendarSpanRibbonDay) -> Content

    @State private var centre: CGFloat?

    var body: some View {
        content(day)
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .named(DPCalendarSpanRibbon.bandSpace)).midX
            } action: {
                centre = $0
            }
    }

    private var day: DPCalendarSpanRibbonDay {
        let fallback = days.last ?? DPCalendarSpanRibbonDay(dutyColor: nil, isCurrentMonth: true)
        guard let centre, let index = DPCalendarSpanRibbon.dayIndex(atX: centre, in: spans), days.indices.contains(index) else {
            return fallback
        }
        return days[index]
    }
}
