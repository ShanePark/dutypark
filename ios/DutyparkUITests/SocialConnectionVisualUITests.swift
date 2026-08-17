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
        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.more"].waitForExistence(timeout: 10)
        )

        let settingsRow = app.buttons["more.settings"]
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 10))
        settingsRow.tap()
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
    func testDisconnectedProviderRowOffersConnectInsteadOfManagement() {
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
        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.more"].waitForExistence(timeout: 10)
        )

        let settingsRow = app.buttons["more.settings"]
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 10))
        settingsRow.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.settings"].waitForExistence(timeout: 10)
        )

        let connectApple = app.buttons["settings.social.connect.apple"]
        scrollUntilHittable(connectApple, in: app)
        XCTAssertTrue(connectApple.isHittable)
        XCTAssertTrue(app.buttons["settings.social.connect.naver"].exists)
        XCTAssertFalse(app.buttons["settings.social.manage.apple"].exists)
        XCTAssertFalse(app.buttons["settings.social.manage.naver"].exists)
        XCTAssertTrue(app.buttons["settings.social.manage.kakao"].exists)
        XCTAssertFalse(app.buttons["settings.social.connect.kakao"].exists)
        capture("parity-ios-social-connection-rows-after")
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
        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.more"].waitForExistence(timeout: 10)
        )

        let settingsRow = app.buttons["more.settings"]
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 10))
        settingsRow.tap()
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
