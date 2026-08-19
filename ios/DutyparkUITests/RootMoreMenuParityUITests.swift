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
        // The UI-test fixture user is not an admin, so `more.admin` must stay absent.
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
            ]
        )
        for button in moreButtons {
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

    // Admin sits two pushes deep in the More stack, so a member calendar opened from a
    // member detail has to stack on top of it instead of replacing the calendar tab.
    @MainActor
    func testAdminMemberCalendarPushesOntoTheMoreStack() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-service-admin",
            "-ui-testing-authenticated",
            "-ui-testing-admin-visual-fixture",
        ]
        app.launch()
        defer { app.terminate() }

        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 20))
        moreTab.tap()

        let adminButton = app.buttons["more.admin"].firstMatch
        XCTAssertTrue(adminButton.waitForExistence(timeout: 10))
        adminButton.tap()

        let memberRow = app.descendants(matching: .any)["admin.member.7"].firstMatch
        XCTAssertTrue(memberRow.waitForExistence(timeout: 10))
        memberRow.tap()

        let openCalendar = app.buttons["달력으로 이동"].firstMatch
        XCTAssertTrue(openCalendar.waitForExistence(timeout: 10))
        openCalendar.tap()

        let memberCalendar = app.descendants(matching: .any)["screen.calendar.member"]
        XCTAssertTrue(memberCalendar.waitForExistence(timeout: 10))
        XCTAssertTrue(
            moreTab.isSelected,
            "A member calendar opened from Admin must not jump to the calendar tab"
        )

        let identityChip = app.buttons["calendar.member.back"].firstMatch
        XCTAssertTrue(identityChip.waitForExistence(timeout: 10))
        identityChip.tap()

        XCTAssertTrue(memberCalendar.waitForNonExistence(timeout: 5))
        // The admin member detail is pushed by a destination-based link, which SwiftUI
        // cannot represent in the tab's path, so growing the path drops it and back
        // lands on the admin member list. That is the same screen the previous
        // origin-restoring implementation returned to, now reached by a real pop.
        XCTAssertTrue(
            memberRow.waitForExistence(timeout: 10),
            "Back from an admin member calendar must return into the admin stack"
        )
        XCTAssertTrue(moreTab.isSelected)
    }
}
