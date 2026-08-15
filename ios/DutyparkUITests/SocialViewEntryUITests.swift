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
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
