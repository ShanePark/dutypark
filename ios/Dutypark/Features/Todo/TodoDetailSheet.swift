import SwiftUI
import PhotosUI

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
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var uploadedAttachments: [AttachmentDto] = []
    @State private var attachmentSessionId: String?
    @State private var isUploadingAttachment = false
    @State private var existingAttachments: [AttachmentDto] = []
    @State private var editAttachments: [AttachmentDto] = []
    @State private var isLoadingAttachments = false

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
                    if let completedDate = todo.completedDate {
                        Text(formatCompletedDate(completedDate))
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

                Section("첨부파일") {
                    if isLoadingAttachments {
                        ProgressView()
                    } else if isEditing {
                        if editAttachments.isEmpty && uploadedAttachments.isEmpty {
                            Text("첨부파일 없음")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(editAttachments, id: \.id) { attachment in
                                attachmentRow(attachment, isUploaded: false)
                            }
                            ForEach(uploadedAttachments, id: \.id) { attachment in
                                attachmentRow(attachment, isUploaded: true)
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
                    } else {
                        if existingAttachments.isEmpty {
                            Text("첨부파일 없음")
                                .foregroundColor(.secondary)
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                ForEach(existingAttachments, id: \.id) { attachment in
                                    AttachmentThumbnail(attachment: attachment)
                                }
                            }
                            .padding(.vertical, 4)
                        }
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
                            beginEditing()
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
            .task {
                await loadAttachments()
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
        editAttachments = existingAttachments
        uploadedAttachments = []
        attachmentSessionId = nil
        selectedPhotoItems = []
        isUploadingAttachment = false
    }

    private func beginEditing() {
        editAttachments = existingAttachments
        uploadedAttachments = []
        attachmentSessionId = nil
        selectedPhotoItems = []
        isUploadingAttachment = false
        isEditing = true
    }

    private func saveChanges() {
        isSaving = true
        Task {
            let attachmentIds = editAttachments.map { $0.id } + uploadedAttachments.map { $0.id }
            let success = await viewModel.updateTodo(
                id: todo.id,
                title: title,
                content: content.isEmpty ? nil : content,
                dueDate: hasDueDate ? dueDate : nil,
                attachmentSessionId: attachmentSessionId,
                orderedAttachmentIds: attachmentIds.isEmpty ? nil : attachmentIds
            )
            if success {
                dismiss()
            }
            isSaving = false
        }
    }

    private func formatCreatedDate() -> String {
        "생성: \(formatTimestamp(todo.createdDate))"
    }

    private func formatCompletedDate(_ dateString: String) -> String {
        "완료: \(formatTimestamp(dateString))"
    }

    private func formatTimestamp(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return formatOutputDate(date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return formatOutputDate(date)
        }
        return dateString
    }

    private func formatOutputDate(_ date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy년 M월 d일 HH:mm"
        outputFormatter.locale = Locale(identifier: "ko_KR")
        return outputFormatter.string(from: date)
    }

    private func formatDueDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy년 M월 d일"
        return outputFormatter.string(from: date)
    }

    private func loadAttachments() async {
        isLoadingAttachments = true
        do {
            let response = try await APIClient.shared.request(
                .attachments(contextType: AttachmentContextType.todo.rawValue, contextId: todo.id),
                responseType: [AttachmentDto].self
            )
            existingAttachments = response
            if !isEditing {
                editAttachments = response
            }
        } catch {
            existingAttachments = []
            if !isEditing {
                editAttachments = []
            }
        }
        isLoadingAttachments = false
    }

    private func uploadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        isUploadingAttachment = true

        if attachmentSessionId == nil {
            attachmentSessionId = await viewModel.createAttachmentSession(targetContextId: todo.id)
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

    private func attachmentRow(_ attachment: AttachmentDto, isUploaded: Bool) -> some View {
        HStack {
            Image(systemName: attachment.hasThumbnail ? "photo" : "doc")
                .foregroundColor(isUploaded ? .green : .secondary)
            Text(attachment.originalFilename)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Button {
                if isUploaded {
                    uploadedAttachments.removeAll { $0.id == attachment.id }
                } else {
                    editAttachments.removeAll { $0.id == attachment.id }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
}

struct AttachmentThumbnail: View {
    let attachment: AttachmentDto
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)

                if isImage, let url = thumbnailURL() {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure, .empty:
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        @unknown default:
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "doc")
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(attachment.originalFilename)
                .font(.caption2)
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                .lineLimit(1)
        }
    }

    private var isImage: Bool {
        attachment.contentType.hasPrefix("image/")
    }

    private func thumbnailURL() -> URL? {
        #if DEBUG
        let baseURL = "http://localhost:8080"
        #else
        let baseURL = "https://duty.park"
        #endif

        if let path = attachment.thumbnailUrl {
            return URL(string: "\(baseURL)\(path)")
        }
        return URL(string: "\(baseURL)/api/attachments/\(attachment.id)/thumbnail")
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
        hasAttachments: false
    )
    return TodoDetailSheet(viewModel: TodoViewModel(), todo: sampleTodo)
}
