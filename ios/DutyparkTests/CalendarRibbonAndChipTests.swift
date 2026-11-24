import CoreGraphics
import SwiftUI
import Testing
import UIKit
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

/// The S2 soft-glass ribbon: a translucent white band that takes its tone from the tile it
/// starts in, instead of a near-white bar drawn over every fill.
struct CalendarSpanRibbonGlassTests {
    @Test
    func lightFillsGetTheBrighterGlass() {
        let glass = DPCalendarSpanRibbonGlass(tone: .onLight, isDarkTheme: false)
        #expect(glass == .light)
        #expect(glass.fillOpacity == 0.45)
        #expect(glass.strokeOpacity == 0.32)
        #expect(glass.dividerOpacity == 0.16)
        #expect(DPCalendarSpanRibbonGlass(tone: .onLight, isDarkTheme: true) == .light,
                "A duty fill looks the same in both themes")
    }

    /// White glass would vanish on the white card, so an empty tile in the light theme takes
    /// a faint tint of its ink instead.
    @Test
    func lightThemeEmptyTilesGetAnInkTintedBand() {
        let glass = DPCalendarSpanRibbonGlass(tone: .theme, isDarkTheme: false)
        #expect(glass == .tinted)
        #expect(glass.fillOpacity == 0.06)
        #expect(glass.strokeOpacity == 0.24)
        #expect(glass.dividerOpacity == 0.12)
    }

    @Test
    func darkFillsAndDarkThemeEmptyTilesGetTheFainterGlass() {
        let glass = DPCalendarSpanRibbonGlass(tone: .onDark, isDarkTheme: false)
        #expect(glass == .dark)
        #expect(glass.fillOpacity == 0.10)
        #expect(glass.strokeOpacity == 0.36)
        #expect(glass.dividerOpacity == 0.20)
        #expect(DPCalendarSpanRibbonGlass(tone: .onDark, isDarkTheme: true) == .dark)
        #expect(DPCalendarSpanRibbonGlass(tone: .theme, isDarkTheme: true) == .dark)
    }
}

/// The tags a multi-day ribbon carries, from the richest presentation to none at all; the
/// ribbon draws the first one that fits beside the title and the chevron.
struct CalendarSpanTagFitTests {
    @Test
    func anUntaggedRibbonHasNoTagLevels() {
        #expect(DPCalendarSpanTagFit.levels(tagCount: 0).isEmpty)
    }

    @Test
    func oneTagFallsFromChipToAvatarToCompactToLoneToNothing() {
        #expect(DPCalendarSpanTagFit.levels(tagCount: 1) == [
            .chips(shown: 1, more: 0),
            .avatars(shown: 1, more: 0),
            .compact(more: 0),
            .lone(more: 0),
            .none,
        ])
    }

    /// No more than four name chips fit in a phone's week row, so richer levels are never
    /// offered; that keeps the candidates the ribbon builds from growing with the tag count.
    @Test
    func manyTagsShowAtMostFourChipsThenStackAtMostTwoAvatars() {
        #expect(DPCalendarSpanTagFit.levels(tagCount: 7) == [
            .chips(shown: 4, more: 3),
            .chips(shown: 3, more: 4),
            .chips(shown: 2, more: 5),
            .chips(shown: 1, more: 6),
            .avatars(shown: 2, more: 5),
            .avatars(shown: 1, more: 6),
            .compact(more: 6),
            .lone(more: 6),
            .none,
        ])
    }

    /// The tightest level is one pill: the first member's avatar, then how many others.
    @Test
    func theTightestLevelIsTheFirstAvatarAndTheOthersInOnePill() throws {
        #expect(DPCalendarSpanTagFit.levels(tagCount: 4).suffix(3) == [.compact(more: 3), .lone(more: 3), .none])

        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Components/DPCalendarSpanRibbon.swift")
        let ribbon = try String(contentsOf: url, encoding: .utf8)
        #expect(!ribbon.contains("systemName: \"person\""), "No person symbol any more")
        #expect(!ribbon.contains("case count("))
    }

    /// The lone avatar carries a `+more` badge that overhangs it to the right; a lone tag
    /// has no badge and no overhang.
    @Test
    func theLoneAvatarIsWiderOnlyByItsBadgesOverhang() {
        #expect(DPCalendarSpanTagFit.loneWidth(tagCount: 0) == 0)
        #expect(DPCalendarSpanTagFit.loneWidth(tagCount: 1) == 13)
        #expect(DPCalendarSpanTagFit.loneWidth(tagCount: 2) == 13 + DPCalendarSpanTagFit.loneBadgeOverhang)
        #expect(DPCalendarSpanTagFit.loneWidth(tagCount: 7) == DPCalendarSpanTagFit.loneWidth(tagCount: 2))
        #expect((3...6).contains(DPCalendarSpanTagFit.loneBadgeOverhang), "A few points, so the title keeps what it can")
    }

    @Test
    func aFewTagsAreAllOfferedAsChips() {
        #expect(DPCalendarSpanTagFit.levels(tagCount: 3).prefix(3) == [
            .chips(shown: 3, more: 0),
            .chips(shown: 2, more: 1),
            .chips(shown: 1, more: 2),
        ])
    }
}

