import XCTest

final class SsoSignupVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDraftCancellationUsesCenteredKoreanConfirmationPanel() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-sso-signup",
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.oauth.signup"]
                .waitForExistence(timeout: 10)
        )

        let nameField = app.textFields["oauth.signup.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText("Draft")

        let keyboardDismiss = app.buttons["keyboard.dismiss"]
        if keyboardDismiss.waitForExistence(timeout: 2) {
            keyboardDismiss.tap()
        }

        let cancelSignup = app.buttons["oauth.signup.cancel"]
        XCTAssertTrue(cancelSignup.waitForExistence(timeout: 5))
        cancelSignup.tap()

        let panel = app.descendants(matching: .any)["oauth.signup.discard.confirmation"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        let title = app.staticTexts["회원가입을 취소할까요?"]
        let message = app.staticTexts["입력한 이름과 약관 동의 내용이 사라집니다."]
        XCTAssertTrue(title.exists)
        XCTAssertTrue(message.exists)

        let continueButton = app.buttons["dp.confirmation.cancel"]
        let discardButton = app.buttons["dp.confirmation.confirm"]
        XCTAssertEqual(continueButton.label, "계속 작성")
        XCTAssertEqual(discardButton.label, "나가기")
        XCTAssertTrue(continueButton.isHittable)
        XCTAssertTrue(discardButton.isHittable)

        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "parity-ios-sso-signup-discard-confirmation-ko-dark"
        attachment.lifetime = .keepAlways
        add(attachment)

        let visiblePanelBounds = [
            title.frame,
            message.frame,
            continueButton.frame,
            discardButton.frame,
        ].reduce(CGRect.null) { $0.union($1) }
        XCTAssertLessThan(abs(visiblePanelBounds.midX - window.frame.midX), 2)
        XCTAssertLessThan(abs(visiblePanelBounds.midY - window.frame.midY), 24)
        XCTAssertLessThanOrEqual(visiblePanelBounds.width, 340)
        XCTAssertLessThan(continueButton.frame.maxX, discardButton.frame.minX)
        XCTAssertGreaterThanOrEqual(continueButton.frame.height, 44)
        XCTAssertGreaterThanOrEqual(discardButton.frame.height, 44)
    }
}
