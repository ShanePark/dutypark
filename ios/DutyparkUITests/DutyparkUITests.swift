import XCTest

final class DutyparkUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNavigatesThroughFivePrimaryTabs() throws {
        let app = XCUIApplication()
        app.launchArguments += [
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
            (tab: "tab.more", screen: "screen.more")
        ]

        for destination in destinations {
            let tab = primaryTab(destination.tab, in: app)
            tab.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)[destination.screen].waitForExistence(timeout: 10)
            )
            assertNoUnexpectedAlert(in: app, context: destination.tab)
        }
    }

    @MainActor
    func testLoginOffersAppleKakaoAndNaver() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-guest"
        ]
        app.launch()

        let loginButton = app.buttons["guest.login"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10))
        loginButton.tap()

        XCTAssertTrue(app.buttons["login.oauth.apple"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["login.oauth.kakao"].exists)
        XCTAssertTrue(app.buttons["login.oauth.naver"].exists)
    }

    @MainActor
    func testKeyboardProvidesAnExplicitDismissAction() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "light",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-guest"
        ]
        app.launch()

        let loginButton = app.buttons["guest.login"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10))
        loginButton.tap()

        let emailField = app.textFields.firstMatch
        XCTAssertTrue(emailField.waitForExistence(timeout: 10))
        emailField.tap()

        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3))
        let dismissButton = app.buttons["keyboard.dismiss"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 3))
        dismissButton.tap()
        XCTAssertFalse(keyboard.waitForExistence(timeout: 1))
    }

    @MainActor
    func testPrimaryToolbarActionsMeetMinimumTouchTarget() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "light",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ui-testing-authenticated"
        ]
        app.launch()

        let brand = app.buttons["header.brand"]
        XCTAssertTrue(brand.waitForExistence(timeout: 10))
        assertMinimumTouchTarget(brand)

        let notificationBell = app.buttons["notifications.bell"]
        XCTAssertTrue(notificationBell.waitForExistence(timeout: 10))
        assertMinimumTouchTarget(notificationBell)

        primaryTab("tab.todo", in: app).tap()
        let todoAdd = app.buttons["todo.add"]
        XCTAssertTrue(todoAdd.waitForExistence(timeout: 10))
        assertMinimumTouchTarget(todoAdd)
        assertNoUnexpectedAlert(in: app, context: "Todo toolbar")
    }

    @MainActor
    func testTodoDraftCanBeEditedAndDiscardedWithoutSaving() throws {
        let app = launchAuthenticatedApp()
        defer { app.terminate() }

        primaryTab("tab.todo", in: app).tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.todo"].waitForExistence(timeout: 10)
        )

        let addButton = app.buttons["todo.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.tap()

        let titleField = app.textFields["todo.form.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))
        titleField.tap()
        titleField.typeText("UI test draft")

        let todoStatus = app.buttons["todo.form.status.todo"]
        XCTAssertTrue(todoStatus.waitForExistence(timeout: 5))
        todoStatus.tap()
        XCTAssertEqual(titleField.value as? String, "UI test draft")

        let keyboardDismiss = app.buttons["keyboard.dismiss"]
        if keyboardDismiss.waitForExistence(timeout: 2) {
            keyboardDismiss.tap()
        }

        app.buttons["todo.form.cancel"].tap()
        let discardButton = app.buttons["dp.confirmation.confirm"]
        XCTAssertTrue(discardButton.waitForExistence(timeout: 5))
        discardButton.tap()

        XCTAssertTrue(waitForNonHittable(titleField, timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["screen.todo"].exists)
        assertNoUnexpectedAlert(in: app, context: "discarding a Todo draft")
    }

    @MainActor
    func testCalendarParityCentersHeaderAndOpensOnlyTheTappedTodoDetail() throws {
        let app = launchAuthenticatedApp(extraArguments: ["-ui-testing-calendar-parity"])
        defer { app.terminate() }

        primaryTab("tab.calendar", in: app).tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.calendar"].waitForExistence(timeout: 10)
        )

        let monthControls = app.descendants(matching: .any)["calendar.month.controls"]
        XCTAssertTrue(monthControls.waitForExistence(timeout: 10))
        XCTAssertEqual(monthControls.frame.midX, app.frame.midX, accuracy: 1)
        XCTAssertFalse(
            app.buttons["calendar.todo.add"].exists,
            "The Todo strip above the calendar is removed"
        )
        XCTAssertTrue(app.buttons["tab.todo"].exists, "The dock Todo entry must remain")

        let comparedDuty = app.descendants(matching: .any)["calendar.compared-duty.2"]
        XCTAssertTrue(comparedDuty.waitForExistence(timeout: 10))

        let calendarEvidence = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        calendarEvidence.name = "calendar-centered-header-profile-duty"
        calendarEvidence.lifetime = .keepAlways
        add(calendarEvidence)

        let dayTodo = app.buttons["calendar.day.todo.A11CE000-0000-4000-8000-000000000011"]
        XCTAssertTrue(dayTodo.waitForExistence(timeout: 10))
        dayTodo.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["calendar.todo.detail"].waitForExistence(timeout: 10)
        )
        XCTAssertTrue(app.staticTexts["Calendar detail check"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["screen.todo"].exists)

        let detailEvidence = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        detailEvidence.name = "calendar-direct-todo-detail"
        detailEvidence.lifetime = .keepAlways
        add(detailEvidence)

        app.buttons["Close"].tap()
        XCTAssertTrue(waitForNonHittable(
            app.descendants(matching: .any)["calendar.todo.detail"],
            timeout: 3
        ))
        XCTAssertTrue(app.descendants(matching: .any)["screen.calendar"].exists)
    }

    @MainActor
    func testCalendarMonthPickerChangesMonthUsingFixture() throws {
        let app = launchAuthenticatedApp()
        defer { app.terminate() }

        primaryTab("tab.calendar", in: app).tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.calendar"].waitForExistence(timeout: 10)
        )

        let monthDisplay = app.buttons["calendar.month.display"]
        XCTAssertTrue(monthDisplay.waitForExistence(timeout: 10))
        let initialYearMonth = try XCTUnwrap(monthDisplay.value as? String)
        let parts = initialYearMonth.split(separator: "-")
        XCTAssertEqual(parts.count, 2)
        let currentYear = try XCTUnwrap(parts.first.flatMap { Int($0) })
        let currentMonth = try XCTUnwrap(parts.dropFirst().first.flatMap { Int($0) })

        monthDisplay.tap()
        let monthPicker = app.descendants(matching: .any)["calendar.monthPicker"]
        XCTAssertTrue(monthPicker.waitForExistence(timeout: 5))

        let alternateMonth = currentMonth == 1 ? 2 : 1
        let alternateMonthButton = app.buttons["calendar.monthPicker.month.\(alternateMonth)"]
        XCTAssertTrue(alternateMonthButton.waitForExistence(timeout: 5))
        alternateMonthButton.tap()

        XCTAssertTrue(monthPicker.waitForNonExistence(timeout: 5))
        let expectedYearMonth = String(format: "%04d-%02d", currentYear, alternateMonth)
        let monthChanged = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedYearMonth),
            object: monthDisplay
        )
        XCTAssertEqual(XCTWaiter.wait(for: [monthChanged], timeout: 5), .completed)
        XCTAssertNotEqual(monthDisplay.value as? String, initialYearMonth)
        XCTAssertTrue(app.descendants(matching: .any)["screen.calendar"].exists)
        assertNoUnexpectedAlert(in: app, context: "changing Calendar month")
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

                let moreTab = primaryTab("tab.more", in: app, timeout: 20)
                XCTAssertTrue(moreTab.isHittable)
                assertMinimumTouchTarget(moreTab)
                moreTab.tap()
                XCTAssertTrue(
                    app.descendants(matching: .any)["screen.more"].waitForExistence(timeout: 10)
                )

                let settingsRow = app.buttons["more.settings"]
                XCTAssertTrue(settingsRow.waitForExistence(timeout: 10))
                settingsRow.tap()
                XCTAssertTrue(
                    app.descendants(matching: .any)["screen.settings"].waitForExistence(timeout: 10)
                )
                assertNoUnexpectedAlert(in: app, context: "Settings")

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
                assertNoUnexpectedAlert(in: app, context: "returning Home")
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
    private func launchAuthenticatedApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "light",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ui-testing-authenticated"
        ]
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func waitForNonHittable(
        _ element: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == false"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
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
    private func assertNoUnexpectedAlert(
        in app: XCUIApplication,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            app.alerts.firstMatch.waitForExistence(timeout: 0.5),
            "Unexpected alert appeared after \(context)",
            file: file,
            line: line
        )
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
