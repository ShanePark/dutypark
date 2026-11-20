import XCTest

final class RootMenuGuideNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMoreMenuGuideOpensNativeGuideScreen() {
        let app = launchApp()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"]
                .waitForExistence(timeout: 20)
        )

        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.more"]
                .waitForExistence(timeout: 10)
        )

        let guideAction = app.buttons["more.guide"]
        XCTAssertTrue(guideAction.waitForExistence(timeout: 10))
        guideAction.tap()

        let guideScreen = app.descendants(matching: .any)["screen.nativeGuide"]
        let appeared = guideScreen.waitForExistence(timeout: 10)
        capture("more-guide-after-tap", in: app)
        XCTAssertTrue(appeared, "screen.nativeGuide never appeared from the More menu")
        XCTAssertTrue(
            app.buttons["guide.expandAll"].waitForExistence(timeout: 10),
            "The guide screen never rendered its content"
        )
    }

    @MainActor
    func testGuideReleaseNotesSegmentOpensNativeReleaseNotes() {
        let app = launchApp()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"]
                .waitForExistence(timeout: 20)
        )

        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()

        let guideAction = app.buttons["more.guide"]
        XCTAssertTrue(guideAction.waitForExistence(timeout: 10))
        guideAction.tap()

        let picker = app.segmentedControls["guide.sectionPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.buttons["업데이트 내역"].tap()

        let releaseNotes = app.descendants(matching: .any)["screen.nativeReleaseNotes"]
        let appeared = releaseNotes.waitForExistence(timeout: 10)
        capture("guide-release-notes-after-tap", in: app)
        XCTAssertTrue(appeared, "screen.nativeReleaseNotes never appeared from the guide segment")
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
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
