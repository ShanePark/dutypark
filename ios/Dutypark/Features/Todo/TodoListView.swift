import SwiftUI

struct TodoListView: View {
    @StateObject private var viewModel = TodoViewModel()
    @State private var showingAddSheet = false
    @State private var newTodoContent = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(TodoStatus.allCases, id: \.self) { status in
                    let todos = viewModel.todos.filter { $0.status == status }
                    if !todos.isEmpty {
                        Section(status.displayName) {
                            ForEach(todos) { todo in
                                todoRow(todo)
                            }
                            .onDelete { indexSet in
                                deleteTodos(at: indexSet, in: todos)
                            }
                        }
                    }
                }

                if viewModel.todos.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "할 일이 없습니다",
                        systemImage: "checkmark.circle",
                        description: Text("새로운 할 일을 추가해보세요")
                    )
                }
            }
            .navigationTitle("할 일")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await viewModel.loadTodos()
            }
            .task {
                await viewModel.loadTodos()
            }
            .alert("새 할 일", isPresented: $showingAddSheet) {
                TextField("할 일 내용", text: $newTodoContent)
                Button("취소", role: .cancel) {
                    newTodoContent = ""
                }
                Button("추가") {
                    Task {
                        await viewModel.createTodo(content: newTodoContent)
                        newTodoContent = ""
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func todoRow(_ todo: Todo) -> some View {
        HStack {
            Button {
                Task {
                    if todo.status == .completed {
                        await viewModel.reopenTodo(todo)
                    } else {
                        await viewModel.completeTodo(todo)
                    }
                }
            } label: {
                Image(systemName: todo.status == .completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.content)
                    .strikethrough(todo.status == .completed)
                    .foregroundStyle(todo.status == .completed ? .secondary : .primary)

                if let completedAt = todo.completedAt {
                    Text("완료: \(formatDate(completedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if todo.status != .completed {
                Menu {
                    ForEach(TodoStatus.allCases.filter { $0 != .completed }, id: \.self) { status in
                        if status != todo.status {
                            Button(status.displayName) {
                                Task {
                                    await viewModel.updateTodoStatus(todo, to: status)
                                }
                            }
                        }
                    }
                } label: {
                    Text(todo.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(todo.status).opacity(0.2))
                        .foregroundStyle(statusColor(todo.status))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func deleteTodos(at indexSet: IndexSet, in todos: [Todo]) {
        for index in indexSet {
            let todo = todos[index]
            Task {
                await viewModel.deleteTodo(todo)
            }
        }
    }

    private func statusColor(_ status: TodoStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .inProgress: return .blue
        case .completed: return .green
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else { return dateString }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "M/d HH:mm"
        return displayFormatter.string(from: date)
    }
}

#Preview {
    TodoListView()
}
