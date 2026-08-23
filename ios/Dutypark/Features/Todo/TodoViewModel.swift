import Combine
import Foundation

@MainActor
final class TodoViewModel: ObservableObject {
    @Published private(set) var board: TodoBoardDTO?
    @Published private(set) var friends: [FriendDTO] = []
    @Published private(set) var attachmentsByTodoID: [TodoID: [AttachmentDTO]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var selectedStatus: TodoStatus = .inProgress
    @Published var errorKey: String?
    /// True while the board shown to the user came from the durable cache
    /// instead of the latest server response.  Mutating operations stay
    /// disabled in this state, except for the deliberately supported plain
    /// Todo create flow.
    @Published private(set) var isOffline = false
    @Published private(set) var isShowingCachedData = false
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var pendingOperationCount = 0

    var isStale: Bool { isShowingCachedData }
    var hasPendingWrites: Bool { pendingOperationCount > 0 }
    var isOfflineMode: Bool { isOffline }
    var cacheStoredAt: Date? { lastSyncedAt }
    var pendingTodoCount: Int { pendingOperationCount }

    private let repository: any TodoRepository
    private let contentFilter: ContentFilterStore
    private let hapticCenter: DPHapticCenter
    private let cache: any OfflineCacheProviding
    private let outbox: any OfflineOutboxProviding
    private let recoveryDelays: [Duration]
    private let recoverySleep: @Sendable (Duration) async throws -> Void
    private let syncQueuedOutbox: @MainActor @Sendable (MemberID) async -> Void
    private var accountID: MemberID?
    private var sessionAvailability: SessionAvailability?
    private var recoveryTask: Task<Void, Never>?
    private var recoveryGeneration = 0

    init(
        repository: any TodoRepository = TodoAPIRepository(),
        contentFilter: ContentFilterStore = .shared,
        hapticCenter: DPHapticCenter = .shared,
        cache: any OfflineCacheProviding = OfflineCacheStore.shared,
        outbox: any OfflineOutboxProviding = OfflineOutboxStore.shared,
        recoveryDelays: [Duration] = [.seconds(2), .seconds(5), .seconds(15), .seconds(30)],
        recoverySleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        },
        syncQueuedOutbox: @escaping @MainActor @Sendable (MemberID) async -> Void = { accountID in
            await OfflineSyncCoordinator.shared.synchronize(accountID: accountID)
        }
    ) {
        self.repository = repository
        self.contentFilter = contentFilter
        self.hapticCenter = hapticCenter
        self.cache = cache
        self.outbox = outbox
        self.recoveryDelays = recoveryDelays
        self.recoverySleep = recoverySleep
        self.syncQueuedOutbox = syncQueuedOutbox
    }

    deinit {
        recoveryTask?.cancel()
    }

    /// Emits semantic feedback from the view-model result boundary. Keeping the
    /// event center injectable makes mutation feedback testable without needing
    /// a device, while the app default still routes through the root haptic host.
    @discardableResult
    func emitHaptic(_ kind: DPHapticKind) -> DPHapticEvent {
        hapticCenter.emit(kind)
    }

    var selectedTodos: [TodoDTO] {
        todos(for: selectedStatus)
    }

    func todos(for status: TodoStatus) -> [TodoDTO] {
        guard let board else { return [] }
        return switch status {
        case .todo: board.todo
        case .inProgress: board.inProgress
        case .done: board.done
        case .unknown: []
        }
    }

    func count(for status: TodoStatus) -> Int {
        guard let counts = board?.counts else { return 0 }
        return switch status {
        case .todo: counts.todo
        case .inProgress: counts.inProgress
        case .done: counts.done
        case .unknown: 0
        }
    }

    /// Selects the matching board column and returns the Todo for presentation.
    /// Notification routing uses this after the latest board has loaded.
    func open(todoID: TodoID) -> TodoDTO? {
        for status in [TodoStatus.todo, .inProgress, .done] {
            if let todo = todos(for: status).first(where: { $0.uuid == todoID }) {
                selectedStatus = status
                return todo
            }
        }
        return nil
    }

