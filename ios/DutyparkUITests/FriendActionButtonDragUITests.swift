import XCTest

/// A reorder drag may start anywhere on a friend card, including on top of the
/// row's trailing action button. Once the long press has been recognized the
/// button underneath must not fire when the finger lifts.
final class FriendActionButtonDragUITests: XCTestCase {
    private let removeFriendLabel = "친구 삭제"

    override func setUpWithError() throws {
        continueAfterFailure = false
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
    func testSocialMoreButtonStillRespondsToPlainTap() {
        let app = launchSocial()
        app.buttons["social.friend.31.more"].tap()
        XCTAssertTrue(
            app.buttons[removeFriendLabel].waitForExistence(timeout: 10),
            "A plain tap on the more button must still open the friend action menu."
        )
        capture("social-action-buttons-plain-taps")
    }

    /// A drag that starts on a Home friend card must reorder the rail without
    /// opening the friend's calendar when the finger lifts elsewhere.
    @MainActor
    func testHomeDragStartingOnTheFriendCardReordersWithoutOpeningCalendar() {
        let app = launchHome()
        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))

        let source = app.buttons["home.friend.31"]
        let target = app.buttons["home.friend.33"]
        for _ in 0..<6 where !(source.isHittable && target.isHittable) {
            home.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(source.isHittable)
        XCTAssertTrue(target.isHittable)
        XCTAssertLessThan(source.frame.minX, target.frame.minX)

        source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.4,
            thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        XCTAssertGreaterThan(
            app.buttons["home.friend.31"].frame.minX,
            app.buttons["home.friend.33"].frame.minX,
            "The home rail must reorder the friend card."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "screen.calendar"))
                .firstMatch
                .exists,
            "A drag started on the friend card must not open the friend's calendar."
        )
        capture("home-friend-card-drag-reorders")
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
        launch(extraArguments: ["-ui-testing-home-many-friends"])
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
