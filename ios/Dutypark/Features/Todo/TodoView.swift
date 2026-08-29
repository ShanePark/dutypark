import SwiftUI

func todoLocalized(_ key: String, locale: Locale? = nil) -> String {
    AppLocalization.string(key, table: "Todo", locale: locale)
}

enum TodoBoardLayout {
    static let mobileColumnWidthRatio: CGFloat = 0.62
    static let boardPadding: CGFloat = 8
    static let columnGap: CGFloat = 10
    static let columnRadius: CGFloat = 12
    static let cardRadius: CGFloat = 14
    /// Shared with the press progress ring so the gauge empties exactly when the
    /// card lifts instead of counting down its own copy of the threshold.
    static let dragLongPressDuration: TimeInterval = DPDragActivation.pressDuration
    static let dragLongPressMaximumDistance: CGFloat = DPDragActivation.maximumPressMovement
    static let dragCollisionHysteresis: CGFloat = 2
    static let dragPushAnimationDuration = 0.1
    static let dragAutoScrollDuration: TimeInterval = 0.3
    static let dragAutoScrollInterval = Duration.milliseconds(300)

    static func mobileColumnWidth(in containerWidth: CGFloat) -> CGFloat {
        containerWidth * mobileColumnWidthRatio
    }

    /// Mirrors the responsive web board: the edge columns snap to the viewport
    /// edges while the middle column remains centered.
    static func scrollAnchor(for status: TodoStatus) -> UnitPoint {
        switch status {
        case .todo:
            .leading
        case .inProgress:
            .center
        case .done:
            .trailing
        case .unknown:
            .center
        }
    }
}

nonisolated enum TodoFormDismissalAction: Equatable, Sendable {
    case dismiss
    case confirmDiscard
    case ignore
}

nonisolated enum TodoFormSubmissionPolicy {
    static func canBegin(isSubmitting: Bool, canSave: Bool, isBusy: Bool) -> Bool {
        !isSubmitting && canSave && !isBusy
    }
}

enum TodoFormDismissalPolicy {
    static func isDirty(
        initialDraft: TodoDraft,
        draft: TodoDraft,
        initialAttachmentIDs: [AttachmentID],
        attachmentIDs: [AttachmentID],
        hasAttachmentSession: Bool
    ) -> Bool {
        var comparableInitialDraft = initialDraft
        var comparableDraft = draft
        if !comparableInitialDraft.hasDueDate {
            comparableInitialDraft.dueDate = .distantPast
        }
        if !comparableDraft.hasDueDate {
            comparableDraft.dueDate = .distantPast
        }

        return comparableDraft != comparableInitialDraft
            || initialAttachmentIDs != attachmentIDs
            || hasAttachmentSession
    }

    static func action(isDirty: Bool, isBusy: Bool) -> TodoFormDismissalAction {
        guard !isBusy else { return .ignore }
        return isDirty ? .confirmDiscard : .dismiss
    }
}

nonisolated enum TodoFormStatusSelectionPolicy {
    static func isVisible(targetTodoID: String?) -> Bool {
        targetTodoID == nil
    }
}

/// Persists attachment sessions whose discard request may outlive the Todo
/// form. Session IDs are account-scoped so a later login can retry only its
/// own cleanup work. These IDs do not contain attachment contents or tokens.
@MainActor
final class TodoAttachmentDiscardStore {
    static let shared = TodoAttachmentDiscardStore()

    private let defaults: UserDefaults
    private let keyPrefix = "dp-todo-attachment-discard."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func enqueue(accountID: MemberID, sessionID: UUID) {
        guard accountID > 0 else { return }
        var values = values(for: accountID)
        let rawValue = sessionID.uuidString
        guard !values.contains(rawValue) else { return }
        values.append(rawValue)
        defaults.set(values, forKey: key(for: accountID))
    }

    func pendingSessionIDs(accountID: MemberID) -> [UUID] {
        guard accountID > 0 else { return [] }
        return values(for: accountID).compactMap(UUID.init(uuidString:))
    }

    func remove(accountID: MemberID, sessionID: UUID) {
        guard accountID > 0 else { return }
        let remaining = values(for: accountID).filter { $0 != sessionID.uuidString }
        if remaining.isEmpty {
            defaults.removeObject(forKey: key(for: accountID))
        } else {
            defaults.set(remaining, forKey: key(for: accountID))
        }
    }

    func purge(accountID: MemberID) {
        guard accountID > 0 else { return }
        defaults.removeObject(forKey: key(for: accountID))
    }

    func purgeAll() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    private func values(for accountID: MemberID) -> [String] {
        defaults.array(forKey: key(for: accountID)) as? [String] ?? []
    }

    private func key(for accountID: MemberID) -> String {
        keyPrefix + String(accountID)
    }
}

/// Finishes cleanup for an attachment session after a Todo form has left the
/// hierarchy. A form is allowed to disappear immediately, but its temporary
/// server session is persisted until a discard succeeds. The coordinator is
/// shared by the authenticated session rather than owned by the form or a
/// particular view model, so retry state survives SwiftUI teardown.
@MainActor
final class TodoAttachmentDiscardCoordinator {
    /// The cleanup coordinator is session-scoped rather than view-scoped. A
    /// Todo board and Calendar detail can both present attachment forms, and
    /// authentication transitions must be able to cancel their in-flight
    /// requests before replacing credentials.
    static let shared = TodoAttachmentDiscardCoordinator()

    /// Mirrors the app outbox's five-second exponential retry cadence while
    /// keeping this cleanup bounded to a short retry window.
    static let defaultRetryDelays: [Duration] = [
        .seconds(5),
        .seconds(10),
        .seconds(20)
    ]

    typealias Sleep = @Sendable (Duration) async throws -> Void
    typealias PersistedDiscard = @Sendable (MemberID, UUID) async -> Bool

    private struct PendingKey: Hashable {
        let accountID: MemberID
        let sessionGeneration: UInt64
        let sessionID: UUID
    }

    private struct PendingOperation {
        let accountID: MemberID
        let sessionID: UUID
        let discard: @MainActor @Sendable () async -> Bool
    }

    private let store: TodoAttachmentDiscardStore
    private let retryDelays: [Duration]
    private let sleep: Sleep
    private let persistedDiscard: PersistedDiscard
    private var pendingOperations: [PendingKey: PendingOperation] = [:]
    private var tasks: [PendingKey: Task<Void, Never>] = [:]
    private var activeSession: AuthenticationSessionContext?

    init(
        store: TodoAttachmentDiscardStore = .shared,
        retryDelays: [Duration] = TodoAttachmentDiscardCoordinator.defaultRetryDelays,
        sleep: @escaping Sleep = { duration in
            try await Task.sleep(for: duration)
        },
        persistedDiscard: @escaping PersistedDiscard = { _, sessionID in
            do {
                try await AttachmentClient().discardSession(sessionID)
                return true
            } catch {
                return false
            }
        }
    ) {
        self.store = store
        self.retryDelays = retryDelays
        self.sleep = sleep
        self.persistedDiscard = persistedDiscard
    }

    /// Sessions that still need a successful discard for the authenticated
    /// account. The account argument is mandatory to avoid cross-account work.
    func pendingSessionIDs(accountID: MemberID) -> Set<UUID> {
        guard accountID > 0 else { return [] }
        let stored = store.pendingSessionIDs(accountID: accountID)
        let inMemory = pendingOperations.keys
            .filter { $0.accountID == accountID }
            .map(\.sessionID)
        return Set(stored + inMemory)
    }

    /// Changes the account boundary and stops old-account retry tasks without
    /// deleting their persisted records. They can be retried after that exact
    /// account authenticates again.
    func activate(accountID: MemberID, sessionGeneration: UInt64) {
        guard accountID > 0 else { return }
        let session = AuthenticationSessionContext(
            memberID: accountID,
            generation: sessionGeneration
        )
        // SessionStore is the authority that crosses authentication
        // boundaries. It calls `cancelAll()` before activating a new context.
        // Refuse a different context here so a stale Todo view cannot move the
        // coordinator back to an old account (or revive an old generation)
        // after logout or account switch.
        guard activeSession == nil || activeSession == session else { return }
        activeSession = session
    }

    /// Cancels only in-memory work for an account. Its durable pending IDs are
    /// intentionally retained for same-account recovery after re-login.
    func cancel(accountID: MemberID) {
        guard accountID > 0 else { return }
        for key in Array(tasks.keys) where key.accountID == accountID {
            tasks[key]?.cancel()
            tasks[key] = nil
        }
        // Do not retain a model-backed closure after the credentials it would
        // use have been invalidated. The durable session ID is rehydrated with
        // a fresh API client when this exact account authenticates again.
        for key in Array(pendingOperations.keys) where key.accountID == accountID {
            pendingOperations[key] = nil
        }
        if activeSession?.memberID == accountID {
            activeSession = nil
        }
    }

