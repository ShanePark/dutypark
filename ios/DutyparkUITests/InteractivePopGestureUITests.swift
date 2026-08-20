import XCTest

final class InteractivePopGestureUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTeamManageReturnsToTeamWithLeftEdgeSwipe() {
        let app = XCUIApplication()
        app.launchArguments += [
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

    // A member calendar is pushed onto the stack of the tab it was opened from, so the
    // tab keeps its selection and both the identity chip and the edge swipe pop back to
    // the shift grid. The authenticated UI-testing calendar fixture always resolves to
    // the signed-in member, so this covers the "my own calendar" push that a shift grid
    // and Admin can also produce.
    @MainActor
    func testMemberCalendarPushedFromTheTeamTabPopsBackToTheShiftGrid() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-team-fixture",
            "-ui-testing-team-shift-fixture",
        ]
        app.launch()
        defer { app.terminate() }

        let teamTab = app.buttons.matching(identifier: "tab.team").firstMatch
        XCTAssertTrue(teamTab.waitForExistence(timeout: 20))
        teamTab.tap()

        let memberCard = app.buttons["김듀티"].firstMatch
        XCTAssertTrue(memberCard.waitForExistence(timeout: 10))
        for _ in 0..<6 where !memberCard.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(memberCard.isHittable)
        memberCard.tap()

        let memberCalendar = app.descendants(matching: .any)["screen.calendar.member"]
        XCTAssertTrue(memberCalendar.waitForExistence(timeout: 10))
        XCTAssertTrue(
            teamTab.isSelected,
            "A member calendar opened from the team tab must not jump to the calendar tab"
        )

        swipeFromLeftEdge(in: app)

        XCTAssertTrue(memberCalendar.waitForNonExistence(timeout: 5))
        XCTAssertTrue(memberCard.waitForExistence(timeout: 5))
        XCTAssertTrue(teamTab.isSelected)

        for _ in 0..<6 where !memberCard.isHittable {
            app.swipeUp()
        }
        memberCard.tap()
        XCTAssertTrue(memberCalendar.waitForExistence(timeout: 10))

        let identityChip = app.buttons["calendar.member.back"].firstMatch
        XCTAssertTrue(identityChip.waitForExistence(timeout: 10))
        identityChip.tap()

        XCTAssertTrue(memberCalendar.waitForNonExistence(timeout: 5))
        XCTAssertTrue(memberCard.waitForExistence(timeout: 5))
        XCTAssertTrue(teamTab.isSelected)
    }

    // The home dashboard opens a pinned friend's calendar through its own route, which
    // pushes onto the home stack instead of switching to the calendar tab.
    @MainActor
    func testMemberCalendarPushedFromTheHomeDashboardPopsBackToIt() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ]
        app.launch()
        defer { app.terminate() }

        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        let homeTab = app.buttons.matching(identifier: "tab.home").firstMatch

        let friendCard = app.buttons["home.friend.21"]
        XCTAssertTrue(friendCard.waitForExistence(timeout: 10))
        for _ in 0..<6 where !friendCard.isHittable {
            home.swipeUp(velocity: .slow)
        }
        friendCard.tap()

        let memberCalendar = app.descendants(matching: .any)["screen.calendar.member"]
        XCTAssertTrue(memberCalendar.waitForExistence(timeout: 10))
        XCTAssertTrue(
            homeTab.isSelected,
            "A friend calendar opened from the dashboard must not jump to the calendar tab"
        )

        swipeFromLeftEdge(in: app)

        XCTAssertTrue(memberCalendar.waitForNonExistence(timeout: 5))
        XCTAssertTrue(friendCard.waitForExistence(timeout: 10))
        XCTAssertTrue(homeTab.isSelected)
    }

    @MainActor
    private func swipeFromLeftEdge(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
}
