import XCTest

final class TodoConfirmationVisualUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDirtyDraftDiscardUsesCenteredSharedConfirmation() {
        let app = launchApp()
        defer { app.terminate() }

        openTodoScreen(in: app)
        let addButton = app.buttons["todo.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.tap()

        let titleField = app.textFields["todo.form.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))
        titleField.tap()
        titleField.typeText("인계 내용 다시 확인")

        let keyboardDismiss = app.buttons["keyboard.dismiss"]
        if keyboardDismiss.waitForExistence(timeout: 2) {
            keyboardDismiss.tap()
        }
        app.buttons["todo.form.cancel"].tap()

        assertCenteredConfirmation(
            title: "변경사항을 버릴까요?",
            message: "저장하지 않은 변경사항이 사라집니다.",
            confirmTitle: "변경사항 버리기",
            in: app
        )
        capture("parity-ios-todo-discard-confirmation-after")
    }

    @MainActor
    func testFixtureTodoDeleteUsesCenteredSharedConfirmation() {
        let app = launchApp()
        defer { app.terminate() }

        openTodoScreen(in: app)

        let fixtureCard = app.descendants(matching: .any)[
            "todo.card.A11CE000-0000-4000-8000-000000000001"
        ]
        XCTAssertTrue(fixtureCard.waitForExistence(timeout: 10))
        XCTAssertTrue(fixtureCard.isHittable)
        fixtureCard.tap()

        let deleteButton = app.buttons
            .matching(NSPredicate(format: "label == %@", "삭제"))
            .firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
        XCTAssertTrue(deleteButton.isHittable)
        deleteButton.tap()

        assertCenteredConfirmation(
            title: "Todo를 삭제할까요?",
            message: "Todo와 첨부파일이 함께 삭제됩니다.",
            confirmTitle: "삭제",
            in: app
        )
        capture("parity-ios-todo-delete-confirmation-after")
    }

    @MainActor
    func testSelectedStatusKeepsMatchingColumnFullyVisible() {
        let app = launchApp()
        defer { app.terminate() }

        openTodoScreen(in: app)

        let inProgressColumn = app.scrollViews["todo.column.IN_PROGRESS"]
        XCTAssertTrue(inProgressColumn.waitForExistence(timeout: 10))
        assertCenteredAndStable(inProgressColumn, in: app)

        let doneStatus = app.buttons["완료"]
        XCTAssertTrue(doneStatus.waitForExistence(timeout: 10))
        doneStatus.tap()

        let doneColumn = app.scrollViews["todo.column.DONE"]
        XCTAssertTrue(doneColumn.waitForExistence(timeout: 10))
        assertCenteredAndStable(doneColumn, in: app)
    }

    @MainActor
    func testFixtureTodoLongPressReordersWithoutOpeningDetail() {
        let app = launchApp()
        defer { app.terminate() }

        openTodoScreen(in: app)

        let firstCard = app.descendants(matching: .any)[
            "todo.card.A11CE000-0000-4000-8000-000000000001"
        ]
        let secondCard = app.descendants(matching: .any)[
            "todo.card.A11CE000-0000-4000-8000-000000000002"
        ]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10))
        XCTAssertTrue(secondCard.waitForExistence(timeout: 10))
        XCTAssertLessThan(firstCard.frame.minY, secondCard.frame.minY)

