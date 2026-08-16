import XCTest

final class CalendarSearchPlaceholderVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testKoreanSearchPlaceholderMatchesWebAndFitsOnIPhone13Mini() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
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

        let openSearch = app.buttons["일정 검색"]
        XCTAssertTrue(openSearch.waitForExistence(timeout: 10))
        openSearch.tap()

        let expectedPlaceholder = "제목이나 상세로 검색"
        let searchField = app.textFields[expectedPlaceholder]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        XCTAssertTrue(searchField.isHittable)
        XCTAssertGreaterThan(searchField.frame.width, 180)
        XCTAssertLessThanOrEqual(searchField.frame.maxX, app.frame.maxX - 48)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "parity-ios-calendar-search-placeholder-after"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