    func load(
        accountID: MemberID? = nil,
        availability: SessionAvailability? = nil
    ) async {
        guard !isLoading else { return }
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            loadUITestingFixture()
            return
        }
#endif
        if let accountID { setAccountID(accountID) }
        if let availability {
            sessionAvailability = availability
            if availability.isOffline {
                isOffline = true
            }
        }
        isLoading = true
        defer { isLoading = false }
        await fetchBoardAndFriends()
    }

    func refresh(
        accountID: MemberID? = nil,
        availability: SessionAvailability? = nil
    ) async {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            loadUITestingFixture()
            return
        }
#endif
        if let accountID { setAccountID(accountID) }
        if let availability {
            sessionAvailability = availability
            if availability.isOffline {
                isOffline = true
            }
        }
        await fetchBoardAndFriends()
    }

    /// Public seam used by the outbox synchronizer after it has successfully
    /// sent queued creates. It intentionally goes through the same cache
    /// refresh path as a user pull-to-refresh so a provisional card is
    /// replaced by its server representation.
    func refreshAfterSync(
        accountID: MemberID? = nil,
        availability: SessionAvailability? = nil
    ) async {
        await refresh(
            accountID: accountID ?? self.accountID,
            // A completed outbox sync is itself proof that a live transport
            // is available, so this seam must not remain in the cached-only
            // branch left by the previous offline session.
            availability: availability ?? .online
        )
    }

    /// Called by the app-level outbox coordinator after a successful drain.
    /// This refresh intentionally emits no haptic feedback: the background
    /// sync is not a direct user action.
    func handleOfflineSyncCompleted(accountID: MemberID? = nil) async {
        guard let accountID = accountID ?? self.accountID else { return }
        await refreshAfterSync(accountID: accountID, availability: .online)
    }

    /// Stops the bounded server-recovery loop when the view leaves the
    /// hierarchy. A later appearance starts a fresh load and can schedule a
    /// new loop if the server is still unavailable.
    func cancelRecovery() {
        recoveryGeneration &+= 1
        recoveryTask?.cancel()
        recoveryTask = nil
    }

    private func setAccountID(_ accountID: MemberID) {
        guard self.accountID != accountID else { return }
        cancelRecovery()
        self.accountID = accountID
    }

    private func fetchBoardAndFriends(allowsRecoveryScheduling: Bool = true) async {
        let currentAccountID = accountID
        let cachedAccount: OfflineAccountSnapshot?
        if let currentAccountID {
            cachedAccount = await cache.loadAccount(memberID: currentAccountID)
        } else {
            cachedAccount = nil
        }

        if sessionAvailability?.isOffline == true {
            guard let currentAccountID,
                  let cachedBoard = await cache.loadTodoBoard(accountID: currentAccountID)
            else {
                board = nil
                isShowingCachedData = false
                lastSyncedAt = nil
                errorKey = "todo.error.load"
                await refreshPendingOperationState()
                return
            }
            board = cachedBoard
            friends = cachedAccount?.friends.sorted(by: friendOrder) ?? []
            isOffline = true
            isShowingCachedData = true
            lastSyncedAt = cachedAccount?.storedAt
            errorKey = nil
            await overlayQueuedTodos(accountID: currentAccountID)
            await saveCurrentBoardToCache(accountID: currentAccountID)
            selectNonemptyStatusIfNeeded()
            await refreshPendingOperationState()
            return
        }

        var usedFallback = false
        var boardLoaded = false
        do {
            let serverBoard = try await repository.fetchBoard()
            board = serverBoard
            boardLoaded = true
            isOffline = false
            isShowingCachedData = false
            lastSyncedAt = .now
            if let currentAccountID {
                try? await cache.saveTodoBoard(
                    accountID: currentAccountID,
                    board: serverBoard,
                    now: .now
                )
            }
        } catch {
            guard isOfflineEligible(error),
                  let currentAccountID,
                  let cachedBoard = await cache.loadTodoBoard(accountID: currentAccountID)
            else {
                errorKey = "todo.error.load"
                await refreshPendingOperationState()
                return
            }
            board = cachedBoard
            boardLoaded = true
            usedFallback = true
            isOffline = true
            isShowingCachedData = true
            lastSyncedAt = cachedAccount?.storedAt
            errorKey = nil
            selectNonemptyStatusIfNeeded()
        }

        guard boardLoaded else {
            errorKey = "todo.error.load"
            await refreshPendingOperationState()
            return
        }
        if let currentAccountID {
            await overlayQueuedTodos(accountID: currentAccountID)
            await saveCurrentBoardToCache(accountID: currentAccountID)
        }
        selectNonemptyStatusIfNeeded()

        do {
            let serverFriends = try await repository.fetchFriends()
            friends = serverFriends.sorted(by: friendOrder)
            if let cachedAccount {
                let updated = OfflineAccountSnapshot(
                    memberID: cachedAccount.memberID,
                    profile: cachedAccount.profile,
                    friends: friends,
                    dDays: cachedAccount.dDays,
                    storedAt: .now
                )
                try? await cache.saveAccount(updated)
            }
        } catch {
            if isOfflineEligible(error), let cachedAccount {
                friends = cachedAccount.friends.sorted(by: friendOrder)
                usedFallback = true
                isOffline = true
                isShowingCachedData = true
                lastSyncedAt = cachedAccount.storedAt
            } else {
                // Preserve the pre-existing behavior for a non-transport
                // friends failure: the board remains usable and an empty
                // friends list simply disables optional tagging UI.
                friends = []
                // Continue through the normal completion path so a fresh
                // board can clear a prior fallback state and wake the
                // outbox even when friends have no usable cache.
                if !usedFallback {
                    isOffline = false
                    isShowingCachedData = false
                }
                if !usedFallback {
                    errorKey = nil
                }
            }
        }

        if !usedFallback {
            isOffline = false
            isShowingCachedData = false
            errorKey = nil
            if allowsRecoveryScheduling {
                cancelRecovery()
            }
            await syncQueuedOutboxIfNeeded(accountID: currentAccountID)
        } else if allowsRecoveryScheduling, let currentAccountID {
            scheduleRecovery(for: currentAccountID)
        }
        await refreshPendingOperationState()
    }

    func loadAttachments(for todo: TodoDTO) async {
        guard ensureOnlineMutationAllowed() else { return }
        guard todo.hasAttachments, attachmentsByTodoID[todo.uuid] == nil else {
            if !todo.hasAttachments { attachmentsByTodoID[todo.uuid] = [] }
            return
        }
        do {
            attachmentsByTodoID[todo.uuid] = try await repository.fetchAttachments(todoID: todo.uuid)
        } catch {
            errorKey = "todo.error.attachments"
        }
    }

    func create(
        draft: TodoDraft,
        accountID: MemberID? = nil,
        availability: SessionAvailability? = nil,
        refreshBoard: Bool = true
    ) async -> Bool {
        guard !isSaving else { return false }
        if let accountID { setAccountID(accountID) }
        if let availability {
            sessionAvailability = availability
            if availability.isOffline {
                isOffline = true
            }
        }
        guard !contentFilter.isBlocked(draft.title, draft.content) else {
            errorKey = "todo.error.contentFilter"
            emitHaptic(.error)
            return false
        }

        let currentAccountID = accountID ?? self.accountID
        if isOffline && !draft.request().supportsOfflineCreate {
            errorKey = "todo.error.offlineUnsupported"
            emitHaptic(.warning)
            return false
        }

        isSaving = true
        defer { isSaving = false }
        // Keep this UUID for the entire attempt. If the transport fails, the
        // exact request and operation identity are placed in the durable
        // outbox; server-side dedupe is handled by the sync transport.
        let operationID = UUID()
        let request = draft.request()
        if isOffline {
            return await enqueueOfflineCreate(
                request,
                operationID: operationID,
                accountID: currentAccountID,
                triggerSync: sessionAvailability?.isOffline != true
            )
        }
        do {
            let created = try await repository.create(request)
            if refreshBoard {
                patchBoard(with: created)
                await saveCurrentBoardToCache(accountID: currentAccountID)
            }
            isOffline = false
            isShowingCachedData = false
            await refreshPendingOperationState(accountID: currentAccountID)
            emitHaptic(.success)
            return true
        } catch let error {
            guard isCreateOfflineEligible(error) else {
                errorKey = "todo.error.create"
                emitHaptic(.error)
                return false
            }

            return await enqueueOfflineCreate(
                request,
                operationID: operationID,
                accountID: currentAccountID,
                triggerSync: true
            )
        }
    }

    func update(todo: TodoDTO, draft: TodoDraft) async -> Bool {
        guard ensureOnlineMutationAllowed() else { return false }
        guard !isSaving else { return false }
        guard !todo.hasAttachments || attachmentsByTodoID[todo.uuid] != nil else {
            errorKey = "todo.error.attachmentsRequired"
            emitHaptic(.warning)
            return false
        }
        guard !contentFilter.isBlocked(draft.title, draft.content) else {
            errorKey = "todo.error.contentFilter"
            emitHaptic(.error)
            return false
        }
        return await performMutation(errorKey: "todo.error.update") {
            try await repository.update(
                id: todo.uuid,
                request: draft.request()
            )
        }
    }

    func delete(_ todo: TodoDTO) async -> Bool {
        guard ensureOnlineMutationAllowed() else { return false }
        return await performRemoval(todoID: todo.uuid, errorKey: "todo.error.delete") {
            try await repository.delete(id: todo.uuid)
        }
    }

    func complete(_ todo: TodoDTO) async -> Bool {
        guard ensureOnlineMutationAllowed() else { return false }
        return await performMutation(errorKey: "todo.error.status") {
            try await repository.complete(id: todo.uuid)
        }
    }

    func reopen(_ todo: TodoDTO) async -> Bool {
        guard ensureOnlineMutationAllowed() else { return false }
        return await performMutation(errorKey: "todo.error.status") {
            try await repository.reopen(id: todo.uuid)
        }
    }

    func move(_ todo: TodoDTO, to status: TodoStatus) async -> Bool {
        guard ensureOnlineMutationAllowed() else { return false }
        guard todo.status != status else { return true }
        return await performMutation(errorKey: "todo.error.status") {
            try await repository.changeStatus(
                id: todo.uuid,
                request: TodoStatusChangeRequest(status: status, orderedIds: [])
            )
        }
    }

    @discardableResult
    func moveWithinSelectedColumn(_ todo: TodoDTO, offset: Int) async -> Bool {
        let items = selectedTodos
        guard let source = items.firstIndex(where: { $0.id == todo.id }) else { return false }
        let destination = source + offset
        guard items.indices.contains(destination) else { return false }
        let target = items[destination]
        return await drop(
            todoID: todo.uuid,
            into: selectedStatus,
            relativeTo: target.uuid,
            insertAfter: offset > 0
        )
    }

    /// Optimistically applies the exact order the viewer sees, then persists it
    /// using the same contract as the web Kanban board. Owned and tagged cards
    /// deliberately share one ordering space on each viewer's board.
    @discardableResult
    func drop(
        todoID: TodoID,
        into destinationStatus: TodoStatus,
        relativeTo targetTodoID: TodoID? = nil,
        insertAfter: Bool = false
    ) async -> Bool {
        guard ensureOnlineMutationAllowed() else { return false }
        guard !isSaving, let originalBoard = board else { return false }
        guard let sourceStatus = boardStatus(of: todoID, in: originalBoard) else { return false }

        if targetTodoID == todoID {
            return true
        }

        var columns = TodoBoardColumns(board: originalBoard)
        let movingTodo = columns.remove(todoID: todoID, from: sourceStatus)
        guard let movingTodo else { return false }

        let insertionIndex = columns.insertionIndex(
            in: destinationStatus,
            relativeTo: targetTodoID,
            insertAfter: insertAfter
        )
        columns.insert(
            movingTodo.updatingStatus(destinationStatus),
            in: destinationStatus,
            at: insertionIndex
        )

        let optimisticBoard = columns.board
        guard optimisticBoard != originalBoard else { return true }

        board = optimisticBoard
        selectedStatus = destinationStatus
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-todo-confirmations") {
            return true
        }