    /// Cancels in-flight model-backed requests at an authentication boundary
    /// while retaining the durable IDs for a same-account retry. The task
    /// cancellation is deliberately separate from store purging: logout and
    /// account switching must preserve cleanup work, while account deletion
    /// decides when to purge it explicitly.
    func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        pendingOperations.removeAll()
        activeSession = nil
    }

    /// Schedules at most one discard task for a session. Calling this from
    /// multiple disappearance callbacks is therefore harmless.
    func schedule(
        model: AttachmentPickerModel,
        accountID: MemberID,
        sessionGeneration: UInt64
    ) {
        guard accountID > 0,
              let activeSession,
              activeSession == AuthenticationSessionContext(
                memberID: accountID,
                generation: sessionGeneration
              ),
              let sessionID = model.attachmentSessionId
        else { return }
        let key = PendingKey(
            accountID: accountID,
            sessionGeneration: sessionGeneration,
            sessionID: sessionID
        )
        store.enqueue(accountID: accountID, sessionID: sessionID)
        let discard: @MainActor @Sendable () async -> Bool = { @MainActor [model] in
            await model.discard()
        }
        pendingOperations[key] = PendingOperation(
            accountID: accountID,
            sessionID: sessionID,
            discard: discard
        )
        guard tasks[key] == nil else { return }
        start(key: key)
    }

    /// Rehydrates pending IDs for this authenticated account and starts their
    /// cleanup through a fresh API client. IDs for every other account remain
    /// untouched and cannot be sent with the current account's credentials.
    func retryPending(accountID: MemberID, sessionGeneration: UInt64) {
        guard accountID > 0,
              activeSession == AuthenticationSessionContext(
                memberID: accountID,
                generation: sessionGeneration
              )
        else { return }
        for sessionID in store.pendingSessionIDs(accountID: accountID) {
            let key = PendingKey(
                accountID: accountID,
                sessionGeneration: sessionGeneration,
                sessionID: sessionID
            )
            guard pendingOperations[key] == nil else { continue }
            let persistedDiscard = self.persistedDiscard
            let discard: @MainActor @Sendable () async -> Bool = {
                await persistedDiscard(accountID, sessionID)
            }
            pendingOperations[key] = PendingOperation(
                accountID: accountID,
                sessionID: sessionID,
                discard: discard
            )
        }
        for key in Array(pendingOperations.keys)
            where key.accountID == accountID && tasks[key] == nil {
            start(key: key)
        }
    }

    private func start(key: PendingKey) {
        guard let operation = pendingOperations[key] else { return }
        let discard = operation.discard
        let store = self.store
        let retryDelays = self.retryDelays
        let sleep = self.sleep
        let isActive: @MainActor @Sendable () -> Bool = { [weak self] in
            guard let self else { return false }
            return self.activeSession == AuthenticationSessionContext(
                memberID: key.accountID,
                generation: key.sessionGeneration
            ) && self.tasks[key] != nil
        }

        tasks[key] = Task { @MainActor [weak self] in
            var discarded = false
            for attempt in 0...retryDelays.count {
                guard !Task.isCancelled, isActive() else { break }
                let succeeded = await discard()
                guard !Task.isCancelled, isActive() else { break }
                if succeeded {
                    discarded = true
                    break
                }

                guard attempt < retryDelays.count else { break }
                do {
                    try await sleep(retryDelays[attempt])
                } catch {
                    break
                }
            }

            if discarded {
                store.remove(accountID: key.accountID, sessionID: key.sessionID)
            }
            guard let self else { return }
            self.tasks[key] = nil
            if discarded {
                self.pendingOperations.removeValue(forKey: key)
            }
        }
    }
}

/// The single Todo creation presentation shared by the Todo board and Calendar quick-add.
struct TodoCreateModal: View {
    @ObservedObject var model: TodoViewModel
    let initialStatus: TodoStatus
    let friends: [FriendDTO]
    let accountID: MemberID?
    let sessionGeneration: UInt64?
    let availability: SessionAvailability?
    let refreshBoardAfterCreate: Bool
    let onCreated: () async -> Void
    let onDismiss: () -> Void

    @State private var dismissRequest = 0
    @State private var isFormBusy = false

    var body: some View {
        DPModalOverlay(
            onDismiss: onDismiss,
            canDismiss: !isFormBusy && !model.isSaving,
            onDismissRequest: { _ in dismissRequest += 1 }
        ) { availableSize, dismiss in
            TodoFormSheet(
                titleKey: "todo.form.createTitle",
                initialDraft: TodoDraft(status: initialStatus),
                friends: friends,
                model: model,
                targetTodoID: nil,
                existingAttachments: [],
                accountID: accountID,
                sessionGeneration: sessionGeneration,
                isSaving: model.isSaving,
                maximumHeight: availableSize.height,
                dismissAction: dismiss,
                savedDismissAction: dismiss,
                dismissRequest: dismissRequest,
                onBusyChange: { isFormBusy = $0 }
            ) { draft in
                let created = await model.create(
                    draft: draft,
                    accountID: accountID,
                    availability: availability,
                    sessionGeneration: sessionGeneration,
                    refreshBoard: refreshBoardAfterCreate
                )
                if created { await onCreated() }
                return created
            }
        }
    }
}

struct TodoView: View {
    @EnvironmentObject private var session: SessionStore
    let initialTodoID: TodoID?
    let onTodoChanged: () async -> Void
    let onInitialTodoOpened: () -> Void

    @StateObject private var model: TodoViewModel
    @State private var selectedTodo: TodoDTO?
    @State private var showingDetail = false
    @State private var showingCreate = false
    @State private var showingHelp = false
    @State private var detailCanDismiss = true
    @State private var detailDismissRequest = 0
    @State private var visibleStatus: TodoStatus?
    @State private var draggedTodoID: TodoID?
    @State private var pressedTodoID: TodoID?
    @State private var dragTargetStatus: TodoStatus?
    @State private var dragTargetTodoID: TodoID?
    @State private var dragInsertAfter = false
    @State private var dragLocation: CGPoint?
    @State private var dragPreviewSize: CGSize?
    @State private var dragGrabOffset: CGSize?
    @State private var pendingDropPlacement: TodoDragPlacement?
    @State private var lastAutoScrolledStatus: TodoStatus?
    @State private var dragAutoScrollTask: Task<Void, Never>?
    @State private var dragAutoScrollGeneration = 0
    @State private var cardDropTargets: [TodoCardDropTarget] = []
    @State private var columnDropTargets: [TodoColumnDropTarget] = []
    @State private var statusDropTargets: [TodoStatusDropTarget] = []

