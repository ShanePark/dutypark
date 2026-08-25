import Foundation
import Testing
@testable import Dutypark

@MainActor
struct TodoOfflineTests {
    @Test
    func calendarTodoDetailBindsItsSessionContext() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "Dutypark/Features/Calendar/CalendarView.swift"),
            encoding: .utf8
        )
        let modalSource = try String(
            contentsOf: root.appending(path: "Dutypark/Features/Todo/TodoModalViews.swift"),
            encoding: .utf8
        )

        #expect(source.contains("todoDetailModel.configureSession"))
        #expect(source.contains(".onChange(of: session.state)"))
        #expect(modalSource.contains("!model.canPerformOnlineMutations"))
        #expect(modalSource.contains("if todo.hasAttachments, model.canPerformOnlineMutations"))
    }

    @Test
    func calendarDetailBindsOfflineSessionBeforeAttachmentOrMutations() async {
        let repository = TodoOfflineRepository()
        let model = TodoViewModel(
            repository: repository,
            cache: TodoOfflineCacheFake(),
            outbox: TodoOfflineOutboxFake()
        )
        model.configureSession(accountID: 42, availability: .offline)
        let todo = makeOfflineTodo(title: "Cached task", hasAttachments: true)
        var draft = TodoDraft(todo: todo)
        draft.title = "Edited while offline"

        #expect(!(await model.update(todo: todo, draft: draft)))
        #expect(model.errorKey == "todo.error.offlineReadOnly")

        model.errorKey = nil
        await model.loadAttachments(for: todo)
        #expect(model.errorKey == nil)

        #expect(!(await model.delete(todo)))
        #expect(!(await model.leaveTag(todo)))
        #expect(model.errorKey == "todo.error.offlineReadOnly")
        #expect(await repository.fetchAttachmentsCount == 0)
        #expect(await repository.mutationCallCount == 0)
    }

    @Test
    func loadUsesCachedBoardAndFriendsWhenTransportFails() async {
        let cachedTodo = makeOfflineTodo(title: "Cached task")
        let cachedBoard = makeOfflineBoard(todo: [cachedTodo])
        let account = makeOfflineAccount(friends: [makeOfflineFriend(id: 9, name: "Cached friend")])
        let cache = TodoOfflineCacheFake(account: account, board: cachedBoard)
        let repository = TodoOfflineRepository(boardError: .transport, friendsError: .transport)
        let model = TodoViewModel(
            repository: repository,
            cache: cache,
            outbox: TodoOfflineOutboxFake()
        )

        await model.load(accountID: 42)

        #expect(model.board == cachedBoard)
        #expect(model.friends == account.friends)
        #expect(model.isOffline)
        #expect(model.isShowingCachedData)
        #expect(model.errorKey == nil)
    }

    @Test
    func loadKeepsExistingErrorWhenTransportHasNoCachedBoard() async {
        let model = TodoViewModel(
            repository: TodoOfflineRepository(boardError: .transport),
            cache: TodoOfflineCacheFake(),
            outbox: TodoOfflineOutboxFake()
        )

        await model.load(accountID: 42)

        #expect(model.board == nil)
        #expect(model.errorKey == "todo.error.load")
        #expect(!model.isShowingCachedData)
    }

    @Test
    func serverRecoveryRetriesFallbackWithBackoffAndDrainsQueuedTodosSilently() async {
        let cachedBoard = makeOfflineBoard(todo: [makeOfflineTodo(title: "Cached")])
        let freshBoard = makeOfflineBoard(todo: [makeOfflineTodo(title: "Fresh")])
        let operationID = UUID()
        let request = TodoRequest(
            title: "Queued",
            content: "",
            status: .todo,
            dueDate: nil,
            tagFriendIds: [],
            attachmentSessionId: nil,
            orderedAttachmentIds: []
        )
        let outbox = TodoOfflineOutboxFake(entries: [
            OfflineOutboxEntry(
                operationID: operationID,
                accountID: 42,
                payload: .todoCreate(request),
                createdAt: Date(timeIntervalSince1970: 100)
            )
        ])
        let repository = TodoOfflineRepository(
            boardSequence: [.failure(.transport), .success(freshBoard)],
            friendsSequence: [.failure(.transport), .success([])]
        )
        let syncRecorder = TodoRecoveryRecorder()
        let model = TodoViewModel(
            repository: repository,
            cache: TodoOfflineCacheFake(
                account: makeOfflineAccount(),
                board: cachedBoard
            ),
            outbox: outbox,
            recoveryDelays: [.zero, .zero],
            recoverySleep: { _ in await Task.yield() },
            syncQueuedOutbox: { accountID in
                await syncRecorder.record(accountID)
            }
        )

        await model.load(accountID: 42)
        for _ in 0..<20 { await Task.yield() }

        #expect(model.todos(for: .todo).contains { $0.title == "Fresh" })
        #expect(model.todos(for: .todo).contains { $0.title == "Queued" })
        #expect(!model.isOffline)
        #expect(!model.isShowingCachedData)
        #expect(await repository.fetchBoardCount == 2)
        #expect(await syncRecorder.accountIDs == [42])
    }

    @Test
    func cancellingTodoRecoveryStopsServerPolling() async {
        let repository = TodoOfflineRepository(
            boardSequence: [.failure(.transport), .success(makeOfflineBoard())]
        )
        let model = TodoViewModel(
            repository: repository,
            cache: TodoOfflineCacheFake(
                account: makeOfflineAccount(),
                board: makeOfflineBoard()
            ),
            outbox: TodoOfflineOutboxFake(),
            recoveryDelays: [.zero, .zero],
            recoverySleep: { _ in await Task.yield() }
        )

        await model.load(accountID: 42)
        model.cancelRecovery()
        for _ in 0..<10 { await Task.yield() }

        #expect(await repository.fetchBoardCount == 1)
        #expect(model.isOffline)
    }

    @Test
    func onlineCreateQueuesFiveHundredAndRequestsOutboxSync() async throws {
        let outbox = TodoOfflineOutboxFake()
        let syncRecorder = TodoRecoveryRecorder()
        let model = TodoViewModel(
            repository: TodoOfflineRepository(createError: .server(status: 503, code: "server.down")),
            cache: TodoOfflineCacheFake(account: makeOfflineAccount(), board: makeOfflineBoard()),
            outbox: outbox,
            syncQueuedOutbox: { accountID in
                await syncRecorder.record(accountID)
            }
        )
        var draft = TodoDraft()
        draft.title = "Save while server recovers"

        #expect(await model.create(draft: draft, accountID: 42))
        let entry = try #require(await outbox.entries(accountID: 42).first)
        #expect(entry.state == .pending)

        for _ in 0..<20 { await Task.yield() }
        #expect(await syncRecorder.accountIDs == [42])
    }

    @Test
    func ambiguousCreateResponsesQueueTheOriginalRequestAndWakeSync() async throws {
        for ambiguousError in [APIError.invalidResponse, APIError.decoding] {
            let outbox = TodoOfflineOutboxFake()
            let syncRecorder = TodoRecoveryRecorder()
            let repository = TodoOfflineRepository(createError: ambiguousError)
            let model = TodoViewModel(
                repository: repository,
                cache: TodoOfflineCacheFake(
                    account: makeOfflineAccount(),
                    board: makeOfflineBoard()
                ),
                outbox: outbox,
                syncQueuedOutbox: { accountID in
                    await syncRecorder.record(accountID)
                }
            )
            var draft = TodoDraft(status: .inProgress)
            draft.title = "Retry ambiguous create"

            #expect(await model.create(draft: draft, accountID: 42))
            let request = try #require(await repository.createRequest)
            let entry = try #require(await outbox.entries(accountID: 42).first)
            #expect(entry.payload == .todoCreate(request))
            #expect(model.board?.inProgress.first?.uuid == entry.operationID)
            for _ in 0..<20 { await Task.yield() }
            #expect(await syncRecorder.accountIDs == [42])
        }
    }

    @Test
    func transportFailureCreateUsesOneOperationIDForOutboxAndProvisionalTodo() async throws {
        let cache = TodoOfflineCacheFake(account: makeOfflineAccount(), board: makeOfflineBoard())
        let outbox = TodoOfflineOutboxFake()
        let repository = TodoOfflineRepository(createError: .transport)
        let haptics = DPHapticCenter()
        let syncRecorder = TodoRecoveryRecorder()
        let model = TodoViewModel(
            repository: repository,
            hapticCenter: haptics,
            cache: cache,
            outbox: outbox,
            syncQueuedOutbox: { accountID in
                await syncRecorder.record(accountID)
            }
        )
        var draft = TodoDraft(status: .inProgress)
        draft.title = "  Offline task  "
        draft.content = "Saved for later"

        let succeeded = await model.create(draft: draft, accountID: 42)
        let request = try #require(await repository.createRequest)
        let entry = try #require(await outbox.entries(accountID: 42).first)
        let provisional = try #require(model.board?.inProgress.first)

        #expect(succeeded)
        #expect(entry.payload == .todoCreate(request))
        #expect(provisional.uuid == entry.operationID)
        #expect(provisional.title == "Offline task")
        #expect(provisional.content == "Saved for later")
        #expect(model.pendingOperationCount == 1)
        #expect(haptics.event?.kind == .success)
        #expect(model.errorKey == nil)
        for _ in 0..<20 { await Task.yield() }
        #expect(await syncRecorder.accountIDs == [42])
    }

    @Test
    func pureOfflineCreateEnqueuesWithoutImmediateSync() async throws {
        let cache = TodoOfflineCacheFake(account: makeOfflineAccount(), board: makeOfflineBoard())
        let outbox = TodoOfflineOutboxFake()
        let repository = TodoOfflineRepository(createError: .transport)
        let syncRecorder = TodoRecoveryRecorder()
        let model = TodoViewModel(
            repository: repository,
            cache: cache,
            outbox: outbox,
            syncQueuedOutbox: { accountID in
                await syncRecorder.record(accountID)
            }
        )
        var draft = TodoDraft()
        draft.title = "Saved without a connection"

        #expect(await model.create(
            draft: draft,
            accountID: 42,
            availability: .offline
        ))
        let entry = try #require(await outbox.entries(accountID: 42).first)

        #expect(await repository.createRequest == nil)
        for _ in 0..<20 { await Task.yield() }
        #expect(await syncRecorder.accountIDs.isEmpty)
    }

    @Test
    func validationFailureDoesNotEnqueueOfflineCreate() async {
        let outbox = TodoOfflineOutboxFake()
        let model = TodoViewModel(
            repository: TodoOfflineRepository(createError: .server(status: 400, code: "todo.invalid")),
            cache: TodoOfflineCacheFake(),
            outbox: outbox
        )
        var draft = TodoDraft()
        draft.title = "Invalid server request"

        #expect(!(await model.create(draft: draft, accountID: 42)))
        #expect(await outbox.entries(accountID: 42).isEmpty)
        #expect(model.board == nil)
        #expect(model.errorKey == "todo.error.create")
    }

    @Test
    func taggedOfflineCreateIsRejectedWithoutChangingBoard() async {
        let original = makeOfflineBoard(todo: [makeOfflineTodo(title: "Existing")])
        let outbox = TodoOfflineOutboxFake()
        let model = TodoViewModel(
            repository: TodoOfflineRepository(createError: .transport),
            cache: TodoOfflineCacheFake(account: makeOfflineAccount(), board: original),
            outbox: outbox
        )
        await model.load(accountID: 42, availability: .offline)
        var draft = TodoDraft()
        draft.title = "Tagged task"
        draft.taggedFriendIDs = [9]

        #expect(!(await model.create(draft: draft, accountID: 42)))
        #expect(model.board == original)
        #expect(await outbox.entries(accountID: 42).isEmpty)
        #expect(model.errorKey == "todo.error.offlineUnsupported")
    }

    @Test
    func onlineBoardAndFriendsAreWrittenToAccountCache() async {
        let board = makeOfflineBoard(todo: [makeOfflineTodo(title: "Fresh task")])
        let friends = [makeOfflineFriend(id: 9, name: "Fresh friend")]
        let cache = TodoOfflineCacheFake(account: makeOfflineAccount(), board: nil)
        let model = TodoViewModel(
            repository: TodoOfflineRepository(board: board, friends: friends),
            cache: cache,
            outbox: TodoOfflineOutboxFake()
        )

        await model.load(accountID: 42)

        #expect(model.board == board)
        #expect(model.friends == friends)
        #expect(!(await cache.savedBoards).isEmpty)
        #expect((await cache.loadAccount(memberID: 42))?.friends == friends)
        #expect(!model.isOffline)
    }

    @Test
    func queuedTodoIsRebuiltFromOutboxAfterAColdCacheLoad() async throws {
        let operationID = UUID()
        let request = TodoRequest(
            title: "Queued after relaunch",
            content: "Keep this visible",
            status: .todo,
            dueDate: nil,
            tagFriendIds: [],
            attachmentSessionId: nil,
            orderedAttachmentIds: []
        )
        let entry = OfflineOutboxEntry(
            operationID: operationID,
            accountID: 42,
            payload: .todoCreate(request),
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let outbox = TodoOfflineOutboxFake(entries: [entry])
        let model = TodoViewModel(
            repository: TodoOfflineRepository(),
            cache: TodoOfflineCacheFake(account: makeOfflineAccount(), board: makeOfflineBoard()),
            outbox: outbox
        )

        await model.load(accountID: 42, availability: .offline)

        let todo = try #require(model.board?.todo.first)
        #expect(todo.uuid == operationID)
        #expect(todo.title == request.title)
        #expect(model.pendingOperationCount == 1)
    }

    @Test
    func pendingBadgeCountsOnlyPendingOutboxEntries() async throws {
        let pendingID = UUID()
        let permanentID = UUID()
        let pendingRequest = TodoRequest(
            title: "Pending",
            content: "",
            status: .todo,
            dueDate: nil,
            tagFriendIds: [],
            attachmentSessionId: nil,
            orderedAttachmentIds: []
        )
        let permanentRequest = TodoRequest(
            title: "Needs attention",
            content: "",
            status: .todo,
            dueDate: nil,
            tagFriendIds: [],
            attachmentSessionId: nil,
            orderedAttachmentIds: []
        )
        let failure = OfflineOutboxFailure(
            code: "todo.invalid",
            statusCode: 400,
            message: "Invalid Todo"
        )
        let outbox = TodoOfflineOutboxFake(entries: [
            OfflineOutboxEntry(
                operationID: pendingID,
                accountID: 42,
                payload: .todoCreate(pendingRequest),
                createdAt: Date(timeIntervalSince1970: 100),
                state: .pending
            ),
            OfflineOutboxEntry(
                operationID: permanentID,
                accountID: 42,
                payload: .todoCreate(permanentRequest),
                createdAt: Date(timeIntervalSince1970: 101),
                state: .permanentFailure,
                failure: failure
            )
        ])
        let model = TodoViewModel(
            repository: TodoOfflineRepository(),
            cache: TodoOfflineCacheFake(account: makeOfflineAccount(), board: makeOfflineBoard()),
            outbox: outbox
        )

        await model.load(accountID: 42, availability: .offline)

        #expect(model.pendingOperationCount == 1)
        #expect(model.board?.todo.map(\.uuid) == [pendingID, permanentID])
    }

    @Test
    func todoViewWiresSessionIdentityAndUsesNumericPendingBannerReplacement() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "Dutypark/Features/Todo/TodoView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("authenticatedAccountID"))
        #expect(source.contains("availability: session.availability"))
        #expect(source.contains("offlineSyncDidComplete"))
        #expect(source.contains("model.cancelRecovery()"))
        #expect(source.contains("replacingOccurrences"))
        #expect(source.contains("String(model.pendingOperationCount)"))
    }
}

