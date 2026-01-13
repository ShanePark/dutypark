import SwiftUI
import PhotosUI

struct AddTodoSheet: View {
    @ObservedObject var viewModel: TodoViewModel
    @Environment(\.dismiss) private var dismiss

    let initialStatus: TodoStatus

    @State private var title = ""
    @State private var content = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var isSaving = false
    @State private var selectedStatus: TodoStatus

    // Attachment states
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var uploadedAttachments: [AttachmentDto] = []
    @State private var attachmentSessionId: String?
    @State private var isUploadingAttachment = false

    init(viewModel: TodoViewModel, initialStatus: TodoStatus) {
        self.viewModel = viewModel
        self.initialStatus = initialStatus
        _selectedStatus = State(initialValue: initialStatus)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("할 일") {
                    HStack {
                        Text("제목")
                        Spacer()
                        Text("\(title.count)/50")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    TextField("제목 (필수)", text: $title)
                    TextField("설명", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("상태") {
                    HStack(spacing: 8) {
                        statusChip(.todo, label: "오늘 할일", icon: "checkmark.circle")
                        statusChip(.inProgress, label: "진행중", icon: "clock")
                        statusChip(.done, label: "완료", icon: "checkmark.seal")
                    }
                }

                Section("마감일") {
                    Toggle("마감일 설정", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("마감일", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("첨부파일") {
                    ForEach(uploadedAttachments, id: \.id) { attachment in
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.green)
                            Text(attachment.originalFilename)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                uploadedAttachments.removeAll { $0.id == attachment.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text(isUploadingAttachment ? "업로드 중..." : "파일 추가")
                        }
                    }
                    .disabled(isUploadingAttachment)
                    .onChange(of: selectedPhotoItems) { _, newItems in
                        guard !newItems.isEmpty else { return }
                        Task {
                            await uploadSelectedPhotos(newItems)
                            selectedPhotoItems = []
                        }
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
        .onChange(of: title) { _, newValue in
            if newValue.count > 50 {
                title = String(newValue.prefix(50))
            }
        }
    }

    private func saveTodo() {
        isSaving = true
        Task {
            let attachmentIds = uploadedAttachments.map { $0.id }
            let success = await viewModel.createTodo(
                title: title,
                content: content.isEmpty ? nil : content,
                dueDate: hasDueDate ? dueDate : nil,
                status: selectedStatus,
                attachmentSessionId: attachmentSessionId,
                orderedAttachmentIds: attachmentIds.isEmpty ? nil : attachmentIds
            )
            if success {
                dismiss()
            }
            isSaving = false
        }
    }

    private func statusChip(_ status: TodoStatus, label: String, icon: String) -> some View {
        Button {
            selectedStatus = status
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selectedStatus == status ? status.backgroundColor : Color(.systemGray6))
            .foregroundColor(selectedStatus == status ? status.foregroundColor : .secondary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func uploadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        isUploadingAttachment = true

        if attachmentSessionId == nil {
            attachmentSessionId = await viewModel.createAttachmentSession()
        }

        guard let sessionId = attachmentSessionId else {
            isUploadingAttachment = false
            return
        }

        for (index, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                if let image = UIImage(data: data),
                   let jpegData = image.jpegData(compressionQuality: 0.8) {
                    let fileName = "todo_\(Date().timeIntervalSince1970)_\(index).jpg"
                    if let attachment = await viewModel.uploadAttachment(sessionId: sessionId, imageData: jpegData, fileName: fileName) {
                        uploadedAttachments.append(attachment)
                    }
                }
            }
        }

        isUploadingAttachment = false
    }
}

#Preview {
    AddTodoSheet(viewModel: TodoViewModel(), initialStatus: .todo)
}