/// The band is opaque, one colour per day it covers — that day's fill under the glass — with
/// a faint divider of its own drawn exactly over each gutter it bridges.
struct CalendarSpanRibbonGutterTests {
    @Test
    func eachDayOfTheBandIsItsOwnFillUnderTheGlass() {
        let teal = DPCalendarSpanRibbonGlass.bandColor(dutyColor: "#A2D9DD", isCurrentMonth: true)
        #expect(rgba(teal, .light) == [204, 234, 236, 255], "White 45% over a light fill")
        #expect(rgba(teal, .dark) == [204, 234, 236, 255], "A duty fill looks the same in both themes")

        let navy = DPCalendarSpanRibbonGlass.bandColor(dutyColor: "#1F3A8A", isCurrentMonth: true)
        #expect(rgba(navy, .light) == [53, 78, 150, 255], "White 10% over a dark fill")

        let empty = DPCalendarSpanRibbonGlass.bandColor(dutyColor: nil, isCurrentMonth: true)
        #expect(rgba(empty, .light) == [241, 241, 242, 255], "Ink 6% over the white card")
        #expect(rgba(empty, .dark) == [53, 62, 75, 255], "White 10% over the dark card")
    }

    /// The outline is the day's own ink, so it contrasts with the tile: dark on a light
    /// fill, light on a dark fill, and the theme's text colour on an empty tile.
    @Test
    func eachDayOfTheBandIsOutlinedInItsInk() {
        let teal = DPCalendarSpanRibbonGlass.strokeColor(dutyColor: "#A2D9DD", isCurrentMonth: true)
        #expect(rgba(teal, .light) == [31, 41, 55, 82], "Dark ink 32% on a light fill")
        #expect(rgba(teal, .dark) == [31, 41, 55, 82], "A duty fill looks the same in both themes")
        let fadedTeal = DPCalendarSpanRibbonGlass.strokeColor(dutyColor: "#A2D9DD", isCurrentMonth: false)
        #expect(rgba(fadedTeal, .light) == [31, 41, 55, 82], "The ink's own fade is not compounded")
        let navy = DPCalendarSpanRibbonGlass.strokeColor(dutyColor: "#1F3A8A", isCurrentMonth: true)
        #expect(rgba(navy, .light) == [255, 255, 255, 92], "White 36% on a dark fill")
        let empty = DPCalendarSpanRibbonGlass.strokeColor(dutyColor: nil, isCurrentMonth: true)
        #expect(rgba(empty, .light) == [17, 24, 39, 61], "Ink 24% on the white card")
        #expect(rgba(empty, .dark) == [249, 250, 251, 92], "Light ink 36% on the dark card")
    }

