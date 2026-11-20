import CoreGraphics
import Testing
@testable import Dutypark

/// The month calendar's tone-on-tone time chip and the white ribbon that carries a
/// multi-day schedule across its week row.
struct CalendarTimeChipPaletteTests {
    /// The values follow `oklch(from F calc(l - 0.08) calc(c * 1.25) h)` for the background
    /// and `oklch(from F 0.36 calc(c * 1.4) h)` for the text, clamped to sRGB.
    @Test
    func theChipIsTheCellFillDarkenedInOKLCH() throws {
        let teal = try #require(DPCalendarTimeChipPalette.toneOnTone(fillHex: "#A2D9DD"))
        #expect(teal.background.hex == "#7CC2C7")
        #expect(teal.foreground.hex == "#00494F")

        let pink = try #require(DPCalendarTimeChipPalette.toneOnTone(fillHex: "#ecc5ca"))
        #expect(pink.background.hex == "#D8A9AF")
        #expect(pink.foreground.hex == "#592E36")
    }

    @Test
    func everyPaletteFillGivesAReadableChip() throws {
        for option in DutyTypeColorPalette.options {
            let chip = try #require(DPCalendarTimeChipPalette.toneOnTone(fillHex: option.hex), "\(option.name)")
            let contrast = DPCalendarTimeChipPalette.contrastRatio(chip.foreground, chip.background)
            #expect(contrast >= 4.5, "\(option.name) \(contrast)")
        }
    }

    @Test
    func aCellWithoutAReadableToneOnToneChipFallsBackToTheNeutralChip() {
        #expect(DPCalendarTimeChipPalette.toneOnTone(fillHex: nil) == nil, "No duty fill")
        #expect(DPCalendarTimeChipPalette.toneOnTone(fillHex: "not-a-colour") == nil)
        // The fixed text lightness cannot reach 4.5:1 on a dark or saturated mid fill.
        #expect(DPCalendarTimeChipPalette.toneOnTone(fillHex: "#1E3A8A") == nil)
        #expect(DPCalendarTimeChipPalette.toneOnTone(fillHex: "#6C757D") == nil)
    }

    @Test
    func contrastFollowsWCAG() {
        let black = DPCalendarTimeChipPalette.RGB(red: 0, green: 0, blue: 0)
        let white = DPCalendarTimeChipPalette.RGB(red: 1, green: 1, blue: 1)
        #expect(abs(DPCalendarTimeChipPalette.contrastRatio(black, white) - 21) < 0.001)
        #expect(abs(DPCalendarTimeChipPalette.contrastRatio(white, black) - 21) < 0.001)
    }
}

struct CalendarSpanLaneTests {
    private struct Item: Equatable {
        let id: String
        let daysFromStart: Int?
        let totalDays: Int?
    }

    private func item(_ id: String, _ day: Int, of total: Int) -> Item {
        Item(id: id, daysFromStart: day, totalDays: total)
    }

    private func single(_ id: String) -> Item {
        Item(id: id, daysFromStart: 1, totalDays: 1)
    }

    private func layout(_ days: [[Item]]) -> [[DPCalendarSpanLanes.Placement<Item>?]] {
        DPCalendarSpanLanes.layout(days, id: \.id, daysFromStart: \.daysFromStart, totalDays: \.totalDays)
    }

    /// Each cell's lanes as ids, with "-" for an empty spacer lane.
    private func lanes(_ result: [[DPCalendarSpanLanes.Placement<Item>?]]) -> [[String]] {
        result.map { $0.map { $0?.item.id ?? "-" } }
    }

    @Test
    func onlyRealMultiDaySchedulesAreSpans() {
        #expect(DPCalendarSpanLanes.isSpan(daysFromStart: 1, totalDays: 3))
        #expect(!DPCalendarSpanLanes.isSpan(daysFromStart: 1, totalDays: 1))
        #expect(!DPCalendarSpanLanes.isSpan(daysFromStart: nil, totalDays: 3))
        #expect(!DPCalendarSpanLanes.isSpan(daysFromStart: 1, totalDays: nil))
    }

    @Test
    func aSpanInsideOneWeekIsOneSegmentWithBothTrueEnds() throws {
        let result = layout([
            [], [], [item("jeju", 1, of: 3), single("lunch")], [item("jeju", 2, of: 3)], [item("jeju", 3, of: 3)], [], [],
        ])
        #expect(lanes(result) == [[], [], ["jeju"], ["jeju"], ["jeju"], [], []])
        let start = try #require(result[2][0])
        #expect(start.lane == 0)
        #expect(start.columns == 2...4)
        #expect(start.isTrueStart && start.isTrueEnd)
        #expect(!start.continuesIntoNextRow)
        #expect(result[3][0]?.columns == 2...4, "Every day of the segment knows the whole segment")
    }