private actor TodoOfflineRepository: TodoRepository {
    let boardResult: Result<TodoBoardDTO, APIError>
    let friendsResult: Result<[FriendDTO], APIError>
    let createResult: Result<TodoDTO, APIError>
    private var boardSequence: [Result<TodoBoardDTO, APIError>]?
    private var friendsSequence: [Result<[FriendDTO], APIError>]?
    private var boardSequenceIndex = 0
    private var friendsSequenceIndex = 0
    private(set) var fetchBoardCount = 0
    private(set) var createRequest: TodoRequest?
    private(set) var fetchAttachmentsCount = 0
    private(set) var mutationCallCount = 0

    init(
        board: TodoBoardDTO = makeOfflineBoard(),
        friends: [FriendDTO] = [],
        boardError: APIError? = nil,
        friendsError: APIError? = nil,
        createError: APIError? = nil,
        boardSequence: [Result<TodoBoardDTO, APIError>]? = nil,
        friendsSequence: [Result<[FriendDTO], APIError>]? = nil
    ) {
        boardResult = boardError.map(Result.failure) ?? .success(board)
        friendsResult = friendsError.map(Result.failure) ?? .success(friends)
        createResult = createError.map(Result.failure)
            ?? .success(makeOfflineTodo(title: "Server task"))
        self.boardSequence = boardSequence
        self.friendsSequence = friendsSequence
    }

    func fetchBoard() async throws -> TodoBoardDTO {
        fetchBoardCount += 1
        if let boardSequence, !boardSequence.isEmpty {
            let index = min(boardSequenceIndex, boardSequence.count - 1)
            boardSequenceIndex += 1
            return try boardSequence[index].get()
        }
        return try boardResult.get()
    }

    func fetchFriends() async throws -> [FriendDTO] {
        if let friendsSequence, !friendsSequence.isEmpty {
            let index = min(friendsSequenceIndex, friendsSequence.count - 1)
            friendsSequenceIndex += 1
            return try friendsSequence[index].get()
        }
        return try friendsResult.get()
    }
    func fetchAttachments(todoID: TodoID) async throws -> [AttachmentDTO] {
        fetchAttachmentsCount += 1
        return []
    }

    func create(_ request: TodoRequest) async throws -> TodoDTO {
        createRequest = request
        return try createResult.get()
    }

    func update(id: TodoID, request: TodoRequest) async throws -> TodoDTO {
        mutationCallCount += 1
        throw APIError.transport
    }
    func delete(id: TodoID) async throws {
        mutationCallCount += 1
        throw APIError.transport
    }
    func complete(id: TodoID) async throws -> TodoDTO {
        mutationCallCount += 1
        throw APIError.transport
    }
    func reopen(id: TodoID) async throws -> TodoDTO {
        mutationCallCount += 1
        throw APIError.transport
    }
    func changeStatus(id: TodoID, request: TodoStatusChangeRequest) async throws -> TodoDTO {
        mutationCallCount += 1
        throw APIError.transport
    }
    func updatePositions(_ request: TodoPositionUpdateRequest) async throws {
        mutationCallCount += 1
        throw APIError.transport
    }
    func leaveTag(id: TodoID) async throws {
        mutationCallCount += 1
        throw APIError.transport
    }
}

