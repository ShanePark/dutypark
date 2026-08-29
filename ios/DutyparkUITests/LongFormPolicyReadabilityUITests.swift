import XCTest

final class LongFormPolicyReadabilityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAISchedulePolicyWrapsAtLargeDynamicType() {
        let app = launchApp()
        defer { app.terminate() }

        openSettings(in: app)
        openPolicy(named: "AI 시간 인식 정책 자세히 보기", in: app)

        let aiHeading = app.descendants(matching: .any)["dp.longForm.heading.0"]
        XCTAssertTrue(aiHeading.waitForExistence(timeout: 10))
        assertFitsScreen(aiHeading, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["dp.longForm.heading.2"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["dp.longForm.list.5.0"].exists)
        let aiLongParagraph = app.descendants(matching: .any)["dp.longForm.paragraph.3"]
        XCTAssertTrue(aiLongParagraph.exists)
        assertFitsScreen(aiLongParagraph, in: app)
        XCTAssertGreaterThan(aiLongParagraph.frame.height, 60)
        capture("settings-ai-policy-readable-ios-after")
    }

    @MainActor
    func testPrivacyTableReflowsAtLargeDynamicType() {
        let app = launchApp(policyRoute: "-ui-testing-long-form-policy-privacy")
        defer { app.terminate() }

        openSettings(in: app, waitForSettingsScreen: false)

        let privacyHeading = app.descendants(matching: .any)["dp.longForm.heading.0"]
        XCTAssertTrue(privacyHeading.waitForExistence(timeout: 10))
        assertFitsScreen(privacyHeading, in: app)
        let firstTableRow = app.descendants(matching: .any)["dp.longForm.table.3.row.0"]
        XCTAssertTrue(firstTableRow.waitForExistence(timeout: 10))
        assertFitsScreen(firstTableRow, in: app)
        XCTAssertGreaterThan(firstTableRow.frame.height, 80)
        capture("settings-privacy-policy-readable-ios-after")
    }

    @MainActor
    func testTermsListWrapsAtLargeDynamicType() {
        let app = launchApp(policyRoute: "-ui-testing-long-form-policy-terms")
        defer { app.terminate() }

        openSettings(in: app, waitForSettingsScreen: false)

        let termsHeading = app.descendants(matching: .any)["dp.longForm.heading.0"]
        XCTAssertTrue(termsHeading.waitForExistence(timeout: 10))
        assertFitsScreen(termsHeading, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["dp.longForm.list.4.0"].exists)
        capture("settings-terms-policy-readable-ios-after")
    }

    @MainActor
    private func launchApp(policyRoute: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraLarge",
            "-ui-testing-authenticated",
            "-ui-testing-long-form-policies",
        ]
        if let policyRoute {
            app.launchArguments.append(policyRoute)
        }
        app.launch()
        return app
    }

    @MainActor
    private func openSettings(in app: XCUIApplication, waitForSettingsScreen: Bool = true) {
        XCTAssertTrue(app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20))
        let moreTab = primaryMoreTab(in: app)
        moreTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.more"].waitForExistence(timeout: 10))
        let settingsEntry = app.buttons["more.settings"]
        XCTAssertTrue(settingsEntry.waitForExistence(timeout: 10))
        settingsEntry.tap()
        if waitForSettingsScreen {
            XCTAssertTrue(app.scrollViews["screen.settings"].firstMatch.waitForExistence(timeout: 10))
        }
    }

    @MainActor
    private func primaryMoreTab(
        in app: XCUIApplication,
        timeout: TimeInterval = 10
    ) -> XCUIElement {
        let identifiedTab = app.buttons.matching(identifier: "tab.more").firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        let identifierGracePeriod = min(timeout, 1)
        if identifiedTab.waitForExistence(timeout: identifierGracePeriod) {
            return identifiedTab
        }

        let labelTab = app.tabBars.buttons["More"].firstMatch
        let remainingTimeout = max(0, deadline.timeIntervalSinceNow)
        XCTAssertTrue(
            labelTab.waitForExistence(timeout: remainingTimeout),
            "Primary tab did not appear: tab.more (English label: More)"
        )
        return labelTab
    }

    @MainActor
    private func openPolicy(named name: String, in app: XCUIApplication) {
        let settings = app.scrollViews["screen.settings"].firstMatch
        let policyLink = app.buttons[name].firstMatch
        let deadline = Date().addingTimeInterval(20)
        var swipeCount = 0
        while Date() < deadline, swipeCount < 10, !policyLink.isHittable {
            settings.swipeUp(velocity: .fast)
            swipeCount += 1
        }
        XCTAssertTrue(policyLink.isHittable, "Could not reveal policy link: \(name)")
        policyLink.tap()
    }

    @MainActor
    private func assertFitsScreen(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertGreaterThanOrEqual(element.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.maxX)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
