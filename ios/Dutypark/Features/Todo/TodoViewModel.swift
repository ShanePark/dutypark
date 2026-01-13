import Foundation

@MainActor
class TodoViewModel: ObservableObject {
    @Published var todoBoard: TodoBoard?
    @Published var isLoading = false
    @Published var error: String?

    var todoItems: [Todo] { todoBoard?.todo ?? [] }
    var inProgressItems: [Todo] { todoBoard?.inProgress ?? [] }
    var doneItems: [Todo] { todoBoard?.done ?? [] }
    var counts: TodoCounts? { todoBoard?.counts }

    func loadTodoBoard() async {
        isLoading = true
        error = nil

        do {
            todoBoard = try await APIClient.shared.request(.todoBoard, responseType: TodoBoard.self)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func createTodo(
        title: String,
        content: String?,
        dueDate: Date?,
        status: TodoStatus = .todo,
        attachmentSessionId: String? = nil,
        orderedAttachmentIds: [String]? = nil
    ) async -> Bool {
        var dueDateString: String?
        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            dueDateString = formatter.string(from: dueDate)
        }

        let request = TodoCreateRequest(
            title: title,
            content: content,
            status: status.rawValue,
            dueDate: dueDateString,
            attachmentSessionId: attachmentSessionId,
            orderedAttachmentIds: orderedAttachmentIds
        )

        do {
            let _: Todo = try await APIClient.shared.request(.createTodo(request: request), responseType: Todo.self)
            await loadTodoBoard()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func updateTodo(
        id: String,
        title: String,
        content: String?,
        dueDate: Date?,
        attachmentSessionId: String? = nil,
        orderedAttachmentIds: [String]? = nil
    ) async -> Bool {
        var dueDateString: String?
        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            dueDateString = formatter.string(from: dueDate)
        }

        let request = TodoUpdateRequest(
            title: title,
            content: content ?? "",
            status: nil,
            dueDate: dueDateString,
            attachmentSessionId: attachmentSessionId,
            orderedAttachmentIds: orderedAttachmentIds
        )

        do {
            let _: Todo = try await APIClient.shared.request(.updateTodo(id: id, request: request), responseType: Todo.self)
            await loadTodoBoard()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func changeTodoStatus(id: String, newStatus: TodoStatus, orderedIds: [String]? = nil) async -> Bool {
        let resolvedIds: [String] = {
            if let orderedIds { return orderedIds }
            switch newStatus {
            case .todo:
                return todoItems.map { $0.id } + [id]
            case .inProgress:
                return inProgressItems.map { $0.id } + [id]
            case .done:
                return doneItems.map { $0.id } + [id]
            }
        }()

        let request = TodoStatusChangeRequest(
            status: newStatus.rawValue,
            orderedIds: resolvedIds
        )

        do {
            let _: Todo = try await APIClient.shared.request(.changeTodoStatus(id: id, request: request), responseType: Todo.self)
            await loadTodoBoard()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func updateTodoPositions(status: TodoStatus, orderedIds: [String]) async -> Bool {
        let request = TodoPositionUpdateRequest(status: status.rawValue, orderedIds: orderedIds)
        do {
            try await APIClient.shared.requestVoid(.updateTodoPositions(request: request))
            await loadTodoBoard()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func completeTodo(_ id: String) async -> Bool {
        do {
            let _: Todo = try await APIClient.shared.request(.completeTodo(id: id), responseType: Todo.self)
            await loadTodoBoard()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func reopenTodo(_ id: String) async -> Bool {
        do {
            let _: Todo = try await APIClient.shared.request(.reopenTodo(id: id), responseType: Todo.self)
            await loadTodoBoard()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteTodo(_ id: String) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.deleteTodo(id: id))
            await loadTodoBoard()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Attachment Management

    func createAttachmentSession(targetContextId: String? = nil) async -> String? {
        let request = CreateSessionRequest(
            contextType: AttachmentContextType.todo.rawValue,
            targetContextId: targetContextId
        )

        do {
            let response = try await APIClient.shared.request(
                .createAttachmentSession(request: request),
                responseType: CreateSessionResponse.self
            )
            return response.sessionId
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func uploadAttachment(sessionId: String, imageData: Data, fileName: String) async -> AttachmentDto? {
        do {
            let attachment = try await APIClient.shared.uploadAttachment(
                sessionId: sessionId,
                fileData: imageData,
                fileName: fileName,
                mimeType: "image/jpeg"
            )
            return attachment
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func deleteAttachmentSession(_ sessionId: String) async {
        do {
            try await APIClient.shared.requestVoid(.deleteAttachmentSession(sessionId: sessionId))
        } catch {
            self.error = error.localizedDescription
        }
    }
}