    init(
        initialTodoID: TodoID? = nil,
        repository: any TodoRepository = TodoAPIRepository(),
        onTodoChanged: @escaping () async -> Void = {},
        onInitialTodoOpened: @escaping () -> Void = {}
    ) {
        self.initialTodoID = initialTodoID
        self.onTodoChanged = onTodoChanged
        self.onInitialTodoOpened = onInitialTodoOpened
        _model = StateObject(wrappedValue: TodoViewModel(repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isShowingCachedData || model.pendingOperationCount > 0 {
                todoAvailabilityBanner
            }
            statusSelector
                .padding(.horizontal, TodoBoardLayout.boardPadding)
                .padding(.bottom, DPSpacing.compact)

            content
        }
        .background(DPColor.backgroundSecondary)
        .coordinateSpace(name: TodoDragCoordinateSpace.name)
        .onPreferenceChange(TodoCardDropTargetPreferenceKey.self) { cardDropTargets = $0 }
        .onPreferenceChange(TodoColumnDropTargetPreferenceKey.self) { columnDropTargets = $0 }
        .onPreferenceChange(TodoStatusDropTargetPreferenceKey.self) { statusDropTargets = $0 }
        .dpDragFeedback(dragID: draggedTodoID)
        .dpDragRetargetFeedback(target: retargetDropSlot)
        .overlay {
            if let draggedTodoID,
               let dragLocation,
               let dragPreviewSize,
               let dragGrabOffset,
               let todo = draggedTodo(withID: draggedTodoID) {
                TodoDragPreview(
                    todo: todo,
                    status: todo.status,
                    size: dragPreviewSize
                )
                    .position(
                        x: dragLocation.x - dragGrabOffset.width,
                        y: dragLocation.y - dragGrabOffset.height
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                DPHelpButton(label: todoLocalized("todo.help.open")) {
                    withoutPresentationAnimation { showingHelp = true }
                }
                .accessibilityIdentifier("todo.help")

                Button {
                    presentCreate()
                } label: {
                    Image(systemName: "plus")
                        .frame(minWidth: DPSize.minimumTouchTarget, minHeight: DPSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityRepresentation {
                    Button {
                        presentCreate()
                    } label: {
                        Color.clear
                            .frame(
                                width: DPSize.minimumTouchTarget + 2,
                                height: DPSize.minimumTouchTarget + 2
                            )
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(todoLocalized("todo.action.add"))
                    .accessibilityIdentifier("todo.add")
                }
            }
        }
        .task(id: initialTodoID) {
            if model.board == nil {
                await model.load(
                    accountID: authenticatedAccountID,
                    availability: session.availability,
                    sessionGeneration: authenticatedSessionGeneration
                )
            } else {
                await model.refresh(
                    accountID: authenticatedAccountID,
                    availability: session.availability,
                    sessionGeneration: authenticatedSessionGeneration
                )
            }
            visibleStatus = model.selectedStatus
            openInitialTodoIfPresent()
        }
        .onChange(of: visibleStatus) { _, status in
            if let status, status != model.selectedStatus {
                model.selectedStatus = status
            }
        }
        .onChange(of: session.availability) { _, availability in
            Task {
                if availability == .online || model.board == nil {
                    await model.refresh(
                        accountID: authenticatedAccountID,
                        availability: availability,
                        sessionGeneration: authenticatedSessionGeneration
                    )
                } else {
                    await model.load(
                        accountID: authenticatedAccountID,
                        availability: availability,
                        sessionGeneration: authenticatedSessionGeneration
                    )
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("offlineSyncDidComplete")
            )
        ) { notification in
            guard offlineSyncAccountID(from: notification) == authenticatedAccountID else { return }
            Task {
                await model.handleOfflineSyncCompleted(accountID: authenticatedAccountID)
            }
        }
        .onDisappear {
            model.cancelRecovery()
        }
        .fullScreenCover(isPresented: $showingCreate) {
            TodoCreateModal(
                model: model,
                initialStatus: model.selectedStatus,
                friends: model.friends,
                accountID: authenticatedAccountID,
                sessionGeneration: authenticatedSessionGeneration,
                availability: session.availability,
                refreshBoardAfterCreate: true,
                onCreated: onTodoChanged,
                onDismiss: { showingCreate = false }
            )
        }
        .fullScreenCover(isPresented: $showingHelp) {
            DPModalOverlay(onDismiss: { showingHelp = false }) { availableSize, dismiss in
                TodoHelpModal(maximumHeight: availableSize.height, dismiss: dismiss)
            }
        }
        .fullScreenCover(isPresented: $showingDetail) {
            if let selectedTodo {
                DPModalOverlay(
                    onDismiss: { showingDetail = false },
                    canDismiss: detailCanDismiss && !model.isSaving,
                    onDismissRequest: { _ in detailDismissRequest += 1 }
                ) { availableSize, dismiss in
                    TodoDetailModal(
                        model: model,
                        todo: selectedTodo,
                        maximumHeight: availableSize.height,
                        accountID: authenticatedAccountID,
                        sessionGeneration: authenticatedSessionGeneration,
                        onTodoChanged: onTodoChanged,
                        onDismissabilityChange: { detailCanDismiss = $0 },
                        dismissRequest: detailDismissRequest,
                        dismiss: dismiss
                    )
                }
            }
        }
        .todoErrorAlert(model)
    }

    private var authenticatedAccountID: MemberID? {
        guard case .authenticated(let member) = session.state else { return nil }
        return member.id
    }

    private var authenticatedSessionGeneration: UInt64? {
        session.authenticationSessionGenerationForCurrentAccount
    }

    private var todoAvailabilityBanner: some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: model.isShowingCachedData ? "wifi.slash" : "arrow.triangle.2.circlepath")
            VStack(alignment: .leading, spacing: 1) {
                if model.isShowingCachedData {
                    Text(todoLocalized("todo.offline.cached"))
                }
                if model.pendingOperationCount > 0 {
                    Text(
                        todoLocalized("todo.offline.pending")
                            .replacingOccurrences(
                                of: "%d",
                                with: String(model.pendingOperationCount)
                            )
                    )
                }
            }
            .font(.caption.weight(.semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, TodoBoardLayout.boardPadding)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("todo.offline.status")
    }

    private func offlineSyncAccountID(from notification: Notification) -> MemberID? {
        if let accountID = notification.object as? MemberID { return accountID }
        if let accountID = notification.object as? NSNumber { return accountID.int64Value }
        if let accountID = notification.userInfo?["accountID"] as? MemberID { return accountID }
        if let accountID = notification.userInfo?["accountID"] as? NSNumber { return accountID.int64Value }
        return nil
    }

    private func openInitialTodoIfPresent() {
        guard let initialTodoID else { return }
        if let todo = model.open(todoID: initialTodoID) {
            selectedTodo = todo
            withoutPresentationAnimation { showingDetail = true }
        }
        onInitialTodoOpened()
    }

    private func draggedTodo(withID id: TodoID) -> TodoDTO? {
        TodoStatus.boardStatuses
            .lazy
            .flatMap { model.todos(for: $0) }
            .first { $0.uuid == id }
    }

    private func handleDrop(
        todoID: TodoID,
        destinationStatus: TodoStatus,
        targetTodoID: TodoID? = nil,
        insertAfter: Bool = false,
        visualPlacement: TodoDragPlacement? = nil
    ) {
        clearInteractiveDrag()
        pendingDropPlacement = visualPlacement
        Task {
            let succeeded = await model.drop(
                todoID: todoID,
                into: destinationStatus,
                relativeTo: targetTodoID,
                insertAfter: insertAfter
            )
            pendingDropPlacement = nil
            if succeeded {
                await onTodoChanged()
            }
        }
    }

    private func updateInteractiveDrag(
        todo: TodoDTO,
        location: CGPoint,
        viewport: CGRect,
        scrollTo: @escaping (TodoStatus) -> Void
    ) {
        guard !model.isSaving else { return }

        let nextAutoScrollStatus = TodoDragAutoScrollPolicy.nextStatus(
            location: location,
            viewport: viewport,
            visibleStatus: visibleStatus ?? model.selectedStatus,
            lastAutoScrolledStatus: lastAutoScrolledStatus
        )
        if let status = nextAutoScrollStatus {
            lastAutoScrolledStatus = status
            // Keep the selector and scroll-position binding in lockstep before
            // the animated scroll has delivered its next preference frame.
            model.selectedStatus = status
            visibleStatus = status
            scrollTo(status)
        } else if !TodoDragAutoScrollPolicy.isInsideActivationEdge(
            location: location,
            viewport: viewport
        ) {
            cancelDragAutoScroll()
            lastAutoScrolledStatus = nil
        }

        var previewSize = dragPreviewSize
        var grabOffset = dragGrabOffset
        if draggedTodoID != todo.uuid {
            draggedTodoID = todo.uuid
            if let frame = cardDropTargets.last(where: { $0.todoID == todo.uuid })?.frame {
                previewSize = frame.size
                grabOffset = CGSize(
                    width: location.x - frame.midX,
                    height: location.y - frame.midY
                )
                dragPreviewSize = previewSize
                dragGrabOffset = grabOffset
            }
        }
        dragLocation = location
        if nextAutoScrollStatus != nil {
            startDragAutoScroll(
                todo: todo,
                viewport: viewport,
                scrollTo: scrollTo
            )
        }
        let movingFrame = previewSize.flatMap { size in
            grabOffset.map { offset in
                CGRect(
                    x: location.x - offset.width - (size.width / 2),
                    y: location.y - offset.height - (size.height / 2),
                    width: size.width,
                    height: size.height
                )
            }
        }
        let previousTarget = dragTargetStatus.map {
            TodoResolvedDropTarget(
                status: $0,
                todoID: dragTargetTodoID,
                insertAfter: dragInsertAfter
            )
        }
        let target = TodoDragTargetResolver.resolve(
            location: location,
            draggedTodoID: todo.uuid,
            // These preferences move with the ScrollView. Keeping a snapshot
            // from lift time would resolve against stale coordinates after an
            // automatic column scroll and prevent Y-axis reordering there.
            cards: cardDropTargets,
            columns: columnDropTargets,
            statuses: statusDropTargets,
            movingFrame: movingFrame,
            previousTarget: previousTarget
        )
        withAnimation(.snappy(duration: TodoBoardLayout.dragPushAnimationDuration, extraBounce: 0)) {
            dragTargetStatus = target?.status
            dragTargetTodoID = target?.todoID
            dragInsertAfter = target?.insertAfter ?? false
        }
    }

    private func startDragAutoScroll(
        todo: TodoDTO,
        viewport: CGRect,
        scrollTo: @escaping (TodoStatus) -> Void
    ) {
        guard dragAutoScrollTask == nil else { return }
        dragAutoScrollGeneration += 1
        let generation = dragAutoScrollGeneration

        // A long-press drag may not emit another gesture sample while the finger
        // stays at the edge. Keep advancing at the same cadence as the scroll
        // animation so a single hold can cross more than one column.
        dragAutoScrollTask = Task { @MainActor in
            while !Task.isCancelled,
                  draggedTodoID == todo.uuid,
                  dragAutoScrollGeneration == generation {
                try? await Task.sleep(for: TodoBoardLayout.dragAutoScrollInterval)
                guard !Task.isCancelled,
                      draggedTodoID == todo.uuid,
                      dragAutoScrollGeneration == generation,
                      let location = dragLocation else {
                    break
                }
                let canAdvance = TodoDragAutoScrollPolicy.nextStatus(
                    location: location,
                    viewport: viewport,
                    visibleStatus: visibleStatus ?? model.selectedStatus,
                    lastAutoScrolledStatus: nil
                ) != nil

                lastAutoScrolledStatus = nil
                // Re-run target resolution after every animation, including the
                // final boundary tick, so lifting immediately after a scroll
                // still commits the column now under the finger.
                updateInteractiveDrag(
                    todo: todo,
                    location: location,
                    viewport: viewport,
                    scrollTo: scrollTo
                )
                guard canAdvance else {
                    break
                }
            }

            if draggedTodoID == todo.uuid,
               dragAutoScrollGeneration == generation {
                dragAutoScrollTask = nil
            }
        }
    }

    private func finishInteractiveDrag(todo: TodoDTO) {
        let destinationStatus = dragTargetStatus
        let targetTodoID = dragTargetTodoID
        let insertAfter = dragInsertAfter

        guard let destinationStatus else {
            clearInteractiveDrag()
            return
        }
        // The same placement the drag was already rendering, so swapping the live
        // projection for the committed one on lift changes nothing on screen.
        let placement = TodoDragPlacement(
            todoID: todo.uuid,
            destinationStatus: destinationStatus,
            targetTodoID: targetTodoID,
            insertAfter: insertAfter
        )
        handleDrop(
            todoID: todo.uuid,
            destinationStatus: destinationStatus,
            targetTodoID: targetTodoID,
            insertAfter: insertAfter,
            visualPlacement: placement
        )
    }

    private func beginPress(on todo: TodoDTO) {
        pressedTodoID = todo.uuid
    }

    private func endPress(on todo: TodoDTO) {
        // A card's ending can arrive after the next card's press has begun — a
        // finger that slides straight from one card to another reports that way.
        // Only the card the ring is currently counting down for may clear it.
        guard pressedTodoID == todo.uuid else { return }
        pressedTodoID = nil
    }

    private func cancelDragAutoScroll() {
        dragAutoScrollGeneration += 1
        dragAutoScrollTask?.cancel()
        dragAutoScrollTask = nil
    }

    private func clearInteractiveDrag() {
        cancelDragAutoScroll()
        draggedTodoID = nil
        dragTargetStatus = nil
        dragTargetTodoID = nil
        dragInsertAfter = false
        dragLocation = nil
        dragPreviewSize = nil
        dragGrabOffset = nil
        lastAutoScrolledStatus = nil
    }

    private var statusSelector: some View {
        HStack(spacing: DPSpacing.small) {
            ForEach(TodoStatus.boardStatuses, id: \.rawValue) { status in
                Button {
                    selectStatus(status)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: status.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                        Text(todoLocalized(status.shortTitleKey))
                            .font(DPFont.bold(size: 12, relativeTo: .caption))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(verbatim: "\(model.count(for: status))")
                            .font(DPFont.bold(size: 11, relativeTo: .caption2))
                            .foregroundStyle(model.selectedStatus == status ? DPColor.textOnDark : DPColor.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(model.selectedStatus == status ? status.color : DPColor.backgroundTertiary)
                            )
                    }
                    .padding(.horizontal, 9)
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                    .foregroundStyle(status.color)
                    .background(
                        RoundedRectangle(cornerRadius: DPRadius.large)
                            .fill(DPColor.backgroundCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DPRadius.large)
                            .stroke(
                                dragTargetStatus == status
                                    ? DPColor.accent
                                    : (model.selectedStatus == status ? status.color : DPColor.borderPrimary),
                                lineWidth: dragTargetStatus == status || model.selectedStatus == status ? 2 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TodoStatusDropTargetPreferenceKey.self,
                            value: [TodoStatusDropTarget(
                                status: status,
                                frame: proxy.frame(in: .named(TodoDragCoordinateSpace.name))
                            )]
                        )
                    }
                }
                .accessibilityLabel(Text(todoLocalized(status.titleKey)))
                .accessibilityValue(Text("\(model.count(for: status))"))
                .accessibilityIdentifier("todo.status.\(status.rawValue)")
            }
        }
        .padding(.top, DPSpacing.small)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("todo.statusSelector")
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.board == nil {
            DPLoadingState(label: LocalizedStringKey(todoLocalized("todo.loading")))
        } else if model.board == nil {
            DPErrorState(
                title: LocalizedStringKey(todoLocalized("todo.error.load")),
                retryTitle: LocalizedStringKey(todoLocalized("common.retry")),
                retryAction: {
                    Task {
                        await model.load(
                            accountID: authenticatedAccountID,
                            availability: session.availability,
                            sessionGeneration: authenticatedSessionGeneration
                        )
                    }
                }
            )
        } else {
            GeometryReader { proxy in
                let columnWidth = TodoBoardLayout.mobileColumnWidth(in: proxy.size.width)
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: TodoBoardLayout.columnGap) {
                            ForEach(TodoStatus.boardStatuses, id: \.rawValue) { status in
                                TodoKanbanColumn(
                                    status: status,
                                    count: model.count(for: status),
                                    todos: displayedTodos(for: status),
                                    width: columnWidth,
                                    draggedTodoID: draggedTodoID,
                                    pressedTodoID: pressedTodoID,
                                    dragTargetStatus: dragTargetStatus,
                                    dragTargetTodoID: dragTargetTodoID,
                                    dragInsertAfter: dragInsertAfter,
                                    add: {
                                        selectStatus(status)
                                        withoutPresentationAnimation { showingCreate = true }
                                    },
                                    select: { selectStatus(status) },
                                    open: { todo in
                                        model.emitHaptic(.routine)
                                        selectedTodo = todo
                                        withoutPresentationAnimation { showingDetail = true }
                                    },
                                    move: { todo, offset in
                                        model.selectedStatus = status
                                        Task {
                                            if await model.moveWithinSelectedColumn(todo, offset: offset) {
                                                await onTodoChanged()
                                            }
                                        }
                                    },
                                    updateDrag: { todo, location in
                                        updateInteractiveDrag(
                                            todo: todo,
                                            location: location,
                                            viewport: proxy.frame(in: .named(TodoDragCoordinateSpace.name)),
                                            scrollTo: { status in
                                                withAnimation(.smooth(
                                                    duration: TodoBoardLayout.dragAutoScrollDuration,
                                                    extraBounce: 0
                                                )) {
                                                    scrollProxy.scrollTo(status, anchor: .center)
                                                }
                                            }
                                        )
                                    },
                                    finishDrag: finishInteractiveDrag,
                                    cancelDrag: clearInteractiveDrag,
                                    pressBegan: beginPress,
                                    pressEnded: endPress,
                                    drop: { todoID, destinationStatus, targetTodoID, insertAfter in
                                        handleDrop(
                                            todoID: todoID,
                                            destinationStatus: destinationStatus,
                                            targetTodoID: targetTodoID,
                                            insertAfter: insertAfter
                                        )
                                    }
                                )
                                .id(status)
                                .containerRelativeFrame(.vertical)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.bottom, DPSpacing.small)
                    }
                    .contentMargins(.horizontal, TodoBoardLayout.boardPadding, for: .scrollContent)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollPosition(id: $visibleStatus, anchor: .center)
                    .scrollDisabled(draggedTodoID != nil)
                    .refreshable {
                        await model.refresh(
                            accountID: authenticatedAccountID,
                            availability: session.availability,
                            sessionGeneration: authenticatedSessionGeneration
                        )
                    }
                    .task(id: model.selectedStatus.rawValue) {
                        let status = model.selectedStatus
                        await Task.yield()
                        guard draggedTodoID == nil else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            visibleStatus = status
                            scrollProxy.scrollTo(
                                status,
                                anchor: TodoBoardLayout.scrollAnchor(for: status)
                            )
                        }
                    }
                }
            }
        }
    }

    private func selectStatus(_ status: TodoStatus) {
        guard model.selectedStatus != status else { return }
        model.selectedStatus = status
        model.emitHaptic(.selection)
    }

    private func presentCreate() {
        model.emitHaptic(.routine)
        withoutPresentationAnimation { showingCreate = true }
    }

    /// The drop target resolved from the current gesture sample, expressed as the
    /// placement the drop would commit. Rendering it makes the neighbouring cards
    /// step aside live and turns the hidden dragged row into a moving placeholder.
    private var inlineDropPlacement: TodoDragPlacement? {
        guard let draggedTodoID, let dragTargetStatus else { return nil }
        return TodoDragPlacement(
            todoID: draggedTodoID,
            destinationStatus: dragTargetStatus,
            targetTodoID: dragTargetTodoID,
            insertAfter: dragInsertAfter
        )
    }

    /// The slot the drop would land in right now, which is what the retarget tick
    /// counts. It shares the drag state with `inlineDropPlacement` but drops the
    /// moving card from it: the finger feels where it is pointing, and the card it
    /// is carrying never changes mid-drag.
    private var retargetDropSlot: TodoDropSlot? {
        TodoDropSlot.resolved(
            draggedTodoID: draggedTodoID,
            targetStatus: dragTargetStatus,
            targetTodoID: dragTargetTodoID,
            insertAfter: dragInsertAfter
        )
    }

    private func displayedTodos(for status: TodoStatus) -> [TodoDTO] {
        let columns = Dictionary(
            uniqueKeysWithValues: TodoStatus.boardStatuses.map { ($0, model.todos(for: $0)) }
        )
        return TodoDragPresentation.columns(
            from: columns,
            interactivePlacement: inlineDropPlacement,
            pendingDropPlacement: pendingDropPlacement
        )[status] ?? []
    }
}

private struct TodoKanbanColumn: View {
    let status: TodoStatus
    let count: Int
    let todos: [TodoDTO]
    let width: CGFloat
    let draggedTodoID: TodoID?
    let pressedTodoID: TodoID?
    let dragTargetStatus: TodoStatus?
    let dragTargetTodoID: TodoID?
    let dragInsertAfter: Bool
    let add: () -> Void
    let select: () -> Void
    let open: (TodoDTO) -> Void
    let move: (TodoDTO, Int) -> Void
    let updateDrag: (TodoDTO, CGPoint) -> Void
    let finishDrag: (TodoDTO) -> Void
    let cancelDrag: () -> Void
    let pressBegan: (TodoDTO) -> Void
    let pressEnded: (TodoDTO) -> Void
    let drop: (TodoID, TodoStatus, TodoID?, Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DPSpacing.extraSmall) {
                Button(action: select) {
                    HStack(spacing: 6) {
                        Image(systemName: status.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                        Text(todoLocalized(status.shortTitleKey))
                            .font(DPFont.bold(size: 14, relativeTo: .subheadline))
                        Spacer(minLength: 4)
                        Text(verbatim: "\(count)")
                            .font(DPFont.bold(size: 12, relativeTo: .caption))
                            .frame(minWidth: 24)
                    }
                    .foregroundStyle(status.color)
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: add) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DPColor.textOnDark)
                        .frame(width: 24, height: 24)
                        .background(DPColor.accent, in: RoundedRectangle(cornerRadius: DPRadius.compact))
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(todoLocalized("todo.action.add"))
            }
            .padding(.leading, DPSpacing.small)
            .background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .padding(.horizontal, DPSpacing.compact)
            .padding(.top, DPSpacing.compact)
            .padding(.bottom, DPSpacing.compact)

