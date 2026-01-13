import Foundation

@MainActor
final class TodoViewModel: ObservableObject {
    @Published var todos: [Todo] = []
    @Published var isLoading = false
    @Published var error: Error?

    func loadTodos() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .todos,
                responseType: TodoListResponse.self
            )
            todos = response.todos
        } catch {
            self.error = error
        }
    }

    func createTodo(content: String) async {
        let request = CreateTodoRequest(content: content, status: "PENDING")

        do {
            let newTodo = try await APIClient.shared.request(
                .createTodo(request: request),
                responseType: Todo.self
            )
            todos.insert(newTodo, at: 0)
        } catch {
            self.error = error
        }
    }

    func updateTodoStatus(_ todo: Todo, to status: TodoStatus) async {
        let request = UpdateTodoRequest(content: nil, status: status.rawValue, position: nil)

        do {
            let updatedTodo = try await APIClient.shared.request(
                .updateTodo(id: todo.id, request: request),
                responseType: Todo.self
            )
            if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                todos[index] = updatedTodo
            }
        } catch {
            self.error = error
        }
    }

    func completeTodo(_ todo: Todo) async {
        do {
            let updatedTodo = try await APIClient.shared.request(
                .completeTodo(id: todo.id),
                responseType: Todo.self
            )
            if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                todos[index] = updatedTodo
            }
        } catch {
            self.error = error
        }
    }

    func reopenTodo(_ todo: Todo) async {
        do {
            let updatedTodo = try await APIClient.shared.request(
                .reopenTodo(id: todo.id),
                responseType: Todo.self
            )
            if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                todos[index] = updatedTodo
            }
        } catch {
            self.error = error
        }
    }

    func deleteTodo(_ todo: Todo) async {
        do {
            try await APIClient.shared.requestVoid(.deleteTodo(id: todo.id))
            todos.removeAll { $0.id == todo.id }
        } catch {
            self.error = error
        }
    }
}
