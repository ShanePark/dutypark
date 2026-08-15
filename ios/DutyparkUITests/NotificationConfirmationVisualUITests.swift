import XCTest

final class NotificationConfirmationVisualUITests: XCTestCase {
    private let unreadNotificationID = "00000000-0000-0000-0000-000000000101"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNotificationDeletionConfirmationUsesStableCenteredSharedPanel() {
        let app = makeApp()
        app.launch()
        defer { app.terminate() }

        openNotificationCenter(in: app)

        let rowDeleteButton = app.buttons[
            "notifications.row.\(unreadNotificationID).delete"
        ]
        XCTAssertTrue(rowDeleteButton.waitForExistence(timeout: 10))
        XCTAssertTrue(rowDeleteButton.isHittable)
        rowDeleteButton.tap()

        assertCenteredConfirmation(
            in: app,
            title: "알림 삭제",
            message: "이 알림을 삭제하시겠습니까?",
            confirmTitle: "삭제"
        )
        capture("parity-ios-notification-delete-confirmation-after")
    }

    @MainActor
    func testReadNotificationDeletionConfirmationUsesStableCenteredSharedPanel() {
        let app = makeApp()
        app.launch()
        defer { app.terminate() }

        openNotificationCenter(in: app)

        let deleteReadButton = app.buttons["notifications.deleteRead"]
        XCTAssertTrue(deleteReadButton.waitForExistence(timeout: 10))
        XCTAssertTrue(deleteReadButton.isHittable)
        deleteReadButton.tap()

        assertCenteredConfirmation(
            in: app,
            title: "읽은 알림 삭제",
            message: "읽은 알림을 모두 삭제하시겠습니까?",
            confirmTitle: "읽은 알림 삭제"
        )
        capture("parity-ios-read-notifications-delete-confirmation-after")
    }

    @MainActor
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-notification-fixture",
        ]
        return app
    }

    @MainActor
    private func openNotificationCenter(in app: XCUIApplication) {
        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))

        let bell = app.buttons["notifications.bell"]
        XCTAssertTrue(bell.waitForExistence(timeout: 10))
        bell.tap()

        let dropdown = app.descendants(matching: .any)["notifications.dropdown"]
        XCTAssertTrue(dropdown.waitForExistence(timeout: 10))
        let viewAll = app.buttons["전체보기"].firstMatch
        XCTAssertTrue(viewAll.waitForExistence(timeout: 10))
        viewAll.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.notifications"]
                .waitForExistence(timeout: 10)
        )
    }

    @MainActor
    private func assertCenteredConfirmation(
        in app: XCUIApplication,
        title: String,
        message: String,
        confirmTitle: String
    ) {
        let titleText = app.staticTexts[title]
        let messageText = app.staticTexts[message]
        let cancelButton = app.buttons["dp.confirmation.cancel"]
        let confirmButton = app.buttons["dp.confirmation.confirm"]

        XCTAssertTrue(titleText.waitForExistence(timeout: 10))
        XCTAssertTrue(messageText.waitForExistence(timeout: 10))
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10))
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))
        XCTAssertEqual(cancelButton.label, "취소")
        XCTAssertEqual(confirmButton.label, confirmTitle)
        XCTAssertTrue(cancelButton.isHittable)
        XCTAssertTrue(confirmButton.isHittable)
        XCTAssertGreaterThanOrEqual(cancelButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(cancelButton.frame.height, 44)
        XCTAssertGreaterThanOrEqual(confirmButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(confirmButton.frame.height, 44)

        let frames = [
            titleText.frame,
            messageText.frame,
            cancelButton.frame,
            confirmButton.frame,
        ]
        for frame in frames {
            XCTAssertTrue(app.frame.contains(frame), "Element frame escaped the app bounds: \(frame)")
        }

        XCTAssertFalse(titleText.frame.intersects(messageText.frame))
        XCTAssertFalse(titleText.frame.intersects(cancelButton.frame))
        XCTAssertFalse(titleText.frame.intersects(confirmButton.frame))
        XCTAssertFalse(messageText.frame.intersects(cancelButton.frame))
        XCTAssertFalse(messageText.frame.intersects(confirmButton.frame))
        XCTAssertFalse(cancelButton.frame.intersects(confirmButton.frame))

        XCTAssertEqual(titleText.frame.midX, app.frame.midX, accuracy: 20)
        XCTAssertEqual(messageText.frame.midX, app.frame.midX, accuracy: 20)
        XCTAssertEqual(
            (cancelButton.frame.midX + confirmButton.frame.midX) / 2,
            app.frame.midX,
            accuracy: 20
        )

        let panelTop = min(titleText.frame.minY, messageText.frame.minY)
        let panelBottom = max(cancelButton.frame.maxY, confirmButton.frame.maxY)
        XCTAssertEqual((panelTop + panelBottom) / 2, app.frame.midY, accuracy: 45)

        assertFramesRemainStable(
            [titleText, messageText, cancelButton, confirmButton],
            consecutiveSamples: 4
        )
    }

    @MainActor
    private func assertFramesRemainStable(
        _ elements: [XCUIElement],
        consecutiveSamples: Int
    ) {
        var previousFrames = elements.map(\.frame)

        for sample in 1..<consecutiveSamples {
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))
            let currentFrames = elements.map(\.frame)

            XCTAssertEqual(currentFrames.count, previousFrames.count)
            for (index, pair) in zip(previousFrames, currentFrames).enumerated() {
                XCTAssertEqual(
                    pair.0.origin.x,
                    pair.1.origin.x,
                    accuracy: 0.5,
                    "Element \(index) moved horizontally at stability sample \(sample)"
                )
                XCTAssertEqual(
                    pair.0.origin.y,
                    pair.1.origin.y,
                    accuracy: 0.5,
                    "Element \(index) moved vertically at stability sample \(sample)"
                )
                XCTAssertEqual(
                    pair.0.size.width,
                    pair.1.size.width,
                    accuracy: 0.5,
                    "Element \(index) changed width at stability sample \(sample)"
                )
                XCTAssertEqual(
                    pair.0.size.height,
                    pair.1.size.height,
                    accuracy: 0.5,
                    "Element \(index) changed height at stability sample \(sample)"
                )
            }
            previousFrames = currentFrames
        }
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
