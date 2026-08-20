import Foundation
import XCTest
@testable import Dutypark

/// The picker's policy is mirrored from `frontend/src/components/common/datePickerGrid.ts`,
/// so these cases follow that module's test file: both clients must answer the same way.
final class DatePickerGridLogicTests: XCTestCase {
    private func value(_ raw: String) -> DateOnly { DateOnly(rawValue: raw) }

    private func date(_ raw: String) throws -> Date {
        try XCTUnwrap(CalendarDateSupport.date(from: DateOnly(rawValue: raw)))
    }

    // MARK: - Grid shape

    /// Six weeks are drawn whatever the month, so paging months cannot resize the sheet
    /// under the user's finger.
    func testEveryMonthGridIsSixWeeks() {
        for (year, month) in [(2026, 2), (2026, 8), (2024, 2), (2027, 5)] {
            XCTAssertEqual(
                DatePickerGridLogic.monthGrid(year: year, month: month).count,
                DatePickerGridLogic.weeksPerGrid * DatePickerGridLogic.daysPerWeek,
                "\(year)-\(month)"
            )
        }
    }

    /// 2026-08-01 is a Saturday, the worst case: the grid has to reach six days back into
    /// July and still finish the following month.
    func testAGridOpensOnTheWeekStartOnOrBeforeTheFirstOfTheMonth() {
        let grid = DatePickerGridLogic.monthGrid(year: 2026, month: 8)

        XCTAssertEqual(grid.first?.date, value("2026-07-26"))
        XCTAssertEqual(grid.first?.isCurrentMonth, false)
        XCTAssertEqual(grid[6].date, value("2026-08-01"))
        XCTAssertEqual(grid[6].day, 1)
        XCTAssertEqual(grid[6].isCurrentMonth, true)
        XCTAssertEqual(grid.last?.date, value("2026-09-05"))
        XCTAssertEqual(grid.last?.isCurrentMonth, false)
    }

    /// 2026-02-01 is a Sunday, so there is no leading day at all and the grid must not
    /// borrow a whole week from January.
    func testAMonthStartingOnTheWeekStartOpensOnTheFirstItself() {
        let grid = DatePickerGridLogic.monthGrid(year: 2026, month: 2)

        XCTAssertEqual(grid.first?.date, value("2026-02-01"))
        XCTAssertEqual(grid.first?.isCurrentMonth, true)
    }

    func testTheGridMarksExactlyTheDaysTheMonthHas() {
        let lengths = [(2026, 2, 28), (2024, 2, 29), (2026, 4, 30), (2026, 8, 31)]

        for (year, month, expected) in lengths {
            let grid = DatePickerGridLogic.monthGrid(year: year, month: month)
            XCTAssertEqual(grid.filter(\.isCurrentMonth).count, expected, "\(year)-\(month)")
            XCTAssertEqual(DatePickerGridLogic.daysInMonth(year: year, month: month), expected, "\(year)-\(month)")
        }
    }

    func testTheGridWalksConsecutiveDaysAcrossAYearBoundary() {
        let grid = DatePickerGridLogic.monthGrid(year: 2025, month: 12)

        for index in 1..<grid.count {
            XCTAssertEqual(
                grid[index].date,
                DatePickerGridLogic.addingDays(1, to: grid[index - 1].date),
                "cell \(index)"
            )
        }
        XCTAssertTrue(grid.contains { $0.date.rawValue.hasPrefix("2026-01") })
    }

    /// The flags the cell is drawn from: a day outside the bounds must arrive already
    /// unselectable, and today must be marked wherever it lands in the grid.
    func testGridCellsCarryTheirDisabledAndTodayFlags() throws {
        let grid = DatePickerGridLogic.monthGrid(
            year: 2026,
            month: 8,
            minimum: value("2026-08-10"),
            maximum: value("2026-08-20"),
            today: try date("2026-08-15")
        )
        let cell = { (raw: String) in grid.first { $0.date == self.value(raw) } }

        XCTAssertEqual(cell("2026-08-09")?.isDisabled, true)
        XCTAssertEqual(cell("2026-08-10")?.isDisabled, false)
        XCTAssertEqual(cell("2026-08-20")?.isDisabled, false)
        XCTAssertEqual(cell("2026-08-21")?.isDisabled, true)
        XCTAssertEqual(cell("2026-07-26")?.isDisabled, true)

        XCTAssertEqual(grid.filter(\.isToday).count, 1)
        XCTAssertEqual(grid.first { $0.isToday }?.date, value("2026-08-15"))
    }

