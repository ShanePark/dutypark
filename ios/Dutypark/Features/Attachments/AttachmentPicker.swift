import Combine
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AttachmentPickerModel: ObservableObject {
    let contextType: AttachmentContextType
    let targetContextId: String?

    @Published private(set) var attachments: [AttachmentDTO]
    @Published private(set) var attachmentSessionId: UUID?
    @Published private(set) var isPreparing = false
    @Published private(set) var isUploading = false
    @Published private(set) var uploadProgress: AttachmentUploadProgress?
    @Published var failure: AttachmentPickerFailure?

    private let client: any AttachmentPickerClient
    private let haptics: DPHapticCenter

    init(
        contextType: AttachmentContextType,
        targetContextId: String? = nil,
        existingAttachments: [AttachmentDTO] = [],
        client: any AttachmentPickerClient = AttachmentClient(),
        haptics: DPHapticCenter = .shared
    ) {
        self.contextType = contextType
        self.targetContextId = targetContextId
        self.attachments = existingAttachments
        self.client = client
        self.haptics = haptics
    }

    var result: AttachmentPickerResult {
        AttachmentPickerResult(
            attachmentSessionId: attachmentSessionId,
            attachments: attachments
        )
    }

    var isBusy: Bool { isPreparing || isUploading }

    func beginPreparing() {
        isPreparing = true
    }

    func endPreparing() {
        isPreparing = false
    }

    func add(files: [AttachmentUploadFile]) async {
        await add(totalFileCount: files.count) { index in
            files[index]
        }
    }

    /// Loads and uploads one selected item at a time. Keeping the loader in
    /// the loop prevents a multi-selection from retaining every source Data
    /// buffer while another file is being uploaded.
    func add(
        totalFileCount: Int,
        load: @escaping @MainActor @Sendable (Int) async throws -> AttachmentUploadFile
    ) async {
        guard totalFileCount > 0, !isUploading else { return }
        isUploading = true
        defer {
            uploadProgress = nil
            isUploading = false
        }

        do {
            for index in 0..<totalFileCount {
                try Task.checkCancellation()
                let file = try await load(index)
                try Task.checkCancellation()
                uploadProgress = AttachmentUploadProgress(
                    completedFileCount: index,
                    totalFileCount: totalFileCount,
                    currentFilename: file.filename
                )
                let sessionId = try await ensureSession()
                attachments.append(try await client.upload(file, sessionId: sessionId))
            }
            try Task.checkCancellation()
            haptics.emit(.success)
        } catch {
            guard !Task.isCancelled else { return }
            if let error = error as? AttachmentUploadError {
                recordFailure(.from(error))
            } else if let error = error as? APIError {
                recordFailure(.from(error))
            } else {
                recordFailure(.uploadFailed)
            }
        }
    }

    func remove(_ attachmentId: AttachmentID) {
        guard !isBusy else { return }
        let countBefore = attachments.count
        attachments.removeAll { $0.id == attachmentId }
        guard attachments.count != countBefore else { return }
    }

    func move(from index: Int, by offset: Int) {
        guard !isBusy, offset != 0 else { return }
        let destination = index + offset
        guard attachments.indices.contains(index), attachments.indices.contains(destination) else {
            return
        }
        attachments.swapAt(index, destination)
        haptics.emit(.selection)
    }

    func recordFailure(_ failure: AttachmentPickerFailure) {
        self.failure = failure
        haptics.emit(.error)
    }

    @discardableResult
    func discard() async -> Bool {
        guard let attachmentSessionId else { return true }
        do {
            try await client.discardSession(attachmentSessionId)
            self.attachmentSessionId = nil
            return true
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return false }
            recordFailure(.discardFailed)
            return false
        }
    }

    /// An empty order does not remove files uploaded into a new server session.
    /// Discard that session before saving so removed uploads cannot be reattached.
    func resultForSave() async -> AttachmentPickerResult? {
        if attachmentSessionId != nil, attachments.isEmpty {
            guard await discard() else { return nil }
        }
        return result
    }

    private func ensureSession() async throws -> UUID {
        if let attachmentSessionId {
            return attachmentSessionId
        }
        let response = try await client.createSession(
            contextType: contextType,
            targetContextId: targetContextId
        )
        attachmentSessionId = response.sessionId
        return response.sessionId
    }
}

