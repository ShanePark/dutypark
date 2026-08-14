import Foundation
import Testing
@testable import Dutypark

@MainActor
struct TodoUserFlowTests {
    @Test
    func attachmentTodoCanBeCreatedMovedEditedAndDeleted() async throws {
        let todoID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let attachmentID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let sessionID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let attachment = makeFlowAttachment(id: attachmentID, todoID: todoID)
        let repository = TodoFlowRepository(
            board: makeFlowBoard(),
            nextTodoID: todoID,
            attachments: [attachment]
        )
        let model = TodoViewModel(repository: repository)

        var creation = TodoDraft(status: .todo)
        creation.title = "  Pack documents  "
        creation.content = "  Passport and tickets  "
        creation.attachmentSessionId = sessionID
        creation.orderedAttachmentIDs = [attachmentID]

        #expect(await model.create(draft: creation))

        let created = try #require(model.todos(for: .todo).first)
        #expect(created.uuid == todoID)
        #expect(created.title == "Pack documents")
        #expect(created.hasAttachments)

        await model.loadAttachments(for: created)
        #expect(model.attachmentsByTodoID[todoID] == [attachment])

        #expect(await model.drop(todoID: todoID, into: .inProgress))
        let moved = try #require(model.todos(for: .inProgress).first)
        #expect(moved.status == .inProgress)
        #expect(model.todos(for: .todo).isEmpty)

        var edit = TodoDraft(todo: moved)
        edit.title = "Pack travel documents"
        edit.content = "Passport, tickets, and insurance"
        edit.orderedAttachmentIDs = [attachmentID]

        #expect(await model.update(todo: moved, draft: edit))

        let updated = try #require(model.todos(for: .inProgress).first)
        #expect(updated.title == "Pack travel documents")
        #expect(updated.content == "Passport, tickets, and insurance")
        #expect(updated.hasAttachments)

        #expect(await model.delete(updated))
        #expect(model.board == makeFlowBoard())

        let snapshot = await repository.snapshot()
        #expect(snapshot.createRequests.count == 1)
        #expect(snapshot.createRequests.first?.attachmentSessionId == sessionID)
        #expect(snapshot.createRequests.first?.orderedAttachmentIds == [attachmentID])
        #expect(snapshot.statusChanges == [
            TodoFlowRepository.StatusChange(
                id: todoID,
                request: TodoStatusChangeRequest(status: .inProgress, orderedIds: [todoID])
            )
        ])
        #expect(snapshot.updateRequests.count == 1)
        #expect(snapshot.updateRequests.first?.id == todoID)
        #expect(snapshot.updateRequests.first?.request.orderedAttachmentIds == [attachmentID])
        #expect(snapshot.deletedIDs == [todoID])
    }

    @Test
    func failedCrossColumnMoveRestoresBoardAndSelection() async {
        let todo = makeFlowTodo(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "Stay put",
            status: .todo
        )
        let originalBoard = makeFlowBoard(todo: [todo])
        let repository = TodoFlowRepository(
            board: originalBoard,
            shouldFailStatusChange: true
        )
        let model = TodoViewModel(repository: repository)
        await model.load()

        let succeeded = await model.drop(todoID: todo.uuid, into: .inProgress)

        #expect(!succeeded)
        #expect(model.board == originalBoard)
        #expect(model.selectedStatus == .todo)
        #expect(model.errorKey == "todo.error.status")
        #expect(!model.isSaving)
    }

    @Test
    func duplicateCreateIsRejectedWhileAttachmentSubmissionIsInFlight() async {
        let todoID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let attachmentID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let repository = TodoFlowRepository(
            board: makeFlowBoard(),
            nextTodoID: todoID,
            blockCreate: true
        )
        let model = TodoViewModel(repository: repository)
        var draft = TodoDraft()
        draft.title = "Upload once"
        draft.attachmentSessionId = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        draft.orderedAttachmentIDs = [attachmentID]

        let firstSubmission = Task { await model.create(draft: draft) }
        defer {
            repository.releaseCreate()
            firstSubmission.cancel()
        }
        guard await repository.waitForCreateCall(timeout: .seconds(1)) else {
            repository.releaseCreate()
            _ = await firstSubmission.value
            Issue.record("Timed out waiting for the first Todo create request")
            return
        }

        #expect(model.isSaving)
        #expect(!(await model.create(draft: draft)))
        #expect(await repository.createCallCount == 1)

        repository.releaseCreate()
        #expect(await firstSubmission.value)
        #expect(!model.isSaving)
        #expect(await repository.createCallCount == 1)

        let request = await repository.snapshot().createRequests.first
        #expect(request?.orderedAttachmentIds == [attachmentID])
    }
}

