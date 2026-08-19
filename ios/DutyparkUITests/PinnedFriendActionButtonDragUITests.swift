import XCTest

/// A reorder drag may start anywhere on a pinned card, including on top of the
/// row's trailing action buttons. Once the long press has been recognized the
/// buttons underneath must not fire when the finger lifts, otherwise reaching for
/// "anywhere on the card" silently unpins the friend or opens the action menu.
final class PinnedFriendActionButtonDragUITests: XCTestCase {
    private let pinLabel = "고정"
    private let unpinLabel = "고정 해제"
    private let removeFriendLabel = "친구 삭제"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSocialReorderDragStartingOnThePinButtonReordersInsteadOfUnpinning() {
        let app = launchSocial()
        let before = persistedOrder(app)
        XCTAssertEqual(before, ["31", "32", "33", "34", "35", "36"])

        let pin = app.buttons["social.friend.31.pin"]
        let target = app.buttons["social.friend.34.pin"]
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        XCTAssertEqual(pin.label, unpinLabel)

        pin.press(
            forDuration: 0.4,
            thenDragTo: target,
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        let after = persistedOrder(app)
        XCTAssertTrue(
            after.contains("31"),
            "A drag started on the star must not unpin the friend. Pinned order is "
                + after.joined(separator: ",")
        )
        XCTAssertEqual(
            Set(after),
            Set(before),
            "The pinned set must be unchanged. Pinned order is " + after.joined(separator: ",")
        )
        XCTAssertEqual(app.buttons["social.friend.31.pin"].label, unpinLabel)
        XCTAssertNotEqual(
            after,
            before,
            "A drag started on the star must still reorder. Order stayed "
                + after.joined(separator: ",")
        )
        capture("social-pin-button-drag-reorders")
    }

    @MainActor
    func testSocialReorderDragStartingOnTheMoreButtonDoesNotOpenTheActionMenu() {
        let app = launchSocial()
        let before = persistedOrder(app)
        XCTAssertEqual(before, ["31", "32", "33", "34", "35", "36"])

        let more = app.buttons["social.friend.31.more"]
        let target = app.buttons["social.friend.34.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        XCTAssertTrue(target.waitForExistence(timeout: 10))

        more.press(
            forDuration: 0.4,
            thenDragTo: target,
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        XCTAssertFalse(
            app.buttons[removeFriendLabel].exists,
            "A drag started on the more button must not open the friend action menu."
        )
        let after = persistedOrder(app)
        XCTAssertEqual(Set(after), Set(before))
        XCTAssertNotEqual(
            after,
            before,
            "A drag started on the more button must still reorder. Order stayed "
                + after.joined(separator: ",")
        )
        capture("social-more-button-drag-reorders")
    }

    @MainActor
    func testSocialPinAndMoreButtonsStillRespondToPlainTaps() {
        let app = launchSocial()
        let pin = app.buttons["social.friend.31.pin"]
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        XCTAssertEqual(pin.label, unpinLabel)

        pin.tap()
        XCTAssertTrue(waitForLabel(pin, equals: pinLabel))
        XCTAssertFalse(app.descendants(matching: .any)["screen.calendar"].exists)

        pin.tap()
        XCTAssertTrue(waitForLabel(pin, equals: unpinLabel))

        app.buttons["social.friend.31.more"].tap()
        XCTAssertTrue(
            app.buttons[removeFriendLabel].waitForExistence(timeout: 10),
            "A plain tap on the more button must still open the friend action menu."
        )
        capture("social-action-buttons-plain-taps")
    }

    @MainActor
    func testHomeReorderDragStartingOnThePinButtonReordersInsteadOfUnpinning() {
        let app = launchHome()
        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))

        let source = app.buttons["home.friend.31"]
        let target = app.buttons["home.friend.34"]
        let pin = app.buttons["home.friend.31.pin"]
        for _ in 0..<6 where !(source.isHittable && target.isHittable) {
            home.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(source.isHittable)
        XCTAssertTrue(target.isHittable)
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        XCTAssertEqual(pin.label, unpinLabel)
        XCTAssertLessThan(source.frame.minY, target.frame.minY)

        // Drop where the dragged row's own star ends up once the live reorder has
        // shifted it down, so the finger lifts inside the star's frame.
        let end = app.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: pin.frame.midX, dy: target.frame.minY + pin.frame.height / 2)
        )
        pin.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.4,
            thenDragTo: end,
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        // Unpinning moves the row to the bottom of the list, out of the LazyVStack's
        // instantiated range, so a missing star is itself the unpin symptom.
        let pinAfter = app.buttons["home.friend.31.pin"]
        XCTAssertTrue(
            pinAfter.waitForExistence(timeout: 5),
            "A drag started on the star must not unpin the friend: the row left the pinned section."
        )
        XCTAssertEqual(
            pinAfter.label,
            unpinLabel,
            "A drag started on the star must not unpin the friend."
        )
        XCTAssertGreaterThan(
            app.buttons["home.friend.31"].frame.minY,
            app.buttons["home.friend.34"].frame.minY,
            "A drag started on the star must still reorder the pinned friend downwards."
        )
        XCTAssertFalse(app.descendants(matching: .any)["screen.calendar"].exists)
        capture("home-pin-button-drag-reorders")
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, equals label: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in element.label == label },
            object: nil
        )
        return XCTWaiter.wait(for: [expectation], timeout: 10) == .completed
    }

    @MainActor
    private func persistedOrder(_ app: XCUIApplication) -> [String] {
        let probe = app.staticTexts["social.reorder.persistedOrder"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10))
        return probe.label.split(separator: ",").map(String.init)
    }

    @MainActor
    private func launchSocial() -> XCUIApplication {
        let app = launch(extraArguments: ["-ui-testing-social-reorder"])
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
    private func launchHome() -> XCUIApplication {
        launch(extraArguments: ["-ui-testing-home-many-pinned"])
    }

    @MainActor
    private func launch(extraArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ] + extraArguments
        app.launch()
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
