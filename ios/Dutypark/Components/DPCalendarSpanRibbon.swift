import SwiftUI

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
    static let ink = Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255)

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
}

/// A tile's ribbon lanes, drawn first under its date number. Only a segment's first tile
/// draws the ribbon, reaching over the rest of the segment; the other tiles keep the lane
/// empty. The ribbon takes no touches, so a tap opens the day under the finger.
struct DPCalendarSpanLaneStack<Item, Ribbon: View>: View {
    let lanes: [DPCalendarSpanLanes.Placement<Item>?]
    let column: Int
    @ViewBuilder let ribbon: (DPCalendarSpanLanes.Placement<Item>) -> Ribbon

    var body: some View {
        if !lanes.isEmpty {
            VStack(alignment: .leading, spacing: DPCalendarSpanRibbon.laneGap) {
                ForEach(lanes.indices, id: \.self) { lane in
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: DPCalendarSpanRibbon.height)
                        .overlay(alignment: .topLeading) {
                            if let placement = lanes[lane], placement.columns.lowerBound == column {
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
}

/// One week-row segment of a multi-day schedule: a white ribbon, the same in light and
/// dark, carrying the title once, the true start and end times it holds, and a chevron
/// when the schedule continues into the next row. Times are left out when they would cut
/// the title short.
struct DPCalendarSpanRibbonBand<Title: View>: View {
    let isTrueStart: Bool
    let isTrueEnd: Bool
    let times: CalendarSpanSegmentTimes
    @ViewBuilder let title: () -> Title

    var body: some View {
        let radius = DPCalendarSpanRibbon.cornerRadius
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: isTrueStart ? radius : 0,
            bottomLeadingRadius: isTrueStart ? radius : 0,
            bottomTrailingRadius: isTrueEnd ? radius : 0,
            topTrailingRadius: isTrueEnd ? radius : 0
        )
        ViewThatFits(in: .horizontal) {
            content(showsTimes: true)
            content(showsTimes: false)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .clipShape(shape)
        .background {
            shape.fill(Color.white.opacity(0.84))
                .shadow(color: DPCalendarSpanRibbon.ink.opacity(0.08), radius: 1, y: 1)
        }
        .overlay { shape.strokeBorder(DPCalendarSpanRibbon.ink.opacity(0.14), lineWidth: 1) }
    }

    private func content(showsTimes: Bool) -> some View {
        HStack(spacing: 3) {
            title()
                .font(DPFont.bold(size: CalendarTypography.cellContent, relativeTo: .caption2))
                .tracking(-0.3)
                .foregroundStyle(DPCalendarSpanRibbon.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .fixedSize(horizontal: showsTimes, vertical: false)
            if showsTimes, let start = times.start {
                time(start)
            }
            Spacer(minLength: 0)
            if showsTimes, let end = times.end {
                time(end)
            }
            if !isTrueEnd {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DPCalendarSpanRibbon.ink.opacity(0.5))
                    .accessibilityHidden(true)
            }
        }
    }

    private func time(_ text: String) -> some View {
        Text(verbatim: text)
            .font(DPFont.bold(size: DPCalendarScheduleTime.fontSize, relativeTo: .caption2).monospacedDigit())
            .tracking(DPCalendarScheduleTime.tracking)
            .foregroundStyle(DPCalendarSpanRibbon.ink.opacity(0.62))
            .lineLimit(1)
            .fixedSize()
    }
}