private actor TodoOfflineCacheFake: OfflineCacheProviding {
    private var account: OfflineAccountSnapshot?
    private var board: TodoBoardDTO?
    private(set) var savedBoards: [TodoBoardDTO] = []

    init(account: OfflineAccountSnapshot? = nil, board: TodoBoardDTO? = nil) {
        self.account = account
        self.board = board
    }

    func saveAccount(_ snapshot: OfflineAccountSnapshot) async throws { account = snapshot }
    func saveAccount(member: LoginMember, friends: [FriendDTO], dDays: [DDayDTO], now: Date) async throws {}
    func loadAccount(memberID: MemberID) async -> OfflineAccountSnapshot? {
        guard account?.memberID == memberID else { return nil }
        return account
    }
    func saveMonth(_ snapshot: OfflineMonthSnapshot) async throws {}
    func loadMonth(accountID: MemberID, key: OfflineMonthKey) async -> OfflineMonthSnapshot? { nil }
    func loadCachedMonths(accountID: MemberID, around current: OfflineMonthKey) async -> [OfflineMonthSnapshot] { [] }
    func saveTodoBoard(accountID: MemberID, board: TodoBoardDTO, now: Date) async throws {
        self.board = board
        savedBoards.append(board)
    }
    func loadTodoBoard(accountID: MemberID) async -> TodoBoardDTO? { board }
    func searchSchedules(accountID: MemberID, query: String, keys: [OfflineMonthKey]?) async -> [ScheduleSearchResultDTO] { [] }
    func purge(accountID: MemberID) async throws {}
}