            ScrollView(.vertical) {
                LazyVStack(spacing: DPSpacing.small) {
                    if todos.isEmpty {
                        Button(action: add) {
                            VStack(spacing: DPSpacing.small) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                Text(todoLocalized("todo.action.add"))
                                    .font(DPTypography.caption)
                            }
                            .foregroundStyle(DPColor.accent)
                            .frame(maxWidth: .infinity, minHeight: 112)
                            .background(DPColor.backgroundCard.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
                            .overlay(
                                RoundedRectangle(cornerRadius: DPRadius.large)
                                    .stroke(DPColor.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        ForEach(Array(todos.enumerated()), id: \.element.id) { index, todo in
                            TodoCard(
                                todo: todo,
                                status: status,
                                isDragging: draggedTodoID == todo.uuid,
                                isPressing: pressedTodoID == todo.uuid,
                                canMoveUp: index > 0,
                                canMoveDown: index < todos.count - 1,
                                open: { open(todo) },
                                moveUp: { move(todo, -1) },
                                moveDown: { move(todo, 1) },
                                moveToStatus: { destination in
                                    drop(todo.uuid, destination, nil, false)
                                },
                                dropEdge: dragTargetStatus == status && dragTargetTodoID == todo.uuid
                                    ? (dragInsertAfter ? .after : .before)
                                    : nil,
                                updateDrag: { location in updateDrag(todo, location) },
                                finishDrag: { finishDrag(todo) },
                                cancelDrag: cancelDrag,
                                pressBegan: { pressBegan(todo) },
                                pressEnded: { pressEnded(todo) }
                            )
                            .dpDragSourceSlot(
                                isLifted: draggedTodoID == todo.uuid,
                                tint: status.color,
                                cornerRadius: TodoBoardLayout.cardRadius
                            )
                        }
                    }

                    TodoColumnDropZone(
                        isTargeted: draggedTodoID != nil
                            && dragTargetStatus == status
                            && dragTargetTodoID == nil
                    )
                }
                .animation(
                    .snappy(duration: TodoBoardLayout.dragPushAnimationDuration, extraBounce: 0),
                    value: todos.map(\.uuid)
                )
                .padding(.horizontal, DPSpacing.compact)
                .padding(.bottom, DPSpacing.compact)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(draggedTodoID != nil)
        }
        .frame(width: width)
        .background {
            ZStack {
                DPColor.backgroundTertiary
                status.color.opacity(status == .todo ? 0.12 : 0.15)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TodoColumnDropTargetPreferenceKey.self,
                    value: [TodoColumnDropTarget(
                        status: status,
                        frame: proxy.frame(in: .named(TodoDragCoordinateSpace.name))
                    )]
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TodoBoardLayout.columnRadius))
        .overlay(
            RoundedRectangle(cornerRadius: TodoBoardLayout.columnRadius)
                .stroke(
                    dragTargetStatus == status ? status.color : .clear,
                    style: StrokeStyle(lineWidth: 2, dash: [7, 5])
                )
                .allowsHitTesting(false)
        )
        .accessibilityIdentifier("todo.column.\(status.rawValue)")
    }
}

private struct TodoCard: View {
    @State private var suppressTapAfterLongPress = false

    let todo: TodoDTO
    let status: TodoStatus
    let isDragging: Bool
    let isPressing: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let open: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    let moveToStatus: (TodoStatus) -> Void
    let dropEdge: TodoDropEdge?
    let updateDrag: (CGPoint) -> Void
    let finishDrag: () -> Void
    let cancelDrag: () -> Void
    let pressBegan: () -> Void
    let pressEnded: () -> Void
    var measuresDropTarget = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: handleTap) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: DPSpacing.small) {
                        Text(todo.title)
                            .font(DPFont.bold(size: 14, relativeTo: .subheadline))
                            .foregroundStyle(DPColor.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(1)
                        Spacer(minLength: 0)
                        if todo.hasAttachments {
                            Image(systemName: "paperclip")
                                .font(.system(size: 15))
                                .foregroundStyle(DPColor.textMuted)
                                .accessibilityLabel(Text(todoLocalized("todo.label.attachments")))
                        }
                    }

                    if !todo.content.isEmpty {
                        Text(todo.content)
                            .font(DPFont.light(size: 12, relativeTo: .caption))
                            .foregroundStyle(DPColor.textSecondary)
                            .lineLimit(2)
                            .lineSpacing(1)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 6)
                    }

