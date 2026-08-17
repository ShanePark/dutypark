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
    func testStatusControlsStayOnCreateAndOutOfDetailAndEdit() {
        let app = launchApp()
        defer { app.terminate() }

        openTodoScreen(in: app)

        let addButton = app.buttons["todo.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.tap()
        XCTAssertTrue(app.buttons["todo.form.status.todo"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["todo.form.status.in_progress"].exists)
        XCTAssertTrue(app.buttons["todo.form.status.done"].exists)
        app.buttons["todo.form.cancel"].tap()

        let fixtureCard = app.descendants(matching: .any)[
            "todo.card.A11CE000-0000-4000-8000-000000000001"
        ]
        XCTAssertTrue(fixtureCard.waitForExistence(timeout: 10))
        fixtureCard.tap()

        let editButton = app.buttons
            .matching(NSPredicate(format: "label == %@", "수정"))
            .firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 10))
        let detailButtons = app.buttons.matching(identifier: "todo.detail")
        let detailEditButton = detailButtons
            .matching(NSPredicate(format: "label == %@", "수정"))
            .firstMatch
        let detailDeleteButton = detailButtons
            .matching(NSPredicate(format: "label == %@", "삭제"))
            .firstMatch
        XCTAssertTrue(detailEditButton.exists)
        XCTAssertTrue(detailDeleteButton.exists)
        XCTAssertGreaterThan(detailEditButton.frame.width, 120)
        XCTAssertEqual(detailEditButton.frame.width, detailDeleteButton.frame.width, accuracy: 2)
        XCTAssertFalse(detailButtons.matching(NSPredicate(format: "label == %@", "완료")).firstMatch.exists)
        XCTAssertFalse(detailButtons.matching(NSPredicate(format: "label == %@", "다시 열기")).firstMatch.exists)

        editButton.tap()
        XCTAssertTrue(app.textFields["todo.form.title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["todo.form.status.todo"].exists)
        XCTAssertFalse(app.buttons["todo.form.status.in_progress"].exists)
        XCTAssertFalse(app.buttons["todo.form.status.done"].exists)
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
    func testInProgressLabelsMatchResponsiveWebCopy() {
        let app = launchApp()
        defer { app.terminate() }

        openTodoScreen(in: app)

        let webCopy = app.staticTexts.matching(NSPredicate(format: "label == %@", "진행중"))
        XCTAssertGreaterThanOrEqual(
            webCopy.count,
            2,
            "The status tab and visible board column must both use the responsive-web copy."
        )
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "진행")).count,
            0,
            "The old abbreviated copy must not remain visible."
        )
        capture("parity-ios-todo-in-progress-copy-after")
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
        let column = app.scrollViews["todo.column.IN_PROGRESS"]
        let inProgressLabels = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "진행중")
        )
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10))
        XCTAssertTrue(secondCard.waitForExistence(timeout: 10))
        XCTAssertTrue(column.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(inProgressLabels.count, 2)
        let columnHeader = inProgressLabels.allElementsBoundByIndex.max {
            $0.frame.minY < $1.frame.minY
        }!
        XCTAssertLessThan(firstCard.frame.minY, secondCard.frame.minY)
        let initialColumnFrame = column.frame
        let initialHeaderFrame = columnHeader.frame
        let initialSecondCardFrame = secondCard.frame

        firstCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.5,
            thenDragTo: secondCard.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.82)),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        XCTAssertGreaterThan(firstCard.frame.minY, secondCard.frame.minY)
        XCTAssertEqual(column.frame.minX, initialColumnFrame.minX, accuracy: 1)
        XCTAssertEqual(column.frame.width, initialColumnFrame.width, accuracy: 1)
        XCTAssertEqual(columnHeader.frame.minX, initialHeaderFrame.minX, accuracy: 1)
        XCTAssertEqual(columnHeader.frame.minY, initialHeaderFrame.minY, accuracy: 1)
        XCTAssertEqual(columnHeader.frame.width, initialHeaderFrame.width, accuracy: 1)
        XCTAssertEqual(secondCard.frame.minX, initialSecondCardFrame.minX, accuracy: 1)
        XCTAssertEqual(secondCard.frame.width, initialSecondCardFrame.width, accuracy: 1)
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "label == %@", "삭제")).firstMatch.exists,
            "A completed long-press drag must not also open the Todo detail."
        )
        capture("parity-ios-todo-card-only-drag-after")
    }

    @MainActor
    func testFixtureTodoLongPressDragKeepsUnrelatedColumnCardsFixed() {
        let app = launchApp()
        defer { app.terminate() }

        openTodoScreen(in: app)

        let firstCard = app.descendants(matching: .any)[
            "todo.card.A11CE000-0000-4000-8000-000000000001"
        ]
        let secondCard = app.descendants(matching: .any)[
            "todo.card.A11CE000-0000-4000-8000-000000000002"
        ]
        let thirdCard = app.descendants(matching: .any)[
            "todo.card.A11CE000-0000-4000-8000-000000000003"
        ]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10))
        XCTAssertTrue(secondCard.waitForExistence(timeout: 10))
        XCTAssertTrue(thirdCard.waitForExistence(timeout: 10))
        XCTAssertLessThan(firstCard.frame.minY, secondCard.frame.minY)
        let initialThirdCardFrame = thirdCard.frame

        secondCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.5,
            thenDragTo: firstCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18)),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        XCTAssertLessThan(secondCard.frame.minY, firstCard.frame.minY)
        XCTAssertEqual(
            thirdCard.frame.minY,
            initialThirdCardFrame.minY,
            accuracy: 2,
            "A card drag must not scroll its column, so cards outside the reorder must stay put."
        )
        XCTAssertEqual(
            thirdCard.frame.height,
            initialThirdCardFrame.height,
            accuracy: 1
        )
        capture("parity-ios-todo-column-fixed-during-drag-after")
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
