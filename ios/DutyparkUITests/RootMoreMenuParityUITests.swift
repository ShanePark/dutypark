import XCTest

final class RootMoreMenuParityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMoreMenuShowsGlobalActionsWithoutDuplicatingDockDestinations() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ]
        app.launch()
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

        let moreButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "more.")
        ).allElementsBoundByIndex
        // Service administration is not exposed in the iOS More menu.
        XCTAssertEqual(
            Set(moreButtons.map(\.identifier)),
            [
                "more.myInfo",
                "more.friends",
                "more.notifications",
                "more.guide",
                "more.support",
                "more.settings",
                "more.logout",
                "more.terms",
                "more.privacy",
            ]
        )
        let footerIdentifiers: Set<String> = ["more.terms", "more.privacy"]
        for button in moreButtons where !footerIdentifiers.contains(button.identifier) {
            XCTAssertTrue(button.isHittable, "More action is not hittable: \(button.identifier)")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }

        // The profile card is the only entry point to the account screen, so it has to
        // stay at the top of the list with a comfortable target.
        let myInfoCard = app.buttons["more.myInfo"]
        XCTAssertGreaterThanOrEqual(myInfoCard.frame.height, 64)
        for button in moreButtons where button.identifier != "more.myInfo" {
            XCTAssertLessThan(myInfoCard.frame.minY, button.frame.minY)
        }

        // The version footer closes the list the way other apps end their settings screen.
        let versionLabel = app.staticTexts["more.appVersion"]
        XCTAssertTrue(versionLabel.waitForExistence(timeout: 10))
        XCTAssertTrue(versionLabel.label.hasPrefix("버전 "), "Unexpected version label: \(versionLabel.label)")
        for button in moreButtons {
            XCTAssertLessThan(button.frame.minY, versionLabel.frame.minY)
        }
        // Terms and privacy sit in the same quiet footer, after the menu and the logout row.
        let logout = app.buttons["more.logout"]
        for identifier in footerIdentifiers {
            XCTAssertGreaterThan(app.buttons[identifier].frame.minY, logout.frame.maxY)
        }

        for removedIdentifier in [
            "more.home",
            "more.calendar",
            "more.todo",
            "more.team",
            "more.more",
        ] {
            XCTAssertFalse(app.buttons[removedIdentifier].exists)
        }

        for dockIdentifier in [
            "tab.home",
            "tab.calendar",
            "tab.todo",
            "tab.team",
            "tab.more",
        ] {
            XCTAssertTrue(app.buttons[dockIdentifier].exists)
        }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "parity-ios-root-more-deduplicated-after"
        attachment.lifetime = .keepAlways
        add(attachment)

        myInfoCard.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.myInfo"].waitForExistence(timeout: 10)
        )
    }

}