    @Test
    func aSpanBrokenByTheWeekKeepsSquareContinuingEdges() throws {
        let result = layout([
            [], [], [], [], [], [], [item("trip", 1, of: 4)],
            [item("trip", 2, of: 4)], [item("trip", 3, of: 4)], [item("trip", 4, of: 4)], [], [], [], [],
        ])
        let first = try #require(result[6][0])
        #expect(first.columns == 6...6)
        #expect(first.isTrueStart && !first.isTrueEnd)
        #expect(first.continuesIntoNextRow)
        let second = try #require(result[7][0])
        #expect(second.columns == 0...2)
        #expect(!second.isTrueStart && second.isTrueEnd)
        #expect(!second.continuesIntoNextRow)
    }

    @Test
    func lanesAreAssignedGreedilyEarlierStartThenLongerThenIncomingOrder() {
        // a starts before this week; b and c start on Monday, c is longer;
        // d starts Monday too, as long as b but listed after it.
        let result = layout([
            [item("a", 3, of: 4)],
            [item("a", 4, of: 4), item("b", 1, of: 2), item("d", 1, of: 2), item("c", 1, of: 3)],
            [item("b", 2, of: 2), item("d", 2, of: 2), item("c", 2, of: 3)],
            [item("c", 3, of: 3), item("e", 1, of: 2)],
            [item("e", 2, of: 2)],
            [], [],
        ])
        #expect(lanes(result) == [
            ["a"],
            ["a", "c", "b", "d"],
            ["-", "c", "b", "d"],
            ["e", "c"],
            ["e"],
            [], [],
        ])
    }

    @Test
    func aLaterLaneKeepsSpacersAboveItButNoTrailingSpacers() {
        let result = layout([
            [item("long", 1, of: 3)],
            [item("long", 2, of: 3), item("short", 1, of: 3)],
            [item("long", 3, of: 3), item("short", 2, of: 3)],
            [item("short", 3, of: 3)],
            [single("alone")],
            [], [],
        ])
        #expect(lanes(result) == [["long"], ["long", "short"], ["long", "short"], ["-", "short"], [], [], []])
    }

    @Test
    func singleDayItemsAreLeftToTheCell() {
        let result = layout([[single("x"), Item(id: "y", daysFromStart: nil, totalDays: nil)], [], [], [], [], [], []])
        #expect(lanes(result) == [[], [], [], [], [], [], []])
    }

    /// The ribbon slot sits inside the tile's horizontal padding; a true end is inset from
    /// the tile edge, and a row break runs to the tile (and row) edge. Later tiles of the
    /// segment are bridged across the gutters.
    @Test
    func theRibbonReachesAcrossItsSegment() {
        let padding = DPCalendarCellStyle.cellHorizontalPadding
        let gutter = DPCalendarCellStyle.gutterWidth
        let inset = DPCalendarSpanRibbon.edgeInset
        let slot: CGFloat = 41
        let tile = slot + padding * 2

        let whole = DPCalendarSpanRibbon.extent(slotWidth: slot, columnCount: 3, isTrueStart: true, isTrueEnd: true)
        #expect(whole.x == -(padding - inset))
        #expect(whole.width == 3 * tile + 2 * gutter - 2 * inset)

        let broken = DPCalendarSpanRibbon.extent(slotWidth: slot, columnCount: 1, isTrueStart: false, isTrueEnd: false)
        #expect(broken.x == -padding)
        #expect(broken.width == tile)
    }
}

struct CalendarSpanSegmentTimeTests {
    private func times(_ start: String, _ end: String, holdsStart: Bool, holdsEnd: Bool) -> CalendarSpanSegmentTimes {
        CalendarVisualLogic.spanSegmentTimes(
            start: LocalDateTimeValue(rawValue: start),
            end: LocalDateTimeValue(rawValue: end),
            holdsStart: holdsStart,
            holdsEnd: holdsEnd
        )
    }

    @Test
    func aSegmentShowsTheTimesOfTheTrueEndsItHolds() {
        #expect(times("2026-11-10T14:00:00", "2026-11-12T18:00:00", holdsStart: true, holdsEnd: true)
            == CalendarSpanSegmentTimes(start: "14:00~", end: "~18:00"))
        #expect(times("2026-11-28T14:00:00", "2026-12-01T18:00:00", holdsStart: true, holdsEnd: false)
            == CalendarSpanSegmentTimes(start: "14:00~", end: nil))
        #expect(times("2026-11-28T14:00:00", "2026-12-01T18:00:00", holdsStart: false, holdsEnd: true)
            == CalendarSpanSegmentTimes(start: nil, end: "~18:00"))
        #expect(times("2026-11-28T14:00:00", "2026-12-01T18:00:00", holdsStart: false, holdsEnd: false)
            == CalendarSpanSegmentTimes(start: nil, end: nil))
    }

    @Test
    func midnightIsNoTime() {
        #expect(times("2026-11-10T00:00:00", "2026-11-12T00:00:00", holdsStart: true, holdsEnd: true)
            == CalendarSpanSegmentTimes(start: nil, end: nil))
        #expect(times("2026-11-10T00:00:00", "2026-11-12T09:30:00", holdsStart: true, holdsEnd: true)
            == CalendarSpanSegmentTimes(start: nil, end: "~09:30"))
    }
}
