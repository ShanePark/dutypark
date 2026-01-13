import SwiftUI

struct TodoListView: View {
    @StateObject private var viewModel = TodoViewModel()
    @State private var showingAddSheet = false
    @State private var newTodoTitle = ""

    var body: some View {
        NavigationStack {
            List {
                // Todo Section
                if !viewModel.todoItems.isEmpty {
                    Section("할 일") {
                        ForEach(viewModel.todoItems) { todo in
                            todoRow(todo)
                        }
                    }
                }

                // In Progress Section
                if !viewModel.inProgressItems.isEmpty {
                    Section("진행 중") {
                        ForEach(viewModel.inProgressItems) { todo in
                            todoRow(todo)
                        }
                    }
                }

                // Done Section
                if !viewModel.doneItems.isEmpty {
                    Section("완료") {
                        ForEach(viewModel.doneItems) { todo in
                            todoRow(todo)
                        }
                    }
                }

                if viewModel.todoItems.isEmpty && viewModel.inProgressItems.isEmpty && viewModel.doneItems.isEmpty && !viewModel.isLoading {
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
                await viewModel.loadTodoBoard()
            }
            .task {
                await viewModel.loadTodoBoard()
            }
            .alert("새 할 일", isPresented: $showingAddSheet) {
                TextField("할 일 제목", text: $newTodoTitle)
                Button("취소", role: .cancel) {
                    newTodoTitle = ""
                }
                Button("추가") {
                    Task {
                        _ = await viewModel.createTodo(title: newTodoTitle, content: nil, dueDate: nil)
                        newTodoTitle = ""
                    }
                }
            }
            .loading(viewModel.isLoading && viewModel.todoBoard == nil)
        }
    }

    @ViewBuilder
    private func todoRow(_ todo: Todo) -> some View {
        HStack {
            Button {
                Task {
                    if todo.status == .done {
                        _ = await viewModel.reopenTodo(todo.id)
                    } else {
                        _ = await viewModel.completeTodo(todo.id)
                    }
                }
            } label: {
                Image(systemName: todo.status == .done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.status == .done ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .strikethrough(todo.status == .done)
                    .foregroundStyle(todo.status == .done ? .secondary : .primary)

                if !todo.content.isEmpty {
                    Text(todo.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let completedDate = todo.completedDate {
                    Text("완료: \(formatDate(completedDate))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let dueDate = todo.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("마감: \(formatDate(dueDate))")
                            .font(.caption2)
                    }
                    .foregroundStyle(todo.isOverdue ? .red : .secondary)
                }
            }

            Spacer()

            if todo.status != .done {
                Menu {
                    ForEach(TodoStatus.allCases.filter { $0 != .done }, id: \.self) { status in
                        if status != todo.status {
                            Button(status.displayName) {
                                Task {
                                    _ = await viewModel.changeTodoStatus(id: todo.id, newStatus: status)
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
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task {
                    _ = await viewModel.deleteTodo(todo.id)
                }
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    private func statusColor(_ status: TodoStatus) -> Color {
        switch status {
        case .todo: return .blue
        case .inProgress: return .orange
        case .done: return .green
        }
    }

    private func formatDate(_ dateString: String) -> String {
        // Handle both ISO8601 and simple date formats
        if dateString.contains("T") {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: dateString) else { return dateString }

            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "M/d HH:mm"
            return displayFormatter.string(from: date)
        } else {
            // Simple date format like "2025-01-13"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard let date = formatter.date(from: dateString) else { return dateString }

            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "M월 d일"
            displayFormatter.locale = Locale(identifier: "ko_KR")
            return displayFormatter.string(from: date)
        }
    }
}

#Preview {
    TodoListView()
}
