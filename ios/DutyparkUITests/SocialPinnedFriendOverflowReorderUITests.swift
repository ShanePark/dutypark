import XCTest

/// Covers the reported "친구관리" symptom: with more pinned friends than fit on
/// screen the `LazyVStack` publishes drop-target frames only for the rows inside
/// the viewport, so a live reorder must not depend on a complete frame set.
final class SocialPinnedFriendOverflowReorderUITests: XCTestCase {
    private let seededOrder = (0..<18).map { String(41 + $0) }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPinnedFriendFixtureOverflowsViewportSoLazyStackDropsDropTargets() {
        let app = launchSocial()

        XCTAssertEqual(persistedOrder(app), seededOrder)
        let publishedTargets = dropTargetCount(app)
        XCTAssertLessThan(
            publishedTargets,
            seededOrder.count,
            "The fixture must overflow the viewport: the LazyVStack published \(publishedTargets) "
                + "of \(seededOrder.count) pinned drop targets."
        )
        XCTAssertFalse(
            app.buttons["social.friend.\(seededOrder[seededOrder.count - 1])"].isHittable,
            "The last pinned friend must be scrolled out of the viewport."
        )
        let onScreen = hittablePinnedCount(app)
        XCTAssertLessThan(
            onScreen,
            seededOrder.count / 2,
            "Most pinned cards must start off-screen; \(onScreen) are on screen."
        )
        XCTAssertLessThan(
            existingPinnedCount(app),
            seededOrder.count,
            "The LazyVStack must leave some pinned rows uninstantiated."
        )
        capture("social-overflow-pinned-list")
    }

    /// a. The drag has to reorder and persist even though several pinned rows
    ///    publish no drop-target frame.
    @MainActor
    func testReorderPersistsWhilePinnedRowsAreOutsideTheViewport() {
        let app = launchSocial()
        let before = persistedOrder(app)
        XCTAssertEqual(before, seededOrder)
        XCTAssertLessThan(dropTargetCount(app), before.count)

        let source = app.buttons["social.friend.41"]
        let target = app.buttons["social.friend.44"]
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        XCTAssertTrue(target.waitForExistence(timeout: 10))

        source.press(
            forDuration: 0.4,
            thenDragTo: target,
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        let after = persistedOrder(app)
        XCTAssertNotEqual(
            after,
            before,
            "Dragging a pinned friend down must reorder the list even when rows are off-screen. "
                + "Order stayed \(after.joined(separator: ","))."
        )
        XCTAssertEqual(
            app.staticTexts["social.reorder.saveCount"].label,
            "1",
            "The new pinned order must be saved exactly once."
        )
        XCTAssertEqual(
            after.firstIndex(of: "41"),
            3,
            "The dragged friend must land on the drop target's slot. Order is "
                + after.joined(separator: ",")
        )
        XCTAssertEqual(Set(after), Set(before))
        XCTAssertFalse(app.descendants(matching: .any)["screen.calendar"].exists)
        capture("social-overflow-reorder-persisted")
    }

    /// b. The whole card is the drag surface, not only the inner avatar+name button.
    @MainActor
    func testReorderDragStartingOutsideTheAvatarButtonReorders() {
        let app = launchSocial()
        let before = persistedOrder(app)
        XCTAssertEqual(before, seededOrder)
        XCTAssertLessThan(dropTargetCount(app), before.count)

        let source = app.buttons["social.friend.41"]
        let target = app.buttons["social.friend.44"]
        let pin = app.buttons["social.friend.41.pin"]
        let more = app.buttons["social.friend.41.more"]
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        XCTAssertTrue(more.waitForExistence(timeout: 10))

        // Trailing lower corner of the card: right of the avatar+name button and
        // below the pin/more action buttons, so only the card itself is hit.
        let grab = CGPoint(x: pin.frame.midX, y: source.frame.maxY + 8)
        XCTAssertFalse(source.frame.contains(grab), "Grab point must be outside the inner button.")
        XCTAssertFalse(pin.frame.contains(grab), "Grab point must be outside the pin button.")
        XCTAssertFalse(more.frame.contains(grab), "Grab point must be outside the more button.")

        let start = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: grab.x, dy: grab.y))
        let end = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: grab.x, dy: target.frame.maxY + 8))

        start.press(
            forDuration: 0.4,
            thenDragTo: end,
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        let after = persistedOrder(app)
        XCTAssertNotEqual(
            after,
            before,
            "A drag started on the card outside the avatar+name button must reorder. "
                + "Order stayed \(after.joined(separator: ","))."
        )
        XCTAssertEqual(app.staticTexts["social.reorder.saveCount"].label, "1")
        XCTAssertEqual(
            after.firstIndex(of: "41"),
            3,
            "The dragged friend must land on the drop target's slot. Order is "
                + after.joined(separator: ",")
        )
        XCTAssertFalse(app.descendants(matching: .any)["screen.calendar"].exists)
        capture("social-overflow-reorder-card-surface")
    }

    /// The reorder must also work upwards, from a row that was scrolled into view
    /// while the rows it moves past have left the viewport.
    @MainActor
    func testReorderUpwardsAfterScrollingWithEarlierRowsOutsideTheViewport() {
        let app = launchSocial()
        let before = persistedOrder(app)
        XCTAssertEqual(before, seededOrder)

        let list = app.descendants(matching: .any)["social.list"]
        let source = app.buttons["social.friend.56"]
        let target = app.buttons["social.friend.53"]
        for _ in 0..<8 where !(source.exists && target.exists && source.isHittable && target.isHittable) {
            list.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(source.isHittable)
        XCTAssertTrue(target.isHittable)
        XCTAssertLessThan(dropTargetCount(app), before.count)
        XCTAssertGreaterThan(source.frame.minY, target.frame.minY)

        source.press(
            forDuration: 0.4,
            thenDragTo: target,
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        let after = persistedOrder(app)
        XCTAssertNotEqual(
            after,
            before,
            "Dragging upwards must reorder while earlier rows are off-screen. "
                + "Order stayed \(after.joined(separator: ","))."
        )
        XCTAssertEqual(app.staticTexts["social.reorder.saveCount"].label, "1")
        XCTAssertEqual(
            after.firstIndex(of: "56"),
            12,
            "The dragged friend must land on the drop target's slot. Order is "
                + after.joined(separator: ",")
        )
        XCTAssertEqual(Set(after), Set(before))
        capture("social-overflow-reorder-upwards")
    }

    @MainActor
    private func hittablePinnedCount(_ app: XCUIApplication) -> Int {
        seededOrder.filter { app.buttons["social.friend.\($0)"].isHittable }.count
    }

    @MainActor
    private func existingPinnedCount(_ app: XCUIApplication) -> Int {
        seededOrder.filter { app.buttons["social.friend.\($0)"].exists }.count
    }

    @MainActor
    private func persistedOrder(_ app: XCUIApplication) -> [String] {
        let probe = app.staticTexts["social.reorder.persistedOrder"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10))
        return probe.label.split(separator: ",").map(String.init)
    }

    @MainActor
    private func dropTargetCount(_ app: XCUIApplication) -> Int {
        let probe = app.staticTexts["social.reorder.dropTargetCount"]
        XCTAssertTrue(probe.waitForExistence(timeout: 10))
        return Int(probe.label) ?? -1
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
            "-ui-testing-social-reorder-overflow",
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