private actor TodoOfflineOutboxFake: OfflineOutboxProviding {
    private var storedEntries: [OfflineOutboxEntry] = []

    init(entries: [OfflineOutboxEntry] = []) {
        storedEntries = entries
    }

    func enqueueScheduleCreate(accountID: MemberID, request: ScheduleSaveDTO, operationID: UUID, now: Date) async throws -> OfflineOutboxEntry {
        fatalError("not used")
    }
    func enqueueTodoCreate(accountID: MemberID, request: TodoRequest, operationID: UUID, now: Date) async throws -> OfflineOutboxEntry {
        makeTodoEntry(
            accountID: accountID,
            request: request,
            operationID: operationID,
            now: now
        )
    }

    private func makeTodoEntry(
        accountID: MemberID,
        request: TodoRequest,
        operationID: UUID,
        now: Date
    ) -> OfflineOutboxEntry {
        if let existing = storedEntries.first(where: { $0.operationID == operationID }) { return existing }
        let entry = OfflineOutboxEntry(
            operationID: operationID,
            accountID: accountID,
            payload: .todoCreate(request),
            createdAt: now
        )
        storedEntries.append(entry)
        return entry
    }

    func entries(accountID: MemberID) async -> [OfflineOutboxEntry] {
        storedEntries.filter { $0.accountID == accountID }
    }
    func pendingEntries(accountID: MemberID, now: Date) async -> [OfflineOutboxEntry] { await entries(accountID: accountID) }
    func recordRetry(accountID: MemberID, operationID: UUID, error: OfflineOutboxFailure, nextAttemptAt: Date?) async throws {}
    func markPermanentFailure(accountID: MemberID, operationID: UUID, error: OfflineOutboxFailure) async throws {}
    func retryPermanentFailure(accountID: MemberID, operationID: UUID, now: Date) async throws {}
    func markSucceeded(accountID: MemberID, operationID: UUID) async throws {}
    func purge(accountID: MemberID) async throws { storedEntries.removeAll { $0.accountID == accountID } }
}

private actor TodoRecoveryRecorder {
    private(set) var accountIDs: [MemberID] = []

    func record(_ accountID: MemberID) {
        accountIDs.append(accountID)
    }
}

nonisolated private func makeOfflineAccount(friends: [FriendDTO] = []) -> OfflineAccountSnapshot {
    OfflineAccountSnapshot(
        memberID: 42,
        profile: OfflineProfileSnapshot(memberID: 42, name: "Offline user", email: nil, teamID: nil, teamName: nil),
        friends: friends
    )
}

nonisolated private func makeOfflineFriend(id: MemberID, name: String) -> FriendDTO {
    FriendDTO(id: id, name: name, teamId: nil, team: nil, hasProfilePhoto: false, profilePhotoVersion: 0, isFamily: false, pinOrder: nil)
}

nonisolated private func makeOfflineTodo(
    id: TodoID = UUID(),
    title: String,
    status: TodoStatus = .todo,
    hasAttachments: Bool = false
) -> TodoDTO {
    TodoDTO(
        id: id.uuidString,
        title: title,
        content: "Details",
        position: 0,
        status: status,
        createdDate: LocalDateTimeValue(rawValue: "2026-08-15T09:00:00"),
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

nonisolated private func makeOfflineBoard(
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
