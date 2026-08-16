import XCTest

final class AdminTeamListParityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturesSearchEmptyClearAndCreatedTeamManagementRoute() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-admin",
            "-ui-testing-admin-visual-fixture",
            "-ui-testing-team-fixture",
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["screen.admin"].waitForExistence(timeout: 20))
        app.descendants(matching: .any)["admin.tile.teams"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["screen.admin.teams"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["총 12개의 팀이 있습니다"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["시각 검증팀"].exists)

        let list = app.collectionViews.firstMatch
        for _ in 0..<8 where !app.buttons["admin.teams.page.2"].exists {
            list.swipeUp()
        }
        XCTAssertTrue(app.buttons["admin.teams.page.2"].waitForExistence(timeout: 5))
        attachScreenshot(named: "parity-ios-admin-team-list-mobile-hierarchy-ko-dark")

        for _ in 0..<8 where !app.searchFields["팀 검색"].exists {
            list.swipeDown()
        }
        let searchField = app.searchFields["팀 검색"].firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("없는 팀\n")

        XCTAssertTrue(app.staticTexts["검색 결과가 없습니다"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["[없는 팀]"].exists)
        XCTAssertTrue(app.staticTexts["총 0개의 팀이 있습니다"].exists)
        attachScreenshot(named: "parity-ios-admin-team-search-empty-ko-dark")

        let clearSearch = app.buttons["admin.teams.search.clear"]
        XCTAssertTrue(clearSearch.waitForExistence(timeout: 5))
        clearSearch.tap()
        XCTAssertTrue(app.staticTexts["시각 검증팀"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["[없는 팀]"].exists)
        let dismissSearch = app.buttons["닫기"]
        XCTAssertTrue(dismissSearch.waitForExistence(timeout: 5))
        dismissSearch.tap()

        app.buttons["admin.teams.create.open"].tap()
        let nameField = app.textFields["admin.teams.create.name"]
        let descriptionField = app.textFields["admin.teams.create.description"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("신규 검증팀")
        app.buttons["admin.teams.create.checkName"].tap()
        XCTAssertTrue(app.staticTexts["사용 가능한 이름입니다."].waitForExistence(timeout: 5))
        descriptionField.tap()
        descriptionField.typeText("생성 후 관리 화면 이동 검증")
        app.buttons["admin.teams.create.submit"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.team.manage.9001"]
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.staticTexts["신규 검증팀 관리"].waitForExistence(timeout: 10))
        attachScreenshot(named: "parity-ios-admin-team-create-manage-route-ko-dark")
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
