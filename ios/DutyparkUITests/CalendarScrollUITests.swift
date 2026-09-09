import XCTest

/// The calendar grid pages sideways inside a page that scrolls down. A finger almost
/// never sets off straight up, so a drag that leans a little sideways on its way has to
/// reach the scroll rather than the pager.
final class CalendarScrollUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAScrollThatSetsOffSidewaysStillMovesThePage() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            // Puts a landmark above the grid to measure the scroll by, and enough
            // below it for the page to have somewhere to scroll to.
            "-ui-testing-calendar-duty-types",
            "-ui-testing-calendar-tall",
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20)
        )

        let calendarTab = app.buttons.matching(identifier: "tab.calendar").firstMatch
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 10))
        calendarTab.tap()

        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "screen.calendar")
                .firstMatch.waitForExistence(timeout: 10)
        )

        let month = app.descendants(matching: .any)["calendar.month.display"]
        XCTAssertTrue(month.waitForExistence(timeout: 10))
        let monthBefore = month.label

        let anchor = app.buttons["calendar.duty.quick.start"]
        XCTAssertTrue(anchor.waitForExistence(timeout: 10))
        let topOfPage = anchor.frame.minY

        // The page has to be able to scroll at all, and the drag the test makes has to
        // be able to scroll it, before a leaning drag proves anything.
        app.swipeUp()
        XCTAssertLessThan(anchor.frame.minY, topOfPage - 20, "The page has nothing to scroll")
        app.swipeDown()

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let straightUp = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        let leaningUp = app.coordinate(withNormalizedOffset: CGVector(dx: 0.66, dy: 0.4))

        let topBeforeStraight = anchor.frame.minY
        start.press(forDuration: 0.05, thenDragTo: straightUp)
        XCTAssertLessThan(
            anchor.frame.minY,
            topBeforeStraight - 20,
            "A drag straight up the screen did not scroll the page"
        )
        app.swipeDown()

        // Sets off over the grid and leans sideways on the way up: the drag a thumb
        // actually makes when it starts a scroll.
        let topBeforeLeaning = anchor.frame.minY
        start.press(forDuration: 0.05, thenDragTo: leaningUp)

        XCTAssertLessThan(
            anchor.frame.minY,
            topBeforeLeaning - 20,
            "A scroll that set off leaning sideways left the page where it was"
        )
        XCTAssertEqual(month.label, monthBefore, "The scroll turned into a month swipe")
    }
}
