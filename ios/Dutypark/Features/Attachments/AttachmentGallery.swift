import Combine
import QuickLook
import SwiftUI
import UIKit

nonisolated protocol AttachmentGalleryClient: Sendable {
    func list(
        contextType: AttachmentContextType,
        contextId: String
    ) async throws -> [AttachmentDTO]

    func delete(_ attachmentId: AttachmentID) async throws

    func reorder(
        contextType: AttachmentContextType,
        contextId: String,
        orderedAttachmentIds: [AttachmentID]
    ) async throws

    func download(
        _ attachment: AttachmentDTO,
        inline: Bool
    ) async throws -> DownloadedAttachment
}

extension AttachmentClient: AttachmentGalleryClient {}

struct AttachmentThumbnail: View {
    let attachment: AttachmentDTO
    var client = AttachmentClient()

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .fill(DPColor.backgroundSecondary)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            } else {
                Image(systemName: iconName)
                    .foregroundStyle(DPColor.textSecondary)
            }
        }
        .clipped()
        .task(id: attachment.id) {
            guard attachment.contentType.hasPrefix("image/") else { return }
            guard let data = try? await client.thumbnailData(for: attachment.id) else { return }
            image = UIImage(data: data)
        }
        .accessibilityHidden(true)
    }

    private var iconName: String {
        if attachment.contentType.hasPrefix("video/") { return "video" }
        if attachment.contentType.hasPrefix("audio/") { return "waveform" }
        if attachment.contentType.contains("pdf") { return "doc.richtext" }
        return "doc"
    }
}

@MainActor
final class AttachmentGalleryModel: ObservableObject {
    let contextType: AttachmentContextType
    let contextId: String

    @Published private(set) var attachments: [AttachmentDTO] = []
    @Published private(set) var isLoading = false
    @Published var failure: AttachmentGalleryFailure?

    private let client: any AttachmentGalleryClient
    private let loadsRemotely: Bool
    private let haptics: DPHapticCenter
    private let temporaryFileStore: AttachmentTemporaryFileStore

    init(
        contextType: AttachmentContextType,
        contextId: String,
        client: any AttachmentGalleryClient = AttachmentClient(),
        haptics: DPHapticCenter = .shared,
        temporaryFileStore: AttachmentTemporaryFileStore = .shared
    ) {
        self.contextType = contextType
        self.contextId = contextId
        self.client = client
        self.loadsRemotely = true
        self.haptics = haptics
        self.temporaryFileStore = temporaryFileStore
    }

    /// Schedule payloads already embed their attachment metadata, so a gallery built
    /// this way renders thumbnails right away instead of waiting for a redundant list
    /// request. The owner keeps it in sync through `apply(_:)`.
    init(
        contextType: AttachmentContextType,
        contextId: String,
        attachments: [AttachmentDTO],
        client: any AttachmentGalleryClient = AttachmentClient(),
        haptics: DPHapticCenter = .shared,
        temporaryFileStore: AttachmentTemporaryFileStore = .shared
    ) {
        self.contextType = contextType
        self.contextId = contextId
        self.client = client
        self.loadsRemotely = false
        self.attachments = attachments
        self.haptics = haptics
        self.temporaryFileStore = temporaryFileStore
    }

#if DEBUG
    init(uiTestingAttachments: [AttachmentDTO]) {
        self.contextType = .todo
        self.contextId = "attachment-gallery-ui-testing-fixture"
        self.client = AttachmentClient()
        self.loadsRemotely = false
        self.attachments = uiTestingAttachments
        self.haptics = .shared
        self.temporaryFileStore = .shared
    }
#endif

    func load() async {
        guard loadsRemotely else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            attachments = try await client.list(contextType: contextType, contextId: contextId)
        } catch {
            guard !Task.isCancelled else { return }
            failure = .loadFailed
        }
    }

    func apply(_ attachments: [AttachmentDTO]) {
        guard !loadsRemotely else { return }
        self.attachments = attachments
    }

    func delete(_ attachment: AttachmentDTO) async {
        do {
            try await client.delete(attachment.id)
            attachments.removeAll { $0.id == attachment.id }
            haptics.emit(.success)
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            recordFailure(.deleteFailed)
        }
    }

    func move(from index: Int, by offset: Int) async {
        guard offset != 0 else { return }
        let destination = index + offset
        guard attachments.indices.contains(index), attachments.indices.contains(destination) else {
            return
        }
        attachments.swapAt(index, destination)
        haptics.emit(.selection)
        do {
            try await client.reorder(
                contextType: contextType,
                contextId: contextId,
                orderedAttachmentIds: attachments.map(\.id)
            )
        } catch {
            attachments.swapAt(index, destination)
            if Task.isCancelled || error is CancellationError { return }
            recordFailure(.reorderFailed)
        }
    }

    func localFile(for attachment: AttachmentDTO) async throws -> URL {
        let downloaded = try await client.download(attachment, inline: false)
        return try temporaryFileStore.write(
            downloaded.data,
            for: attachment.id,
            filename: downloaded.filename
        )
    }

    func removeTemporaryFile(at url: URL) {
        temporaryFileStore.remove(url)
    }

    func recordFailure(_ failure: AttachmentGalleryFailure) {
        self.failure = failure
        haptics.emit(.error)
    }

    func attachmentOpened() {
        haptics.emit(.routine)
    }

}