    /// A day that is not on screen this month is not today's cell either, so the marker
    /// must not leak into a month the clock is not in.
    func testTodayIsUnmarkedInAMonthItDoesNotAppearIn() throws {
        let grid = DatePickerGridLogic.monthGrid(year: 2026, month: 12, today: try date("2026-08-15"))

        XCTAssertTrue(grid.allSatisfy { !$0.isToday })
    }

    // MARK: - Day values

    func testOnlyARealCalendarDayIsAValidValue() {
        XCTAssertTrue(DatePickerGridLogic.isValidDay(value("2026-08-20")))
        XCTAssertTrue(DatePickerGridLogic.isValidDay(value("2024-02-29")))

        XCTAssertFalse(DatePickerGridLogic.isValidDay(nil))
        XCTAssertFalse(DatePickerGridLogic.isValidDay(value("")))
        XCTAssertFalse(DatePickerGridLogic.isValidDay(value("2026-8-20")))
        XCTAssertFalse(DatePickerGridLogic.isValidDay(value("2026-08-20T00:00")))
        // Foundation rolls this forward to 2026-03-02 instead of rejecting it; only the
        // round trip back to text catches it.
        XCTAssertFalse(DatePickerGridLogic.isValidDay(value("2026-02-30")))
        XCTAssertFalse(DatePickerGridLogic.isValidDay(value("2026-13-01")))
        XCTAssertFalse(DatePickerGridLogic.isValidDay(value("2026-02-29")))
    }

    func testAddingDaysCrossesMonthAndYearBoundaries() {
        XCTAssertEqual(DatePickerGridLogic.addingDays(1, to: value("2026-08-31")), value("2026-09-01"))
        XCTAssertEqual(DatePickerGridLogic.addingDays(-1, to: value("2026-01-01")), value("2025-12-31"))
        XCTAssertEqual(DatePickerGridLogic.addingDays(7, to: value("2026-08-20")), value("2026-08-27"))
        XCTAssertNil(DatePickerGridLogic.addingDays(1, to: value("2026-02-30")))
    }

    func testAddingMonthsClampsOntoAShorterMonth() {
        XCTAssertEqual(DatePickerGridLogic.addingMonths(1, to: value("2026-08-20")), value("2026-09-20"))
        XCTAssertEqual(DatePickerGridLogic.addingMonths(1, to: value("2026-12-20")), value("2027-01-20"))
        XCTAssertEqual(DatePickerGridLogic.addingMonths(1, to: value("2026-01-31")), value("2026-02-28"))
        XCTAssertEqual(DatePickerGridLogic.addingMonths(1, to: value("2024-01-31")), value("2024-02-29"))
        XCTAssertEqual(DatePickerGridLogic.addingMonths(-1, to: value("2026-03-31")), value("2026-02-28"))
    }

    func testWeekBoundsSnapToTheDisplayedWeek() {
        // 2026-08-20 is a Thursday, in a Sunday-first week.
        XCTAssertEqual(DatePickerGridLogic.startOfWeek(value("2026-08-20")), value("2026-08-16"))
        XCTAssertEqual(DatePickerGridLogic.endOfWeek(value("2026-08-20")), value("2026-08-22"))
        XCTAssertEqual(DatePickerGridLogic.startOfWeek(value("2026-08-16")), value("2026-08-16"))
        XCTAssertEqual(DatePickerGridLogic.endOfWeek(value("2026-08-22")), value("2026-08-22"))
    }

    func testAMonthAndItsFirstDayConvertBackAndForth() {
        XCTAssertEqual(DatePickerGridLogic.month(of: value("2026-08-20")), DatePickerMonth(year: 2026, month: 8))
        XCTAssertNil(DatePickerGridLogic.month(of: value("2026-02-30")))
        XCTAssertEqual(
            DatePickerGridLogic.firstDay(of: DatePickerMonth(year: 2026, month: 8)),
            value("2026-08-01")
        )
    }

    // MARK: - Bounds