    /// Light-theme dividers carry the grid gutter through the same glass as each day.
    @Test
    func theLightThemeGutterContinuesThroughEachDaysGlass() {
        let teal = DPCalendarSpanRibbonGlass.dividerColor(dutyColor: "#A2D9DD", isCurrentMonth: true)
        #expect(rgba(teal, .light) == [241, 242, 244, 255])
        let navy = DPCalendarSpanRibbonGlass.dividerColor(dutyColor: "#1F3A8A", isCurrentMonth: true)
        #expect(rgba(navy, .light) == [232, 233, 237, 255])
        let empty = DPCalendarSpanRibbonGlass.dividerColor(dutyColor: nil, isCurrentMonth: true)
        #expect(rgba(empty, .light) == [216, 219, 223, 255])
    }

    /// Dark-theme dividers keep a faint stroke of each day's ink over its glass.
    @Test
    func theGutterDividerIsAFaintTintOfTheDaysInk() {
        let teal = DPCalendarSpanRibbonGlass.dividerColor(dutyColor: "#A2D9DD", isCurrentMonth: true)
        #expect(rgba(teal, .dark) == [31, 41, 55, 41], "Dark ink 16% on a light fill")
        let navy = DPCalendarSpanRibbonGlass.dividerColor(dutyColor: "#1F3A8A", isCurrentMonth: true)
        #expect(rgba(navy, .dark) == [255, 255, 255, 51], "White 20% on a dark fill")
        let empty = DPCalendarSpanRibbonGlass.dividerColor(dutyColor: nil, isCurrentMonth: true)
        #expect(rgba(empty, .dark) == [249, 250, 251, 51], "Light ink 20% on the dark card")
    }

    /// The title sits on the day the band starts in; the tags, end time and chevron sit at
    /// its trailing end, on the last day, and take that day's ink.
    @Test
    func theTrailingEndIsInkedForTheDayUnderIt() {
        let days = [
            DPCalendarSpanRibbonDay(dutyColor: "#1F3A8A", isCurrentMonth: true),
            DPCalendarSpanRibbonDay(dutyColor: "#1F3A8A", isCurrentMonth: true),
            DPCalendarSpanRibbonDay(dutyColor: "#A2D9DD", isCurrentMonth: true),
        ]
        let inks = DPCalendarSpanRibbon.inks(for: days)
        let onDark = DPCalendarCellStyle.primaryForeground(dutyColor: "#1F3A8A")
        let onLight = DPCalendarCellStyle.primaryForeground(dutyColor: "#A2D9DD")
        #expect(rgba(onDark, .light) != rgba(onLight, .light))
        #expect(rgba(inks.title, .light) == rgba(onDark, .light))
        #expect(rgba(inks.trailing, .light) == rgba(onLight, .light))
    }

    /// Each day owns its tile and half of each gutter beside it, so the band changes colour
    /// in the middle of a gutter and the gutter itself never shows.
    @Test
    func theBandSplitsAtTheMiddleOfEachGutter() {
        let tile = 41 + DPCalendarCellStyle.cellHorizontalPadding * 2
        let gutter = DPCalendarCellStyle.gutterWidth
        let inset = DPCalendarSpanRibbon.edgeInset
        let width = 3 * tile + 2 * gutter - 2 * inset
        let spans = DPCalendarSpanRibbon.daySpans(bandWidth: width, columnCount: 3, isTrueStart: true, isTrueEnd: true)
        #expect(spans == [0..<(tile + gutter / 2 - inset), (tile + gutter / 2 - inset)..<(2 * tile + gutter * 1.5 - inset), (2 * tile + gutter * 1.5 - inset)..<width])

        let broken = DPCalendarSpanRibbon.daySpans(bandWidth: 2 * tile + gutter, columnCount: 2, isTrueStart: false, isTrueEnd: false)
        #expect(broken == [0..<(tile + gutter / 2), (tile + gutter / 2)..<(2 * tile + gutter)])
    }