nonisolated struct AttachmentUploadProgress: Equatable, Sendable {
    let completedFileCount: Int
    let totalFileCount: Int
    let currentFilename: String

    var overallFraction: Double {
        guard totalFileCount > 0 else { return 0 }
        return Double(completedFileCount) / Double(totalFileCount)
    }

    var currentFileNumber: Int {
        min(completedFileCount + 1, totalFileCount)
    }
}

nonisolated enum AttachmentPickerFailure: String, Identifiable, Sendable {
    case emptyFile
    case tooLarge
    case unreadableFile
    case conversionFailed
    case blockedExtension
    case uploadFailed
    case discardFailed

    var id: String { rawValue }

    var messageKey: String {
        switch self {
        case .emptyFile: "attachment.error.empty"
        case .tooLarge: "attachment.error.tooLarge"
        case .unreadableFile: "attachment.error.unreadable"
        case .conversionFailed: "attachment.error.conversion"
        case .blockedExtension: "attachment.error.blockedExtension"
        case .uploadFailed: "attachment.error.upload"
        case .discardFailed: "attachment.error.discard"
        }
    }

    static func from(_ error: AttachmentUploadError) -> Self {
        switch error {
        case .emptyFile: .emptyFile
        case .tooLarge: .tooLarge
        case .unreadableFile: .unreadableFile
        case .imageConversionFailed: .conversionFailed
        }
    }

    static func from(_ error: APIError) -> Self {
        if case .server(_, let code) = error {
            return switch code {
            case "attachment.size.exceeded": .tooLarge
            case "attachment.extension.blocked": .blockedExtension
            default: .uploadFailed
            }
        }
        return .uploadFailed
    }
}

@MainActor
final class AttachmentUploadCoordinator {
    private var task: Task<Void, Never>?
    private var generation = 0

    func start(
        model: AttachmentPickerModel,
        operation: @escaping @MainActor () async -> Void
    ) {
        task?.cancel()
        generation &+= 1
        let currentGeneration = generation
        model.beginPreparing()
        task = Task { @MainActor [weak self, weak model] in
            await operation()
            guard let self, self.generation == currentGeneration else { return }
            model?.endPreparing()
            self.task = nil
        }
    }

    func cancel(model: AttachmentPickerModel) {
        generation &+= 1
        task?.cancel()
        task = nil
        model.endPreparing()
    }
}

