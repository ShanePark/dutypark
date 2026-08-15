import XCTest

final class SettingsRootConfirmationVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSettingsLogoutUsesCenteredKoreanConfirmation() {
        let app = launchAuthenticatedApp()
        defer { app.terminate() }

        openSettings(in: app)
        let logoutButton = app.buttons["settings.logout"]
        XCTAssertTrue(revealSettingsElement(logoutButton, in: app))
        logoutButton.tap()

        assertCenteredConfirmation(
            in: app,
            title: "로그아웃",
            message: "정말 로그아웃 하시겠습니까?",
            confirmTitle: "로그아웃"
        )
        capture("parity-ios-settings-logout-confirmation-after")
    }

    @MainActor
    func testProfilePhotoDeleteUsesCenteredKoreanConfirmation() {
        let app = launchAuthenticatedApp(profilePhotoFixture: true)
        defer { app.terminate() }

        openSettings(in: app)
        let deleteButton = app.buttons["settings.photo.delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        XCTAssertTrue(deleteButton.isHittable)
        deleteButton.tap()

        assertCenteredConfirmation(
            in: app,
            title: "프로필 사진 삭제",
            message: "현재 프로필 사진을 삭제하시겠습니까?",
            confirmTitle: "프로필 사진 삭제"
        )
        capture("parity-ios-profile-photo-delete-confirmation-after")
    }

    @MainActor
    func testRootMenuLogoutUsesCenteredKoreanConfirmation() {
        let app = launchAuthenticatedApp()
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

        let logoutButton = app.buttons["menu.logout"]
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 10))
        XCTAssertTrue(logoutButton.isHittable)
        logoutButton.tap()

        assertCenteredConfirmation(
            in: app,
            title: "로그아웃",
            message: "정말 로그아웃 하시겠습니까?",
            confirmTitle: "로그아웃"
        )
        capture("parity-ios-root-menu-logout-confirmation-after")
    }

    @MainActor
    private func launchAuthenticatedApp(profilePhotoFixture: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ]
        if profilePhotoFixture {
            app.launchArguments.append("-ui-testing-profile-photo")
        }
        app.launch()
        return app
    }

    @MainActor
    private func openSettings(in app: XCUIApplication) {
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20)
        )
        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.settings"].waitForExistence(timeout: 10)
        )
    }

    @MainActor
    private func revealSettingsElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 10
    ) -> Bool {
        let scrollView = app.scrollViews["screen.settings"].firstMatch
        guard scrollView.waitForExistence(timeout: 2) else { return false }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, !element.isHittable {
            scrollView.swipeUp(velocity: .fast)
        }
        return element.isHittable
    }

    @MainActor
    private func assertCenteredConfirmation(
        in app: XCUIApplication,
        title: String,
        message: String,
        confirmTitle: String
    ) {
        let titleText = app.staticTexts[title].firstMatch
        let messageText = app.staticTexts[message].firstMatch
        let cancelButton = app.buttons["dp.confirmation.cancel"]
        let confirmButton = app.buttons["dp.confirmation.confirm"]

        XCTAssertTrue(titleText.waitForExistence(timeout: 10))
        XCTAssertTrue(messageText.waitForExistence(timeout: 10))
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10))
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))
        XCTAssertEqual(cancelButton.label, "취소")
        XCTAssertEqual(confirmButton.label, confirmTitle)
        XCTAssertEqual(
            (cancelButton.frame.midX + confirmButton.frame.midX) / 2,
            app.frame.midX,
            accuracy: 20
        )
    }

    @MainActor
    private func capture(_ name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
