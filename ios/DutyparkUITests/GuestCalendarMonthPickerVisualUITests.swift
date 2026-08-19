import XCTest

final class GuestCalendarMonthPickerVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSelectsDistantMonthFromPublicCalendar() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-guest",
            "-ui-testing-guest-calendar"
        ]
        app.launch()

        let monthButton = app.buttons["guest.calendar.monthPicker.open"]
        XCTAssertTrue(monthButton.waitForExistence(timeout: 20))
        monthButton.tap()

        let picker = app.descendants(matching: .any)["guest.calendar.monthPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        attachScreenshot(named: "guest-calendar-month-picker", app: app)

        let nextYear = app.buttons["guest.calendar.monthPicker.nextYear"]
        XCTAssertTrue(nextYear.waitForExistence(timeout: 5))
        nextYear.tap()
        nextYear.tap()

        let february = app.buttons["guest.calendar.monthPicker.month.2"]
        XCTAssertTrue(february.waitForExistence(timeout: 5))
        february.tap()

        let requestedMonth = NSPredicate(format: "value == %@", "2028년 2월")
        expectation(for: requestedMonth, evaluatedWith: monthButton)
        waitForExpectations(timeout: 20)
        attachScreenshot(named: "guest-calendar-distant-month-selected", app: app)
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