#endif
        isSaving = true
        defer { isSaving = false }

        do {
            let orderedIds = columns.todos(for: destinationStatus).map(\.uuid)
            if sourceStatus == destinationStatus {
                try await repository.updatePositions(
                    TodoPositionUpdateRequest(status: destinationStatus, orderedIds: orderedIds)
                )
            } else {
                _ = try await repository.changeStatus(
                    id: todoID,
                    request: TodoStatusChangeRequest(
                        status: destinationStatus,
                        orderedIds: orderedIds
                    )
                )
            }
            await saveCurrentBoardToCache(accountID: accountID)
            return true
        } catch {
            board = originalBoard
            selectedStatus = sourceStatus
            errorKey = sourceStatus == destinationStatus
                ? "todo.error.reorder"
                : "todo.error.status"
            emitHaptic(.error)
            return false
        }
    }

    func leaveTag(_ todo: TodoDTO) async -> Bool {
        guard ensureOnlineMutationAllowed() else { return false }
        return await performRemoval(todoID: todo.uuid, errorKey: "todo.error.leaveTag") {
            try await repository.leaveTag(id: todo.uuid)
        }
    }

    private func performMutation(
        errorKey: String,
        operation: () async throws -> TodoDTO
    ) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            patchBoard(with: try await operation())
            await saveCurrentBoardToCache(accountID: accountID)
            emitHaptic(.success)
            return true
        } catch {
            self.errorKey = errorKey
            emitHaptic(.error)
            return false
        }
    }

    private func performRemoval(
        todoID: TodoID,
        errorKey: String,
        operation: () async throws -> Void
    ) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await operation()
            removeFromBoard(todoID: todoID)
            attachmentsByTodoID[todoID] = nil
            await saveCurrentBoardToCache(accountID: accountID)
            emitHaptic(.success)
            return true
        } catch {
            self.errorKey = errorKey
            emitHaptic(.error)
            return false
        }
    }

    private func ensureOnlineMutationAllowed() -> Bool {
        guard !isOffline else {
            errorKey = "todo.error.offlineReadOnly"
            emitHaptic(.warning)
            return false
        }
        return true
    }

    private func scheduleRecovery(for accountID: MemberID) {
        guard accountID > 0, !recoveryDelays.isEmpty else { return }
        cancelRecovery()
        let generation = recoveryGeneration
        let delays = recoveryDelays
        let sleep = recoverySleep
        recoveryTask = Task { @MainActor [weak self] in
            defer {
                if let self, self.recoveryGeneration == generation {
                    self.recoveryTask = nil
                }
            }

            for delay in delays {
                do {
                    try await sleep(delay)
                } catch {
                    return
                }
                guard let self,
                      self.recoveryGeneration == generation,
                      self.accountID == accountID
                else { return }

                // Keep this request silent. The user did not initiate a new
                // mutation, and the regular refresh path never emits haptics.
                await self.fetchBoardAndFriends(allowsRecoveryScheduling: false)
                guard self.recoveryGeneration == generation,
                      self.accountID == accountID
                else { return }
                if !self.isOffline && !self.isShowingCachedData { return }
            }
        }
    }

    private func syncQueuedOutboxIfNeeded(accountID: MemberID?) async {
        guard let accountID else { return }
        let hasPending = await outbox.entries(accountID: accountID).contains {
            $0.state == .pending
        }
        guard hasPending else { return }
        // The coordinator uses a satisfied transport hint here deliberately:
        // this path exists for a server outage with an unchanged NWPath, where
        // waiting for another path transition would leave the queue stuck.
        await syncQueuedOutbox(accountID)
    }

    private func isOfflineEligible(_ error: Error) -> Bool {
        guard let error = error as? APIError else { return false }
        switch error {
        case .transport:
            return true
        case .server(let status, _), .serverWithDetails(let status, _, _):
            return status >= 500
        default:
            return false
        }
    }

    /// A create response can be ambiguous even when the HTTP request reached
    /// the server: a 2xx with an empty or malformed body may have committed the
    /// Todo before decoding failed. Keep GET fallback strict, but preserve the
    /// same idempotent create request for a later server reconciliation.
    private func isCreateOfflineEligible(_ error: Error) -> Bool {
        guard let error = error as? APIError else { return false }
        switch error {
        case .transport, .invalidResponse, .decoding:
            return true
        case .server(let status, _), .serverWithDetails(let status, _, _):
            return status >= 500
        default:
            return false
        }
    }

    private func refreshPendingOperationState(accountID: MemberID? = nil) async {
        guard let accountID = accountID ?? self.accountID else {
            pendingOperationCount = 0
            return
        }
        pendingOperationCount = await outbox.entries(accountID: accountID).filter {
            $0.state == .pending
        }.count
    }

    private func saveCurrentBoardToCache(accountID: MemberID? = nil) async {
        guard let accountID = accountID ?? self.accountID, let board else { return }
        try? await cache.saveTodoBoard(accountID: accountID, board: board, now: .now)
    }

    /// Rebuilds locally-created cards from the durable outbox on every board
    /// load. The cache is normally enough, but this overlay also survives an
    /// interrupted cache write and keeps a queued card visible after a relaunch.
    private func overlayQueuedTodos(accountID: MemberID) async {
        for entry in await outbox.entries(accountID: accountID) {
            guard case .todoCreate(let request) = entry.payload else { continue }
            patchBoard(with: provisionalTodo(
                from: request,
                id: entry.operationID,
                createdAt: entry.createdAt
            ))
        }
    }

    private func enqueueOfflineCreate(
        _ request: TodoRequest,
        operationID: UUID,
        accountID: MemberID?,
        triggerSync: Bool
    ) async -> Bool {
        guard let accountID,
              request.supportsOfflineCreate
        else {
            errorKey = "todo.error.offlineUnsupported"
            emitHaptic(.warning)
            return false
        }

        do {
            _ = try await outbox.enqueueTodoCreate(
                accountID: accountID,
                request: request,
                operationID: operationID,
                now: .now,
                requiresPreflight: triggerSync
            )
        } catch {
            // A failed durable write must never be presented as a queued
            // success. Keep the in-memory board untouched so the caller can
            // retry without losing the last confirmed state.
            errorKey = "todo.error.offlineQueue"
            emitHaptic(.error)
            return false
        }

        let provisional = provisionalTodo(
            from: request,
            id: operationID,
            createdAt: .now
        )
        patchBoard(with: provisional)
        isOffline = true
        isShowingCachedData = true
        await saveCurrentBoardToCache(accountID: accountID)
        await refreshPendingOperationState(accountID: accountID)
        errorKey = nil
        // The user's local save completed durably; the later network drain
        // is silent and must not emit a second success event.
        emitHaptic(.success)
        if triggerSync {
            let sync = syncQueuedOutbox
            Task { @MainActor in
                await sync(accountID)
            }
        }
        return true
    }

    private func provisionalTodo(
        from request: TodoRequest,
        id: TodoID,
        createdAt: Date
    ) -> TodoDTO {
        let status = request.status ?? .todo
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return TodoDTO(
            id: id.uuidString,
            title: request.title,
            content: request.content,
            position: todos(for: status).count,
            status: status,
            createdDate: LocalDateTimeValue(rawValue: formatter.string(from: createdAt)),
            completedDate: nil,
            dueDate: request.dueDate,
            isOverdue: false,
            isTagged: false,
            owner: "Me",
            taggedByMember: nil,
            tags: [],
            hasAttachments: false
        )
    }

    private func patchBoard(with todo: TodoDTO) {
        var columns = board.map(TodoBoardColumns.init(board:)) ?? TodoBoardColumns()
        columns.replace(todo)
        board = columns.board
    }

    private func removeFromBoard(todoID: TodoID) {
        guard let board else { return }
        var columns = TodoBoardColumns(board: board)
        columns.remove(todoID: todoID)
        self.board = columns.board
    }

    private func selectNonemptyStatusIfNeeded() {
        guard let board, board.counts.total > 0, count(for: selectedStatus) == 0 else { return }
        if !board.inProgress.isEmpty {
            selectedStatus = .inProgress
        } else if !board.todo.isEmpty {
            selectedStatus = .todo
        } else {
            selectedStatus = .done
        }
    }

    private func friendOrder(_ lhs: FriendDTO, _ rhs: FriendDTO) -> Bool {
        switch (lhs.pinOrder, rhs.pinOrder) {
        case let (left?, right?) where left != right:
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            if lhs.isFamily != rhs.isFamily {
                return lhs.isFamily
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func boardStatus(of todoID: TodoID, in board: TodoBoardDTO) -> TodoStatus? {
        for status in TodoStatus.boardStatuses {
            if TodoBoardColumns(board: board).todos(for: status).contains(where: { $0.uuid == todoID }) {
                return status
            }
        }
        return nil
    }

#if DEBUG
    private func loadUITestingFixture() {
        let overflowTodos = (3...10).map { index in
            TodoDTO(
                id: String(format: "A11CE000-0000-4000-8000-%012d", index),
                title: "스크롤 확인 \(index)",
                content: "세로 목록 이동과 카드 탭 동작을 확인합니다.",
                position: index - 1,
                status: .inProgress,
                createdDate: LocalDateTimeValue(rawValue: "2026-08-15T09:00:00"),
                completedDate: nil,
                dueDate: nil,
                isOverdue: false,
                isTagged: false,
                owner: "UI Test",
                taggedByMember: nil,
                tags: [],
                hasAttachments: false
            )
        }
        let fixtureTodos: [TodoDTO] = ProcessInfo.processInfo.arguments.contains("-ui-testing-todo-confirmations")
            ? [
                TodoDTO(
                    id: "A11CE000-0000-4000-8000-000000000001",
                    title: "병동 인수인계 확인",
                    content: "오후 근무 전 확인할 항목을 정리합니다.",
                    position: 0,
                    status: .inProgress,
                    createdDate: LocalDateTimeValue(rawValue: "2026-08-15T08:00:00"),
                    completedDate: nil,
                    dueDate: DateOnly(rawValue: "2026-08-15"),
                    isOverdue: false,
                    isTagged: false,
                    owner: "UI Test",
                    taggedByMember: nil,
                    tags: [],
                    hasAttachments: false
                ),
                TodoDTO(
                    id: "A11CE000-0000-4000-8000-000000000002",
                    title: "저녁 근무 준비",
                    content: "투약 목록과 병실 순서를 확인합니다.",
                    position: 1,
                    status: .inProgress,
                    createdDate: LocalDateTimeValue(rawValue: "2026-08-15T08:30:00"),
                    completedDate: nil,
                    dueDate: nil,
                    isOverdue: false,
                    isTagged: false,
                    owner: "UI Test",
                    taggedByMember: nil,
                    tags: [],
                    hasAttachments: false
                )
            ] + overflowTodos
            : []
        board = TodoBoardDTO(
            todo: [],
            inProgress: fixtureTodos,
            done: [],
            counts: TodoCountsDTO(
                todo: 0,
                inProgress: fixtureTodos.count,
                done: 0,
                total: fixtureTodos.count
            )
        )
        friends = []
        attachmentsByTodoID = [:]
        errorKey = nil
        selectedStatus = .inProgress
        isOffline = false
        isShowingCachedData = false
        lastSyncedAt = nil
        pendingOperationCount = 0
    }
#endif
}

private struct TodoBoardColumns {
    var todo: [TodoDTO]
    var inProgress: [TodoDTO]
    var done: [TodoDTO]

    init() {
        todo = []
        inProgress = []
        done = []
    }

    init(board: TodoBoardDTO) {
        todo = board.todo
        inProgress = board.inProgress
        done = board.done
    }

    var board: TodoBoardDTO {
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

    func todos(for status: TodoStatus) -> [TodoDTO] {
        switch status {
        case .todo: todo
        case .inProgress: inProgress
        case .done: done
        case .unknown: []
        }
    }

    mutating func remove(todoID: TodoID, from status: TodoStatus) -> TodoDTO? {
        switch status {
        case .todo: remove(todoID: todoID, from: &todo)
        case .inProgress: remove(todoID: todoID, from: &inProgress)
        case .done: remove(todoID: todoID, from: &done)
        case .unknown: nil
        }
    }

    mutating func remove(todoID: TodoID) {
        for status in TodoStatus.boardStatuses {
            _ = remove(todoID: todoID, from: status)
        }
    }

    mutating func replace(_ item: TodoDTO) {
        remove(todoID: item.uuid)
        let index = item.position ?? todos(for: item.status).endIndex
        insert(item, in: item.status, at: index)
    }

    mutating func insert(_ item: TodoDTO, in status: TodoStatus, at index: Int) {
        switch status {
        case .todo: todo.insert(item, at: min(max(0, index), todo.endIndex))
        case .inProgress: inProgress.insert(item, at: min(max(0, index), inProgress.endIndex))
        case .done: done.insert(item, at: min(max(0, index), done.endIndex))
        case .unknown: break
        }
    }

    func insertionIndex(
        in status: TodoStatus,
        relativeTo targetTodoID: TodoID?,
        insertAfter: Bool
    ) -> Int {
        let items = todos(for: status)
        guard
            let targetTodoID,
            let targetIndex = items.firstIndex(where: { $0.uuid == targetTodoID })
        else {
            return items.endIndex
        }
        return targetIndex + (insertAfter ? 1 : 0)
    }

    private func remove(todoID: TodoID, from items: inout [TodoDTO]) -> TodoDTO? {
        guard let index = items.firstIndex(where: { $0.uuid == todoID }) else { return nil }
        return items.remove(at: index)
    }
}

private extension TodoDTO {
    func updatingStatus(_ status: TodoStatus) -> TodoDTO {
        TodoDTO(
            id: id,
            title: title,
            content: content,
            position: position,
            status: status,
            createdDate: createdDate,
            completedDate: completedDate,
            dueDate: dueDate,
            isOverdue: isOverdue,
            isTagged: isTagged,
            owner: owner,
            taggedByMember: taggedByMember,
            tags: tags,
            hasAttachments: hasAttachments
        )
    }
}

struct TodoDraft: Equatable {
    var title = ""
    var content = ""
    var status: TodoStatus = .todo
    var hasDueDate = false
    var dueDate = Date()
    var taggedFriendIDs: Set<MemberID> = []
    var attachmentSessionId: UUID?
    var orderedAttachmentIDs: [AttachmentID] = []

    init(status: TodoStatus = .todo) {
        self.status = status
    }

    init(todo: TodoDTO) {
        title = todo.title
        content = todo.content
        status = todo.status
        taggedFriendIDs = Set(todo.tags.compactMap(\.id))
        if let dueDate = todo.dueDate, let date = TodoDateFormatter.date(from: dueDate.rawValue) {
            hasDueDate = true
            self.dueDate = date
        }
    }

    var canSave: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 50
    }

    func request() -> TodoRequest {
        TodoRequest(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            dueDate: hasDueDate ? DateOnly(rawValue: TodoDateFormatter.string(from: dueDate)) : nil,
            tagFriendIds: taggedFriendIDs.sorted(),
            attachmentSessionId: attachmentSessionId,
            orderedAttachmentIds: orderedAttachmentIDs
        )
    }
}

enum TodoDateFormatter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(from value: String) -> Date? {
        dateFormatter.date(from: value)
    }

    static func string(from date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

extension TodoDTO {
    var uuid: TodoID {
        UUID(uuidString: id)!
    }
}

private extension TodoRequest {
    var supportsOfflineCreate: Bool {
        tagFriendIds?.isEmpty != false
            && attachmentSessionId == nil
            && orderedAttachmentIds.isEmpty
    }
}