nonisolated enum AttachmentGalleryFailure: String, Identifiable, Sendable {
    case loadFailed
    case downloadFailed
    case deleteFailed
    case reorderFailed

    var id: String { rawValue }

    var messageKey: String {
        switch self {
        case .loadFailed: "attachment.error.load"
        case .downloadFailed: "attachment.error.download"
        case .deleteFailed: "attachment.error.delete"
        case .reorderFailed: "attachment.error.reorder"
        }
    }
}

/// Identifies the attachment awaiting delete confirmation so the shared
/// confirmation presentation can be driven by its item binding.
nonisolated struct AttachmentDeletionCandidate: Identifiable, Equatable, Sendable {
    let attachment: AttachmentDTO

    var id: AttachmentID { attachment.id }
}

struct AttachmentGallery: View {
    @ObservedObject var model: AttachmentGalleryModel
    let canEdit: Bool

    @State private var previewURL: URL?
    @State private var shareURL: URL?
    @State private var deleteCandidate: AttachmentDeletionCandidate?
    @State private var isPreparingFile = false
    @State private var preparationTask: Task<Void, Never>?

    init(model: AttachmentGalleryModel, canEdit: Bool = false) {
        self.model = model
        self.canEdit = canEdit
    }

    var body: some View {
        Group {
            if model.isLoading && model.attachments.isEmpty {
                ProgressView(AttachmentLocalization.text("attachment.loading"))
                    .frame(maxWidth: .infinity)
            } else if model.attachments.isEmpty {
                Text(AttachmentLocalization.text("attachment.empty"))
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: DPSpacing.small) {
                    Label {
                        Text(
                            AttachmentLocalization.format(
                                "attachment.gallery.label",
                                Int64(model.attachments.count)
                            )
                        )
                    } icon: {
                        Image(systemName: "paperclip")
                    }
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: DPSpacing.small),
                            GridItem(.flexible(), spacing: DPSpacing.small)
                        ],
                        spacing: DPSpacing.small
                    ) {
                        ForEach(Array(model.attachments.enumerated()), id: \.element.id) { index, attachment in
                            galleryCard(attachment, at: index)
                        }
                    }
                }
            }
        }
        .task { await model.load() }
        .quickLookPreview(previewBinding)
        .sheet(
            isPresented: Binding(
                get: { shareURL != nil },
                set: { isPresented in
                    if !isPresented {
                        dismissShare()
                    }
                }
            )
        ) {
            if let shareURL {
                AttachmentShareSheet(items: [shareURL])
            }
        }
        .dpConfirmation(
            item: $deleteCandidate,
            copy: { candidate in
                DPConfirmationCopy(
                    title: AttachmentLocalization.text("attachment.delete.title"),
                    message: candidate.attachment.originalFilename,
                    confirmTitle: AttachmentLocalization.text("attachment.action.delete"),
                    cancelTitle: AttachmentLocalization.text("attachment.action.cancel"),
                    isDestructive: true
                )
            },
            confirm: { candidate, dismiss in
                dismiss()
                Task { await model.delete(candidate.attachment) }
            }
        )
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
        .onDisappear {
            preparationTask?.cancel()
            preparationTask = nil
            dismissPreview()
            dismissShare()
        }
        .overlay {
            if isPreparingFile {
                ProgressView()
                    .padding(DPSpacing.medium)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DPRadius.standard))
            }
        }
    }

    private func galleryCard(_ attachment: AttachmentDTO, at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                prepare(attachment, forSharing: false)
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    AttachmentThumbnail(attachment: attachment)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(Rectangle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(attachment.originalFilename)
                            .font(DPTypography.label)
                            .foregroundStyle(DPColor.textPrimary)
                            .lineLimit(1)
                        Text(AttachmentFormatting.bytes(attachment.size))
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                    }
                    .padding(DPSpacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(AttachmentLocalization.text("attachment.action.preview"))

            HStack(spacing: 0) {
                if canEdit {
                    Menu {
                        Button {
                            Task { await model.move(from: index, by: -1) }
                        } label: {
                            Label(
                                AttachmentLocalization.text("attachment.action.moveUp"),
                                systemImage: "arrow.up"
                            )
                        }
                        .disabled(index == 0)

                        Button {
                            Task { await model.move(from: index, by: 1) }
                        } label: {
                            Label(
                                AttachmentLocalization.text("attachment.action.moveDown"),
                                systemImage: "arrow.down"
                            )
                        }
                        .disabled(index == model.attachments.count - 1)

                        Button(role: .destructive) {
                            requestDelete(attachment)
                        } label: {
                            Label(
                                AttachmentLocalization.text("attachment.action.delete"),
                                systemImage: "trash"
                            )
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(DPColor.textOnDark)
                            .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                            .background(Color.black.opacity(0.50))
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(AttachmentLocalization.text("attachment.action.more"))
                    .accessibilityIdentifier("attachment.\(attachment.id.uuidString).more")
                }

                Button {
                    prepare(attachment, forSharing: true)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(DPColor.textOnDark)
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                        .background(Color.black.opacity(0.50))
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(AttachmentLocalization.text("attachment.action.share"))
            }
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
                .allowsHitTesting(false)
        }
        .contextMenu {
            Button {
                prepare(attachment, forSharing: true)
            } label: {
                Label(
                    AttachmentLocalization.text("attachment.action.share"),
                    systemImage: "square.and.arrow.up"
                )
            }

            if canEdit {
                Button {
                    Task { await model.move(from: index, by: -1) }
                } label: {
                    Label(
                        AttachmentLocalization.text("attachment.action.moveUp"),
                        systemImage: "arrow.up"
                    )
                }
                .disabled(index == 0)

                Button {
                    Task { await model.move(from: index, by: 1) }
                } label: {
                    Label(
                        AttachmentLocalization.text("attachment.action.moveDown"),
                        systemImage: "arrow.down"
                    )
                }
                .disabled(index == model.attachments.count - 1)

                Button(role: .destructive) {
                    requestDelete(attachment)
                } label: {
                    Label(
                        AttachmentLocalization.text("attachment.action.delete"),
                        systemImage: "trash"
                    )
                }
            }
        }
    }

    private func prepare(_ attachment: AttachmentDTO, forSharing: Bool) {
        guard !isPreparingFile else { return }
        isPreparingFile = true
        preparationTask = Task {
            var preparedURL: URL?
            defer { isPreparingFile = false }
            do {
                let url = try await model.localFile(for: attachment)
                preparedURL = url
                try Task.checkCancellation()
                if forSharing {
                    shareURL = url
                } else {
                    previewURL = url
                }
                preparedURL = nil
                model.attachmentOpened()
            } catch {
                if let preparedURL {
                    model.removeTemporaryFile(at: preparedURL)
                }
                guard !Task.isCancelled else { return }
                model.recordFailure(.downloadFailed)
            }
        }
    }

    private func requestDelete(_ attachment: AttachmentDTO) {
        deleteCandidate = AttachmentDeletionCandidate(attachment: attachment)
    }

    private var previewBinding: Binding<URL?> {
        Binding(
            get: { previewURL },
            set: { value in
                if value == nil {
                    dismissPreview()
                } else {
                    previewURL = value
                }
            }
        )
    }

    private func dismissPreview() {
        if let previewURL {
            model.removeTemporaryFile(at: previewURL)
        }
        previewURL = nil
    }

    private func dismissShare() {
        if let shareURL {
            model.removeTemporaryFile(at: shareURL)
        }
        shareURL = nil
    }
}

#if DEBUG
struct AttachmentGalleryUITestingFixtureView: View {
    private static let attachmentID = UUID(
        uuidString: "11111111-2222-3333-4444-555555555555"
    )!

    @StateObject private var model: AttachmentGalleryModel

    init() {
        _model = StateObject(
            wrappedValue: AttachmentGalleryModel(
                uiTestingAttachments: [
                    AttachmentDTO(
                        id: Self.attachmentID,
                        contextType: .todo,
                        contextId: "attachment-gallery-ui-testing-fixture",
                        originalFilename: "교대표-확인용.pdf",
                        contentType: "application/pdf",
                        size: 128_000,
                        hasThumbnail: false,
                        thumbnailUrl: nil,
                        orderIndex: 0,
                        createdAt: "2026-08-15T00:00:00Z",
                        createdBy: 1
                    )
                ]
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DPSpacing.large) {
                Text(verbatim: "첨부파일 삭제 UI 검증")
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)

                AttachmentGallery(model: model, canEdit: true)
            }
            .padding(DPSpacing.large)
        }
        .background(DPColor.backgroundPrimary)
        .accessibilityIdentifier("screen.attachmentGallery.fixture")
    }
}
#endif

private struct AttachmentShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
