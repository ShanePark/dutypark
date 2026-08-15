import XCTest

final class TeamParityVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testKoreanYearMonthPickerVisual() {
        let app = launchTeamFixture()
        defer { app.terminate() }

        let chooseMonth = app.buttons["연월 선택"].firstMatch
        XCTAssertTrue(chooseMonth.waitForExistence(timeout: 10))
        chooseMonth.tap()

        XCTAssertTrue(app.navigationBars["연월 선택"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["1월"].exists)
        XCTAssertTrue(app.buttons["6월"].exists)
        XCTAssertTrue(app.buttons["12월"].exists)
        capture("parity-ios-team-year-month-picker-ko-after")
    }

    @MainActor
    func testJoinedTeamScheduleDeleteUsesCenteredConfirmation() {
        let app = launchTeamFixture()
        defer { app.terminate() }

        let deleteSchedule = app.buttons["일정 삭제"].firstMatch
        scrollUntilHittable(deleteSchedule, in: app)
        XCTAssertTrue(deleteSchedule.isHittable)
        deleteSchedule.tap()

        let cancel = app.buttons["dp.confirmation.cancel"]
        let confirm = app.buttons["dp.confirmation.confirm"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertEqual(cancel.label, "취소")
        XCTAssertEqual(confirm.label, "삭제")
        XCTAssertTrue(app.staticTexts["일정 삭제"].exists)
        XCTAssertTrue(app.staticTexts["“정기 팀 회의” 팀 일정을 삭제하시겠습니까?\n삭제된 일정은 복구할 수 없습니다."].exists)
        XCTAssertEqual((cancel.frame.midX + confirm.frame.midX) / 2, app.frame.midX, accuracy: 20)
        capture("parity-ios-team-schedule-delete-confirmation-after")

        cancel.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testTeamManagementActionUsesCenteredConfirmation() {
        let app = launchTeamFixture()
        defer { app.terminate() }

        let manageTeam = app.buttons["팀 관리"].firstMatch
        XCTAssertTrue(manageTeam.waitForExistence(timeout: 10))
        manageTeam.tap()

        XCTAssertTrue(app.staticTexts["듀티파크 테스트팀 관리"].waitForExistence(timeout: 10))
        let removeMember = app.buttons["제외"].firstMatch
        scrollUntilHittable(removeMember, in: app)
        XCTAssertTrue(removeMember.isHittable)
        removeMember.tap()

        let cancel = app.buttons["dp.confirmation.cancel"]
        let confirm = app.buttons["dp.confirmation.confirm"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertEqual(cancel.label, "취소")
        XCTAssertEqual(confirm.label, "제외")
        XCTAssertTrue(app.staticTexts["제외"].exists)
        XCTAssertTrue(app.staticTexts["테스트 관리자 님을 팀에서 제외하시겠습니까?"].exists)
        XCTAssertEqual((cancel.frame.midX + confirm.frame.midX) / 2, app.frame.midX, accuracy: 20)
        capture("parity-ios-team-management-confirmation-after")

        cancel.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    private func launchTeamFixture() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-team-fixture",
        ]
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20)
        )
        let teamTab = app.buttons.matching(identifier: "tab.team").firstMatch
        XCTAssertTrue(teamTab.waitForExistence(timeout: 10))
        teamTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.team"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.staticTexts["듀티파크 테스트팀"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 6
    ) {
        for _ in 0..<attempts where !element.isHittable {
            app.swipeUp()
        }
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