        firstCard.press(
            forDuration: 0.5,
            thenDragTo: secondCard,
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        XCTAssertGreaterThan(firstCard.frame.minY, secondCard.frame.minY)
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "label == %@", "삭제")).firstMatch.exists,
            "A completed long-press drag must not also open the Todo detail."
        )
    }

    @MainActor
    func testFixtureTodoVerticalSwipeScrollsWithoutOpeningDetailOrReordering() {
        let app = launchApp()
        defer { app.terminate() }

        openTodoScreen(in: app)

        let firstCard = app.descendants(matching: .any)[
            "todo.card.A11CE000-0000-4000-8000-000000000001"
        ]
        let secondCard = app.descendants(matching: .any)[
            "todo.card.A11CE000-0000-4000-8000-000000000002"
        ]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10))
        XCTAssertTrue(secondCard.waitForExistence(timeout: 10))
        let initialSecondY = secondCard.frame.minY

        firstCard.swipeUp()

        XCTAssertLessThan(secondCard.frame.minY, initialSecondY)
        XCTAssertLessThan(firstCard.frame.minY, secondCard.frame.minY)
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "label == %@", "삭제")).firstMatch.exists,
            "A vertical scroll must not open Todo detail."
        )
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-language", "ko",
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-todo-confirmations",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func openTodoScreen(in app: XCUIApplication) {
        let home = app.descendants(matching: .any)["screen.home"]
        XCTAssertTrue(home.waitForExistence(timeout: 20))
        let todoTab = app.buttons.matching(identifier: "tab.todo").firstMatch
        XCTAssertTrue(todoTab.waitForExistence(timeout: 10))
        todoTab.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["screen.todo"].waitForExistence(timeout: 10)
        )
    }

    @MainActor
    private func assertCenteredConfirmation(
        title: String,
        message: String,
        confirmTitle: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let confirmationTitle = app.staticTexts[title]
        let confirmationMessage = app.staticTexts[message]
        let cancelButton = app.buttons["dp.confirmation.cancel"]
        let confirmButton = app.buttons["dp.confirmation.confirm"]
        XCTAssertTrue(confirmationTitle.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertTrue(confirmationMessage.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertEqual(cancelButton.label, "취소", file: file, line: line)
        XCTAssertEqual(confirmButton.label, confirmTitle, file: file, line: line)

        let elements = [confirmationTitle, confirmationMessage, cancelButton, confirmButton]
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        let firstFrames = elements.map(\.frame)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        let settledFrames = elements.map(\.frame)
        for (first, settled) in zip(firstFrames, settledFrames) {
            XCTAssertEqual(first.minX, settled.minX, accuracy: 1, file: file, line: line)
            XCTAssertEqual(first.minY, settled.minY, accuracy: 1, file: file, line: line)
            XCTAssertEqual(first.width, settled.width, accuracy: 1, file: file, line: line)
            XCTAssertEqual(first.height, settled.height, accuracy: 1, file: file, line: line)
        }

        XCTAssertTrue(cancelButton.isHittable, file: file, line: line)
        XCTAssertTrue(confirmButton.isHittable, file: file, line: line)
        XCTAssertGreaterThanOrEqual(cancelButton.frame.width, 44, file: file, line: line)
        XCTAssertGreaterThanOrEqual(cancelButton.frame.height, 44, file: file, line: line)
        XCTAssertGreaterThanOrEqual(confirmButton.frame.width, 44, file: file, line: line)
        XCTAssertGreaterThanOrEqual(confirmButton.frame.height, 44, file: file, line: line)
        XCTAssertLessThan(confirmationTitle.frame.maxY, confirmationMessage.frame.minY, file: file, line: line)
        XCTAssertLessThan(
            confirmationMessage.frame.maxY,
            min(cancelButton.frame.minY, confirmButton.frame.minY),
            file: file,
            line: line
        )
        XCTAssertLessThan(cancelButton.frame.maxX, confirmButton.frame.minX, file: file, line: line)
        XCTAssertEqual(
            (cancelButton.frame.midX + confirmButton.frame.midX) / 2,
            app.frame.midX,
            accuracy: 20,
            file: file,
            line: line
        )
    }

    @MainActor
    private func assertCenteredAndStable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate { _, _ in
            element.frame.minX >= app.frame.minX
                && element.frame.maxX <= app.frame.maxX
                && abs(element.frame.midX - app.frame.midX) <= 2
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 3),
            .completed,
            "The selected Todo column must be centered and fully visible.",
            file: file,
            line: line
        )

        let frames = (0..<3).map { _ in
            let frame = element.frame
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))
            return frame
        }
        for frame in frames.dropFirst() {
            XCTAssertEqual(frame.minX, frames[0].minX, accuracy: 1, file: file, line: line)
            XCTAssertEqual(frame.minY, frames[0].minY, accuracy: 1, file: file, line: line)
            XCTAssertEqual(frame.width, frames[0].width, accuracy: 1, file: file, line: line)
            XCTAssertEqual(frame.height, frames[0].height, accuracy: 1, file: file, line: line)
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
