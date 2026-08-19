import XCTest

final class DutyPatternHiddenSelectionParityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHiddenDutyTypeExplainsPausedPatternAndDisabledSave() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-hidden-duty-pattern",
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20))
        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["screen.more"].waitForExistence(timeout: 10))
        let myInfoEntry = app.buttons["more.myInfo"]
        XCTAssertTrue(myInfoEntry.waitForExistence(timeout: 10))
        myInfoEntry.tap()

        XCTAssertTrue(app.descendants(matching: .any)["screen.myInfo"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["일부 요일의 자동 적용이 중지되었습니다."].firstMatch
                .waitForExistence(timeout: 10)
        )

        let editPatternButton = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "변경"))
            .firstMatch
        XCTAssertTrue(editPatternButton.waitForExistence(timeout: 10))
        editPatternButton.tap()

        let warning = app.descendants(matching: .any)["settings.pattern.paused.warning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["일부 요일의 자동 적용이 중지되었습니다."].firstMatch.exists)
        XCTAssertTrue(
            app.staticTexts[
                "숨겨진 근무 유형이 지정된 요일은 다른 유형을 선택하거나 해당 유형을 복원할 때까지 적용되지 않습니다."
            ].exists
        )
        XCTAssertTrue(app.staticTexts["숨김"].firstMatch.exists)

        let hiddenDutyType = app.buttons["일: 야간, 숨김"]
        XCTAssertTrue(hiddenDutyType.waitForExistence(timeout: 10))
        let saveButton = app.buttons["저장"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 10))
        XCTAssertFalse(saveButton.isEnabled)

        capture("settings-hidden-duty-pattern-ios-after")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
