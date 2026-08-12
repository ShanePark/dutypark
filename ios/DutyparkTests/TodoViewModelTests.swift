import Foundation
import Testing
@testable import Dutypark

@MainActor
struct TodoViewModelTests {
    @Test
    func mobileBoardMatchesWebColumnGeometry() {
        #expect(TodoBoardLayout.mobileColumnWidthRatio == 0.62)
        #expect(TodoBoardLayout.boardPadding == 8)
        #expect(TodoBoardLayout.columnGap == 10)
        #expect(TodoBoardLayout.columnRadius == 12)
        #expect(TodoBoardLayout.cardRadius == 14)
        #expect(TodoBoardLayout.dragHandleSize == 44)
        #expect(TodoBoardLayout.dragActivationDistance == 2)

        #expect(375 * TodoBoardLayout.mobileColumnWidthRatio == 232.5)
        #expect(402 * TodoBoardLayout.mobileColumnWidthRatio == 249.24)
    }

    @Test(arguments: [
        (CGSize(width: 0, height: 2), true),
        (CGSize(width: 0, height: -12), true),
        (CGSize(width: 2, height: 0), true),
        (CGSize(width: -8, height: 10), true),
        (CGSize(width: 1, height: 1), false)
    ])
    func handleDragReordersImmediatelyInEveryDirection(
        translation: CGSize,
        expected: Bool
    ) {
        #expect(TodoHandleDragActivation.shouldReorder(translation: translation) == expected)
    }

