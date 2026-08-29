import XCTest

final class AccountDeletionParityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFinalDestructiveActionMatchesResponsiveWebWithoutExecutingDeletion() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-account-deletion",
        ]
        app.launch()
        defer { app.terminate() }

        openAccountDeletion(in: app)
        advanceToFinalConfirmation(in: app)

        let backButton = app.buttons["accountDeletion.back"]
        let deleteButton = app.buttons["accountDeletion.submit"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 10))
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        XCTAssertTrue(backButton.isHittable)
        XCTAssertTrue(deleteButton.isHittable)
        XCTAssertEqual(deleteButton.label, "계정 영구 삭제")
        XCTAssertFalse(app.buttons["내 계정 삭제"].exists)
        XCTAssertGreaterThanOrEqual(deleteButton.frame.height, 44)
        XCTAssertGreaterThan(deleteButton.frame.width, 120)
        XCTAssertGreaterThanOrEqual(deleteButton.frame.minX, 0)
        XCTAssertLessThanOrEqual(deleteButton.frame.maxX, app.frame.maxX)
        XCTAssertEqual(
            (backButton.frame.midX + deleteButton.frame.midX) / 2,
            app.frame.midX,
            accuracy: 20
        )
        XCTAssertFalse(backButton.frame.intersects(deleteButton.frame))

        capture("parity-ios-account-permanent-delete-copy-after")
    }

    @MainActor
    private func openAccountDeletion(in app: XCUIApplication) {
        XCTAssertTrue(app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20))
        let identifiedMoreTab = app.buttons["tab.more"].firstMatch
        let moreTab = identifiedMoreTab.waitForExistence(timeout: 2)
            ? identifiedMoreTab
            : app.tabBars.buttons["더보기"].firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["screen.more"].waitForExistence(timeout: 10))
        let myInfoEntry = app.buttons["more.myInfo"]
        XCTAssertTrue(myInfoEntry.waitForExistence(timeout: 10))
        myInfoEntry.tap()

        let myInfoScreen = app.scrollViews["screen.myInfo"].firstMatch
        XCTAssertTrue(myInfoScreen.waitForExistence(timeout: 10))
        let deleteEntry = app.buttons["settings.account.delete"]
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline, !deleteEntry.isHittable {
            myInfoScreen.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(deleteEntry.isHittable)
        deleteEntry.tap()
        XCTAssertTrue(app.staticTexts["회원 탈퇴"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func advanceToFinalConfirmation(in app: XCUIApplication) {
        let continueButton = app.buttons["accountDeletion.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        continueButton.tap()
        XCTAssertTrue(app.staticTexts["팀 처리"].waitForExistence(timeout: 10))
        continueButton.tap()

        let password = app.secureTextFields["accountDeletion.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 10))
        password.tap()
        password.typeText("fixture-password")
        dismissKeyboard(in: app)

        let reauthenticate = app.buttons["accountDeletion.passwordReauth"]
        XCTAssertTrue(reauthenticate.waitForExistence(timeout: 10))
        XCTAssertTrue(reauthenticate.isHittable)
        reauthenticate.tap()
        XCTAssertTrue(app.staticTexts["본인 확인 완료"].waitForExistence(timeout: 10))
        XCTAssertTrue(continueButton.isHittable)
        continueButton.tap()

        let name = app.textFields["accountDeletion.nameConfirmation"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("Test\n")
        XCTAssertTrue(continueButton.isHittable)
        continueButton.tap()

        XCTAssertTrue(app.staticTexts["최종 확인"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let keyboardDismiss = app.buttons["keyboard.dismiss"]
        if keyboardDismiss.waitForExistence(timeout: 2) {
            keyboardDismiss.tap()
        } else {
            let done = app.keyboards.buttons["Done"]
            if done.waitForExistence(timeout: 2) {
                done.tap()
            } else {
                app.keyboards.firstMatch.swipeDown()
                XCTAssertFalse(app.keyboards.firstMatch.exists)
            }
        }
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
