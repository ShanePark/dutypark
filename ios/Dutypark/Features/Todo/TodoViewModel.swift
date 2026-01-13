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

    func createTodo(title: String, content: String?, dueDate: Date?, status: TodoStatus = .todo) async -> Bool {
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
            attachmentSessionId: nil,
            orderedAttachmentIds: nil
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

    func updateTodo(id: String, title: String, content: String?, dueDate: Date?) async -> Bool {
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
            attachmentSessionId: nil,
            orderedAttachmentIds: nil
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

    func changeTodoStatus(id: String, newStatus: TodoStatus) async -> Bool {
        var orderedIds: [String]
        switch newStatus {
        case .todo:
            orderedIds = todoItems.map { $0.id }
        case .inProgress:
            orderedIds = inProgressItems.map { $0.id }
        case .done:
            orderedIds = doneItems.map { $0.id }
        }
        orderedIds.append(id)

        let request = TodoStatusChangeRequest(
            status: newStatus.rawValue,
            orderedIds: orderedIds
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
}
