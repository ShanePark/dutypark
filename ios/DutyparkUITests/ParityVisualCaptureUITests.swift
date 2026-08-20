import XCTest

final class ParityVisualCaptureUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturesPopulatedHomeFriendsParity() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ]
        app.launch()
        defer { app.terminate() }

        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))

        let total = app.descendants(matching: .any)["home.friends.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 10))
        XCTAssertEqual(total.value as? String, "3")

        home.swipeUp()

        let firstPinnedFriend = app.buttons["home.friend.21"]
        let secondPinnedFriend = app.buttons["home.friend.22"]
        let unpinnedFriend = app.buttons["home.friend.23"]
        XCTAssertTrue(firstPinnedFriend.waitForExistence(timeout: 10))
        XCTAssertTrue(secondPinnedFriend.exists)
        XCTAssertTrue(unpinnedFriend.exists)
        XCTAssertFalse(app.staticTexts["받은 요청"].exists)
        XCTAssertFalse(app.staticTexts["보낸 요청"].exists)
        XCTAssertEqual(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.friend.reorderHandle"))
                .count,
            0
        )

        // The rail no longer reorders (D3), so there is no drag state left to
        // capture: a stationary long press on a card is just a slow tap that
        // opens the friend's calendar, which the home interaction tests cover.
        XCTAssertTrue(home.exists)
        capture("parity-ios-home-friends-populated-after")
    }

    @MainActor
    func testCapturesKoreanDarkModeParityFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ]
        app.launch()
        defer { app.terminate() }

        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        capture("parity-ios-01-home-ko-dark")

        let todoTab = app.buttons.matching(identifier: "tab.todo").firstMatch
        XCTAssertTrue(todoTab.waitForExistence(timeout: 10))
        todoTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.todo"].waitForExistence(timeout: 10)
        )
        capture("parity-ios-02-todo-ko-dark")

        let calendarTab = app.buttons.matching(identifier: "tab.calendar").firstMatch
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 10))
        calendarTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.calendar"].waitForExistence(timeout: 10)
        )
        capture("parity-ios-03-calendar-ko-dark")

        let teamTab = app.buttons.matching(identifier: "tab.team").firstMatch
        XCTAssertTrue(teamTab.waitForExistence(timeout: 10))
        teamTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.team"].waitForExistence(timeout: 10)
        )
        capture("parity-ios-04-team-ko-dark")

        let homeTab = app.buttons.matching(identifier: "tab.home").firstMatch
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))
        homeTab.tap()
        XCTAssertTrue(home.waitForExistence(timeout: 10))

        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()

        let more = app.descendants(matching: .any)["screen.more"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        capture("parity-ios-05-more-ko-dark")

        let myInfoRow = app.buttons["more.myInfo"]
        XCTAssertTrue(myInfoRow.waitForExistence(timeout: 10))
        myInfoRow.tap()

        let myInfo = app.descendants(matching: .any)["screen.myInfo"]
        XCTAssertTrue(myInfo.waitForExistence(timeout: 10))
        let patternTitle = app.staticTexts["기본 근무 패턴"].firstMatch
        XCTAssertTrue(patternTitle.waitForExistence(timeout: 10))
        capture("parity-ios-06-my-info-ko-dark")

        let editPatternButton = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "변경"))
            .firstMatch
        XCTAssertTrue(editPatternButton.waitForExistence(timeout: 10))
        editPatternButton.tap()

        let patternModalTitle = app.staticTexts
            .matching(identifier: "기본 근무 패턴")
            .firstMatch
        XCTAssertTrue(patternModalTitle.waitForExistence(timeout: 10))
        let disablePatternButton = app.buttons["패턴 해제"].firstMatch
        XCTAssertTrue(disablePatternButton.waitForExistence(timeout: 10))
        capture("parity-ios-07-default-work-pattern-ko-dark")

        disablePatternButton.tap()

        let confirmationTitle = app.staticTexts["근무 패턴을 해제할까요?"]
        XCTAssertTrue(confirmationTitle.waitForExistence(timeout: 10))
        capture("parity-ios-08-disable-pattern-confirmation-ko-dark")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
