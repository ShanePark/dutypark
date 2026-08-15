import XCTest

final class AdminConfirmationVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturesMemberActiveSessionCountParity() throws {
        let app = launchServiceAdminApp()
        defer { app.terminate() }

        openAdministration(in: app)
        app.staticTexts["회원 관리"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["관리자 검증 회원"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["1개의 활성 세션"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["세션 없는 회원"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["활성 세션 없음"].firstMatch.exists)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "parity-ios-admin-member-active-session-count-ko-dark"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCapturesCenteredTeamDeleteConfirmation() throws {
        let app = launchServiceAdminApp()
        defer { app.terminate() }

        openAdministration(in: app)
        app.staticTexts["팀 관리"].firstMatch.tap()

        let fixtureTeam = app.staticTexts["시각 검증팀"].firstMatch
        XCTAssertTrue(fixtureTeam.waitForExistence(timeout: 10))
        fixtureTeam.swipeLeft()
        let deleteButton = app.buttons["삭제"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        assertCenteredConfirmation(
            in: app,
            title: "팀을 삭제할까요?",
            message: "시각 검증팀 팀을 삭제할까요? 회원이 있는 팀은 삭제할 수 없습니다.",
            confirmTitle: "삭제",
            screenshotName: "parity-ios-admin-team-delete-confirmation-ko-dark"
        )
    }

    @MainActor
    func testCapturesCenteredMemberSessionRevokeConfirmation() throws {
        let app = launchServiceAdminApp()
        defer { app.terminate() }

        openAdministration(in: app)
        app.staticTexts["회원 관리"].firstMatch.tap()

        let fixtureMember = app.staticTexts["관리자 검증 회원"].firstMatch
        XCTAssertTrue(fixtureMember.waitForExistence(timeout: 10))
        fixtureMember.tap()

        let revokeButton = app.buttons["admin.member.session.revoke.99"]
        for _ in 0..<4 where !(revokeButton.exists && revokeButton.isHittable) {
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(revokeButton.waitForExistence(timeout: 10))
        XCTAssertTrue(revokeButton.isHittable)
        revokeButton.tap()

        assertCenteredConfirmation(
            in: app,
            title: "이 세션을 종료할까요?",
            message: "관리자 검증 회원님의 iPhone 13 mini · Dutypark (127.0.0.1) 세션을 종료하시겠습니까?",
            confirmTitle: "세션 종료",
            screenshotName: "parity-ios-admin-member-session-confirmation-ko-dark"
        )
    }

    @MainActor
    private func launchServiceAdminApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-admin",
            "-ui-testing-admin-visual-fixture",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func openAdministration(in app: XCUIApplication) {
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.admin"].waitForExistence(timeout: 20)
        )
    }

    @MainActor
    private func assertCenteredConfirmation(
        in app: XCUIApplication,
        title: String,
        message: String,
        confirmTitle: String,
        screenshotName: String
    ) {
        let titleElement = app.staticTexts[title]
        let messageElement = app.staticTexts[message]
        let confirmButton = app.buttons["dp.confirmation.confirm"]
        let cancelButton = app.buttons["dp.confirmation.cancel"]

        XCTAssertTrue(titleElement.waitForExistence(timeout: 10))
        XCTAssertTrue(messageElement.exists)
        XCTAssertTrue(confirmButton.exists)
        XCTAssertTrue(cancelButton.exists)
        XCTAssertTrue(confirmButton.isHittable)
        XCTAssertTrue(cancelButton.isHittable)
        XCTAssertEqual(confirmButton.label, confirmTitle)
        XCTAssertEqual(cancelButton.label, "취소")

        let panelMidY = (titleElement.frame.minY + confirmButton.frame.maxY) / 2
        XCTAssertLessThan(abs(panelMidY - app.frame.midY), app.frame.height * 0.18)
        XCTAssertLessThan(abs(cancelButton.frame.midY - confirmButton.frame.midY), 2)
        XCTAssertLessThanOrEqual(cancelButton.frame.maxX, confirmButton.frame.minX + 1)
        XCTAssertLessThan(abs(cancelButton.frame.width - confirmButton.frame.width), 2)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = screenshotName
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
