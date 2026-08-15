import XCTest

final class GuestGuideTitleVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testGuestGuideUsesTheSameKoreanTitleAsTheWebGuide() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-guest"
        ]
        app.launch()
        defer { app.terminate() }

        let guideButton = app.buttons["guest.guide"]
        for _ in 0..<12 where !guideButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(guideButton.waitForExistence(timeout: 5))
        XCTAssertTrue(guideButton.isHittable)
        guideButton.tap()

        let title = app.navigationBars.staticTexts["이용 안내"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars.staticTexts["이용 안내 및 릴리스 노트"].exists)

        let screen = app.windows.firstMatch.frame
        XCTAssertTrue(screen.contains(title.frame))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "guest-guide-title-ios-after"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testGuestGuideHomeLinkReturnsToTheNativeGuestLanding() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-guest"
        ]
        app.launch()
        defer { app.terminate() }

        let guideButton = app.buttons["guest.guide"]
        for _ in 0..<12 where !guideButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(guideButton.waitForExistence(timeout: 5))
        guideButton.tap()

        let homeLink = app.links["홈으로 돌아가기"]
        XCTAssertTrue(homeLink.waitForExistence(timeout: 15))
        XCTAssertTrue(homeLink.isHittable)
        homeLink.tap()

        XCTAssertTrue(guideButton.waitForExistence(timeout: 5))
        XCTAssertTrue(guideButton.isHittable)
        XCTAssertFalse(app.navigationBars.staticTexts["이용 안내"].exists)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "guest-guide-home-native-landing-ios-after"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
