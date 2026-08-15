import XCTest

final class AttachmentGalleryVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAttachmentDeleteUsesCenteredConfirmationPanel() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-direct-attachment-gallery",
        ]
        app.launch()
        defer { app.terminate() }

        let fixtureScreen = app.descendants(matching: .any)["screen.attachmentGallery.fixture"]
        XCTAssertTrue(fixtureScreen.waitForExistence(timeout: 20))

        let moreButton = app.buttons[
            "attachment.11111111-2222-3333-4444-555555555555.more"
        ]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 10))
        XCTAssertTrue(moreButton.isHittable)
        moreButton.tap()

        let menuDeleteButton = app.buttons
            .matching(NSPredicate(format: "label == %@", "삭제"))
            .firstMatch
        XCTAssertTrue(menuDeleteButton.waitForExistence(timeout: 10))
        menuDeleteButton.tap()

        let title = app.staticTexts["이 첨부파일을 삭제할까요?"]
        let cancelButton = app.buttons["dp.confirmation.cancel"]
        let confirmButton = app.buttons["dp.confirmation.confirm"]

        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10))
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10))
        XCTAssertEqual(cancelButton.label, "취소")
        XCTAssertEqual(confirmButton.label, "삭제")

        let filenameQuery = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "교대표-확인용.pdf")
        )
        XCTAssertTrue(filenameQuery.firstMatch.waitForExistence(timeout: 10))
        let filename = try XCTUnwrap(
            filenameQuery.allElementsBoundByIndex.first {
                $0.frame.midY > title.frame.maxY && $0.frame.midY < cancelButton.frame.minY
            },
            "The confirmation filename must render between its title and action buttons"
        )

        XCTAssertEqual(title.frame.midX, app.frame.midX, accuracy: 20)
        XCTAssertEqual(filename.frame.midX, app.frame.midX, accuracy: 20)
        XCTAssertEqual(
            (cancelButton.frame.midX + confirmButton.frame.midX) / 2,
            app.frame.midX,
            accuracy: 20
        )
        XCTAssertLessThan(cancelButton.frame.minX, confirmButton.frame.minX)
        XCTAssertEqual(cancelButton.frame.width, confirmButton.frame.width, accuracy: 2)

        capture("parity-ios-attachment-delete-confirmation-after")

        cancelButton.tap()
        XCTAssertTrue(confirmButton.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
