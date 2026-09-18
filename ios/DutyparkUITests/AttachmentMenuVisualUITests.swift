import XCTest

/// Screenshot-only coverage for the Todo attachment source picker.
///
/// The test deliberately stops after the source menu is visible. It does not
/// select a source, invoke a system picker, upload a file, or save the Todo.
final class AttachmentMenuVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testKoreanDarkTodoAttachmentMenu() {
        captureTodoAttachmentFlow(theme: "dark", suffix: "ko-dark")
    }

    @MainActor
    func testKoreanLightTodoAttachmentMenu() {
        captureTodoAttachmentFlow(theme: "light", suffix: "ko-light")
    }

    @MainActor
    private func captureTodoAttachmentFlow(theme: String, suffix: String) {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", theme,
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
        ]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20),
            "Authenticated home screen did not become ready"
        )

        let todoTab = app.buttons["tab.todo"]
        XCTAssertTrue(todoTab.waitForExistence(timeout: 10))
        XCTAssertTrue(todoTab.isHittable)
        todoTab.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.todo"].waitForExistence(timeout: 10),
            "Todo screen did not become ready"
        )

        let addButton = app.buttons["todo.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        XCTAssertTrue(addButton.isHittable)
        addButton.tap()

        let titleField = app.textFields["todo.form.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))

        // The attachment control is intentionally a single, full-width action
        // before the menu opens. This keeps the screenshot useful as a layout
        // check as well as an interaction check.
        let attachmentButton = app.buttons["attachment.add"]
        XCTAssertTrue(
            attachmentButton.waitForExistence(timeout: 10),
            "Todo form must expose one attachment action"
        )
        XCTAssertTrue(attachmentButton.isHittable)
        XCTAssertGreaterThan(attachmentButton.frame.width, 200)
        XCTAssertGreaterThan(attachmentButton.frame.minY, titleField.frame.maxY)
        capture("todo-attachment-\(suffix)-modal")

        attachmentButton.tap()

        // These identifiers are shared by the three source actions and are
        // asserted without tapping them, so no system picker can be launched.
        let sourceButtons = [
            (id: "attachment.source.camera", label: "camera"),
            (id: "attachment.source.photos", label: "photo library"),
            (id: "attachment.source.files", label: "files"),
        ]
        for source in sourceButtons {
            let button = app.buttons[source.id]
            XCTAssertTrue(
                button.waitForExistence(timeout: 10),
                "Attachment source menu must expose \(source.label)"
            )
            // Simulator has no camera; the capture action remains visible but disabled.
            if source.id != "attachment.source.camera" {
                XCTAssertTrue(button.isHittable, "Attachment \(source.label) action must be hittable")
            }
        }
        capture("todo-attachment-\(suffix)-source-menu")
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