private actor TodoFlowRepository: TodoRepository {
    struct StatusChange: Equatable, Sendable {
        let id: TodoID
        let request: TodoStatusChangeRequest
    }

    struct UpdateCall: Equatable, Sendable {
        let id: TodoID
        let request: TodoRequest
    }

    struct Snapshot: Sendable {
        let createRequests: [TodoRequest]
        let updateRequests: [UpdateCall]
        let statusChanges: [StatusChange]
        let deletedIDs: [TodoID]
    }

    private var board: TodoBoardDTO
    private let nextTodoID: TodoID
    private let attachments: [AttachmentDTO]
    private let shouldFailStatusChange: Bool
    private let blockCreate: Bool
    private let createGate = TodoFlowCreateGate()
    private var createRequests: [TodoRequest] = []
    private var updateRequests: [UpdateCall] = []
    private var statusChanges: [StatusChange] = []
    private var deletedIDs: [TodoID] = []

    init(
        board: TodoBoardDTO,
        nextTodoID: TodoID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
        attachments: [AttachmentDTO] = [],
        shouldFailStatusChange: Bool = false,
        blockCreate: Bool = false
    ) {
        self.board = board
        self.nextTodoID = nextTodoID
        self.attachments = attachments
        self.shouldFailStatusChange = shouldFailStatusChange
        self.blockCreate = blockCreate
    }

    var createCallCount: Int { createRequests.count }

    func snapshot() -> Snapshot {
        Snapshot(
            createRequests: createRequests,
            updateRequests: updateRequests,
            statusChanges: statusChanges,
            deletedIDs: deletedIDs
        )
    }

    nonisolated func waitForCreateCall(timeout: Duration) async -> Bool {
        await createGate.waitForStart(timeout: timeout)
    }

    nonisolated func releaseCreate() {
        createGate.release()
    }

    func fetchBoard() async throws -> TodoBoardDTO { board }
    func fetchFriends() async throws -> [FriendDTO] { [] }
    func fetchAttachments(todoID: TodoID) async throws -> [AttachmentDTO] { attachments }

    func create(_ request: TodoRequest) async throws -> TodoDTO {
        createRequests.append(request)
        createGate.signalStart()
        if blockCreate {
            guard await createGate.waitForRelease(timeout: .seconds(2)) else {
                throw TodoFlowCreateGateTimeout()
            }
        }

        let created = makeFlowTodo(
            id: nextTodoID,
            title: request.title,
            content: request.content,
            status: request.status ?? .todo,
            hasAttachments: request.attachmentSessionId != nil || !request.orderedAttachmentIds.isEmpty
        )
        insert(created)
        return created
    }

    func update(id: TodoID, request: TodoRequest) async throws -> TodoDTO {
        updateRequests.append(UpdateCall(id: id, request: request))
        guard let existing = remove(id: id) else { throw CocoaError(.fileNoSuchFile) }
        let updated = makeFlowTodo(
            id: id,
            title: request.title,
            content: request.content,
            status: request.status ?? existing.status,
            hasAttachments: request.attachmentSessionId != nil || !request.orderedAttachmentIds.isEmpty
        )
        insert(updated)
        return updated
    }

    func delete(id: TodoID) async throws {
        deletedIDs.append(id)
        _ = remove(id: id)
    }

    func complete(id: TodoID) async throws -> TodoDTO {
        try changeStatus(
            id: id,
            request: TodoStatusChangeRequest(status: .done, orderedIds: [])
        )
    }

    func reopen(id: TodoID) async throws -> TodoDTO {
        try changeStatus(
            id: id,
            request: TodoStatusChangeRequest(status: .inProgress, orderedIds: [])
        )
    }

    func changeStatus(id: TodoID, request: TodoStatusChangeRequest) throws -> TodoDTO {
        statusChanges.append(StatusChange(id: id, request: request))
        if shouldFailStatusChange { throw CocoaError(.fileWriteUnknown) }
        guard let existing = remove(id: id) else { throw CocoaError(.fileNoSuchFile) }
        let moved = makeFlowTodo(
            id: id,
            title: existing.title,
            content: existing.content,
            status: request.status,
            hasAttachments: existing.hasAttachments
        )
        insert(moved, orderedIDs: request.orderedIds)
        return moved
    }

    func updatePositions(_ request: TodoPositionUpdateRequest) async throws {}
    func leaveTag(id: TodoID) async throws { _ = remove(id: id) }

    private func insert(_ todo: TodoDTO, orderedIDs: [TodoID] = []) {
        var columns = currentColumns()
        columns[todo.status, default: []].append(todo)
        if !orderedIDs.isEmpty {
            let positions = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($1, $0) })
            columns[todo.status, default: []].sort {
                positions[$0.uuid, default: .max] < positions[$1.uuid, default: .max]
            }
        }
        board = makeFlowBoard(
            todo: columns[.todo, default: []],
            inProgress: columns[.inProgress, default: []],
            done: columns[.done, default: []]
        )
    }

    private func remove(id: TodoID) -> TodoDTO? {
        var columns = currentColumns()
        for status in TodoStatus.boardStatuses {
            if let index = columns[status, default: []].firstIndex(where: { $0.uuid == id }) {
                let removed = columns[status, default: []].remove(at: index)
                board = makeFlowBoard(
                    todo: columns[.todo, default: []],
                    inProgress: columns[.inProgress, default: []],
                    done: columns[.done, default: []]
                )
                return removed
            }
        }
        return nil
    }

    private func currentColumns() -> [TodoStatus: [TodoDTO]] {
        [.todo: board.todo, .inProgress: board.inProgress, .done: board.done]
    }
}

