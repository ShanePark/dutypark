import XCTest

/// Captures the real local demo account for README and App Store artwork.
///
/// This suite intentionally does not use any `-ui-testing-*` fixture. The account is
/// seeded by the local backend, and the app's `-capture-demo-local-only` launch guard
/// refuses to run if the simulator build points at a remote API.
final class DemoAppStoreCaptureUITests: XCTestCase {
    private let koreanDemoEmail = "demo.seoa@dutypark.local"
    private let englishDemoEmail = "demo.en.emma@dutypark.local"
    private let demoPassword = "demo1234!"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturesKoreanDemoScreensForAppStore() throws {
        try captureDemoScreens(
            language: "ko",
            locale: "ko_KR",
            email: koreanDemoEmail
        )
    }

    @MainActor
    func testCapturesEnglishDemoScreensForAppStore() throws {
        try captureDemoScreens(
            language: "en",
            locale: "en_US",
            email: englishDemoEmail
        )
    }

    @MainActor
    private func captureDemoScreens(language: String, locale: String, email: String) throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "light",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
            "-capture-demo-local-only",
            "-capture-demo-real-account"
        ]
        app.launch()
        defer { app.terminate() }

        signOutIfNeeded(in: app)
        signIn(in: app, email: email)

        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 30), "Demo account did not reach Home")
        waitForHomeContent(in: app)
        capture("appstore-\(language)-01-home-demo")

        openPrimaryTab("tab.calendar", screen: "screen.calendar", in: app)
        waitForSettledContent(in: app, loadingIdentifier: nil)
        if language == "en" {
            selectEnglishCaptureMonth(in: app)
        }
        capture("appstore-\(language)-02-calendar-demo")
        captureCalendarDDay(language: language, in: app)

        openPrimaryTab("tab.todo", screen: "screen.todo", in: app)
        waitForSettledContent(in: app, loadingIdentifier: nil)
        capture("appstore-\(language)-03-todo-demo")

        openPrimaryTab("tab.team", screen: "screen.team", in: app)
        waitForSettledContent(in: app, loadingIdentifier: nil)
        capture("appstore-\(language)-04-team-demo")

        openPrimaryTab("tab.more", screen: "screen.more", in: app)
        waitForSettledContent(in: app, loadingIdentifier: nil)
        capture("appstore-\(language)-05-more-demo")

        let friends = app.buttons["more.friends"]
        XCTAssertTrue(friends.waitForExistence(timeout: 10), "More menu did not load friend entry")
        friends.tap()
        let social = app.descendants(matching: .any)["social.list"]
        XCTAssertTrue(social.waitForExistence(timeout: 20), "Friend list did not load")
        waitForSettledContent(in: app, loadingIdentifier: "social.loading")
        capture("appstore-\(language)-06-social-demo")
    }

    @MainActor
    private func signIn(in app: XCUIApplication, email demoEmail: String) {
        let loginEntry = app.buttons["guest.login"]
        XCTAssertTrue(loginEntry.waitForExistence(timeout: 30), "Guest landing did not load")
        loginEntry.tap()

        let email = app.textFields.firstMatch
        let password = app.secureTextFields.firstMatch
        XCTAssertTrue(email.waitForExistence(timeout: 10), "Email field did not load")
        XCTAssertTrue(password.waitForExistence(timeout: 10), "Password field did not load")
        email.tap()
        email.typeText(demoEmail)
        password.tap()
        password.typeText(demoPassword)

        let submit = app.buttons["login.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 10), "Login submit button did not load")
        let dismissKeyboard = app.buttons["keyboard.dismiss"].firstMatch
        if !submit.isHittable, dismissKeyboard.waitForExistence(timeout: 2) {
            dismissKeyboard.tap()
        }
        submit.tap()
    }

    @MainActor
    private func signOutIfNeeded(in app: XCUIApplication) {
        let home = app.descendants(matching: .any)["screen.home"]
        guard home.waitForExistence(timeout: 5) else { return }

        let more = app.buttons["tab.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 10), "More tab did not load for account reset")
        more.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.more"].waitForExistence(timeout: 10),
            "More screen did not load for account reset"
        )

        let logout = app.buttons["more.logout"]
        XCTAssertTrue(logout.waitForExistence(timeout: 10), "Logout action did not load")
        logout.tap()

        let confirm = app.buttons["dp.confirmation.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "Logout confirmation did not load")
        confirm.tap()
        XCTAssertTrue(
            app.buttons["guest.login"].waitForExistence(timeout: 30),
            "Guest landing did not return after logout"
        )
    }

    @MainActor
    private func openPrimaryTab(
        _ tabIdentifier: String,
        screen screenIdentifier: String,
        in app: XCUIApplication
    ) {
        let tab = app.buttons[tabIdentifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "Missing primary tab: \(tabIdentifier)")
        tab.tap()
        let screen = app.descendants(matching: .any)[screenIdentifier]
        XCTAssertTrue(screen.waitForExistence(timeout: 20), "Missing screen: \(screenIdentifier)")
    }

    @MainActor
    private func waitForHomeContent(in app: XCUIApplication) {
        waitForSettledContent(in: app, loadingIdentifier: "home.loading")
        XCTAssertTrue(
            app.descendants(matching: .any)["home.friends.total"].waitForExistence(timeout: 20),
            "Home friend rail did not load demo data"
        )
    }

    @MainActor
    private func selectEnglishCaptureMonth(in app: XCUIApplication) {
        let monthDisplay = app.buttons["calendar.month.display"]
        XCTAssertTrue(monthDisplay.waitForExistence(timeout: 10), "Calendar month control did not load")
        XCTAssertEqual(
            monthDisplay.value as? String,
            "2026-08",
            "The English demo capture starts in August 2026 before its three-month move"
        )

        monthDisplay.tap()
        let monthPicker = app.descendants(matching: .any)["calendar.monthPicker"]
        XCTAssertTrue(monthPicker.waitForExistence(timeout: 5), "Calendar month picker did not load")
        XCTAssertTrue(
            app.staticTexts["2026"].waitForExistence(timeout: 5),
            "The English month picker must be on the 2026 year"
        )

        let november = app.buttons["calendar.monthPicker.month.11"]
        XCTAssertTrue(november.waitForExistence(timeout: 5), "November month button did not load")
        november.tap()
        XCTAssertTrue(monthPicker.waitForNonExistence(timeout: 5), "Month picker did not dismiss")

        let monthChanged = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "2026-11"),
            object: monthDisplay
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [monthChanged], timeout: 10),
            .completed,
            "English capture must show November 2026 after moving three months"
        )
        XCTAssertEqual(monthDisplay.value as? String, "2026-11")
    }

    @MainActor
    private func captureCalendarDDay(language: String, in app: XCUIApplication) {
        let calendar = app.descendants(matching: .any)["screen.calendar"]
        XCTAssertTrue(calendar.exists, "Calendar must remain visible before D-Day capture")

        let dDayBadge = app.staticTexts.matching(
            NSPredicate(
                format: "label MATCHES %@",
                "D(-|\\+)[0-9]+|D-Day"
            )
        ).firstMatch
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10), "Calendar scroll view did not load")

        // Move the D-Day cards away from the calendar overview so this capture is
        // visually distinct even on tall devices where a badge is already visible.
        scrollView.swipeUp()
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))

        for _ in 0..<7 where !dDayBadge.exists {
            scrollView.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        XCTAssertTrue(
            dDayBadge.waitForExistence(timeout: 10),
            "Calendar D-Day cards did not become visible after scrolling"
        )
        capture("appstore-\(language)-07-dday-demo")
    }

    @MainActor
    private func waitForSettledContent(in app: XCUIApplication, loadingIdentifier: String?) {
        if let loadingIdentifier {
            let loading = app.descendants(matching: .any)[loadingIdentifier]
            if loading.exists {
                XCTAssertTrue(
                    loading.waitForNonExistence(timeout: 30),
                    "Timed out while waiting for \(loadingIdentifier)"
                )
            }
        }
        // Let the network response, avatar loads, and SwiftUI layout settle before the
        // screenshot is attached to the xcresult bundle.
        RunLoop.current.run(until: Date().addingTimeInterval(0.75))
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
