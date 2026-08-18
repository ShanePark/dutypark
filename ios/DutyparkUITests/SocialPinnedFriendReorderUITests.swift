import XCTest

final class SocialPinnedFriendReorderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLongPressDragReordersSixPinnedFriendsAndSavesOnceWithoutReload() {
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
        let sixthPinButton = app.buttons["social.friend.36.pin"]
        for _ in 0..<4 where !sixthPinButton.exists {
            list.swipeUp()
        }
        XCTAssertTrue(sixthPinButton.waitForExistence(timeout: 5))
        capture("social-six-pinned-reordered")
    }

    @MainActor
    func testPinnedCardVerticalSwipeScrollsWithoutReorderOrCalendarNavigation() {
        let app = launchSocial()
        let list = app.descendants(matching: .any)["social.list"]
        let first = app.buttons["social.friend.31"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        let initialY = first.frame.minY
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).press(
            forDuration: 0.05,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        )

        XCTAssertLessThan(first.frame.minY, initialY - 10)
        XCTAssertTrue(list.exists)
        XCTAssertEqual(app.staticTexts["social.reorder.saveCount"].label, "0")
        XCTAssertFalse(app.descendants(matching: .any)["screen.calendar"].exists)
        capture("social-pinned-card-vertical-swipe")
    }

    @MainActor
    func testPinButtonDoesNotNavigateAndPinnedCardTapStillOpensCalendar() {
        let app = launchSocial()
        let pinButton = app.buttons["social.friend.31.pin"]
        XCTAssertTrue(pinButton.waitForExistence(timeout: 10))

        pinButton.tap()

        XCTAssertFalse(app.descendants(matching: .any)["screen.calendar"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["social.list"].exists)

        let pinnedCard = app.buttons["social.friend.32"]
        XCTAssertTrue(pinnedCard.waitForExistence(timeout: 10))
        pinnedCard.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.calendar"].waitForExistence(timeout: 10)
        )
        capture("social-pinned-card-calendar")
    }

    @MainActor
    private func launchSocial() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
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