private struct TodoFlowCreateGateTimeout: Error {}

private final class TodoFlowCreateGate: Sendable {
    private let startStream: AsyncStream<Void>
    private let startContinuation: AsyncStream<Void>.Continuation
    private let releaseStream: AsyncStream<Void>
    private let releaseContinuation: AsyncStream<Void>.Continuation

    init() {
        let start = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        startStream = start.stream
        startContinuation = start.continuation
        let release = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        releaseStream = release.stream
        releaseContinuation = release.continuation
    }

    func signalStart() {
        startContinuation.yield()
    }

    func release() {
        releaseContinuation.yield()
    }

    func waitForStart(timeout: Duration) async -> Bool {
        await wait(for: startStream, timeout: timeout)
    }

    func waitForRelease(timeout: Duration) async -> Bool {
        await wait(for: releaseStream, timeout: timeout)
    }

    private func wait(for stream: AsyncStream<Void>, timeout: Duration) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next() != nil
            }
            group.addTask {
                do {
                    try await Task.sleep(for: timeout)
                    return false
                } catch {
                    return false
                }
            }

            let receivedSignal = await group.next() ?? false
            group.cancelAll()
            return receivedSignal
        }
    }
}

nonisolated private func makeFlowTodo(
    id: TodoID,
    title: String,
    content: String = "Details",
    status: TodoStatus,
    hasAttachments: Bool = false
) -> TodoDTO {
    TodoDTO(
        id: id.uuidString,
        title: title,
        content: content,
        position: 0,
        status: status,
        createdDate: LocalDateTimeValue(rawValue: "2026-08-14T10:00:00"),
        completedDate: nil,
        dueDate: nil,
        isOverdue: false,
        isTagged: false,
        owner: "Me",
        taggedByMember: nil,
        tags: [],
        hasAttachments: hasAttachments
    )
}

nonisolated private func makeFlowBoard(
    todo: [TodoDTO] = [],
    inProgress: [TodoDTO] = [],
    done: [TodoDTO] = []
) -> TodoBoardDTO {
    TodoBoardDTO(
        todo: todo,
        inProgress: inProgress,
        done: done,
        counts: TodoCountsDTO(
            todo: todo.count,
            inProgress: inProgress.count,
            done: done.count,
            total: todo.count + inProgress.count + done.count
        )
    )
}

nonisolated private func makeFlowAttachment(id: AttachmentID, todoID: TodoID) -> AttachmentDTO {
    AttachmentDTO(
        id: id,
        contextType: .todo,
        contextId: todoID.uuidString,
        originalFilename: "travel.pdf",
        contentType: "application/pdf",
        size: 512,
        hasThumbnail: false,
        thumbnailUrl: nil,
        orderIndex: 0,
        createdAt: "2026-08-14T10:00:00+09:00",
        createdBy: 1
    )
}