                    let tags = TodoMemberTagAdapter.items(of: todo)
                    if !tags.isEmpty {
                        DPMemberTagChips(items: tags, size: .compact, limit: 2)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, DPSpacing.small)
                    }

                    if let dueDate = todo.dueDate {
                        Label(dueDate.rawValue, systemImage: "calendar.badge.checkmark")
                            .font(DPFont.light(size: 12, relativeTo: .caption))
                            .foregroundStyle(todo.isOverdue ? DPColor.danger : DPColor.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                todo.isOverdue ? DPColor.dangerSoft : DPColor.backgroundTertiary,
                                in: Capsule()
                            )
                            .padding(.top, DPSpacing.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: TodoBoardLayout.cardRadius))
        .contentShape(RoundedRectangle(cornerRadius: TodoBoardLayout.cardRadius))
        .modifier(TodoCardGestureModifier(
            suppressTapAfterLongPress: $suppressTapAfterLongPress,
            handleTap: handleTap,
            updateDrag: updateDrag,
            finishDrag: finishDrag,
            cancelDrag: cancelDrag,
            onPressBegan: pressBegan,
            onPressEnded: pressEnded
        ))
        .dpPressProgress(isPressing: isPressing, isDragging: isDragging, tint: status.color)
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: TodoBoardLayout.cardRadius)
                    .stroke(dropEdge == nil ? DPColor.borderPrimary : status.color, lineWidth: dropEdge == nil ? 1 : 2)

                if let dropEdge {
                    VStack(spacing: 0) {
                        if dropEdge == .after { Spacer(minLength: 0) }
                        Capsule()
                            .fill(status.color)
                            .frame(height: 4)
                            .padding(.horizontal, 10)
                            .offset(y: dropEdge == .before ? -8 : 8)
                        if dropEdge == .before { Spacer(minLength: 0) }
                    }
                }
            }
            .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .background {
            if measuresDropTarget {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: TodoCardDropTargetPreferenceKey.self,
                            value: [TodoCardDropTarget(
                                todoID: todo.uuid,
                                status: status,
                                frame: proxy.frame(in: .named(TodoDragCoordinateSpace.name))
                            )]
                        )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text(todoLocalized("todo.action.moveUp"))) {
            if canMoveUp { moveUp() }
        }
        .accessibilityAction(named: Text(todoLocalized("todo.action.moveDown"))) {
            if canMoveDown { moveDown() }
        }
        .accessibilityActions {
            ForEach(TodoStatus.boardStatuses.filter { $0 != status }, id: \.rawValue) { destination in
                Button(todoLocalized(destination.titleKey)) {
                    moveToStatus(destination)
                }
            }
        }
        .accessibilityIdentifier("todo.card.\(todo.id)")
    }

    private func handleTap() {
        if suppressTapAfterLongPress {
            suppressTapAfterLongPress = false
            return
        }
        open()
    }
}

private struct TodoCardGestureModifier: ViewModifier {
    @Binding var suppressTapAfterLongPress: Bool
    let handleTap: () -> Void
    let updateDrag: (CGPoint) -> Void
    let finishDrag: () -> Void
    let cancelDrag: () -> Void
    /// Touch down and its ending, which is what the press progress ring counts
    /// down. Reported by the reorder gesture itself so no second gesture has to be
    /// layered on the card to notice the finger.
    let onPressBegan: () -> Void
    let onPressEnded: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .gesture(modernLongPressGesture)
                .simultaneousGesture(
                    TapGesture().onEnded(handleTap)
                )
        } else {
            content.highPriorityGesture(legacyLongPressGesture)
        }
    }

    @available(iOS 18.0, *)
    private var modernLongPressGesture: DPLongPressGestureRecognizer {
        DPLongPressGestureRecognizer(
            minimumDuration: TodoBoardLayout.dragLongPressDuration,
            maximumMovement: TodoBoardLayout.dragLongPressMaximumDistance,
            coordinateSpaceName: TodoDragCoordinateSpace.name,
            onPressBegan: onPressBegan,
            onPressEnded: onPressEnded,
            onBegan: { location in
                suppressTapAfterLongPress = true
                updateDrag(location)
            },
            onChanged: updateDrag,
            onEnded: {
                finishDrag()
                releaseTapSuppression()
            },
            onCancelled: {
                cancelDrag()
                releaseTapSuppression()
            }
        )
    }

    private var legacyLongPressGesture: some Gesture {
        LongPressGesture(
            minimumDuration: TodoBoardLayout.dragLongPressDuration,
            maximumDistance: TodoBoardLayout.dragLongPressMaximumDistance
        )
        .sequenced(before: DragGesture(
            minimumDistance: 0,
            coordinateSpace: .named(TodoDragCoordinateSpace.name)
        ))
        .onChanged { phase in
            if case .first(true) = phase {
                onPressBegan()
                return
            }
            guard case let .second(didLongPress, dragValue) = phase,
                  TodoCardDragActivation.shouldReorder(
                      didLongPress: didLongPress,
                      hasDragValue: dragValue != nil
                  ),
                  let dragValue else { return }
            updateDrag(dragValue.location)
        }
        .onEnded { phase in
            onPressEnded()
            guard case let .second(didLongPress, dragValue) = phase,
                  TodoCardDragActivation.shouldReorder(
                      didLongPress: didLongPress,
                      hasDragValue: dragValue != nil
                  ) else { return }
            finishDrag()
        }
    }

    private func releaseTapSuppression() {
        DispatchQueue.main.async {
            suppressTapAfterLongPress = false
        }
    }
}