    func testMinimumAndMaximumAreInclusiveBounds() {
        XCTAssertFalse(DatePickerGridLogic.isDisabled(value("2026-08-20"), minimum: value("2026-08-20"), maximum: value("2026-08-20")))
        XCTAssertTrue(DatePickerGridLogic.isDisabled(value("2026-08-19"), minimum: value("2026-08-20"), maximum: nil))
        XCTAssertTrue(DatePickerGridLogic.isDisabled(value("2026-08-21"), minimum: nil, maximum: value("2026-08-20")))
    }

    func testUnusableBoundsAreIgnoredRatherThanDisablingTheWholeGrid() {
        XCTAssertFalse(DatePickerGridLogic.isDisabled(value("2026-08-20")))
        XCTAssertFalse(DatePickerGridLogic.isDisabled(value("2026-08-20"), minimum: value(""), maximum: value("")))
        XCTAssertFalse(DatePickerGridLogic.isDisabled(value("2026-08-20"), minimum: value("nonsense"), maximum: value("nonsense")))
    }

    func testClampPullsAValueInsideTheBounds() {
        let minimum = value("2026-08-01")
        let maximum = value("2026-08-31")

        XCTAssertEqual(DatePickerGridLogic.clamped(value("2026-01-01"), minimum: minimum, maximum: maximum), minimum)
        XCTAssertEqual(DatePickerGridLogic.clamped(value("2026-12-31"), minimum: minimum, maximum: maximum), maximum)
        XCTAssertEqual(DatePickerGridLogic.clamped(value("2026-08-20"), minimum: minimum, maximum: maximum), value("2026-08-20"))
        XCTAssertEqual(DatePickerGridLogic.clamped(value("2026-08-20")), value("2026-08-20"))
    }

    // MARK: - Range mode

    /// The anchor is the floor of a range grid, and it has to stay selectable itself: a
    /// one-day range is legal, and an off-by-one here makes the day the user just picked
    /// untappable.
    func testTheRangeAnchorStaysSelectableWhileEveryEarlierDayIsDisabled() {
        let minimum = DatePickerGridLogic.rangeMinimum(nil, anchor: value("2026-08-20"))

        XCTAssertTrue(DatePickerGridLogic.isDisabled(value("2026-08-19"), minimum: minimum))
        XCTAssertTrue(DatePickerGridLogic.isDisabled(value("2026-01-01"), minimum: minimum))
        XCTAssertFalse(DatePickerGridLogic.isDisabled(value("2026-08-20"), minimum: minimum))
        XCTAssertFalse(DatePickerGridLogic.isDisabled(value("2026-12-31"), minimum: minimum))
    }

    func testRangeMinimumKeepsWhicheverBoundIsLater() {
        XCTAssertEqual(DatePickerGridLogic.rangeMinimum(value("2026-08-01"), anchor: value("2026-08-20")), value("2026-08-20"))
        XCTAssertEqual(DatePickerGridLogic.rangeMinimum(value("2026-09-01"), anchor: value("2026-08-20")), value("2026-09-01"))
        XCTAssertEqual(DatePickerGridLogic.rangeMinimum(value("2026-08-20"), anchor: value("2026-08-20")), value("2026-08-20"))
    }

    func testRangeMinimumFallsBackToThePlainMinimumAndNormalisesUnusableBounds() {
        XCTAssertEqual(DatePickerGridLogic.rangeMinimum(value("2026-08-01"), anchor: nil), value("2026-08-01"))
        XCTAssertEqual(DatePickerGridLogic.rangeMinimum(value("2026-08-01"), anchor: value("2026-02-30")), value("2026-08-01"))
        XCTAssertEqual(DatePickerGridLogic.rangeMinimum(value("nonsense"), anchor: value("2026-08-20")), value("2026-08-20"))
        XCTAssertNil(DatePickerGridLogic.rangeMinimum(nil, anchor: nil))
        XCTAssertNil(DatePickerGridLogic.rangeMinimum(value("nonsense"), anchor: value("nonsense")))
    }

