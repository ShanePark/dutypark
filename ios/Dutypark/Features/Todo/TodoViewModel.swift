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

    private let repository: any TodoRepository

    init(repository: any TodoRepository = TodoAPIRepository()) {
        self.repository = repository
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

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            board = try await repository.fetchBoard()
            selectNonemptyStatusIfNeeded()
        } catch {
            errorKey = "todo.error.load"
            return
        }
        friends = ((try? await repository.fetchFriends()) ?? []).sorted(by: friendOrder)
    }

    func refresh() async {
        do {
            board = try await repository.fetchBoard()
            selectNonemptyStatusIfNeeded()
        } catch {
            errorKey = "todo.error.load"
        }
    }

    func loadAttachments(for todo: TodoDTO) async {
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

    func create(draft: TodoDraft, refreshBoard: Bool = true) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await repository.create(draft.request())
            if refreshBoard {
                await refresh()
            }
            return true
        } catch {
            errorKey = "todo.error.create"
            return false
        }
    }

    func update(todo: TodoDTO, draft: TodoDraft) async -> Bool {
        guard !todo.hasAttachments || attachmentsByTodoID[todo.uuid] != nil else {
            errorKey = "todo.error.attachmentsRequired"
            return false
        }
        return await performMutation(errorKey: "todo.error.update") {
            _ = try await repository.update(
                id: todo.uuid,
                request: draft.request()
            )
        }
    }

    func delete(_ todo: TodoDTO) async -> Bool {
        await performMutation(errorKey: "todo.error.delete") {
            try await repository.delete(id: todo.uuid)
        }
    }

    func complete(_ todo: TodoDTO) async -> Bool {
        await performMutation(errorKey: "todo.error.status") {
            _ = try await repository.complete(id: todo.uuid)
        }
    }

    func reopen(_ todo: TodoDTO) async -> Bool {
        await performMutation(errorKey: "todo.error.status") {
            _ = try await repository.reopen(id: todo.uuid)
        }
    }

    func move(_ todo: TodoDTO, to status: TodoStatus) async -> Bool {
        guard todo.status != status else { return true }
        return await performMutation(errorKey: "todo.error.status") {
            _ = try await repository.changeStatus(
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
            return true
        } catch {
            board = originalBoard
            selectedStatus = sourceStatus
            errorKey = sourceStatus == destinationStatus
                ? "todo.error.reorder"
                : "todo.error.status"
            return false
        }
    }

    func leaveTag(_ todo: TodoDTO) async -> Bool {
        await performMutation(errorKey: "todo.error.leaveTag") {
            try await repository.leaveTag(id: todo.uuid)
        }
    }

    private func performMutation(
        errorKey: String,
        operation: () async throws -> Void
    ) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            try await operation()
            await refresh()
            return true
        } catch {
            self.errorKey = errorKey
            return false
        }
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
}

private struct TodoBoardColumns {
    var todo: [TodoDTO]
    var inProgress: [TodoDTO]
    var done: [TodoDTO]

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
