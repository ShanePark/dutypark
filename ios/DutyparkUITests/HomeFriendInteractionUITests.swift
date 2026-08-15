import XCTest

final class HomeFriendInteractionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testVerticalSwipeStartingOnPinnedCardScrollsWithoutOpeningCalendar() {
        let app = launchApp()
        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))

        home.swipeUp()
        let pinnedFriend = app.buttons["home.friend.21"]
        XCTAssertTrue(pinnedFriend.waitForExistence(timeout: 10))
        let initialY = pinnedFriend.frame.minY
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        pinnedFriend.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).press(
            forDuration: 0.05,
            thenDragTo: destination
        )

        XCTAssertGreaterThan(pinnedFriend.frame.minY, initialY + 10)
        XCTAssertTrue(home.exists)
        XCTAssertFalse(app.descendants(matching: .any)["screen.calendar"].exists)
        attachScreenshot(named: "home-friend-card-vertical-swipe")
    }

    @MainActor
    func testPinnedAndUnpinnedFriendCardsOpenCalendarButPinButtonDoesNot() {
        let app = launchApp()
        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        home.swipeUp()

        let pinnedPinButton = app.buttons["home.friend.21.pin"]
        XCTAssertTrue(pinnedPinButton.waitForExistence(timeout: 10))
        pinnedPinButton.tap()
        XCTAssertTrue(home.exists)
        XCTAssertFalse(app.descendants(matching: .any)["screen.calendar"].exists)

        app.buttons["home.friend.22"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.calendar"].waitForExistence(timeout: 10)
        )
        attachScreenshot(named: "home-pinned-friend-calendar")

        app.buttons.matching(identifier: "tab.home").firstMatch.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        home.swipeUp()
        app.buttons["home.friend.23"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.calendar"].waitForExistence(timeout: 10)
        )
        attachScreenshot(named: "home-unpinned-friend-calendar")
    }

    @MainActor
    func testPinAndUnpinKeepFriendContentVisibleWithoutViewportJump() {
        let app = launchApp()
        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        home.swipeUp()

        let unpinnedFriend = app.buttons["home.friend.23"]
        let pinButton = app.buttons["home.friend.23.pin"]
        XCTAssertTrue(unpinnedFriend.waitForExistence(timeout: 10))
        XCTAssertTrue(pinButton.waitForExistence(timeout: 10))
        let initialY = unpinnedFriend.frame.minY

        pinButton.tap()

        XCTAssertFalse(app.descendants(matching: .any)["home.loading"].exists)
        XCTAssertTrue(unpinnedFriend.exists)
        XCTAssertEqual(unpinnedFriend.frame.minY, initialY, accuracy: 10)
        XCTAssertEqual(pinButton.label, "고정 해제")

        pinButton.tap()

        XCTAssertFalse(app.descendants(matching: .any)["home.loading"].exists)
        XCTAssertTrue(unpinnedFriend.exists)
        XCTAssertEqual(pinButton.label, "고정")
        XCTAssertTrue(home.exists)
        XCTAssertFalse(app.descendants(matching: .any)["screen.calendar"].exists)
        attachScreenshot(named: "home-friend-pin-unpin-stable")
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