    /// A divider covers each gutter between the covered tiles exactly, continuing the gutter
    /// line above and below the band, and the band changes colour at its centre.
    @Test
    func aDividerSitsOnEachGutterWithTheSeamAtItsCentre() {
        let tile = 41 + DPCalendarCellStyle.cellHorizontalPadding * 2
        let gutter = DPCalendarCellStyle.gutterWidth
        let inset = DPCalendarSpanRibbon.edgeInset
        let width = 3 * tile + 2 * gutter - 2 * inset
        let dividers = DPCalendarSpanRibbon.gutters(bandWidth: width, columnCount: 3, isTrueStart: true, isTrueEnd: true)
        #expect(dividers == [(tile - inset)..<(tile + gutter - inset), (2 * tile + gutter - inset)..<(2 * tile + 2 * gutter - inset)])
        let spans = DPCalendarSpanRibbon.daySpans(bandWidth: width, columnCount: 3, isTrueStart: true, isTrueEnd: true)
        #expect(dividers.map { ($0.lowerBound + $0.upperBound) / 2 } == spans.dropLast().map(\.upperBound))

        // Placed at the band's extent, each divider lands on a gutter of the grid.
        let extent = DPCalendarSpanRibbon.extent(slotWidth: 41, columnCount: 3, isTrueStart: true, isTrueEnd: true)
        let padding = DPCalendarCellStyle.cellHorizontalPadding
        let gridGutters = (1..<3).map { CGFloat($0) * (tile + gutter) - gutter - padding }
        #expect(dividers.map { $0.lowerBound + extent.x } == gridGutters)

        let broken = DPCalendarSpanRibbon.gutters(bandWidth: 2 * tile + gutter, columnCount: 2, isTrueStart: false, isTrueEnd: false)
        #expect(broken == [tile..<(tile + gutter)])
        #expect(DPCalendarSpanRibbon.gutters(bandWidth: tile - 2 * inset, columnCount: 1, isTrueStart: true, isTrueEnd: true).isEmpty)
    }

    @Test
    func anUnmeasuredBandHasNoVisibleDividers() {
        let dividers = DPCalendarSpanRibbon.gutters(bandWidth: 0, columnCount: 3, isTrueStart: true, isTrueEnd: false)
        #expect(dividers.allSatisfy { $0.isEmpty })
    }

    /// Before the band has been measured its width is zero; the spans collapse rather than
    /// form an inverted range.
    @Test
    func anUnmeasuredBandHasEmptySpans() {
        let spans = DPCalendarSpanRibbon.daySpans(bandWidth: 0, columnCount: 3, isTrueStart: true, isTrueEnd: false)
        #expect(spans == [0..<0, 0..<0, 0..<0])
    }

    @Test
    func aTileKnowsTheDaysOfItsWeekRow() {
        let days = (0..<14).map { DPCalendarSpanRibbonDay(dutyColor: "#\($0)", isCurrentMonth: true) }
        #expect(DPCalendarSpanRibbonDay.week(containing: 9, in: days) == Array(days[7..<14]))
        #expect(DPCalendarSpanRibbonDay.week(containing: 0, in: days) == Array(days[0..<7]))
    }

    /// A tag cluster can span several days; each chip, avatar or pill takes the ink and ring
    /// of the day under its centre, split at the middle of each gutter like the band.
    @Test
    func eachTagItemTakesTheDayUnderItsCentre() throws {
        let days = [
            DPCalendarSpanRibbonDay(dutyColor: "#1F3A8A", isCurrentMonth: true),
            DPCalendarSpanRibbonDay(dutyColor: "#1F3A8A", isCurrentMonth: true),
            DPCalendarSpanRibbonDay(dutyColor: "#A2D9DD", isCurrentMonth: true),
        ]
        let tile = 41 + DPCalendarCellStyle.cellHorizontalPadding * 2
        let gutter = DPCalendarCellStyle.gutterWidth
        let width = 3 * tile + 2 * gutter - 2 * DPCalendarSpanRibbon.edgeInset
        let spans = DPCalendarSpanRibbon.daySpans(bandWidth: width, columnCount: 3, isTrueStart: true, isTrueEnd: true)

        let overDark = try #require(DPCalendarSpanRibbon.dayIndex(atX: spans[1].upperBound - 1, in: spans))
        let overLight = try #require(DPCalendarSpanRibbon.dayIndex(atX: spans[1].upperBound + 1, in: spans))
        #expect(overDark == 1)
        #expect(overLight == 2, "Just past the middle of the gutter belongs to the next day")
        #expect(DPCalendarSpanRibbon.dayIndex(atX: -4, in: spans) == 0, "Clamped to the first day")
        #expect(DPCalendarSpanRibbon.dayIndex(atX: width + 4, in: spans) == 2, "Clamped to the last day")
        #expect(DPCalendarSpanRibbon.dayIndex(atX: 10, in: []) == nil)

        let lightInk = DPCalendarCellStyle.primaryForeground(dutyColor: "#1F3A8A")
        let darkInk = DPCalendarCellStyle.primaryForeground(dutyColor: "#A2D9DD")
        #expect(rgba(DPCalendarSpanRibbon.ink(for: days[overDark]), .light) == rgba(lightInk, .light))
        #expect(rgba(DPCalendarSpanRibbon.ink(for: days[overLight]), .light) == rgba(darkInk, .light))
        #expect(rgba(lightInk, .light) != rgba(darkInk, .light))
    }

