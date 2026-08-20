import XCTest

final class CalendarBatchVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturesCenteredMonthlyDutySelector() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-calendar-batch",
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
            app.descendants(matching: .any)["screen.calendar"].waitForExistence(timeout: 10)
        )

        let quickEditButton = app.buttons["calendar.duty.quick.start"]
        XCTAssertTrue(quickEditButton.waitForExistence(timeout: 10))
        quickEditButton.tap()

        let batchUpdateButton = app.buttons["calendar.duty.batch.open"]
        XCTAssertTrue(batchUpdateButton.waitForExistence(timeout: 10))
        batchUpdateButton.tap()

        let title = app.staticTexts["calendar.duty.batch.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["calendar.duty.batch.option.101"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["calendar.duty.batch.option.102"].exists)
        XCTAssertTrue(app.buttons["calendar.duty.batch.cancel"].exists)
        XCTAssertEqual(title.frame.midX, app.frame.midX, accuracy: 20)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "parity-ios-calendar-batch-selection-after"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
