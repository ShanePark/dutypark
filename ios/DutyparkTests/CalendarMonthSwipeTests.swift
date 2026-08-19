import CoreGraphics
import Foundation
import XCTest
@testable import Dutypark

final class CalendarMonthSwipeTests: XCTestCase {
    func testASidewaysDragPastTheThresholdPicksTheNeighbouringMonth() {
        let travel = CalendarMonthSwipe.threshold

        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(translation: CGSize(width: travel, height: 0)),
            -1,
            "Dragging left to right pulls the previous month in"
        )
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(translation: CGSize(width: -travel, height: 0)),
            1,
            "Dragging right to left pulls the next month in"
        )
    }

    func testAShortDragKeepsTheMonth() {
        let travel = CalendarMonthSwipe.threshold - 1

        XCTAssertEqual(CalendarMonthSwipe.monthOffset(translation: CGSize(width: travel, height: 0)), 0)
        XCTAssertEqual(CalendarMonthSwipe.monthOffset(translation: CGSize(width: -travel, height: 0)), 0)
        XCTAssertEqual(CalendarMonthSwipe.monthOffset(translation: .zero), 0)
    }

    /// The grid lives inside the scrolling calendar, so a scroll that drifts sideways
    /// must not land on another month.
    func testAScrollThatDriftsSidewaysKeepsTheMonth() {
        let translation = CGSize(
            width: CalendarMonthSwipe.threshold + 20,
            height: CalendarMonthSwipe.threshold + 20
        )

        XCTAssertEqual(CalendarMonthSwipe.monthOffset(translation: translation), 0)
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(
                translation: CGSize(width: -translation.width, height: translation.height)
            ),
            0
        )
    }

    func testTheGridFollowsTheFingerOnlyAsFarAsTheDampedLimit() {
        let limit = CalendarMonthSwipe.maximumFollowDistance

        XCTAssertEqual(CalendarMonthSwipe.followOffset(translation: .zero), 0, accuracy: 0.001)

        let short = CalendarMonthSwipe.followOffset(translation: CGSize(width: 10, height: 0))
        XCTAssertGreaterThan(short, 0)
        XCTAssertLessThan(short, 10, "The travel is damped from the first point on")

        let long = CalendarMonthSwipe.followOffset(translation: CGSize(width: 1_000, height: 0))
        XCTAssertLessThanOrEqual(long, limit)
        XCTAssertGreaterThan(long, limit * 0.9)

        XCTAssertEqual(
            CalendarMonthSwipe.followOffset(translation: CGSize(width: -1_000, height: 0)),
            -long,
            accuracy: 0.001,
            "The grid follows the finger in whichever direction it moves"
        )
    }

    func testTheGridStaysPutWhileTheDragIsMostlyVertical() {
        XCTAssertEqual(
            CalendarMonthSwipe.followOffset(translation: CGSize(width: 20, height: 40)),
            0,
            accuracy: 0.001
        )
    }

    /// The swipe has to ride along with the enclosing scroll view and the day cells'
    /// own tap, which is what `simultaneousGesture` buys; claiming the drag outright
    /// would break vertical scrolling over the grid.
    func testTheCalendarGridCarriesTheSwipeAlongsideItsOtherGestures() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Dutypark/Features/Calendar/CalendarView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("simultaneousGesture(monthSwipeGesture)"))
        XCTAssertTrue(
            source.contains("guard !isSwipingMonth, !isSlidingMonth else { return }"),
            "A day that was dragged sideways must not open its detail modal"
        )
        XCTAssertTrue(source.contains("CalendarMonthSwipe.monthOffset(translation:"))
        XCTAssertTrue(source.contains("CalendarMonthSwipe.followOffset(translation:"))
    }
}
