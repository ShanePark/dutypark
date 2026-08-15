import XCTest

final class RootHamburgerMenuParityUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHamburgerShowsGlobalActionsWithoutDuplicatingDockDestinations() {
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

        let menuButtons = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "menu.")
        ).allElementsBoundByIndex
        XCTAssertEqual(
            Set(menuButtons.map(\.identifier)),
            [
                "menu.friends",
                "menu.notifications",
                "menu.guide",
                "menu.logout",
            ]
        )
        for button in menuButtons {
            XCTAssertTrue(button.isHittable, "Menu action is not hittable: \(button.identifier)")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }

        for removedIdentifier in [
            "menu.home",
            "menu.calendar",
            "menu.todo",
            "menu.team",
            "menu.settings",
        ] {
            XCTAssertFalse(app.buttons[removedIdentifier].exists)
        }

        for dockIdentifier in [
            "tab.home",
            "tab.calendar",
            "tab.todo",
            "tab.team",
            "tab.settings",
        ] {
            XCTAssertTrue(app.buttons[dockIdentifier].exists)
        }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "parity-ios-root-menu-deduplicated-after"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