    private func rgba(_ color: Color, _ style: UIUserInterfaceStyle) -> [Int] {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
    }
}

/// A ribbon's row is laid out in one pass: times only when the whole title still fits
/// beside them, then the tags in what is left, never cutting the title below its floor.
struct CalendarSpanRibbonRowPlanTests {
    @Test
    func timesShowWhenTheWholeTitleFitsBesideThem() {
        let plan = DPCalendarSpanRibbonRowPlan(
            width: 200, title: 60, floor: 30, start: 30, end: 30, chevron: 10, tagsFitting: { min($0, 40) }
        )
        #expect(plan.showsTimes)
        #expect(plan.titleWidth == 60)
        #expect(plan.tagsWidth == 40, "The tags take what the gap leaves: 200 - 60 - 30 - 3 - 30 - 10 = 67")
    }

    @Test
    func timesGoWhenTheyWouldCutTheTitleShort() {
        let plan = DPCalendarSpanRibbonRowPlan(
            width: 120, title: 60, floor: 30, start: 30, end: 30, chevron: 10, tagsFitting: { _ in 0 }
        )
        #expect(!plan.showsTimes)
        #expect(plan.titleWidth == 60, "Without tags the whole title shows")
    }

    @Test
    func tagsNeverCutTheTitleBelowItsFloor() {
        let plan = DPCalendarSpanRibbonRowPlan(
            width: 100, title: 80, floor: 30, start: 30, end: 30, chevron: 10, tagsFitting: { $0 }
        )
        #expect(!plan.showsTimes)
        #expect(plan.tagsWidth == 57, "100 - 30 - 3 - 10")
        #expect(plan.titleWidth == 30)
    }

    /// Tags as the ribbon's levels measure them: a 40pt level, else the 13pt lone avatar,
    /// else nothing.
    private static func levels(_ offered: CGFloat) -> CGFloat {
        offered >= 40 ? 40 : offered >= 13 ? 13 : 0
    }

    @Test
    func theLoneAvatarKeepsTheNormalFloorWhenItFits() {
        let plan = DPCalendarSpanRibbonRowPlan(
            width: 50, title: 40, floor: 25, start: 0, end: 0, chevron: 8, lone: 13,
            tagsFitting: Self.levels
        )
        #expect(plan.tagsWidth == 13, "50 - 25 - 3 - 8 = 14 holds the lone avatar")
        #expect(plan.titleWidth == 26, "50 - 3 - 13 - 8")
    }

    @Test
    func theTitleFloorRelaxesToOneCharacterForTheLoneAvatar() {
        let plan = DPCalendarSpanRibbonRowPlan(
            width: 42, title: 20, floor: 27, start: 0, end: 0, chevron: 8, lone: 13,
            tagsFitting: Self.levels
        )
        #expect(plan.tagsWidth == 13, "42 - 20 - 3 - 8 = 11 holds no level at the normal floor")
        #expect(plan.titleWidth == 18, "42 - 3 - 13 - 8: the title keeps about one character")
    }

