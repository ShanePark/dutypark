import SwiftUI

struct AddTodoSheet: View {
    @ObservedObject var viewModel: TodoViewModel
    @Environment(\.dismiss) private var dismiss

    let initialStatus: TodoStatus

    @State private var title = ""
    @State private var content = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("할 일") {
                    TextField("제목 (필수)", text: $title)
                    TextField("설명", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("마감일") {
                    Toggle("마감일 설정", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("마감일", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section {
                    HStack {
                        Text("상태")
                        Spacer()
                        TodoStatusBadge(status: initialStatus)
                    }
                }
            }
            .navigationTitle("할 일 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("추가") {
                        saveTodo()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveTodo() {
        isSaving = true
        Task {
            let success = await viewModel.createTodo(
                title: title,
                content: content.isEmpty ? nil : content,
                dueDate: hasDueDate ? dueDate : nil,
                status: initialStatus
            )
            if success {
                dismiss()
            }
            isSaving = false
        }
    }
}

#Preview {
    AddTodoSheet(viewModel: TodoViewModel(), initialStatus: .todo)
}