enum TodoCardDragActivation {
    static func shouldReorder(didLongPress: Bool, hasDragValue: Bool) -> Bool {
        didLongPress && hasDragValue
    }
}

private enum TodoDropEdge: Equatable {
    case before
    case after
}

private struct TodoColumnDropZone: View {
    let isTargeted: Bool

    var body: some View {
        Label(todoLocalized("todo.drag.dropHere"), systemImage: "arrow.down.to.line")
            .font(DPTypography.caption)
            .foregroundStyle(isTargeted ? DPColor.accent : DPColor.textMuted)
            .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
            .opacity(isTargeted ? 1 : 0)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }
}

private struct TodoDragPreview: View {
    let todo: TodoDTO
    let status: TodoStatus
    let size: CGSize

    var body: some View {
        TodoCard(
            todo: todo,
            status: status,
            // This copy is the held card itself, so it is past the countdown the
            // ring shows: it is already dragging, and never pressing.
            isDragging: true,
            isPressing: false,
            canMoveUp: false,
            canMoveDown: false,
            open: {},
            moveUp: {},
            moveDown: {},
            moveToStatus: { _ in },
            dropEdge: nil,
            updateDrag: { _ in },
            finishDrag: {},
            cancelDrag: {},
            pressBegan: {},
            pressEnded: {},
            measuresDropTarget: false
        )
        .frame(width: size.width, height: size.height)
        .dpDragLift(tint: status.color, cornerRadius: TodoBoardLayout.cardRadius)
    }
}

struct TodoDragPlacement: Equatable {
    let todoID: TodoID
    let destinationStatus: TodoStatus
    let targetTodoID: TodoID?
    let insertAfter: Bool
}

enum TodoDragAutoScrollPolicy {
    static let activationEdgeWidth: CGFloat = 56

    static func isInsideActivationEdge(location: CGPoint, viewport: CGRect) -> Bool {
        guard viewport.minX...viewport.maxX ~= location.x else { return false }
        return location.x <= viewport.minX + activationEdgeWidth
            || location.x >= viewport.maxX - activationEdgeWidth
    }

    static func nextStatus(
        location: CGPoint,
        viewport: CGRect,
        visibleStatus: TodoStatus?,
        lastAutoScrolledStatus: TodoStatus?,
        statuses: [TodoStatus] = TodoStatus.boardStatuses
    ) -> TodoStatus? {
        guard lastAutoScrolledStatus == nil,
              isInsideActivationEdge(location: location, viewport: viewport),
              let visibleStatus,
              let visibleIndex = statuses.firstIndex(of: visibleStatus) else {
            return nil
        }

        let direction = location.x <= viewport.minX + activationEdgeWidth ? -1 : 1
        let destinationIndex = visibleIndex + direction
        guard statuses.indices.contains(destinationIndex) else { return nil }
        return statuses[destinationIndex]
    }
}

/// Where the card under the finger would land, as the drag haptic sees it.
nonisolated struct TodoDropSlot: Equatable, Sendable {
    let status: TodoStatus
    let targetTodoID: TodoID?
    let insertAfter: Bool

    /// `nil` whenever no drop is on offer — nothing held, or the finger outside
    /// every column — which is what leaves the edges of a drag to the lift and
    /// drop haptics and keeps the tick for genuine crossings between slots.
    static func resolved(
        draggedTodoID: TodoID?,
        targetStatus: TodoStatus?,
        targetTodoID: TodoID?,
        insertAfter: Bool
    ) -> TodoDropSlot? {
        guard draggedTodoID != nil, let targetStatus else { return nil }
        return TodoDropSlot(
            status: targetStatus,
            targetTodoID: targetTodoID,
            insertAfter: insertAfter
        )
    }
}

enum TodoDragPresentation {
    /// The board follows the finger: while a card is held the live interactive
    /// placement drives the layout, and the committed placement takes over for
    /// the frames between the lift and the model update. Both project the same
    /// board at the hand-off, so the card never jumps on drop.
    static func columns(
        from columns: [TodoStatus: [TodoDTO]],
        interactivePlacement: TodoDragPlacement? = nil,
        pendingDropPlacement: TodoDragPlacement?
    ) -> [TodoStatus: [TodoDTO]] {
        TodoDragProjection.columns(
            projecting: interactivePlacement ?? pendingDropPlacement,
            from: columns
        )
    }
}

enum TodoDragProjection {
    /// Mirrors `TodoViewModel.drop` so the projected board is exactly the board
    /// the drop will commit. The moving card is looked up in whichever column
    /// currently holds it, which is what lets the same projection drive both a
    /// same-column reorder and a cross-column preview.
    static func columns(
        projecting placement: TodoDragPlacement?,
        from columns: [TodoStatus: [TodoDTO]]
    ) -> [TodoStatus: [TodoDTO]] {
        guard let placement, placement.targetTodoID != placement.todoID else { return columns }
        guard let sourceStatus = TodoStatus.boardStatuses.first(where: { status in
            columns[status]?.contains { $0.uuid == placement.todoID } == true
        }),
            let movingTodo = columns[sourceStatus]?.first(where: { $0.uuid == placement.todoID }),
            columns[placement.destinationStatus] != nil else {
            return columns
        }

        var result = columns
        result[sourceStatus]?.removeAll { $0.uuid == placement.todoID }
        var destination = result[placement.destinationStatus] ?? []
        let insertionIndex: Int
        if let targetTodoID = placement.targetTodoID,
           let targetIndex = destination.firstIndex(where: { $0.uuid == targetTodoID }) {
            insertionIndex = targetIndex + (placement.insertAfter ? 1 : 0)
        } else {
            insertionIndex = destination.endIndex
        }
        destination.insert(movingTodo, at: min(max(0, insertionIndex), destination.endIndex))
        result[placement.destinationStatus] = destination
        return result
    }
}

private enum TodoDragCoordinateSpace {
    static let name = "todo-board-drag"
}

struct TodoCardDropTarget: Equatable {
    let todoID: TodoID
    let status: TodoStatus
    let frame: CGRect
}

struct TodoColumnDropTarget: Equatable {
    let status: TodoStatus
    let frame: CGRect
}

struct TodoStatusDropTarget: Equatable {
    let status: TodoStatus
    let frame: CGRect
}

private struct TodoCardDropTargetPreferenceKey: PreferenceKey {
    static let defaultValue: [TodoCardDropTarget] = []
    static func reduce(value: inout [TodoCardDropTarget], nextValue: () -> [TodoCardDropTarget]) {
        value.append(contentsOf: nextValue())
    }
}

private struct TodoColumnDropTargetPreferenceKey: PreferenceKey {
    static let defaultValue: [TodoColumnDropTarget] = []
    static func reduce(value: inout [TodoColumnDropTarget], nextValue: () -> [TodoColumnDropTarget]) {
        value.append(contentsOf: nextValue())
    }
}

private struct TodoStatusDropTargetPreferenceKey: PreferenceKey {
    static let defaultValue: [TodoStatusDropTarget] = []
    static func reduce(value: inout [TodoStatusDropTarget], nextValue: () -> [TodoStatusDropTarget]) {
        value.append(contentsOf: nextValue())
    }
}

struct TodoResolvedDropTarget: Equatable {
    let status: TodoStatus
    let todoID: TodoID?
    let insertAfter: Bool
}

enum TodoDragTargetResolver {
    static func resolve(
        location: CGPoint,
        draggedTodoID: TodoID,
        cards: [TodoCardDropTarget],
        columns: [TodoColumnDropTarget],
        statuses: [TodoStatusDropTarget],
        movingFrame: CGRect? = nil,
        previousTarget: TodoResolvedDropTarget? = nil
    ) -> TodoResolvedDropTarget? {
        if let status = statuses.last(where: { $0.frame.contains(location) })?.status {
            return TodoResolvedDropTarget(status: status, todoID: nil, insertAfter: false)
        }

        if let source = cards.last(where: { $0.todoID == draggedTodoID }),
           let movingFrame,
           source.frame.minX...source.frame.maxX ~= movingFrame.midX,
           let edgeTarget = resolveVerticalEdgeCollision(
               source: source,
               movingFrame: movingFrame,
               cards: cards,
               previousTarget: previousTarget
           ) {
            return edgeTarget
        }

        if let card = cards.last(where: {
            $0.todoID != draggedTodoID && $0.frame.contains(location)
        }) {
            return TodoResolvedDropTarget(
                status: card.status,
                todoID: card.todoID,
                insertAfter: location.y >= card.frame.midY
            )
        }

        // The first zero-distance sample after the long press should not
        // accidentally send the card to the end of its own column.
        if cards.contains(where: { $0.todoID == draggedTodoID && $0.frame.contains(location) }) {
            return nil
        }

        guard let column = columns.last(where: { $0.frame.contains(location) }) else {
            return nil
        }

        let candidates = cards
            .filter { $0.status == column.status && $0.todoID != draggedTodoID }
            .sorted { $0.frame.minY < $1.frame.minY }

        guard let last = candidates.last else {
            return TodoResolvedDropTarget(status: column.status, todoID: nil, insertAfter: false)
        }
        guard location.y <= last.frame.maxY else {
            return TodoResolvedDropTarget(status: column.status, todoID: nil, insertAfter: false)
        }

        let nearest = candidates.min {
            abs($0.frame.midY - location.y) < abs($1.frame.midY - location.y)
        } ?? last
        return TodoResolvedDropTarget(
            status: column.status,
            todoID: nearest.todoID,
            insertAfter: location.y >= nearest.frame.midY
        )
    }

