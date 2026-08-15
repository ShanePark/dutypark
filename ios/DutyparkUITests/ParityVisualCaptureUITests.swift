import XCTest

final class ParityVisualCaptureUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturesKoreanDarkModeParityFlow() throws {
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

        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        capture("parity-ios-01-home-ko-dark")

        let todoTab = app.buttons.matching(identifier: "tab.todo").firstMatch
        XCTAssertTrue(todoTab.waitForExistence(timeout: 10))
        todoTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.todo"].waitForExistence(timeout: 10)
        )
        capture("parity-ios-02-todo-ko-dark")

        let homeTab = app.buttons.matching(identifier: "tab.home").firstMatch
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))
        homeTab.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 10))

        let menuButton = app.buttons["home.menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 10))
        menuButton.tap()

        let menu = app.descendants(matching: .any)["screen.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        capture("parity-ios-03-menu-ko-dark")

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()

        let settings = app.descendants(matching: .any)["screen.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        let patternTitle = app.staticTexts["기본 근무 패턴"].firstMatch
        XCTAssertTrue(patternTitle.waitForExistence(timeout: 10))
        capture("parity-ios-04-settings-ko-dark")

        let editPatternButton = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "변경"))
            .firstMatch
        XCTAssertTrue(editPatternButton.waitForExistence(timeout: 10))
        editPatternButton.tap()

        let patternModalTitle = app.staticTexts
            .matching(identifier: "기본 근무 패턴")
            .firstMatch
        XCTAssertTrue(patternModalTitle.waitForExistence(timeout: 10))
        let disablePatternButton = app.buttons["패턴 해제"].firstMatch
        XCTAssertTrue(disablePatternButton.waitForExistence(timeout: 10))
        capture("parity-ios-05-default-work-pattern-ko-dark")

        disablePatternButton.tap()

        let confirmationTitle = app.staticTexts["근무 패턴을 해제할까요?"]
        XCTAssertTrue(confirmationTitle.waitForExistence(timeout: 10))
        capture("parity-ios-06-disable-pattern-confirmation-ko-dark")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
