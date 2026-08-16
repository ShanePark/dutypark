import XCTest

final class SocialConnectionVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturesConnectedProviderAndCenteredUnlinkConfirmation() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-social-connections",
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

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.settings"].waitForExistence(timeout: 10)
        )

        let manageKakao = app.buttons["settings.social.manage.kakao"]
        scrollUntilHittable(manageKakao, in: app)
        XCTAssertTrue(manageKakao.isHittable)
        manageKakao.tap()

        let managementPanel = app.descendants(matching: .any)[
            "settings.social.management.panel.kakao"
        ]
        let connectedStatus = app.descendants(matching: .any)[
            "settings.social.management.status.kakao"
        ]
        let unlinkButton = app.buttons["settings.social.management.unlink.kakao"]
        XCTAssertTrue(managementPanel.waitForExistence(timeout: 10))
        XCTAssertTrue(connectedStatus.waitForExistence(timeout: 10))
        XCTAssertTrue(unlinkButton.waitForExistence(timeout: 10))
        XCTAssertTrue(unlinkButton.isEnabled)
        capture("parity-ios-social-connection-management-after")

        unlinkButton.tap()

        let cancelButton = app.buttons["dp.confirmation.cancel"]
        let confirmButton = app.buttons["dp.confirmation.confirm"]
        XCTAssertTrue(app.staticTexts["소셜 계정 연결을 해제할까요?"].waitForExistence(timeout: 10))
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10))
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))
        XCTAssertEqual(
            (cancelButton.frame.midX + confirmButton.frame.midX) / 2,
            app.frame.midX,
            accuracy: 20
        )
        capture("parity-ios-social-unlink-confirmation-after")

        cancelButton.tap()
        XCTAssertTrue(confirmButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(managementPanel.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAppleUnlinkPanelsExplainAuthorizationRevocation() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-apple-social-connection",
        ]
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20)
        )
        let menuButton = app.buttons["home.menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 10))
        menuButton.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.menu"].waitForExistence(timeout: 10)
        )

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.settings"].waitForExistence(timeout: 10)
        )

        let manageApple = app.buttons["settings.social.manage.apple"]
        scrollUntilHittable(manageApple, in: app)
        XCTAssertTrue(manageApple.isHittable)
        manageApple.tap()

        let managementPanel = app.descendants(matching: .any)[
            "settings.social.management.panel.apple"
        ]
        let unlinkButton = app.buttons["settings.social.management.unlink.apple"]
        XCTAssertTrue(managementPanel.waitForExistence(timeout: 10))
        XCTAssertTrue(unlinkButton.waitForExistence(timeout: 10))
        XCTAssertTrue(unlinkButton.isEnabled)
        XCTAssertTrue(
            app.staticTexts[
                "Apple 연동을 해제하면 Dutypark가 먼저 Apple 인증 권한을 철회한 뒤 연결 정보를 삭제합니다. 철회에 실패하면 Apple 권한과 Dutypark 연결 정보가 모두 유지됩니다."
            ].waitForExistence(timeout: 10)
        )
        capture("parity-ios-apple-social-connection-management-after")

        unlinkButton.tap()

        let cancelButton = app.buttons["dp.confirmation.cancel"]
        let confirmButton = app.buttons["dp.confirmation.confirm"]
        XCTAssertTrue(
            app.staticTexts[
                "Apple 인증 권한을 철회하고 Dutypark에 저장된 연결 정보를 삭제합니다. 이후 이 Apple 계정으로 Dutypark에 로그인할 수 없습니다."
            ].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10))
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))
        XCTAssertEqual(
            (cancelButton.frame.midX + confirmButton.frame.midX) / 2,
            app.frame.midX,
            accuracy: 20
        )
        capture("parity-ios-apple-social-unlink-confirmation-after")

        cancelButton.tap()
        XCTAssertTrue(confirmButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(managementPanel.waitForExistence(timeout: 5))
    }

    @MainActor
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maximumSwipes: Int = 10
    ) {
        for _ in 0..<maximumSwipes where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