    private static func resolveVerticalEdgeCollision(
        source: TodoCardDropTarget,
        movingFrame: CGRect,
        cards: [TodoCardDropTarget],
        previousTarget: TodoResolvedDropTarget?
    ) -> TodoResolvedDropTarget? {
        let candidates = cards
            .filter {
                $0.status == source.status
                    && $0.todoID != source.todoID
                    && movingFrame.maxX > $0.frame.minX
                    && movingFrame.minX < $0.frame.maxX
            }
            .sorted { $0.frame.minY < $1.frame.minY }
        let displacement = movingFrame.midY - source.frame.midY

        if displacement > 0 {
            let crossed = candidates.filter { candidate in
                guard candidate.frame.midY > source.frame.midY else { return false }
                let threshold = collisionThreshold(
                    candidate: candidate,
                    insertAfter: true,
                    previousTarget: previousTarget
                )
                return movingFrame.maxY >= candidate.frame.minY + threshold
            }
            guard let target = crossed.last else { return nil }
            return TodoResolvedDropTarget(status: source.status, todoID: target.todoID, insertAfter: true)
        }

        if displacement < 0 {
            let crossed = candidates.filter { candidate in
                guard candidate.frame.midY < source.frame.midY else { return false }
                let threshold = collisionThreshold(
                    candidate: candidate,
                    insertAfter: false,
                    previousTarget: previousTarget
                )
                return movingFrame.minY <= candidate.frame.maxY - threshold
            }
            guard let target = crossed.first else { return nil }
            return TodoResolvedDropTarget(status: source.status, todoID: target.todoID, insertAfter: false)
        }

        return nil
    }

    private static func collisionThreshold(
        candidate: TodoCardDropTarget,
        insertAfter: Bool,
        previousTarget: TodoResolvedDropTarget?
    ) -> CGFloat {
        let isMaintainingCurrentTarget = previousTarget?.status == candidate.status
            && previousTarget?.todoID == candidate.todoID
            && previousTarget?.insertAfter == insertAfter
        return isMaintainingCurrentTarget
            ? -TodoBoardLayout.dragCollisionHysteresis
            : TodoBoardLayout.dragCollisionHysteresis
    }
}


/// The people a to-do names.
///
/// Someone else's to-do names whoever tagged you into it; your own names the friends
/// you tagged. Either way the tag carries the member behind it so it can show a face.
nonisolated enum TodoMemberTagAdapter {
    static func items(of todo: TodoDTO) -> [DPMemberTagItem] {
        guard todo.isTagged else {
            return todo.tags.map { DPMemberTagItem($0) }
        }
        // A to-do can remember its owner by name alone, so that tag keeps the name and
        // goes without a face rather than disappearing.
        guard let taggedByMember = todo.taggedByMember else {
            return [DPMemberTagItem(memberID: nil, name: todo.owner)]
        }
        return [DPMemberTagItem(taggedByMember)]
    }
}


nonisolated enum TodoFriendTagAdapter {
    static func item(_ friend: FriendDTO) -> DPFriendTagItem {
        DPFriendTagItem(
            id: friend.id,
            name: friend.name,
            team: friend.team,
            hasProfilePhoto: friend.hasProfilePhoto,
            profilePhotoVersion: friend.profilePhotoVersion,
            isFamily: friend.isFamily,
            pinOrder: friend.pinOrder
        )
    }

    static func item(_ member: MemberPreviewDTO) -> DPFriendTagItem? {
        guard let id = member.id else { return nil }
        return DPFriendTagItem(
            id: id,
            name: member.name,
            team: member.team,
            hasProfilePhoto: member.hasProfilePhoto,
            profilePhotoVersion: member.profilePhotoVersion
        )
    }
}


struct TodoFormSheet: View {
    let titleKey: String
    let friends: [FriendDTO]
    let preservedTags: [MemberPreviewDTO]
    let accountID: MemberID?
    let sessionGeneration: UInt64?
    let isSaving: Bool
    let maximumHeight: CGFloat?
    let dismissAction: (() -> Void)?
    let savedDismissAction: (() -> Void)?
    let dismissRequest: Int
    let onBusyChange: (Bool) -> Void
    let save: (TodoDraft) async -> Bool
    let showsStatusSelection: Bool

    @ObservedObject var model: TodoViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TodoDraft
    /// The dismissal baseline is pinned to the same snapshot that seeded `draft` and
    /// `attachmentModel`. Presenters rebuild `initialDraft` on every render, so reading it
    /// directly would let an unrelated re-render redefine "unchanged" and mark an untouched
    /// form dirty.
    @State private var baselineDraft: TodoDraft
    @State private var baselineAttachmentIDs: [AttachmentID]
    @State private var didSave = false
    @State private var showsDiscardConfirmation = false
    @State private var isDiscarding = false
    @State private var dismissFormAfterDiscard = false
    @State private var isSubmitting = false
    @StateObject private var attachmentModel: AttachmentPickerModel
    /// Keep the authentication context from the presentation that created the
    /// attachment session. SwiftUI may render this form again after the
    /// session changes, but a late disappearance must never reschedule the old
    /// session with the new credentials.
    @State private var boundAccountID: MemberID?
    @State private var boundSessionGeneration: UInt64?
    @FocusState private var focusedField: TodoFormField?
    @State private var isTagSearchFocused = false

    init(
        titleKey: String,
        initialDraft: TodoDraft,
        friends: [FriendDTO],
        model: TodoViewModel,
        targetTodoID: String?,
        existingAttachments: [AttachmentDTO],
        preservedTags: [MemberPreviewDTO] = [],
        accountID: MemberID? = nil,
        sessionGeneration: UInt64? = nil,
        isSaving: Bool,
        maximumHeight: CGFloat? = nil,
        dismissAction: (() -> Void)? = nil,
        savedDismissAction: (() -> Void)? = nil,
        dismissRequest: Int = 0,
        onBusyChange: @escaping (Bool) -> Void = { _ in },
        save: @escaping (TodoDraft) async -> Bool
    ) {
        self.titleKey = titleKey
        self.friends = friends
        self.preservedTags = preservedTags
        self.accountID = accountID
        self.sessionGeneration = sessionGeneration
        self.model = model
        self.isSaving = isSaving
        self.maximumHeight = maximumHeight
        self.dismissAction = dismissAction
        self.savedDismissAction = savedDismissAction
        self.dismissRequest = dismissRequest
        self.onBusyChange = onBusyChange
        self.save = save
        self.showsStatusSelection = TodoFormStatusSelectionPolicy.isVisible(
            targetTodoID: targetTodoID
        )
        _draft = State(initialValue: initialDraft)
        _baselineDraft = State(initialValue: initialDraft)
        _baselineAttachmentIDs = State(initialValue: existingAttachments.map(\.id))
        _boundAccountID = State(initialValue: accountID)
        _boundSessionGeneration = State(initialValue: sessionGeneration)
        _attachmentModel = StateObject(
            wrappedValue: AttachmentPickerModel(
                contextType: .todo,
                targetContextId: targetTodoID,
                existingAttachments: existingAttachments
            )
        )
    }

    /// `DPModalOverlay` always measures the height available to the panel; the fallback
    /// keeps the panel bounded when a presenter provides no measurement.
    private var maximumPanelHeight: CGFloat {
        min(maximumHeight.map { $0 * TodoModalLayout.maximumPanelHeightRatio } ?? .infinity, 786)
    }

    /// The tag search field belongs to `DPFriendTagSelector`, so it never appears in
    /// `focusedField`; fall back to it only when no field of this sheet holds focus.
    private var scrollTarget: TodoFormField? {
        focusedField ?? (isTagSearchFocused ? .tags : nil)
    }

    var body: some View {
        DPModalPanel(
            maximumPanelHeight: maximumPanelHeight,
            scrollTarget: scrollTarget
        ) {
            formHeader
        } content: {
            formContent
        } footer: {
            formFooter
        }
        .interactiveDismissDisabled(isOperationallyBusy || isDirty)
        .onChange(of: isBusy) { _, value in onBusyChange(value) }
        .onChange(of: dismissRequest) { _, _ in requestDismissal() }
        .onAppear { onBusyChange(isBusy) }
        .onDisappear {
            guard !showsDiscardConfirmation else { return }
            onBusyChange(false)
            guard !didSave else { return }
            model.scheduleAttachmentDiscard(
                for: attachmentModel,
                accountID: boundAccountID,
                sessionGeneration: boundSessionGeneration
            )
        }
        .fullScreenCover(isPresented: $showsDiscardConfirmation) {
            DPModalOverlay(
                maximumContentWidth: DPConfirmationPanel.maximumWidth,
                onDismiss: { finishDiscardConfirmationDismissal() },
                canDismiss: TodoConfirmationPolicy.canDismiss(
                    isConfirming: isDiscarding,
                    isSaving: isDiscardConfirmationSaving
                ),
                // The destructive confirmation button already acknowledges its
                // press; avoid a second haptic as the panel closes.
                dismissHaptic: nil
            ) { availableSize, confirmationDismiss in
                DPConfirmationPanel(
                    title: todoLocalized("todo.confirm.discardTitle"),
                    message: todoLocalized("todo.confirm.discardMessage"),
                    confirmTitle: todoLocalized("todo.confirm.discardAction"),
                    cancelTitle: todoLocalized("common.cancel"),
                    isDestructive: true,
                    isWorking: isDiscarding || isDiscardConfirmationSaving,
                    maximumHeight: availableSize.height,
                    cancel: confirmationDismiss,
                    confirm: { confirmDiscard(dismissConfirmation: confirmationDismiss) }
                )
            }
        }
        .todoErrorAlert(model)
    }

