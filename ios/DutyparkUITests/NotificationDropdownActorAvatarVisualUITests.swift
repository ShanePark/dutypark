import XCTest

final class NotificationDropdownActorAvatarVisualUITests: XCTestCase {
    private let profilePhotoNotificationID = "00000000-0000-0000-0000-000000000101"
    private let fallbackNotificationID = "00000000-0000-0000-0000-000000000102"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDropdownShowsActorProfilePhotoAndFallbackAvatar() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-notification-fixture",
            "-ui-testing-notification-actor-avatar",
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"]
                .waitForExistence(timeout: 20)
        )

        let bell = app.buttons["notifications.bell"]
        XCTAssertTrue(bell.waitForExistence(timeout: 10))
        bell.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["notifications.dropdown"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "notifications.dropdown.row.\(profilePhotoNotificationID).avatar.photo"
            ].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "notifications.dropdown.row.\(fallbackNotificationID).avatar.fallback"
            ].waitForExistence(timeout: 10)
        )

        capture("parity-ios-notification-dropdown-actor-avatar-after")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