    @Test
    func immediateHandleDragDoesNotMoveWhileStillInsideItsSourceCard() {
        let sourceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let otherID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let cards = [
            TodoCardDropTarget(
                todoID: sourceID,
                status: .todo,
                frame: CGRect(x: 10, y: 100, width: 200, height: 80)
            ),
            TodoCardDropTarget(
                todoID: otherID,
                status: .todo,
                frame: CGRect(x: 10, y: 190, width: 200, height: 80)
            )
        ]

        let target = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 190, y: 104),
            draggedTodoID: sourceID,
            cards: cards,
            columns: [TodoColumnDropTarget(
                status: .todo,
                frame: CGRect(x: 0, y: 80, width: 220, height: 400)
            )],
            statuses: []
        )

        #expect(target == nil)
    }

    @Test
    func handleDragMapsCardGapsAndColumnBottomToStableDropTargets() {
        let sourceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let otherID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let cards = [
            TodoCardDropTarget(
                todoID: sourceID,
                status: .todo,
                frame: CGRect(x: 10, y: 100, width: 200, height: 80)
            ),
            TodoCardDropTarget(
                todoID: otherID,
                status: .todo,
                frame: CGRect(x: 10, y: 190, width: 200, height: 80)
            )
        ]
        let columns = [TodoColumnDropTarget(
            status: .todo,
            frame: CGRect(x: 0, y: 80, width: 220, height: 400)
        )]

        let gapTarget = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 100, y: 185),
            draggedTodoID: sourceID,
            cards: cards,
            columns: columns,
            statuses: []
        )
        let bottomTarget = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 100, y: 350),
            draggedTodoID: sourceID,
            cards: cards,
            columns: columns,
            statuses: []
        )

        #expect(gapTarget == TodoResolvedDropTarget(
            status: .todo,
            todoID: otherID,
            insertAfter: false
        ))
        #expect(bottomTarget == TodoResolvedDropTarget(
            status: .todo,
            todoID: nil,
            insertAfter: false
        ))
    }

    @Test
    func statusSelectorTakesPriorityAsCrossColumnDropTarget() {
        let sourceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let target = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 250, y: 24),
            draggedTodoID: sourceID,
            cards: [],
            columns: [],
            statuses: [TodoStatusDropTarget(
                status: .done,
                frame: CGRect(x: 220, y: 0, width: 100, height: 48)
            )]
        )

        #expect(target == TodoResolvedDropTarget(
            status: .done,
            todoID: nil,
            insertAfter: false
        ))
    }

    @Test
    func todoCatalogResolvesFeatureAndCommonKeysInEverySupportedLocale() {
        let keys = [
            "todo.action.add",
            "todo.action.complete",
            "todo.action.delete",
            "todo.action.leaveTag",
            "todo.action.reopen",
            "todo.drag.dropHere",
            "todo.drag.hint",
            "todo.error.load",
            "common.close",
            "common.edit",
            "common.save"
        ]
        let locales = ["ko", "en", "ja", "zh-Hans", "es"]

        for localeIdentifier in locales {
            for key in keys {
                #expect(
                    todoLocalized(key, locale: Locale(identifier: localeIdentifier)) != key,
                    "\(key) was not resolved for \(localeIdentifier)"
                )
            }
        }
    }

    @Test
    func detailModalFitsShortContentAndCapsLongContentForIPhone13Mini() {
        let availableOverlayHeight: CGFloat = 780
        let maximumPanelHeight = availableOverlayHeight * TodoModalLayout.maximumPanelHeightRatio
        let fixedChromeHeight: CGFloat = 176

        #expect(TodoModalLayout.maximumPanelHeightRatio == 0.9)
        #expect(TodoModalLayout.bodyHeight(
            contentHeight: 148,
            maximumPanelHeight: maximumPanelHeight,
            fixedChromeHeight: fixedChromeHeight
        ) == 148)
        #expect(TodoModalLayout.bodyHeight(
            contentHeight: 900,
            maximumPanelHeight: maximumPanelHeight,
            fixedChromeHeight: fixedChromeHeight
        ) == 526)
    }

    @Test
    func loadSelectsFirstNonemptyColumnAndCountsTaggedTodos() async {
        let own = makeTodo(title: "Own", status: .todo)
        let tagged = makeTodo(title: "Shared", status: .todo, isTagged: true)
        let repository = FakeTodoRepository(board: makeBoard(todo: [own, tagged]))
        let model = TodoViewModel(repository: repository)

        await model.load()

        #expect(model.selectedStatus == .todo)
        #expect(model.count(for: .todo) == 2)
        #expect(model.selectedTodos.map(\.title) == ["Own", "Shared"])
    }

    @Test
    func taggedTodoCanMoveStatusWithoutOwnerEdit() async {
        let todo = makeTodo(status: .todo, isTagged: true)
        let repository = FakeTodoRepository(board: makeBoard(todo: [todo]))
        let model = TodoViewModel(repository: repository)

        let succeeded = await model.move(todo, to: .inProgress)
        let change = await repository.statusChange

        #expect(succeeded)
        #expect(change?.id == UUID(uuidString: todo.id))
        #expect(change?.request.status == .inProgress)
        #expect(change?.request.orderedIds.isEmpty == true)
    }

    @Test(arguments: [
        (TodoStatus.todo, TodoStatus.inProgress),
        (TodoStatus.inProgress, TodoStatus.todo)
    ])
    func detailStatusControlMovesDirectlyBetweenActiveColumns(
        source: TodoStatus,
        destination: TodoStatus
    ) async {
        let todo = makeTodo(status: source)
        let repository = FakeTodoRepository(
            board: source == .todo
                ? makeBoard(todo: [todo])
                : makeBoard(inProgress: [todo])
        )
        let model = TodoViewModel(repository: repository)

        let succeeded = await model.move(todo, to: destination)
        let change = await repository.statusChange

        #expect(succeeded)
        #expect(change?.id == todo.uuid)
        #expect(change?.request.status == destination)
        #expect(change?.request.orderedIds.isEmpty == true)
    }

    @Test
    func notificationTodoSelectsItsColumnForPresentation() async {
        let todo = makeTodo(status: .inProgress)
        let repository = FakeTodoRepository(board: makeBoard(inProgress: [todo]))
        let model = TodoViewModel(repository: repository)

        await model.load()
        let opened = model.open(todoID: todo.uuid)

        #expect(opened?.id == todo.id)
        #expect(model.selectedStatus == .inProgress)
    }

    @Test
    func updatePreservesEveryExistingAttachmentID() async {
        let todo = makeTodo(hasAttachments: true)
        let first = makeAttachment(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let second = makeAttachment(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)
        let repository = FakeTodoRepository(
            board: makeBoard(todo: [todo]),
            attachments: [first, second]
        )
        let model = TodoViewModel(repository: repository)

        await model.loadAttachments(for: todo)
        var draft = TodoDraft(todo: todo)
        draft.title = "Updated"
        draft.orderedAttachmentIDs = [first.id, second.id]
        let succeeded = await model.update(todo: todo, draft: draft)
        let update = await repository.updateRequest

        #expect(succeeded)
        #expect(update?.request.orderedAttachmentIds == [first.id, second.id])
    }

    @Test
    func detailAttachmentPreloadCachesFilesForEditing() async {
        let todo = makeTodo(hasAttachments: true)
        let attachment = makeAttachment(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let repository = FakeTodoRepository(
            board: makeBoard(todo: [todo]),
            attachments: [attachment]
        )
        let model = TodoViewModel(repository: repository)

        await model.loadAttachments(for: todo)

        #expect(model.attachmentsByTodoID[todo.uuid] == [attachment])
        #expect(model.errorKey == nil)
    }

    @Test
    func failedDetailAttachmentPreloadKeepsEditingLockedAndReportsError() async {
        let todo = makeTodo(hasAttachments: true)
        let repository = FakeTodoRepository(
            board: makeBoard(todo: [todo]),
            shouldFailAttachmentFetch: true
        )
        let model = TodoViewModel(repository: repository)

        await model.loadAttachments(for: todo)

        #expect(model.attachmentsByTodoID[todo.uuid] == nil)
        #expect(model.errorKey == "todo.error.attachments")
    }

    @Test
    func sameColumnMoveSendsTheCompleteViewerOrder() async {
        let first = makeTodo(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "First")
        let tagged = makeTodo(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Shared",
            isTagged: true
        )
        let repository = FakeTodoRepository(board: makeBoard(todo: [first, tagged]))
        let model = TodoViewModel(repository: repository)

        await model.load()

        await model.moveWithinSelectedColumn(tagged, offset: -1)
        let reorder = await repository.positionRequest

        #expect(reorder?.status == .todo)
        #expect(reorder?.orderedIds == [tagged.uuid, first.uuid])
    }

    @Test
    func cardDropOptimisticallyReordersOwnedAndTaggedTodosInOneViewerOrder() async {
        let first = makeTodo(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "First")
        let tagged = makeTodo(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Shared",
            isTagged: true
        )
        let repository = FakeTodoRepository(board: makeBoard(todo: [first, tagged]))
        let model = TodoViewModel(repository: repository)
        await model.load()

        let succeeded = await model.drop(
            todoID: tagged.uuid,
            into: .todo,
            relativeTo: first.uuid,
            insertAfter: false
        )
        let request = await repository.positionRequest

        #expect(succeeded)
        #expect(model.todos(for: .todo).map(\.uuid) == [tagged.uuid, first.uuid])
        #expect(request == TodoPositionUpdateRequest(status: .todo, orderedIds: [tagged.uuid, first.uuid]))
    }

    @Test
    func crossColumnDropSendsTheCompleteDestinationOrderAndUpdatesStatus() async {
        let moving = makeTodo(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Shared",
            status: .todo,
            isTagged: true
        )
        let existing = makeTodo(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Existing",
            status: .inProgress
        )
        let repository = FakeTodoRepository(board: makeBoard(todo: [moving], inProgress: [existing]))
        let model = TodoViewModel(repository: repository)
        await model.load()

        let succeeded = await model.drop(
            todoID: moving.uuid,
            into: .inProgress,
            relativeTo: existing.uuid,
            insertAfter: true
        )
        let change = await repository.statusChange

        #expect(succeeded)
        #expect(model.todos(for: .todo).isEmpty)
        #expect(model.todos(for: .inProgress).map(\.uuid) == [existing.uuid, moving.uuid])
        #expect(model.todos(for: .inProgress).last?.status == .inProgress)
        #expect(change?.id == moving.uuid)
        #expect(change?.request == TodoStatusChangeRequest(
            status: .inProgress,
            orderedIds: [existing.uuid, moving.uuid]
        ))
    }

    @Test
    func failedDropRestoresTheOriginalBoardAndExposesReorderError() async {
        let first = makeTodo(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "First")
        let second = makeTodo(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, title: "Second")
        let original = makeBoard(todo: [first, second])
        let repository = FakeTodoRepository(board: original, shouldFailPositionUpdate: true)
        let model = TodoViewModel(repository: repository)
        await model.load()

        let succeeded = await model.drop(
            todoID: second.uuid,
            into: .todo,
            relativeTo: first.uuid,
            insertAfter: false
        )

        #expect(!succeeded)
        #expect(model.board == original)
        #expect(model.errorKey == "todo.error.reorder")
    }
}

