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

        let destinations = [
            (tab: "tab.home", screen: "screen.home"),
            (tab: "tab.calendar", screen: "screen.calendar"),
            (tab: "tab.todo", screen: "screen.todo"),
            (tab: "tab.team", screen: "screen.team"),
            (tab: "tab.settings", screen: "screen.settings")
        ]

        for destination in destinations {
            let tab = primaryTab(destination.tab, in: app)
            tab.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)[destination.screen].waitForExistence(timeout: 10)
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
            "-AppleLocale", "ko_KR",
            "-ui-testing-guest"
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

        primaryTab("tab.todo", in: app).tap()
        let todoAdd = app.buttons["todo.add"]
        XCTAssertTrue(waitForTodoToolbarAction(todoAdd, in: app, timeout: 10))
        assertMinimumTouchTarget(todoAdd)
    }

    @MainActor
    private func primaryTab(
        _ identifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let tab = app.buttons.matching(identifier: identifier).firstMatch
        XCTAssertTrue(
            tab.waitForExistence(timeout: timeout),
            "Primary tab did not appear: \(identifier)",
            file: file,
            line: line
        )
        return tab
    }

    @MainActor
    private func waitForTodoToolbarAction(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let loadErrorAlert = app.alerts["Todo error"]

        while Date() < deadline {
            if element.exists { return true }

            if loadErrorAlert.exists,
               loadErrorAlert.staticTexts["Failed to load Todos."].exists {
                let dismissButton = loadErrorAlert.buttons["OK"]
                guard dismissButton.exists else { return false }
                dismissButton.tap()
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return element.exists
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