    /// The span is painted as one continuous block, so the states have to keep meeting up
    /// where a grid shows two months at once.
    func testRangeStatesPaintOneBlockAcrossAMonthBoundary() {
        let anchor = value("2026-08-30")
        let end = value("2026-09-02")

        XCTAssertEqual(DatePickerGridLogic.rangeDayState(value("2026-08-29"), anchor: anchor, end: end), .none)
        XCTAssertEqual(DatePickerGridLogic.rangeDayState(anchor, anchor: anchor, end: end), .start)
        XCTAssertEqual(DatePickerGridLogic.rangeDayState(value("2026-08-31"), anchor: anchor, end: end), .middle)
        XCTAssertEqual(DatePickerGridLogic.rangeDayState(value("2026-09-01"), anchor: anchor, end: end), .middle)
        XCTAssertEqual(DatePickerGridLogic.rangeDayState(end, anchor: anchor, end: end), .end)
        XCTAssertEqual(DatePickerGridLogic.rangeDayState(value("2026-09-03"), anchor: anchor, end: end), .none)
        XCTAssertEqual(
            DatePickerGridLogic.rangeDayState(value("2026-12-31"), anchor: value("2026-12-30"), end: value("2027-01-02")),
            .middle
        )
    }

    func testASingleDayRangeCollapsesToOneRoundedCell() {
        let anchor = value("2026-08-20")

        XCTAssertEqual(DatePickerGridLogic.rangeDayState(anchor, anchor: anchor, end: anchor), .single)
    }

    func testNothingIsPaintedWithoutAnAnchorOrAnEndToPreview() {
        let anchor = value("2026-08-20")

        XCTAssertEqual(DatePickerGridLogic.rangeDayState(anchor, anchor: nil, end: value("2026-08-24")), .none)
        XCTAssertEqual(DatePickerGridLogic.rangeDayState(anchor, anchor: anchor, end: nil), .none)
        XCTAssertEqual(DatePickerGridLogic.rangeDayState(anchor, anchor: value("nonsense"), end: value("nonsense")), .none)
    }

    /// Defensive ordering: a caller that hands over an end before the anchor still gets a
    /// painted span rather than nothing at all.
    func testRangeStatesReadLeftToRightWhenTheEndLandsBeforeTheAnchor() {
        let anchor = value("2026-08-20")

        XCTAssertEqual(DatePickerGridLogic.rangeDayState(value("2026-08-18"), anchor: anchor, end: value("2026-08-18")), .start)
        XCTAssertEqual(DatePickerGridLogic.rangeDayState(value("2026-08-19"), anchor: anchor, end: value("2026-08-18")), .middle)
        XCTAssertEqual(DatePickerGridLogic.rangeDayState(anchor, anchor: anchor, end: value("2026-08-18")), .end)
    }

    func testDayCountsIncludeBothEnds() {
        XCTAssertEqual(DatePickerGridLogic.inclusiveDayCount(from: value("2026-08-20"), to: value("2026-08-20")), 1)
        XCTAssertEqual(DatePickerGridLogic.inclusiveDayCount(from: value("2026-08-20"), to: value("2026-08-21")), 2)
        XCTAssertEqual(DatePickerGridLogic.inclusiveDayCount(from: value("2026-08-20"), to: value("2026-08-24")), 5)
        XCTAssertEqual(DatePickerGridLogic.inclusiveDayCount(from: value("2026-08-01"), to: value("2026-09-01")), 32)
        XCTAssertEqual(DatePickerGridLogic.inclusiveDayCount(from: value("2025-12-31"), to: value("2026-01-01")), 2)
        XCTAssertEqual(DatePickerGridLogic.inclusiveDayCount(from: value("2024-02-01"), to: value("2024-03-01")), 30)
    }

    func testDayCountsAreOrderIndependentAndZeroForAnUnusableEnd() {
        XCTAssertEqual(DatePickerGridLogic.inclusiveDayCount(from: value("2026-08-24"), to: value("2026-08-20")), 5)
        XCTAssertEqual(DatePickerGridLogic.inclusiveDayCount(from: nil, to: value("2026-08-20")), 0)
        XCTAssertEqual(DatePickerGridLogic.inclusiveDayCount(from: value("2026-08-20"), to: value("nonsense")), 0)
    }

    // MARK: - Opening month

