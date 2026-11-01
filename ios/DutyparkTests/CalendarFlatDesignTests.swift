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
                    DPMemberTagPalette.background(onCalendarFill: true),
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
        #expect(DPCalendarSpan(daysFromStart: 1, totalDays: 1) == nil)
        #expect(DPCalendarSpan(daysFromStart: nil, totalDays: 3) == nil)
        let start = DPCalendarSpan(daysFromStart: 1, totalDays: 3)
        #expect(start?.isStart == true && start?.isEnd == false)
        let end = DPCalendarSpan(daysFromStart: 3, totalDays: 3)
        #expect(end?.isStart == false && end?.isEnd == true)
    }

    @Test
    func aMultiDayTitleIsDrawnOnlyWhereTheRunStartsOrReentersAWeekRow() throws {
        let first = try #require(DPCalendarSpan(daysFromStart: 1, totalDays: 5))
        let middle = try #require(DPCalendarSpan(daysFromStart: 3, totalDays: 5))
        let last = try #require(DPCalendarSpan(daysFromStart: 5, totalDays: 5))

        #expect(first.showsTitle(weekdayIndex: 4))
        #expect(!middle.showsTitle(weekdayIndex: 6))
        #expect(!last.showsTitle(weekdayIndex: 1))
        // A run that continues into the next week names itself again on Sunday.
        #expect(middle.showsTitle(weekdayIndex: 0))
        #expect(last.showsTitle(weekdayIndex: 0))
        #expect(DPCalendarSpan.titleLineLimit == 2)
    }

    @Test
    func aSelectionRingWinsOverTodaysRing() {
        #expect(DPCalendarTileRing(isToday: true, hasHighlight: true) == .highlight)
        #expect(DPCalendarTileRing(isToday: true, hasHighlight: false) == .today)
        #expect(DPCalendarTileRing(isToday: false, hasHighlight: true) == .highlight)
        #expect(DPCalendarTileRing(isToday: false, hasHighlight: false) == .none)
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
        #expect(cell.contains("DPCalendarSpan(daysFromStart: schedule.daysFromStart, totalDays: schedule.totalDays)"))
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
