import XCTest

final class SocialViewEntryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFriendManagementOpensWithoutCrashing() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20)
        )

        let menuButton = app.buttons["home.menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 10))
        menuButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.menu"].waitForExistence(timeout: 10)
        )

        let friendManagementButton = app.buttons["친구관리"].firstMatch
        XCTAssertTrue(friendManagementButton.waitForExistence(timeout: 10))
        friendManagementButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["social.list"].waitForExistence(timeout: 10)
        )

        let firstFriend = app.descendants(matching: .any)["social.friend.31"]
        let secondFriend = app.descendants(matching: .any)["social.friend.32"]
        XCTAssertTrue(firstFriend.waitForExistence(timeout: 10))
        XCTAssertTrue(secondFriend.waitForExistence(timeout: 10))
        let initialFirstY = firstFriend.frame.minY
        let initialSecondY = secondFriend.frame.minY
        capture("parity-ios-friends-after")

        firstFriend.press(
            forDuration: 0.5,
            thenDragTo: secondFriend,
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertGreaterThan(initialSecondY, initialFirstY)
        XCTAssertGreaterThan(firstFriend.frame.minY, secondFriend.frame.minY)
        capture("parity-ios-friends-reordered-after")
    }

    @MainActor
    func testRemoveFriendUsesCenteredSharedConfirmation() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20)
        )
        app.buttons["home.menu"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.menu"].waitForExistence(timeout: 10)
        )
        let friendManagementButton = app.buttons["친구관리"].firstMatch
        XCTAssertTrue(friendManagementButton.waitForExistence(timeout: 10))
        friendManagementButton.tap()
        let socialList = app.descendants(matching: .any)["social.list"]
        XCTAssertTrue(socialList.waitForExistence(timeout: 10))

        let pinButton = socialList.buttons["social.friend.31.pin"]
        XCTAssertTrue(pinButton.waitForExistence(timeout: 10))
        XCTAssertTrue(pinButton.isHittable)
        let moreButton = socialList.buttons["social.friend.31.more"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 10))
        XCTAssertTrue(
            moreButton.isHittable,
            "pin=\(pinButton.frame) more=\(moreButton.frame) list=\(socialList.frame) app=\(app.frame)"
        )
        moreButton.tap()
        let removeButton = app.buttons
            .matching(NSPredicate(format: "label == %@", "친구 삭제"))
            .firstMatch
        XCTAssertTrue(removeButton.waitForExistence(timeout: 10))
        removeButton.tap()

        let cancelButton = app.buttons["dp.confirmation.cancel"]
        let confirmButton = app.buttons["dp.confirmation.confirm"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10))
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))
        XCTAssertEqual(
            (cancelButton.frame.midX + confirmButton.frame.midX) / 2,
            app.frame.midX,
            accuracy: 20
        )
        capture("parity-ios-friend-delete-confirmation-after")

        cancelButton.tap()
        XCTAssertTrue(confirmButton.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
