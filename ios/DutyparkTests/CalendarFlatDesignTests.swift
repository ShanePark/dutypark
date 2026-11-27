import SwiftUI
import Testing
import UIKit
@testable import Dutypark

/// The flat month grid and D-Day list shared with the web calendar.
struct CalendarFlatDesignTests {
    @Test
    func dDayListShowsUpcomingNearestFirstThenPastMostRecentFirst() {
        func dDay(_ title: String, _ date: String, _ calc: Int64) -> DDayDTO {
            DDayDTO(id: calc, title: title, date: DateOnly(rawValue: date), isPrivate: false, calc: calc, daysLeft: calc)
        }
        let dDays = [
            dDay("past-old", "2025-01-01", -305),
            dDay("future-far", "2026-12-25", 54),
            dDay("past-recent", "2026-10-30", -3),
            dDay("today", "2026-11-01", 0),
            dDay("future-near", "2026-11-02", 1),
        ]

        #expect(dDays.sorted(by: DDayDTO.listOrder).map(\.title) == [
            "today", "future-near", "future-far", "past-recent", "past-old",
        ])
    }

    @Test
    func outOfMonthDutyFillFadesSixtyPercentTowardWhite() {
        #expect(DPCalendarCellStyle.fadedOutsideHex("#9DDBDE") == "#C4E9EB")
        #expect(DPCalendarCellStyle.fadedOutsideHex("#000000") == "#666666")
        #expect(DPCalendarCellStyle.fadedOutsideHex("not-a-colour") == nil)
        #expect(DPCalendarCellStyle.fadedOutsideHex(nil) == nil)
        #expect(DPCalendarCellStyle.fillHex(dutyColor: "#9ddbde", isCurrentMonth: true) == "#9DDBDE")
        #expect(DPCalendarCellStyle.fillHex(dutyColor: "#9DDBDE", isCurrentMonth: false) == "#C4E9EB")
        #expect(DPCalendarCellStyle.fillHex(dutyColor: nil, isCurrentMonth: true) == nil)
    }

    @Test
    func toneFollowsTheFillThatIsActuallyPainted() {
        #expect(DPCalendarCellStyle.tone(dutyColor: nil, isCurrentMonth: true) == .theme)
        #expect(DPCalendarCellStyle.tone(dutyColor: "#9DDBDE", isCurrentMonth: true) == .onLight)
        #expect(DPCalendarCellStyle.tone(dutyColor: "#1E3A8A", isCurrentMonth: true) == .onDark)
        // Faded toward white, a dark duty becomes a light fill outside the month.
        #expect(DPCalendarCellStyle.tone(dutyColor: "#1E3A8A", isCurrentMonth: false) == .onLight)
    }

    @Test
    func everythingDrawnOnADutyFillLooksTheSameInLightAndDark() {
        for dutyColor in ["#9DDBDE", "#F6D365", "#1E3A8A", "#111827"] {
            for isCurrentMonth in [true, false] {
                let colors: [Color] = [
                    DPCalendarCellStyle.cellBackground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth),
                    DPCalendarCellStyle.primaryForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth),
                    DPCalendarCellStyle.secondaryForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth),
                    DPCalendarCellStyle.ruleColor(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth),
                    DPCalendarCellStyle.holidayForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth),
                    DPCalendarCellStyle.dayNumberColor(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth, weekdayIndex: 0, hasHoliday: false),
                    DPCalendarCellStyle.dayNumberColor(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth, weekdayIndex: 6, hasHoliday: false),
                    DPCalendarCellStyle.dayNumberColor(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth, weekdayIndex: 3, hasHoliday: false),
                    DPMemberTagPalette.gradient(onCalendarFill: true).top,
                    DPMemberTagPalette.gradient(onCalendarFill: true).bottom,
                    DPMemberTagPalette.highlight(onCalendarFill: true),
                    DPMemberTagPalette.border(onCalendarFill: true),
                    DPMemberTagPalette.foreground(onCalendarFill: true)
                ]
                for color in colors {
                    #expect(rgba(color, .light) == rgba(color, .dark), "\(dutyColor) current=\(isCurrentMonth)")
                }
            }
        }
        // A tile without a duty follows the theme.
        let empty = DPCalendarCellStyle.cellBackground(dutyColor: nil, isCurrentMonth: true)
        #expect(rgba(empty, .light) != rgba(empty, .dark))
    }

    @Test
    func weekendInkUsesTheWebFillInks() {
        #expect(rgba(DPCalendarCellStyle.dayNumberColor(dutyColor: "#9DDBDE", weekdayIndex: 0, hasHoliday: false), .light) == rgba(hex: 0x991B1B))
        #expect(rgba(DPCalendarCellStyle.dayNumberColor(dutyColor: "#9DDBDE", weekdayIndex: 6, hasHoliday: false), .light) == rgba(hex: 0x1E40AF))
        #expect(rgba(DPCalendarCellStyle.dayNumberColor(dutyColor: "#1E3A8A", weekdayIndex: 0, hasHoliday: false), .dark) == rgba(hex: 0xFCA5A5))
        #expect(rgba(DPCalendarCellStyle.dayNumberColor(dutyColor: "#1E3A8A", weekdayIndex: 6, hasHoliday: false), .dark) == rgba(hex: 0x93C5FD))
        #expect(rgba(DPCalendarCellStyle.dayNumberColor(dutyColor: nil, weekdayIndex: 0, hasHoliday: false), .light) == rgba(hex: 0xDC2626))
        #expect(rgba(DPCalendarCellStyle.dayNumberColor(dutyColor: nil, weekdayIndex: 0, hasHoliday: false), .dark) == rgba(hex: 0xF87171))
    }

    @Test
    func todaysWeekdayHeaderIsMarkedOnlyInTodaysMonth() throws {
        let calendar = CalendarDateSupport.calendar
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)))
        #expect(DPCalendarCellStyle.todayWeekdayIndex(year: 2026, month: 11, today: today, calendar: calendar) == 0)
        #expect(DPCalendarCellStyle.todayWeekdayIndex(year: 2026, month: 10, today: today, calendar: calendar) == nil)
        #expect(DPCalendarCellStyle.todayWeekdayIndex(year: 2025, month: 11, today: today, calendar: calendar) == nil)
    }

    @Test
    func dDayRowsShareOneLayoutAndOnlyTheCounterColourChanges() {
        #expect(DDayListPresentation.rowHeight == 58)
        #expect(DDayListPresentation.state(calc: -1) == .past)
        #expect(DDayListPresentation.state(calc: 0) == .urgent)
        #expect(DDayListPresentation.state(calc: 3) == .urgent)
        #expect(DDayListPresentation.state(calc: 4) == .soon)
        #expect(DDayListPresentation.state(calc: 14) == .soon)
        #expect(DDayListPresentation.state(calc: 15) == .future)
        #expect(DDayListPresentation.label(calc: 0) == "D-Day")
        #expect(DDayListPresentation.label(calc: 13) == "D-13")
        #expect(DDayListPresentation.label(calc: -2) == "D+2")
        let date = DateOnly(rawValue: "2026-11-14")
        #expect(DDayListPresentation.dateText(date, locale: Locale(identifier: "ko")) == "2026.11.14 (토)")
        #expect(DDayListPresentation.dateText(date, locale: Locale(identifier: "en")) == "2026.11.14 (Sat)")
    }

    @Test
    func cellTodosAndSpansFollowTheMobileWebRules() {
        #expect(CalendarVisualLogic.cellTodoTitle("장보기") == "장보기")
        #expect(CalendarVisualLogic.cellTodoTitle("여섯글자제목") == "여섯글자제목")
        #expect(CalendarVisualLogic.cellTodoTitle("일곱글자의제목") == "일곱글자의제…")
    }

    /// A multi-day schedule is a ribbon in its week row's lanes, drawn before every other
    /// item of the tile; the old underline, its connectors and the "(n/m)" counter are gone
    /// from month tiles. The day detail keeps its counter.
    @Test
    func aMultiDayScheduleIsARibbonAboveEveryOtherItemInEveryMonthCell() throws {
        let style = try source("Dutypark/Components/DPCalendarCellStyle.swift")
        #expect(!style.contains("spanBar"), "The underline is gone")
        #expect(!style.contains("DPCalendarScheduleTitle"), "No (n/m) counter in month tiles")
        let scheduleLine = try source("Dutypark/Components/DPCalendarScheduleLine.swift")
        #expect(scheduleLine.contains("container.maximumNumberOfLines = 2"), "Inline clock titles keep their two-line limit")

        let cells = [
            try declaration(
                named: "private struct CalendarDayCell: View",
                in: source("Dutypark/Features/Calendar/CalendarView.swift")
            ),
            try declaration(
                named: "private struct GuestCalendarDayCell: View",
                in: source("Dutypark/Features/Guest/GuestPublicCalendarView.swift")
            ),
            try declaration(
                named: "private struct TeamCalendarDayCell: View",
                in: source("Dutypark/Features/Team/TeamView.swift")
            ),
        ]
        for cell in cells {
            let lanes = try #require(cell.range(of: "DPCalendarSpanLaneStack("), "Every month cell draws ribbon lanes")
            let holidays = try #require(cell.range(of: "holiday.dateName"))
            #expect(lanes.lowerBound < holidays.lowerBound, "Lanes come first, under the date number")
            #expect(cell.contains("DPCalendarSpanRibbonBand("))
            #expect(cell.contains("ribbonColumn"), "A tile drawing a ribbon is layered over the tiles it crosses")
            #expect(cell.contains("DPCalendarScheduleLine(") || cell.contains(".lineLimit(2)"), "Single-day titles still wrap to two lines")
            #expect(!cell.contains("dayCounter"), "No (n/m) counter in month tiles")
        }

        let detail = try declaration(
            named: "private struct DayDetailView: View",
            in: source("Dutypark/Features/Calendar/CalendarView.swift")
        )
        #expect(detail.contains("(\\(schedule.daysFromStart)/\\(schedule.totalDays))"), "The day detail keeps its counter")
    }

    /// A multi-day schedule names the same members in its ribbon as a single-day one does
    /// in its tile, and the ribbon's glass and ink follow the tile it starts in.
    @Test
    func theMemberCalendarRibbonCarriesTheScheduleTags() throws {
        let ribbon = try declaration(
            named: "private func spanRibbon(_ placement: DPCalendarSpanLanes.Placement<ScheduleDTO>)",
            in: source("Dutypark/Features/Calendar/CalendarView.swift")
        )
        #expect(ribbon.contains("tags: ScheduleTagDisplayPolicy.displayTags(for: schedule, calendarMemberID: calendarMemberID)"))
        #expect(ribbon.contains("DPCalendarLockBadge(onFill: isOnFill)"), "The badge sits on the tile's tone, not a white bar")
        #expect(
            ribbon.contains("titleFloorLeading: showsPrivateBadge(schedule) ? DPCalendarLockBadge.diameter + 2 : 0"),
            "The badge does not eat into the characters the title keeps"
        )
    }

    /// A title squeezed by tags keeps two characters and its ellipsis, not one character.
    @Test
    func aSqueezedRibbonTitleKeepsTwoCharactersAndItsEllipsis() throws {
        let ribbon = try source("Dutypark/Components/DPCalendarSpanRibbon.swift")
        #expect(ribbon.contains("Text(verbatim: \"가나…\")"))
        #expect(!ribbon.contains("Text(verbatim: \"가나\")"))
    }

    /// The band is coloured day by day, so every month grid hands each tile its week row.
    @Test
    func everyRibbonIsColouredByTheDaysItCovers() throws {
        let cells = [
            try declaration(
                named: "private struct CalendarDayCell: View",
                in: source("Dutypark/Features/Calendar/CalendarView.swift")
            ),
            try declaration(
                named: "private struct GuestCalendarDayCell: View",
                in: source("Dutypark/Features/Guest/GuestPublicCalendarView.swift")
            ),
            try declaration(
                named: "private struct TeamCalendarDayCell: View",
                in: source("Dutypark/Features/Team/TeamView.swift")
            ),
        ]
        for cell in cells {
            #expect(cell.contains("let weekDays: [DPCalendarSpanRibbonDay]"))
            #expect(cell.contains("days: placement.columns.map { weekDays[$0] }"))
        }
    }

    @Test
    func everyMonthGridLaysOutRibbonLanesPerWeekRow() throws {
        let grids = [
            try declaration(
                named: "private func calendarMonthBody(",
                in: source("Dutypark/Features/Calendar/CalendarView.swift")
            ),
            try declaration(
                named: "private var calendarGrid: some View",
                in: source("Dutypark/Features/Guest/GuestPublicCalendarView.swift")
            ),
            try declaration(
                named: "private func calendarMonthBody(_ page: TeamCalendarMonthPage",
                in: source("Dutypark/Features/Team/TeamView.swift")
            ),
        ]
        for grid in grids {
            #expect(grid.contains("DPCalendarSpanLanes.layout("))
            #expect(grid.contains("spanLanes: spanLanes["))
        }
    }

    @Test
    func aTileThatDrawsARibbonSitsAboveTheTilesItCrosses() {
        #expect(DPCalendarTileRing.zIndex(ring: .none, ribbonColumn: nil) == 0)
        #expect(DPCalendarTileRing.zIndex(ring: .highlight, ribbonColumn: nil) == 1)
        let monday = DPCalendarTileRing.zIndex(ring: .none, ribbonColumn: 1)
        let tuesday = DPCalendarTileRing.zIndex(ring: .none, ribbonColumn: 2)
        #expect(monday > tuesday, "An earlier ribbon stays above a later tile that draws its own")
        #expect(DPCalendarTileRing.zIndex(ring: .none, ribbonColumn: 6) > 1, "A ribbon tile is above a selection ring")
    }

    /// Today is marked by its red header strip, so the only ring a tile draws is a selection.
    @Test
    func todayDrawsNoRingAndOnlyASelectionDrawsOne() throws {
        #expect(DPCalendarTileRing(hasHighlight: true) == .highlight)
        #expect(DPCalendarTileRing(hasHighlight: false) == .none)
        let style = try source("Dutypark/Components/DPCalendarCellStyle.swift")
        #expect(!style.contains("DPCalendarTodayRing"), "Today's ring is gone")
        #expect(!style.contains("Circle().fill(DPCalendarCellStyle.todayColor)"), "Today's numeral has no red circle")
        let tile = try declaration(
            named: "nonisolated struct DPCalendarDayTile<Accessory: View, Content: View>: View",
            in: style
        )
        // The selection stroke is the tile's overlay, so it is drawn over today's strip.
        let strip = try #require(tile.range(of: "DPCalendarTodayStrip.Band()"))
        let stroke = try #require(tile.range(of: "strokeBorder(highlight"))
        #expect(strip.lowerBound < stroke.lowerBound)
    }

    /// E2: today's date row is a full-width red strip, the same red in light and dark, with a
    /// white numeral and a faint dark hairline beneath it.
    @Test
    func todaysHeaderIsAWhiteOnRedStrip() {
        #expect(DPCalendarTodayStrip.background == DPCalendarCellStyle.todayColor)
        #expect(DPCalendarTodayStrip.ink == Color.white)
        #expect(DPCalendarTodayStrip.hairlineWidth == 1)
        #expect(DPCalendarTodayStrip.hairlineOpacity == 0.2)
        // The strip reaches the tile's top, left and right edges.
        #expect(DPCalendarTodayStrip.bleed == EdgeInsets(
            top: DPCalendarCellStyle.cellTopPadding,
            leading: DPCalendarCellStyle.cellHorizontalPadding,
            bottom: 0,
            trailing: DPCalendarCellStyle.cellHorizontalPadding
        ))
    }

    /// The strip carries only the numeral (and a pinned D-Day label): no visible today word.
    @Test
    func todaysStripShowsNoTodayWord() throws {
        let style = try source("Dutypark/Components/DPCalendarCellStyle.swift")
        let tile = try declaration(
            named: "nonisolated struct DPCalendarDayTile<Accessory: View, Content: View>: View",
            in: style
        )
        let number = try declaration(named: "nonisolated struct DPCalendarDayNumber: View", in: style)
        for part in [tile, number] {
            #expect(!part.contains("calendar.today"))
            #expect(!part.contains("오늘"))
        }
    }

    /// Today's pinned D-Day label is white inside the strip.
    @Test
    func todaysPinnedDDayLabelIsWhiteInsideTheStrip() throws {
        let cell = try declaration(
            named: "private struct CalendarDayCell: View",
            in: source("Dutypark/Features/Calendar/CalendarView.swift")
        )
        #expect(cell.contains("DPCalendarTodayStrip.ink"))
    }

    @Test
    func theDayCellShowsEveryDueTodo() throws {
        let cell = try declaration(
            named: "private struct CalendarDayCell: View",
            in: source("Dutypark/Features/Calendar/CalendarView.swift")
        )
        #expect(cell.contains("ForEach(day.todos, id: \\.id)"))
        #expect(!cell.contains("maximumTodosPerCell"), "Due todos are no longer capped behind a count")
    }

    @Test
    func theGuestCalendarUsesTheFlatGridAndDDayList() throws {
        let guest = try source("Dutypark/Features/Guest/GuestPublicCalendarView.swift")
        let cell = try declaration(named: "private struct GuestCalendarDayCell: View", in: guest)
        #expect(cell.contains("DPCalendarDayTile("))
        #expect(cell.contains("DPCalendarItemRow("))
        #expect(cell.contains("DPCalendarSpanLaneStack(lanes: spanLanes, column: weekday)"))
        #expect(!cell.contains("prefix("), "Every schedule and D-Day is drawn")
        #expect(!cell.contains("opacity("), "Out-of-month days are faded by colour, not opacity")

        let grid = try declaration(named: "private var calendarGrid: some View", in: guest)
        #expect(grid.contains("DPCalendarWeekdayRow("))
        #expect(grid.contains("DPCalendarCellStyle.todayWeekdayIndex("))
        #expect(grid.contains("CalendarMonthCellGrid(items: visibleCalendarDays)"))
        #expect(grid.contains(".background(DPCalendarCellStyle.gutterColor)"))

        let dDays = try declaration(named: "private var dDaySection: some View", in: guest)
        #expect(dDays.contains("DDayRow("))
        #expect(dDays.contains("canPin: false"), "A guest cannot pin another member's D-Day")
        #expect(!dDays.contains("LazyVGrid("))
    }

    private func source(_ path: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func declaration(named signature: String, in source: String) throws -> String {
        let start = try #require(source.range(of: signature), "\(signature) is no longer declared").lowerBound
        var depth = 0
        var index = start
        while index < source.endIndex {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" {
                depth -= 1
                if depth == 0 { return String(source[start...index]) }
            }
            index = source.index(after: index)
        }
        return String(source[start...])
    }

    private func rgba(_ color: Color, _ style: UIUserInterfaceStyle) -> [Int] {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
    }

    private func rgba(hex: UInt32) -> [Int] {
        [Int((hex >> 16) & 0xFF), Int((hex >> 8) & 0xFF), Int(hex & 0xFF), 255]
    }
}