private actor FakeTodoRepository: TodoRepository {
    var board: TodoBoardDTO
    let attachments: [AttachmentDTO]
    var updateRequest: (id: TodoID, request: TodoRequest)?
    var statusChange: (id: TodoID, request: TodoStatusChangeRequest)?
    var positionRequest: TodoPositionUpdateRequest?
    let shouldFailPositionUpdate: Bool
    let shouldFailAttachmentFetch: Bool

    init(
        board: TodoBoardDTO,
        attachments: [AttachmentDTO] = [],
        shouldFailPositionUpdate: Bool = false,
        shouldFailAttachmentFetch: Bool = false
    ) {
        self.board = board
        self.attachments = attachments
        self.shouldFailPositionUpdate = shouldFailPositionUpdate
        self.shouldFailAttachmentFetch = shouldFailAttachmentFetch
    }

    func fetchBoard() async throws -> TodoBoardDTO { board }
    func fetchFriends() async throws -> [FriendDTO] { [] }
    func fetchAttachments(todoID: TodoID) async throws -> [AttachmentDTO] {
        if shouldFailAttachmentFetch {
            throw CocoaError(.fileReadUnknown)
        }
        return attachments
    }
    func create(_ request: TodoRequest) async throws -> TodoDTO { board.todo[0] }

    func update(id: TodoID, request: TodoRequest) async throws -> TodoDTO {
        updateRequest = (id, request)
        return board.todo[0]
    }

    func delete(id: TodoID) async throws {}
    func complete(id: TodoID) async throws -> TodoDTO { board.todo[0] }
    func reopen(id: TodoID) async throws -> TodoDTO { board.todo[0] }

    func changeStatus(id: TodoID, request: TodoStatusChangeRequest) async throws -> TodoDTO {
        statusChange = (id, request)
        return try todo(id: id)
    }

    func updatePositions(_ request: TodoPositionUpdateRequest) async throws {
        if shouldFailPositionUpdate {
            throw CocoaError(.fileWriteUnknown)
        }
        positionRequest = request
    }

    func leaveTag(id: TodoID) async throws {}

    private func todo(id: TodoID) throws -> TodoDTO {
        guard let todo = (board.todo + board.inProgress + board.done)
            .first(where: { $0.uuid == id })
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        return todo
    }
}

