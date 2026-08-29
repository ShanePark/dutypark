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
    func testEnglishWeekdaysFollowSystemLanguageWhenDeviceIsEnglish() {
        let app = launchTeamFixture(deviceLanguage: "en", deviceLocale: "en_US")
        defer { app.terminate() }

        for weekday in ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] {
            XCTAssertTrue(app.staticTexts[weekday].firstMatch.exists)
        }
        XCTAssertFalse(app.staticTexts["일"].exists)
        XCTAssertFalse(app.staticTexts["월"].exists)
        capture("parity-ios-team-weekdays-en-system-en-device-after")
    }

    @MainActor
    func testCalendarRendersTheFirstWeekOfDayCells() {
        let app = launchTeamFixture()
        defer { app.terminate() }

        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        guard let year = now.year, let month = now.month else {
            return XCTFail("The current year and month must be resolvable")
        }
        for day in 1...7 {
            let cell = app.buttons["\(year)-\(month)-\(day)"]
            XCTAssertTrue(cell.waitForExistence(timeout: 10), "Day \(day) must render in the first week row")
        }
    }

    @MainActor
    func testScheduledDayDoesNotShowAFalseEmptyMessageWhenShiftsAreEmpty() {
        let app = launchTeamFixture()
        defer { app.terminate() }

        XCTAssertTrue(app.staticTexts["정기 팀 회의"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["이 날의 팀 일정이 없습니다."].exists)
        capture("parity-ios-team-empty-shift-message-after")
    }

    @MainActor
    func testKoreanShiftMemberCountIncludesUnit() {
        let app = launchTeamFixture(includeShifts: true)
        defer { app.terminate() }

        let memberCount = app.staticTexts["team.shift.memberCount"].firstMatch
        scrollUntilHittable(memberCount, in: app)
        XCTAssertTrue(memberCount.isHittable)
        XCTAssertEqual(memberCount.label, "2명")
        app.swipeUp()
        XCTAssertTrue(memberCount.isHittable)
        capture("parity-ios-team-shift-member-count-ko-after")
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
    func testScheduleEditorCanBeOpenedAndCancelledWithoutTerminatingTheApp() {
        let app = launchTeamFixture()
        defer { app.terminate() }

        let addSchedule = app.buttons["팀 일정 추가"].firstMatch
        scrollUntilHittable(addSchedule, in: app)
        XCTAssertTrue(addSchedule.isHittable)
        addSchedule.tap()

        XCTAssertTrue(app.staticTexts["팀 일정 저장"].waitForExistence(timeout: 10))
        let close = app.buttons["닫기"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        close.tap()

        XCTAssertTrue(app.staticTexts["팀 일정 저장"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.buttons["팀 일정 추가"].waitForExistence(timeout: 5))
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
    func testDutyTypeHideAndRestoreRequireNamedCenteredConfirmations() {
        let app = launchTeamFixture()
        defer { app.terminate() }

        let manageTeam = app.buttons["팀 관리"].firstMatch
        XCTAssertTrue(manageTeam.waitForExistence(timeout: 10))
        manageTeam.tap()
        XCTAssertTrue(app.staticTexts["듀티파크 테스트팀 관리"].waitForExistence(timeout: 10))

        let hide = app.buttons["숨기기"].firstMatch
        scrollUntilHittable(hide, in: app)
        if !hide.isHittable { app.swipeLeft() }
        XCTAssertTrue(hide.waitForExistence(timeout: 5))
        hide.tap()
        assertVisibilityConfirmation(
            app: app,
            title: "숨기기",
            message: "[주간] 근무 유형을 숨기시겠습니까? 과거 근무 기록은 유지됩니다."
        )
        app.buttons["dp.confirmation.cancel"].tap()
        XCTAssertTrue(app.buttons["dp.confirmation.confirm"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["사용 중"].exists)

        let restore = app.buttons["복원"].firstMatch
        if !restore.isHittable { app.swipeLeft() }
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        assertVisibilityConfirmation(
            app: app,
            title: "복원",
            message: "[야간] 근무 유형을 다시 사용하시겠습니까?"
        )
        app.buttons["dp.confirmation.cancel"].tap()
        XCTAssertTrue(app.buttons["dp.confirmation.confirm"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["숨김"].exists)
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    func testResetLeadConfirmationNamesTheCurrentLeadAndFitsThePanel() {
        let app = launchTeamFixture()
        defer { app.terminate() }

        let manageTeam = app.buttons["팀 관리"].firstMatch
        XCTAssertTrue(manageTeam.waitForExistence(timeout: 10))
        manageTeam.tap()

        XCTAssertTrue(app.staticTexts["듀티파크 테스트팀 관리"].waitForExistence(timeout: 10))
        let resetLead = app.buttons["대표 취소"].firstMatch
        scrollUntilHittable(resetLead, in: app)
        XCTAssertTrue(resetLead.isHittable)
        resetLead.tap()

        let cancel = app.buttons["dp.confirmation.cancel"]
        let confirm = app.buttons["dp.confirmation.confirm"]
        let message = app.staticTexts["김듀티 님의 팀 대표 권한을 초기화하시겠습니까?"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertTrue(message.exists)
        XCTAssertEqual(cancel.label, "취소")
        XCTAssertEqual(confirm.label, "대표 취소")
        XCTAssertTrue(app.staticTexts["대표 취소"].exists)
        XCTAssertEqual((cancel.frame.midX + confirm.frame.midX) / 2, app.frame.midX, accuracy: 20)
        XCTAssertGreaterThanOrEqual(message.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(message.frame.maxX, app.frame.maxX)
        XCTAssertGreaterThanOrEqual(cancel.frame.minY, app.frame.minY)
        XCTAssertLessThanOrEqual(confirm.frame.maxY, app.frame.maxY)
        capture("parity-ios-team-reset-lead-confirmation-after")

        // The destructive confirmation is intentionally left unsubmitted.
    }

    @MainActor
    private func launchTeamFixture(
        deviceLanguage: String = "ko",
        deviceLocale: String = "ko_KR",
        includeShifts: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(\(deviceLanguage))",
            "-AppleLocale", deviceLocale,
            "-ui-testing-authenticated",
            "-ui-testing-team-fixture",
        ]
        if includeShifts {
            app.launchArguments.append("-ui-testing-team-shift-fixture")
        }
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
    private func assertVisibilityConfirmation(
        app: XCUIApplication,
        title: String,
        message: String
    ) {
        let cancel = app.buttons["dp.confirmation.cancel"]
        let confirm = app.buttons["dp.confirmation.confirm"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        XCTAssertEqual(cancel.label, "취소")
        XCTAssertEqual(confirm.label, title)
        XCTAssertTrue(app.staticTexts[title].exists)
        XCTAssertTrue(app.staticTexts[message].exists)
        XCTAssertEqual((cancel.frame.midX + confirm.frame.midX) / 2, app.frame.midX, accuracy: 20)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