    @Test
    func theLoneAvatarStaysWhenTheTitleShrinksToItsEllipsis() {
        let plan = DPCalendarSpanRibbonRowPlan(
            width: 30, title: 20, floor: 27, start: 0, end: 0, chevron: 8, lone: 13,
            tagsFitting: Self.levels
        )
        #expect(plan.tagsWidth == 13)
        #expect(plan.titleWidth == 6, "30 - 3 - 13 - 8")
    }

    @Test
    func tagsGoOnlyWhenTheBandCannotHoldTheChevronAndTheAvatar() {
        let roomy = DPCalendarSpanRibbonRowPlan(
            width: 21, title: 20, floor: 27, start: 0, end: 0, chevron: 8, lone: 13,
            tagsFitting: Self.levels
        )
        #expect(roomy.tagsWidth == 13)
        #expect(roomy.titleWidth == 0)

        let tooSmall = DPCalendarSpanRibbonRowPlan(
            width: 20, title: 20, floor: 27, start: 0, end: 0, chevron: 8, lone: 13,
            tagsFitting: Self.levels
        )
        #expect(tooSmall.tagsWidth == 0)
    }

    @Test
    func theRowMakesRoomForTheLoneAvatarsBadge() {
        let plain = DPCalendarSpanTagFit.loneWidth(tagCount: 1)
        let badged = DPCalendarSpanTagFit.loneWidth(tagCount: 7)
        func plan(lone: CGFloat) -> DPCalendarSpanRibbonRowPlan {
            DPCalendarSpanRibbonRowPlan(
                width: 42, title: 20, floor: 27, start: 0, end: 0, chevron: 8, lone: lone,
                tagsFitting: { $0 >= lone ? lone : 0 }
            )
        }
        #expect(plan(lone: plain).tagsWidth == 13)
        #expect(plan(lone: plain).titleWidth == 18, "42 - 3 - 13 - 8")
        #expect(plan(lone: badged).tagsWidth == badged)
        #expect(plan(lone: badged).titleWidth == 42 - 3 - badged - 8)
    }

    @Test
    func timesFoldBeforeTheyCrowdOutTheLoneAvatar() {
        let plan = DPCalendarSpanRibbonRowPlan(
            width: 140, title: 60, floor: 30, start: 30, end: 30, chevron: 10, lone: 13,
            tagsFitting: Self.levels
        )
        #expect(!plan.showsTimes, "60 + 30 + 3 + 30 + 10 leaves 7, under the avatar's 13")
        #expect(plan.tagsWidth == 40)
        #expect(plan.titleWidth == 60)
    }

    @Test
    func theTitleGrowsIntoWhatTheTagsLeave() {
        let plan = DPCalendarSpanRibbonRowPlan(
            width: 100, title: 80, floor: 30, start: 30, end: 30, chevron: 10, tagsFitting: { min($0, 20) }
        )
        #expect(plan.titleWidth == 67, "100 - 3 - 20 - 10")
    }
}

/// Together view: compared duties sit above the ribbon lanes, so each tile must hold the
/// same chip rows for the lanes below to stay level across a week row.
struct CalendarComparedDutyRowsTests {
    private func duty(_ member: MemberID, day: Int) -> ComparedDuty {
        ComparedDuty(
            memberID: member,
            name: "Member \(member)",
            hasProfilePhoto: false,
            profilePhotoVersion: 0,
            duty: DutyDTO(
                year: 2026, month: 11, day: day,
                dutyType: "OFF", dutyColor: nil, isOff: true, dutyTypeId: nil, source: .override
            )
        )
    }

    @Test
    func everyDayGetsARowForEachComparedMemberInOneOrder() {
        let rows = CalendarComparedDutyRows.rows(for: [
            [duty(3, day: 9), duty(5, day: 9)],
            [duty(5, day: 10)],
            [],
            [duty(5, day: 12), duty(3, day: 12)],
        ])

        #expect(rows.map { $0.map { $0?.memberID } } == [
            [3, 5],
            [nil, 5],
            [nil, nil],
            [3, 5],
        ])
        #expect(rows[1][1]?.duty.day == 10)
    }

    @Test
    func noComparisonLeavesNoRows() {
        let rows = CalendarComparedDutyRows.rows(for: [[], []])
        #expect(rows.map(\.count) == [0, 0])
    }
}