private func makeTodo(
    id: UUID = UUID(),
    title: String = "Todo",
    status: TodoStatus = .todo,
    isTagged: Bool = false,
    hasAttachments: Bool = false
) -> TodoDTO {
    TodoDTO(
        id: id.uuidString,
        title: title,
        content: "Details",
        position: 0,
        status: status,
        createdDate: LocalDateTimeValue(rawValue: "2026-08-12T10:00:00"),
        completedDate: nil,
        dueDate: DateOnly(rawValue: "2026-08-20"),
        isOverdue: false,
        isTagged: isTagged,
        owner: isTagged ? "Owner" : "Me",
        taggedByMember: nil,
        tags: [],
        hasAttachments: hasAttachments
    )
}

private func makeBoard(todo: [TodoDTO] = [], inProgress: [TodoDTO] = []) -> TodoBoardDTO {
    TodoBoardDTO(
        todo: todo,
        inProgress: inProgress,
        done: [],
        counts: TodoCountsDTO(
            todo: todo.count,
            inProgress: inProgress.count,
            done: 0,
            total: todo.count + inProgress.count
        )
    )
}

private func makeAttachment(id: UUID) -> AttachmentDTO {
    AttachmentDTO(
        id: id,
        contextType: .todo,
        contextId: UUID().uuidString,
        originalFilename: "file.pdf",
        contentType: "application/pdf",
        size: 100,
        hasThumbnail: false,
        thumbnailUrl: nil,
        orderIndex: 0,
        createdAt: "2026-08-12T10:00:00+09:00",
        createdBy: 1
    )
}