    private var formHeader: some View {
        HStack(spacing: DPSpacing.small) {
            Text(todoLocalized(titleKey))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Spacer()
            Button {
                requestDismissal()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .disabled(isOperationallyBusy)
            .accessibilityLabel(todoLocalized("common.cancel"))
            .accessibilityIdentifier("todo.form.cancel")
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.small)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.large) {
            if showsStatusSelection {
                TodoFormSection(title: todoLocalized("todo.field.status")) {
                    HStack(spacing: DPSpacing.small) {
                        ForEach(TodoStatus.boardStatuses, id: \.rawValue) { status in
                            Button {
                                guard draft.status != status else { return }
                                draft.status = status
                                model.emitHaptic(.selection)
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: status.systemImage)
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(todoLocalized(status.shortTitleKey))
                                        .font(DPTypography.caption)
                                        .lineLimit(1)
                                }
                                .foregroundStyle(status.color)
                                .frame(maxWidth: .infinity, minHeight: 62)
                                .background(status.softColor)
                                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DPRadius.standard)
                                        .stroke(draft.status == status ? status.color : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(draft.status == status ? .isSelected : [])
                            .accessibilityIdentifier("todo.form.status.\(status.rawValue.lowercased())")
                        }
                    }
                }
            }

            TodoFormSection(title: todoLocalized("todo.field.title")) {
                TextField("", text: $draft.title, prompt: Text(todoLocalized("todo.field.title")))
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedField, equals: .title)
                    .accessibilityIdentifier("todo.form.title")
                    .dpInputChrome(
                        isFocused: focusedField == .title,
                        isInvalid: draft.title.count > 50
                    )
                Text(verbatim: "\(draft.title.count)/50")
                    .font(DPTypography.caption)
                    .foregroundStyle(draft.title.count > 50 ? DPColor.danger : DPColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .id(TodoFormField.title)

            TodoFormSection(title: todoLocalized("todo.field.content")) {
                TextEditor(text: $draft.content)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .content)
                    .frame(minHeight: 132)
                    .dpInputChrome(isFocused: focusedField == .content)
                    .overlay(alignment: .topLeading) {
                        if draft.content.isEmpty {
                            Text(todoLocalized("todo.field.content"))
                                .font(DPTypography.body)
                                .foregroundStyle(DPColor.textMuted)
                                .padding(.leading, DPChrome.inputHorizontalPadding + 4)
                                .padding(.top, DPChrome.inputVerticalPadding + 7)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .id(TodoFormField.content)

            TodoFormSection(title: todoLocalized("todo.field.dueDate")) {
                Toggle(isOn: $draft.hasDueDate) {
                    Label(todoLocalized("todo.field.setDueDate"), systemImage: "calendar")
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                }
                .tint(DPColor.accent)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .onChange(of: draft.hasDueDate) { _, _ in
                    model.emitHaptic(.selection)
                }
                if draft.hasDueDate {
                    DatePicker(
                        todoLocalized("todo.field.dueDate"),
                        selection: $draft.dueDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .font(DPTypography.body)
                    .dpInputChrome()
                }
            }

            if !friends.isEmpty || !preservedTags.isEmpty {
                TodoFormSection(title: todoLocalized("todo.field.tags")) {
                    DPFriendTagSelector(
                        items: friends.map(TodoFriendTagAdapter.item),
                        preservedItems: preservedTags.compactMap(TodoFriendTagAdapter.item),
                        selection: $draft.taggedFriendIDs,
                        disabled: isBusy,
                        isSearchFocused: $isTagSearchFocused
                    )
                }
                .id(TodoFormField.tags)
            }

            TodoFormSection(title: todoLocalized("todo.label.attachments")) {
                AttachmentPicker(model: attachmentModel)
                    .padding(DPSpacing.compact)
                    .background(DPColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            }
        }
        .padding(DPSpacing.medium)
    }

    private var formFooter: some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                requestDismissal()
            } label: {
                Text(todoLocalized("common.close"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())
            .disabled(isOperationallyBusy)

            Button {
                submit()
            } label: {
                Text(todoLocalized("common.save"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(!draft.canSave || isOperationallyBusy)
        }
        .padding(DPSpacing.compact)
        .safeAreaPadding(.bottom, DPSpacing.extraSmall)
    }

    private func requestDismissal() {
        switch TodoFormDismissalPolicy.action(isDirty: isDirty, isBusy: isOperationallyBusy) {
        case .dismiss:
            dismissForm(saved: false)
        case .confirmDiscard:
            showsDiscardConfirmation = true
        case .ignore:
            break
        }
    }

    private func confirmDiscard(dismissConfirmation: @escaping () -> Void) {
        guard TodoConfirmationPolicy.canBegin(
            isConfirming: isDiscarding,
            isSaving: isDiscardConfirmationSaving
        ) else { return }
        isDiscarding = true
        onBusyChange(true)
        Task {
            let discarded = await attachmentModel.discard()
            isDiscarding = false
            if discarded {
                dismissFormAfterDiscard = true
                await Task.yield()
                dismissConfirmation()
            } else {
                onBusyChange(isBusy)
            }
        }
    }

    private func finishDiscardConfirmationDismissal() {
        showsDiscardConfirmation = false
        guard dismissFormAfterDiscard else { return }
        dismissFormAfterDiscard = false
        onBusyChange(isBusy)
        Task {
            await Task.yield()
            dismissForm(saved: false)
        }
    }

    private func submit() {
        guard TodoFormSubmissionPolicy.canBegin(
            isSubmitting: isSubmitting,
            canSave: draft.canSave,
            isBusy: isOperationallyBusy
        ) else { return }
        isSubmitting = true
        onBusyChange(true)
        Task {
            guard let attachments = await attachmentModel.resultForSave() else {
                isSubmitting = false
                onBusyChange(isBusy)
                return
            }
            var submission = draft
            submission.attachmentSessionId = attachments.attachmentSessionId
            submission.orderedAttachmentIDs = attachments.orderedAttachmentIds
            if await save(submission) {
                didSave = true
                onBusyChange(false)
                await Task.yield()
                dismissForm(saved: true)
            } else {
                isSubmitting = false
                onBusyChange(isBusy)
            }
        }
    }

    private var isDirty: Bool {
        !didSave && TodoFormDismissalPolicy.isDirty(
            initialDraft: baselineDraft,
            draft: draft,
            initialAttachmentIDs: baselineAttachmentIDs,
            attachmentIDs: attachmentModel.attachments.map(\.id),
            hasAttachmentSession: attachmentModel.attachmentSessionId != nil
        )
    }

    private var isOperationallyBusy: Bool {
        isSubmitting
            || dismissFormAfterDiscard
            || (!didSave && (isSaving || attachmentModel.isBusy || isDiscarding))
    }

    private var isBusy: Bool {
        isOperationallyBusy
    }

    private var isDiscardConfirmationSaving: Bool {
        isSubmitting || isSaving || attachmentModel.isBusy
    }

    private func dismissForm(saved: Bool) {
        if saved, let savedDismissAction {
            savedDismissAction()
        } else if !saved, let dismissAction {
            dismissAction()
        } else {
            dismiss()
        }
    }
}

private enum TodoFormField: Hashable {
    case title
    case content
    case tags
}

private struct TodoFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Text(title)
                .font(DPFont.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(DPColor.textSecondary)
            content
        }
    }
}

private struct TodoErrorAlertModifier: ViewModifier {
    @ObservedObject var model: TodoViewModel

    func body(content: Content) -> some View {
        content.alert(
            todoLocalized("todo.error.title"),
            isPresented: Binding(
                get: { model.errorKey != nil },
                set: { if !$0 { model.errorKey = nil } }
            )
        ) {
            Button(todoLocalized("common.ok"), role: .cancel) {
                model.errorKey = nil
            }
        } message: {
            if let errorKey = model.errorKey {
                Text(todoLocalized(errorKey))
            }
        }
    }
}

private extension View {
    func todoErrorAlert(_ model: TodoViewModel) -> some View {
        modifier(TodoErrorAlertModifier(model: model))
    }
}

extension TodoStatus {
    static let boardStatuses: [TodoStatus] = [.todo, .inProgress, .done]

    var titleKey: String {
        switch self {
        case .todo: "todo.status.todo"
        case .inProgress: "todo.status.inProgress"
        case .done: "todo.status.done"
        case .unknown: "todo.status.unknown"
        }
    }

    var shortTitleKey: String {
        switch self {
        case .todo: "todo.statusShort.todo"
        case .inProgress: "todo.statusShort.inProgress"
        case .done: "todo.statusShort.done"
        case .unknown: "todo.status.unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .todo: "list.bullet"
        case .inProgress: "clock"
        case .done: "checkmark.circle"
        case .unknown: "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .todo: DPColor.accent
        case .inProgress: DPColor.warning
        case .done: DPColor.success
        case .unknown: DPColor.textMuted
        }
    }

    var softColor: Color {
        switch self {
        case .todo: DPColor.backgroundTertiary
        case .inProgress: DPColor.warningSoft
        case .done: DPColor.successSoft
        case .unknown: DPColor.backgroundTertiary
        }
    }
}
