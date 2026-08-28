import XCTest

final class SettingsRootConfirmationVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testProfilePhotoDeleteUsesCenteredKoreanConfirmation() {
        let app = launchAuthenticatedApp(profilePhotoFixture: true)
        defer { app.terminate() }

        openMyInfo(in: app)
        let photoActionsButton = app.buttons["settings.photo.actions"]
        XCTAssertTrue(photoActionsButton.waitForExistence(timeout: 10))
        XCTAssertTrue(photoActionsButton.isHittable)
        let pixelTolerance: CGFloat = 0.01
        XCTAssertGreaterThanOrEqual(photoActionsButton.frame.width, 80 - pixelTolerance)
        XCTAssertGreaterThanOrEqual(photoActionsButton.frame.height, 80 - pixelTolerance)
        XCTAssertFalse(app.buttons["현재 프로필 사진 자르기"].exists)
        photoActionsButton.tap()

        let deleteButton = app.buttons["settings.photo.delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        XCTAssertTrue(deleteButton.isHittable)
        deleteButton.tap()

        assertCenteredConfirmation(
            in: app,
            title: "기본 이미지로 변경",
            message: "프로필 사진을 기본 이미지로 변경하시겠습니까?",
            confirmTitle: "기본 이미지로 변경"
        )
        capture("parity-ios-profile-photo-delete-confirmation-after")
    }

    @MainActor
    func testRootMenuLogoutUsesCenteredKoreanConfirmation() {
        let app = launchAuthenticatedApp()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20)
        )
        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.more"].waitForExistence(timeout: 10)
        )

        let logoutButton = app.buttons["more.logout"]
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 10))
        XCTAssertTrue(logoutButton.isHittable)
        logoutButton.tap()

        assertCenteredConfirmation(
            in: app,
            title: "로그아웃",
            message: "정말 로그아웃 하시겠습니까?",
            confirmTitle: "로그아웃"
        )
        capture("parity-ios-root-menu-logout-confirmation-after")
    }

    @MainActor
    func testRootMenuUsesTheSameKoreanGuideCopyAsTheWebMenu() {
        let app = launchAuthenticatedApp()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20)
        )
        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.more"].waitForExistence(timeout: 10)
        )

        XCTAssertTrue(app.staticTexts["이용 안내"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["사용 가이드"].exists)
        capture("parity-ios-root-menu-guide-copy-after")
    }

    @MainActor
    private func launchAuthenticatedApp(profilePhotoFixture: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ]
        if profilePhotoFixture {
            app.launchArguments.append("-ui-testing-profile-photo")
        }
        app.launch()
        return app
    }

    @MainActor
    private func openMyInfo(in app: XCUIApplication) {
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20)
        )
        let moreTab = app.buttons.matching(identifier: "tab.more").firstMatch
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.more"].waitForExistence(timeout: 10)
        )
        let myInfoEntry = app.buttons["more.myInfo"]
        XCTAssertTrue(myInfoEntry.waitForExistence(timeout: 10))
        myInfoEntry.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.myInfo"].waitForExistence(timeout: 10)
        )
    }

    @MainActor
    private func assertCenteredConfirmation(
        in app: XCUIApplication,
        title: String,
        message: String,
        confirmTitle: String
    ) {
        let titleText = app.staticTexts[title].firstMatch
        let messageText = app.staticTexts[message].firstMatch
        let cancelButton = app.buttons["dp.confirmation.cancel"]
        let confirmButton = app.buttons["dp.confirmation.confirm"]

        XCTAssertTrue(titleText.waitForExistence(timeout: 10))
        XCTAssertTrue(messageText.waitForExistence(timeout: 10))
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10))
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))
        XCTAssertEqual(cancelButton.label, "취소")
        XCTAssertEqual(confirmButton.label, confirmTitle)
        XCTAssertEqual(
            (cancelButton.frame.midX + confirmButton.frame.midX) / 2,
            app.frame.midX,
            accuracy: 20
        )
    }

    @MainActor
    private func capture(_ name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
