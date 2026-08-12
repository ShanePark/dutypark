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

    func create(draft: TodoDraft) async -> Bool {
        await performMutation(errorKey: "todo.error.create") {
            _ = try await repository.create(draft.request())
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

    func moveWithinSelectedColumn(_ todo: TodoDTO, offset: Int) async {
        var items = selectedTodos
        guard let source = items.firstIndex(where: { $0.id == todo.id }) else { return }
        let destination = source + offset
        guard items.indices.contains(destination) else { return }
        items.swapAt(source, destination)
        do {
            try await repository.updatePositions(
                TodoPositionUpdateRequest(status: selectedStatus, orderedIds: items.map(\.uuid))
            )
            await refresh()
        } catch {
            errorKey = "todo.error.reorder"
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