    func testThePickerOpensOnTheSelectedValueWhenThereIsOne() throws {
        XCTAssertEqual(
            DatePickerGridLogic.initialMonth(selected: value("2026-03-14"), today: try date("2026-08-20")),
            DatePickerMonth(year: 2026, month: 3)
        )
        XCTAssertEqual(
            DatePickerGridLogic.initialMonth(selected: value("2031-11-02"), today: try date("2026-08-20")),
            DatePickerMonth(year: 2031, month: 11)
        )
    }

    func testAnEmptyPickerOpensOnToday() throws {
        XCTAssertEqual(
            DatePickerGridLogic.initialMonth(selected: nil, today: try date("2026-08-20")),
            DatePickerMonth(year: 2026, month: 8)
        )
        XCTAssertEqual(
            DatePickerGridLogic.initialMonth(selected: value(""), today: try date("2026-08-20")),
            DatePickerMonth(year: 2026, month: 8)
        )
    }

    /// An end-date picker anchored in the future must not open on a month where every day
    /// is disabled, and the same holds for a far-future maximum in the other direction.
    func testAPickerWhoseBoundsExcludeTodayOpensOnAReachableMonth() throws {
        let today = try date("2026-08-20")

        XCTAssertEqual(
            DatePickerGridLogic.initialMonth(
                selected: nil,
                minimum: DatePickerGridLogic.rangeMinimum(nil, anchor: value("2027-01-10")),
                today: today
            ),
            DatePickerMonth(year: 2027, month: 1)
        )
        XCTAssertEqual(
            DatePickerGridLogic.initialMonth(selected: nil, maximum: value("2025-04-02"), today: today),
            DatePickerMonth(year: 2025, month: 4)
        )
    }

    // MARK: - Labels

    /// The header must read the way the calendar screen's own header does, in the language
    /// the app is running in rather than the device's region default.
    func testWeekdayAndMonthLabelsFollowTheAppLanguage() {
        XCTAssertEqual(
            DatePickerGridLogic.weekdayLabels(locale: Locale(identifier: "ko")),
            ["일", "월", "화", "수", "목", "금", "토"]
        )
        XCTAssertEqual(
            DatePickerGridLogic.weekdayLabels(locale: Locale(identifier: "en")),
            ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        )

        XCTAssertEqual(DatePickerGridLogic.monthLabel(year: 2026, month: 8, locale: Locale(identifier: "ko")), "2026년 8월")
        XCTAssertEqual(DatePickerGridLogic.monthLabel(year: 2026, month: 8, locale: Locale(identifier: "en")), "August 2026")
    }

    func testTheFieldReadsTheSelectedDayAndNothingAtAllWhenUnset() {
        XCTAssertEqual(DatePickerGridLogic.fieldLabel(value("2026-08-20"), locale: Locale(identifier: "ko")), "2026. 08. 20.")
        XCTAssertEqual(DatePickerGridLogic.fieldLabel(value("2026-08-20"), locale: Locale(identifier: "en")), "08/20/2026")
        XCTAssertEqual(DatePickerGridLogic.fieldLabel(nil, locale: Locale(identifier: "ko")), "")
        XCTAssertEqual(DatePickerGridLogic.fieldLabel(value("not-a-date"), locale: Locale(identifier: "ko")), "")
    }

    /// A day button reads as a bare number to VoiceOver otherwise, which says nothing about
    /// which week or month the cursor is in.
    func testEachDayHasASpokenLabelCarryingItsWeekday() {
        XCTAssertTrue(
            DatePickerGridLogic.dayAccessibilityLabel(value("2026-08-20"), locale: Locale(identifier: "en"))
                .contains("Thursday")
        )
        XCTAssertTrue(
            DatePickerGridLogic.dayAccessibilityLabel(value("2026-08-20"), locale: Locale(identifier: "ko"))
                .contains("목요일")
        )
    }

    func testWeekdayLabelsResolveFromTheCalendarTableInEveryLocale() throws {
        for locale in ["en", "ko"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try XCTUnwrap(Bundle(url: url))
            for key in ["sun", "mon", "tue", "wed", "thu", "fri", "sat"] {
                XCTAssertNotEqual(
                    bundle.localizedString(forKey: "calendar.weekday.\(key)", value: "calendar.weekday.\(key)", table: "Calendar"),
                    "calendar.weekday.\(key)",
                    "Missing calendar.weekday.\(key) for \(locale)"
                )
            }
        }
    }
}
