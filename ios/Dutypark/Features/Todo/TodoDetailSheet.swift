import SwiftUI

struct TodoDetailSheet: View {
    @ObservedObject var viewModel: TodoViewModel
    @Environment(\.dismiss) private var dismiss

    let todo: Todo

    @State private var title: String
    @State private var content: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false

    init(viewModel: TodoViewModel, todo: Todo) {
        self.viewModel = viewModel
        self.todo = todo
        _title = State(initialValue: todo.title)
        _content = State(initialValue: todo.content)
        _hasDueDate = State(initialValue: todo.dueDate != nil)

        if let dueDateString = todo.dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            _dueDate = State(initialValue: formatter.date(from: dueDateString) ?? Date())
        } else {
            _dueDate = State(initialValue: Date())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TodoStatusBadge(status: todo.status)
                        Spacer()
                        Text(formatCreatedDate())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("내용") {
                    if isEditing {
                        TextField("제목", text: $title)
                        TextField("설명", text: $content, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        Text(todo.title)
                            .font(.headline)
                        if !todo.content.isEmpty {
                            Text(todo.content)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("마감일") {
                    if isEditing {
                        Toggle("마감일", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("날짜", selection: $dueDate, displayedComponents: .date)
                        }
                    } else if let dueDate = todo.dueDate {
                        HStack {
                            Text(formatDueDate(dueDate))
                            Spacer()
                            if todo.isOverdue {
                                Text("지남")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    } else {
                        Text("없음")
                            .foregroundColor(.secondary)
                    }
                }

                Section("상태 변경") {
                    ForEach(TodoStatus.allCases, id: \.self) { status in
                        Button {
                            Task {
                                await viewModel.changeTodoStatus(id: todo.id, newStatus: status)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                TodoStatusBadge(status: status, showLabel: false)
                                Text(status.displayName)
                                Spacer()
                                if todo.status == status {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(todo.status == status)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("삭제")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "할 일 수정" : "할 일 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "취소" : "닫기") {
                        if isEditing {
                            resetFields()
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("저장") {
                            saveChanges()
                        }
                        .disabled(title.isEmpty || isSaving)
                    } else {
                        Button("수정") {
                            isEditing = true
                        }
                    }
                }
            }
            .alert("할 일 삭제", isPresented: $showDeleteConfirmation) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    Task {
                        await viewModel.deleteTodo(todo.id)
                        dismiss()
                    }
                }
            } message: {
                Text("'\(todo.title)'을(를) 삭제하시겠습니까?")
            }
        }
    }

    private func resetFields() {
        title = todo.title
        content = todo.content
        hasDueDate = todo.dueDate != nil
        if let dueDateString = todo.dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            dueDate = formatter.date(from: dueDateString) ?? Date()
        }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            let success = await viewModel.updateTodo(
                id: todo.id,
                title: title,
                content: content.isEmpty ? nil : content,
                dueDate: hasDueDate ? dueDate : nil
            )
            if success {
                dismiss()
            }
            isSaving = false
        }
    }

    private func formatCreatedDate() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: todo.createdDate) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: todo.createdDate) else {
                return ""
            }
            return formatOutputDate(date)
        }
        return formatOutputDate(date)
    }

    private func formatOutputDate(_ date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy.M.d"
        return "생성: " + outputFormatter.string(from: date)
    }

    private func formatDueDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy년 M월 d일"
        return outputFormatter.string(from: date)
    }
}

#Preview {
    let sampleTodo = Todo(
        id: "1",
        title: "Sample Todo",
        content: "This is a sample todo item",
        position: 0,
        status: .todo,
        createdDate: "2024-01-13T10:00:00Z",
        completedDate: nil,
        dueDate: "2024-01-20",
        isOverdue: false,
        attachments: nil
    )
    return TodoDetailSheet(viewModel: TodoViewModel(), todo: sampleTodo)
}
