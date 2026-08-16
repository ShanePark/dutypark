import XCTest

final class RootMenuGuideNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHamburgerMenuGuideOpensNativeGuideScreen() {
        let app = launchApp()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"]
                .waitForExistence(timeout: 20)
        )

        let menuButton = app.buttons["home.menu"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 10))
        menuButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.menu"]
                .waitForExistence(timeout: 10)
        )

        let guideAction = app.buttons["menu.guide"]
        XCTAssertTrue(guideAction.waitForExistence(timeout: 10))
        guideAction.tap()

        let guideScreen = app.descendants(matching: .any)["screen.nativeGuide"]
        let appeared = guideScreen.waitForExistence(timeout: 10)
        capture("menu-guide-after-tap", in: app)
        XCTAssertTrue(appeared, "screen.nativeGuide never appeared from the home menu")
        XCTAssertTrue(
            app.buttons["guide.expandAll"].waitForExistence(timeout: 10),
            "The guide screen never rendered its content"
        )
    }

    @MainActor
    func testSettingsGuideLinkOpensNativeGuideScreen() {
        let app = launchApp()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"]
                .waitForExistence(timeout: 20)
        )

        let settingsTab = app.buttons.matching(identifier: "tab.settings").firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()

        let settings = app.scrollViews["screen.settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 10))

        let guideLink = app.buttons["사용 가이드"].firstMatch
        let deadline = Date().addingTimeInterval(20)
        var swipeCount = 0
        while Date() < deadline, swipeCount < 12, !guideLink.isHittable {
            settings.swipeUp(velocity: .fast)
            swipeCount += 1
        }
        XCTAssertTrue(guideLink.isHittable, "Could not reveal the settings guide link")
        // Tapped at the row centre on purpose: that point sits on the Spacer between the
        // label and the chevron, which is only hit-testable while the row keeps its
        // explicit content shape.
        guideLink.tap()

        let guideScreen = app.descendants(matching: .any)["screen.nativeGuide"]
        let appeared = guideScreen.waitForExistence(timeout: 10)
        capture("settings-guide-after-tap", in: app)
        XCTAssertTrue(appeared, "screen.nativeGuide never appeared from the settings link")
        XCTAssertTrue(
            app.buttons["guide.expandAll"].waitForExistence(timeout: 10),
            "The guide screen never rendered its content"
        )
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
