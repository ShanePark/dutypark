import XCTest

final class SocialFriendReorderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLongPressDragReordersSixFriendsAndSavesOnceWithoutReload() {
        let app = launchSocial()
        let list = app.descendants(matching: .any)["social.list"]
        let first = app.buttons["social.friend.31"]
        let second = app.buttons["social.friend.32"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(second.waitForExistence(timeout: 10))
        let firstY = first.frame.minY
        let secondY = second.frame.minY

        first.press(
            forDuration: 0.4,
            thenDragTo: second,
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        XCTAssertGreaterThan(first.frame.minY, second.frame.minY)
        XCTAssertEqual(second.frame.minY, firstY, accuracy: 12)
        XCTAssertEqual(first.frame.minY, secondY, accuracy: 12)
        XCTAssertFalse(app.descendants(matching: .any)["social.loading"].exists)
        XCTAssertTrue(list.exists)
        let saveCount = app.staticTexts["social.reorder.saveCount"]
        XCTAssertEqual(saveCount.label, "1")
        XCTAssertFalse(app.descendants(matching: .any)["screen.calendar"].exists)
        let sixthFriend = app.buttons["social.friend.36"]
        for _ in 0..<4 where !sixthFriend.exists {
            list.swipeUp()
        }
        XCTAssertTrue(sixthFriend.waitForExistence(timeout: 5))
        capture("social-six-friends-reordered")
    }

    @MainActor
    func testFriendCardVerticalSwipeScrollsWithoutReorderOrCalendarNavigation() {
        let app = launchSocial()
        let list = app.descendants(matching: .any)["social.list"]
        let first = app.buttons["social.friend.31"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        let initialY = first.frame.minY
        let start = first.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5))
        start.press(
            forDuration: 0.05,
            thenDragTo: start.withOffset(CGVector(dx: 0, dy: -220))
        )

        XCTAssertLessThan(first.frame.minY, initialY - 10)
        XCTAssertTrue(list.exists)
        XCTAssertEqual(app.staticTexts["social.reorder.saveCount"].label, "0")
        XCTAssertFalse(app.descendants(matching: .any)["screen.calendar"].exists)
        capture("social-friend-card-vertical-swipe")
    }

    @MainActor
    func testFriendCardTapOpensCalendar() {
        let app = launchSocial()
        let friendCard = app.buttons["social.friend.31"]
        XCTAssertTrue(friendCard.waitForExistence(timeout: 10))
        friendCard.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.calendar.member"].waitForExistence(timeout: 10)
        )
        capture("social-friend-card-calendar")
    }

    @MainActor
    private func launchSocial() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-social-reorder",
        ]
        app.launch()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20)
        )
        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.more"].waitForExistence(timeout: 10)
        )
        let friendManagement = app.buttons["more.friends"].firstMatch
        XCTAssertTrue(friendManagement.waitForExistence(timeout: 10))
        friendManagement.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["social.list"].waitForExistence(timeout: 10)
        )
        return app
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
