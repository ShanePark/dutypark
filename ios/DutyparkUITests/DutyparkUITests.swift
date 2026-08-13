import XCTest

final class DutyparkUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNavigatesThroughFivePrimaryTabs() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "en",
            "-dp-theme", "light",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ui-testing-authenticated"
        ]
        app.launch()

        let destinations = [
            (tab: "tab.home", screen: "screen.home"),
            (tab: "tab.calendar", screen: "screen.calendar"),
            (tab: "tab.todo", screen: "screen.todo"),
            (tab: "tab.team", screen: "screen.team"),
            (tab: "tab.settings", screen: "screen.settings")
        ]

        for destination in destinations {
            let tab = primaryTab(destination.tab, in: app)
            tab.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)[destination.screen].waitForExistence(timeout: 10)
            )
        }
    }

    @MainActor
    func testLoginOffersKakaoAndNaver() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-guest"
        ]
        app.launch()

        let loginButton = app.buttons["guest.login"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10))
        loginButton.tap()

        XCTAssertTrue(app.buttons["login.oauth.kakao"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["login.oauth.naver"].exists)
    }

    @MainActor
    func testPrimaryToolbarActionsMeetMinimumTouchTarget() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "en",
            "-dp-theme", "light",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ui-testing-authenticated"
        ]
        app.launch()

        let notificationBell = app.buttons["notifications.bell"]
        XCTAssertTrue(notificationBell.waitForExistence(timeout: 10))
        assertMinimumTouchTarget(notificationBell)

        primaryTab("tab.todo", in: app).tap()
        let todoAdd = app.buttons["todo.add"]
        XCTAssertTrue(waitForTodoToolbarAction(todoAdd, in: app, timeout: 10))
        assertMinimumTouchTarget(todoAdd)
    }

    @MainActor
    func testLanguageAndThemePreferencesAcrossSupportedCombinations() throws {
        let combinations = [
            (language: "ko", locale: "ko_KR", theme: "light", home: "홈", themeLabel: "테마", themeValue: "현재 테마: 라이트"),
            (language: "ko", locale: "ko_KR", theme: "dark", home: "홈", themeLabel: "테마", themeValue: "현재 테마: 다크"),
            (language: "en", locale: "en_US", theme: "light", home: "Home", themeLabel: "Theme", themeValue: "Current theme: Light"),
            (language: "en", locale: "en_US", theme: "dark", home: "Home", themeLabel: "Theme", themeValue: "Current theme: Dark")
        ]

        for combination in combinations {
            try XCTContext.runActivity(
                named: "\(combination.language) × \(combination.theme)"
            ) { _ in
                let app = XCUIApplication()
                app.launchArguments += [
                    "-dp-language", combination.language,
                    "-dp-theme", combination.theme,
                    "-AppleLanguages", "(\(combination.language))",
                    "-AppleLocale", combination.locale,
                    "-ui-testing-authenticated"
                ]
                app.launch()
                defer { app.terminate() }

                XCTAssertTrue(
                    app.wait(for: .runningForeground, timeout: 10),
                    "App did not reach the foreground"
                )
                XCTAssertTrue(
                    app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20),
                    "Authenticated home screen did not become ready"
                )

                let homeTab = primaryTab("tab.home", in: app, timeout: 20)
                XCTAssertEqual(homeTab.label, combination.home)
                XCTAssertTrue(homeTab.isHittable)
                assertMinimumTouchTarget(homeTab)

                let settingsTab = primaryTab("tab.settings", in: app, timeout: 20)
                XCTAssertTrue(settingsTab.isHittable)
                assertMinimumTouchTarget(settingsTab)
                settingsTab.tap()
                XCTAssertTrue(
                    app.descendants(matching: .any)["screen.settings"].waitForExistence(timeout: 10)
                )

                let themePicker = app.descendants(matching: .any)
                    .matching(
                        NSPredicate(
                            format: "label == %@ AND value == %@",
                            combination.themeLabel,
                            combination.themeValue
                        )
                    )
                    .firstMatch
                XCTAssertTrue(
                    revealSettingsElement(themePicker, in: app, timeout: 10),
                    "Theme preference was not reflected: \(combination.themeValue)"
                )

                let themeDescription = app.staticTexts[combination.themeValue].firstMatch
                XCTAssertTrue(
                    themeDescription.waitForExistence(timeout: 10),
                    "Dynamic Type probe text did not appear: \(combination.themeValue)"
                )
                let evidence = XCTAttachment(
                    string: "text=\(combination.themeValue), frame=\(themeDescription.frame)"
                )
                evidence.name = "Dynamic Type frame — \(combination.language) × \(combination.theme)"
                evidence.lifetime = .keepAlways
                add(evidence)

                let returnHomeTab = primaryTab("tab.home", in: app)
                XCTAssertTrue(returnHomeTab.isHittable)
                returnHomeTab.tap()
                XCTAssertTrue(
                    app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 10),
                    "Home screen did not become ready after returning from Settings"
                )
            }
        }
    }

    @MainActor
    private func revealSettingsElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        let settingsScrollView = app.scrollViews["screen.settings"].firstMatch
        guard settingsScrollView.waitForExistence(timeout: 2) else { return false }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, !element.exists {
            settingsScrollView.swipeUp(velocity: .fast)
        }
        return element.exists
    }

    @MainActor
    private func primaryTab(
        _ identifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let tab = app.buttons.matching(identifier: identifier).firstMatch
        XCTAssertTrue(
            tab.waitForExistence(timeout: timeout),
            "Primary tab did not appear: \(identifier)",
            file: file,
            line: line
        )
        return tab
    }

    @MainActor
    private func waitForTodoToolbarAction(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let loadErrorAlert = app.alerts["Todo error"]

        while Date() < deadline {
            if element.exists { return true }

            if loadErrorAlert.exists,
               loadErrorAlert.staticTexts["Failed to load Todos."].exists {
                let dismissButton = loadErrorAlert.buttons["OK"]
                guard dismissButton.exists else { return false }
                dismissButton.tap()
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return element.exists
    }

    @MainActor
    private func assertMinimumTouchTarget(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let pixelTolerance: CGFloat = 0.01
        let frame = element.frame
        let width = frame.width
        let height = frame.height
        XCTAssertGreaterThanOrEqual(width, 44 - pixelTolerance, file: file, line: line)
        XCTAssertGreaterThanOrEqual(height, 44 - pixelTolerance, file: file, line: line)
    }
}
