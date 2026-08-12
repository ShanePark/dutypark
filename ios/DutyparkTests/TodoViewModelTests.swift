import Foundation
import Testing
@testable import Dutypark

@MainActor
struct TodoViewModelTests {
    @Test
    func todoCatalogResolvesFeatureAndCommonKeysInEverySupportedLocale() {
        let keys = ["todo.action.add", "todo.error.load", "common.save"]
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
}

private actor FakeTodoRepository: TodoRepository {
    var board: TodoBoardDTO
    let attachments: [AttachmentDTO]
    var updateRequest: (id: TodoID, request: TodoRequest)?
    var statusChange: (id: TodoID, request: TodoStatusChangeRequest)?
    var positionRequest: TodoPositionUpdateRequest?

    init(board: TodoBoardDTO, attachments: [AttachmentDTO] = []) {
        self.board = board
        self.attachments = attachments
    }

    func fetchBoard() async throws -> TodoBoardDTO { board }
    func fetchFriends() async throws -> [FriendDTO] { [] }
    func fetchAttachments(todoID: TodoID) async throws -> [AttachmentDTO] { attachments }
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
        return board.todo[0]
    }

    func updatePositions(_ request: TodoPositionUpdateRequest) async throws {
        positionRequest = request
    }

    func leaveTag(id: TodoID) async throws {}
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
