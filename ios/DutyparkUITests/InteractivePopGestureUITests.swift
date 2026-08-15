import XCTest

final class InteractivePopGestureUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTeamManageReturnsToTeamWithLeftEdgeSwipe() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-team-fixture",
        ]
        app.launch()

        let teamTab = app.buttons.matching(identifier: "tab.team").firstMatch
        XCTAssertTrue(teamTab.waitForExistence(timeout: 10))
        teamTab.tap()

        let manageTeam = app.buttons["팀 관리"].firstMatch
        XCTAssertTrue(manageTeam.waitForExistence(timeout: 10))
        manageTeam.tap()

        let manageTitle = app.staticTexts["듀티파크 테스트팀 관리"]
        XCTAssertTrue(manageTitle.waitForExistence(timeout: 10))

        swipeFromLeftEdge(in: app)

        XCTAssertTrue(manageTitle.waitForNonExistence(timeout: 5))
        XCTAssertTrue(manageTeam.waitForExistence(timeout: 5))
        XCTAssertTrue(manageTeam.isHittable)
    }

    @MainActor
    func testGuestLoginReturnsToLandingWithLeftEdgeSwipe() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-guest",
        ]
        app.launch()

        let loginButton = app.buttons["guest.login"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10))
        loginButton.tap()

        let loginScreen = app.descendants(matching: .any)["screen.login"]
        XCTAssertTrue(loginScreen.waitForExistence(timeout: 10))

        let terms = app.buttons["이용약관"]
        XCTAssertTrue(terms.waitForExistence(timeout: 5))
        terms.tap()
        XCTAssertTrue(app.navigationBars["이용약관"].waitForExistence(timeout: 5))

        swipeFromLeftEdge(in: app)

        XCTAssertTrue(loginScreen.waitForExistence(timeout: 5))

        swipeFromLeftEdge(in: app)

        XCTAssertTrue(loginScreen.waitForNonExistence(timeout: 5))
        XCTAssertTrue(loginButton.waitForExistence(timeout: 5))
        XCTAssertTrue(loginButton.isHittable)
    }

    @MainActor
    private func swipeFromLeftEdge(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
}
