import XCTest

final class HomeFriendInteractionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A vertical drag that starts on a friend card belongs to the page, not to the
    /// rail and not to the card: it has to scroll the page, leave the rail's
    /// horizontal offset alone and open nothing. The home page only overflows once
    /// its content is tall enough, so this launches at an accessibility text size
    /// to guarantee there is something to scroll.
    @MainActor
    func testVerticalSwipeStartingOnPinnedCardScrollsWithoutOpeningCalendar() {
        let app = launchApp(contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))

        let pinnedFriend = app.buttons["home.friend.21"]
        XCTAssertTrue(pinnedFriend.waitForExistence(timeout: 10))
        home.swipeUp()
        let initial = pinnedFriend.frame
        let start = pinnedFriend.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 220)))

        let moved = pinnedFriend.frame
        XCTAssertGreaterThan(
            moved.minY,
            initial.minY + 10,
            "A vertical drag from a friend card must scroll the page. Card moved from "
                + "\(initial) to \(moved)"
        )
        XCTAssertEqual(
            moved.minX,
            initial.minX,
            accuracy: 2,
            "A vertical drag must not scroll the friend rail sideways"
        )
        XCTAssertTrue(home.exists)
        XCTAssertFalse(anyCalendar(app).exists)
        attachScreenshot(named: "home-friend-card-vertical-swipe")
    }

    /// The friend list is a horizontal rail now, so a sideways drag has to scroll
    /// the rail rather than count as a tap on the card it started on.
    @MainActor
    func testHorizontalSwipeScrollsTheFriendRailWithoutOpeningCalendar() {
        let app = launchApp(manyPinnedFriends: true)
        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        home.swipeUp()

        let firstFriend = app.buttons["home.friend.31"]
        XCTAssertTrue(firstFriend.waitForExistence(timeout: 10))
        let initialX = firstFriend.frame.minX
        let initialY = firstFriend.frame.minY

        firstFriend.swipeLeft(velocity: .slow)

        XCTAssertLessThan(
            firstFriend.frame.minX,
            initialX - 10,
            "A sideways swipe should scroll the friend rail"
        )
        XCTAssertEqual(
            firstFriend.frame.minY,
            initialY,
            accuracy: 2,
            "Scrolling the rail must not move the page"
        )
        XCTAssertTrue(home.exists)
        XCTAssertFalse(anyCalendar(app).exists)
        attachScreenshot(named: "home-friend-rail-horizontal-swipe")
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
        XCTAssertFalse(anyCalendar(app).exists)

        app.buttons["home.friend.22"].tap()
        XCTAssertTrue(
            memberCalendar(app).waitForExistence(timeout: 10),
            "Tapping a pinned card must open that friend's calendar"
        )
        attachScreenshot(named: "home-pinned-friend-calendar")

        app.buttons.matching(identifier: "tab.home").firstMatch.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        home.swipeUp()
        app.buttons["home.friend.23"].tap()
        XCTAssertTrue(
            memberCalendar(app).waitForExistence(timeout: 10),
            "Tapping an unpinned card must open that friend's calendar"
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
        let initialFrame = unpinnedFriend.frame

        pinButton.tap()

        XCTAssertFalse(app.descendants(matching: .any)["home.loading"].exists)
        XCTAssertTrue(unpinnedFriend.exists)
        XCTAssertEqual(unpinnedFriend.frame.minY, initialFrame.minY, accuracy: 10)
        XCTAssertEqual(unpinnedFriend.frame.minX, initialFrame.minX, accuracy: 10)
        XCTAssertEqual(pinButton.label, "고정 해제")

        pinButton.tap()

        XCTAssertFalse(app.descendants(matching: .any)["home.loading"].exists)
        XCTAssertTrue(unpinnedFriend.exists)
        XCTAssertEqual(pinButton.label, "고정")
        XCTAssertTrue(home.exists)
        XCTAssertFalse(anyCalendar(app).exists)
        attachScreenshot(named: "home-friend-pin-unpin-stable")
    }

    /// A long press on a pinned home card reorders the horizontal friend rail.
    @MainActor
    func testLongPressDragOnFriendCardReordersPinnedFriends() {
        let app = launchApp(manyPinnedFriends: true)
        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        home.swipeUp()

        let source = app.buttons["home.friend.31"]
        let target = app.buttons["home.friend.33"]
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        XCTAssertLessThan(source.frame.minX, target.frame.minX)

        source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.6,
            thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
            withVelocity: .slow,
            thenHoldForDuration: 0.3
        )

        XCTAssertGreaterThan(
            source.frame.minX,
            target.frame.minX,
            "A long press drag must reorder the home friend rail"
        )
        XCTAssertTrue(home.exists)
        XCTAssertFalse(anyCalendar(app).exists)
        attachScreenshot(named: "home-friend-long-press-reordered")
    }

    /// D1/D7: a friend without a team, or without a duty, still gets a card of the
    /// exact same size, which is what keeps the rail from looking ragged.
    @MainActor
    func testEveryFriendCardHasTheSameSizeRegardlessOfTeamOrDuty() {
        let app = launchApp(manyPinnedFriends: true)
        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        home.swipeUp()

        let reference = app.buttons["home.friend.31"]
        XCTAssertTrue(reference.waitForExistence(timeout: 10))
        let expected = reference.frame.size
        XCTAssertGreaterThan(expected.width, 0)
        XCTAssertGreaterThan(expected.height, 0)

        // 32 has no team, 33 has a team but no duty, 34 has neither, 35 carries a
        // long team name and 36 is off duty.
        for id in [32, 33, 34, 35, 36] {
            let card = app.buttons["home.friend.\(id)"]
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            XCTAssertEqual(
                card.frame.height,
                expected.height,
                accuracy: 1,
                "home.friend.\(id) must be exactly as tall as every other card"
            )
            XCTAssertEqual(
                card.frame.width,
                expected.width,
                accuracy: 1,
                "home.friend.\(id) must be exactly as wide as every other card"
            )
        }
        attachScreenshot(named: "home-friend-rail-uniform-cards")
    }

    /// A friend's calendar is pushed onto the home tab's stack, so it identifies as
    /// the member calendar rather than the calendar tab.
    @MainActor
    private func memberCalendar(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["screen.calendar.member"]
    }

    @MainActor
    private func anyCalendar(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "screen.calendar"))
            .firstMatch
    }

    @MainActor
    private func launchApp(
        manyPinnedFriends: Bool = false,
        contentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ]
        if manyPinnedFriends {
            app.launchArguments.append("-ui-testing-home-many-pinned")
        }
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
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