struct AttachmentPicker: View {
    @ObservedObject var model: AttachmentPickerModel

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isImportingFiles = false
    @State private var uploadCoordinator = AttachmentUploadCoordinator()

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.compact) {
            HStack(spacing: DPSpacing.small) {
                PhotosPicker(
                    selection: $photoItems,
                    maxSelectionCount: 10,
                    matching: .any(of: [.images, .videos])
                ) {
                    Label(
                        AttachmentLocalization.text("attachment.action.photos"),
                        systemImage: "photo.on.rectangle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(model.isBusy)
                .accessibilityIdentifier("attachment.photoPicker")

                Button {
                    isImportingFiles = true
                } label: {
                    Label(
                        AttachmentLocalization.text("attachment.action.files"),
                        systemImage: "folder"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPOutlineButtonStyle())
                .disabled(model.isBusy)
                .accessibilityIdentifier("attachment.filePicker")
            }

            if model.isBusy {
                VStack(alignment: .leading, spacing: DPSpacing.small) {
                    if let progress = model.uploadProgress {
                        HStack {
                            Text(AttachmentLocalization.text("attachment.upload.overall"))
                            Spacer()
                            Text("\(progress.completedFileCount)/\(progress.totalFileCount)")
                                .monospacedDigit()
                        }
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textSecondary)

                        ProgressView(value: progress.overallFraction)
                            .tint(DPColor.accent)

                        HStack(spacing: DPSpacing.small) {
                            ProgressView()
                                .tint(DPColor.accent)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(AttachmentLocalization.text("attachment.upload.current"))
                                    .font(DPTypography.caption)
                                    .foregroundStyle(DPColor.textMuted)
                                Text(progress.currentFilename)
                                    .font(DPTypography.label)
                                    .foregroundStyle(DPColor.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(progress.currentFileNumber)/\(progress.totalFileCount)")
                                .font(DPTypography.caption)
                                .monospacedDigit()
                                .foregroundStyle(DPColor.textMuted)
                        }
                    } else {
                        HStack(spacing: DPSpacing.small) {
                            ProgressView()
                                .tint(DPColor.accent)
                            Text(AttachmentLocalization.text("attachment.uploading"))
                                .font(DPTypography.label)
                                .foregroundStyle(DPColor.textSecondary)
                        }
                    }

                    Button(role: .cancel) {
                        uploadCoordinator.cancel(model: model)
                    } label: {
                        Label(
                            AttachmentLocalization.text("attachment.action.cancelUpload"),
                            systemImage: "xmark.circle"
                        )
                    }
                    .frame(minHeight: DPSize.minimumTouchTarget)
                    .buttonStyle(DPOutlineButtonStyle())
                }
                .padding(DPSpacing.small)
                .background(DPColor.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.compact))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.compact)
                        .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
                }
                .accessibilityIdentifier("attachment.uploading")
            }

            ForEach(Array(model.attachments.enumerated()), id: \.element.id) { index, attachment in
                pickerRow(attachment, at: index)
            }
        }
        .fileImporter(
            isPresented: $isImportingFiles,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            startUpload { await add(urls: urls) }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            photoItems = []
            startUpload { await add(photoItems: items) }
        }
        .alert(
            AttachmentLocalization.text("attachment.error.title"),
            isPresented: Binding(
                get: { model.failure != nil },
                set: { if !$0 { model.failure = nil } }
            )
        ) {
            Button(AttachmentLocalization.text("attachment.action.ok"), role: .cancel) {
                model.failure = nil
            }
        } message: {
            if let failure = model.failure {
                Text(AttachmentLocalization.text(failure.messageKey))
            }
        }
        .interactiveDismissDisabled(model.isBusy || model.attachmentSessionId != nil)
        .onDisappear {
            uploadCoordinator.cancel(model: model)
        }
    }

    private func pickerRow(_ attachment: AttachmentDTO, at index: Int) -> some View {
        HStack(spacing: DPSpacing.compact) {
            AttachmentThumbnail(attachment: attachment)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.originalFilename)
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                Text(AttachmentFormatting.bytes(attachment.size))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DPIconActionButton(
                systemImage: "xmark",
                label: AttachmentLocalization.text("attachment.action.remove"),
                tone: .danger
            ) {
                model.remove(attachment.id)
            }
            .disabled(model.isBusy)
            .padding(.trailing, -DPIconActionMetrics.touchPadding)
        }
        .padding(DPSpacing.small)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.compact))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.compact)
                .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
        }
        .contextMenu {
            Button {
                model.move(from: index, by: -1)
            } label: {
                Label(
                    AttachmentLocalization.text("attachment.action.moveUp"),
                    systemImage: "arrow.up"
                )
            }
            .disabled(index == 0 || model.isBusy)

            Button {
                model.move(from: index, by: 1)
            } label: {
                Label(
                    AttachmentLocalization.text("attachment.action.moveDown"),
                    systemImage: "arrow.down"
                )
            }
            .disabled(index == model.attachments.count - 1 || model.isBusy)
        }
        .accessibilityElement(children: .contain)
    }

    private func add(urls: [URL]) async {
        await model.add(totalFileCount: urls.count) { index in
            do {
                return try await Task.detached(priority: .userInitiated) {
                    try AttachmentFileLoader.load(from: urls[index])
                }.value
            } catch let error as AttachmentUploadError {
                throw error
            } catch {
                throw AttachmentUploadError.unreadableFile
            }
        }
    }

    private func add(photoItems: [PhotosPickerItem]) async {
        await model.add(totalFileCount: photoItems.count) { index in
            do {
                return try await AttachmentFileLoader.load(from: photoItems[index])
            } catch let error as AttachmentUploadError {
                throw error
            } catch {
                throw AttachmentUploadError.unreadableFile
            }
        }
    }

    private func startUpload(_ operation: @escaping @MainActor () async -> Void) {
        uploadCoordinator.start(model: model, operation: operation)
    }
}

enum AttachmentFormatting {
    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}
