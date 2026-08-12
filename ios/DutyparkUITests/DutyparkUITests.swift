import XCTest

final class DutyparkUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNavigatesThroughFivePrimaryTabs() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "en",
            "-dp-theme", "light",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ui-testing-authenticated"
        ]
        app.launch()

        let tabBar = app.descendants(matching: .any)["primary.tabbar"]
        XCTAssertTrue(tabBar.waitForExistence(timeout: 2))

        let destinations = [
            (tab: "tab.home", screen: "screen.home"),
            (tab: "tab.calendar", screen: "screen.calendar"),
            (tab: "tab.todo", screen: "screen.todo"),
            (tab: "tab.team", screen: "screen.team"),
            (tab: "tab.settings", screen: "screen.settings")
        ]

        for destination in destinations {
            let tab = app.buttons[destination.tab]
            XCTAssertTrue(tab.waitForExistence(timeout: 2))
            tab.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)[destination.screen].waitForExistence(timeout: 2)
            )
        }
    }

    @MainActor
    func testLoginOffersKakaoAndNaver() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR"
        ]
        app.launch()

        let loginButton = app.buttons["guest.login"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10))
        loginButton.tap()

        XCTAssertTrue(app.buttons["login.oauth.kakao"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["login.oauth.naver"].exists)
    }

    @MainActor
    func testPrimaryToolbarActionsMeetMinimumTouchTarget() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "en",
            "-dp-theme", "light",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ui-testing-authenticated"
        ]
        app.launch()

        let notificationBell = app.buttons["notifications.bell"]
        XCTAssertTrue(notificationBell.waitForExistence(timeout: 10))
        assertMinimumTouchTarget(notificationBell)

        app.buttons["tab.todo"].tap()
        let todoAdd = app.buttons["todo.add"]
        XCTAssertTrue(todoAdd.waitForExistence(timeout: 10))
        assertMinimumTouchTarget(todoAdd)
    }

    @MainActor
    private func assertMinimumTouchTarget(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let pixelTolerance: CGFloat = 0.01
        let frame = element.frame
        let width = frame.width
        let height = frame.height
        XCTAssertGreaterThanOrEqual(width, 44 - pixelTolerance, file: file, line: line)
        XCTAssertGreaterThanOrEqual(height, 44 - pixelTolerance, file: file, line: line)
    }
}
