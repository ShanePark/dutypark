import Combine
import QuickLook
import SwiftUI
import UIKit

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

    private let client: AttachmentClient

    init(
        contextType: AttachmentContextType,
        contextId: String,
        client: AttachmentClient = AttachmentClient()
    ) {
        self.contextType = contextType
        self.contextId = contextId
        self.client = client
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            attachments = try await client.list(contextType: contextType, contextId: contextId)
        } catch {
            failure = .loadFailed
        }
    }

    func delete(_ attachment: AttachmentDTO) async {
        do {
            try await client.delete(attachment.id)
            attachments.removeAll { $0.id == attachment.id }
        } catch {
            failure = .deleteFailed
        }
    }

    func move(from index: Int, by offset: Int) async {
        let destination = index + offset
        guard attachments.indices.contains(index), attachments.indices.contains(destination) else {
            return
        }
        attachments.swapAt(index, destination)
        do {
            try await client.reorder(
                contextType: contextType,
                contextId: contextId,
                orderedAttachmentIds: attachments.map(\.id)
            )
        } catch {
            attachments.swapAt(index, destination)
            failure = .reorderFailed
        }
    }

    func localFile(for attachment: AttachmentDTO) async throws -> URL {
        let downloaded = try await client.download(attachment)
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DutyparkAttachments", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(
            path: "\(attachment.id.uuidString)-\(safeFilename(downloaded.filename))",
            directoryHint: .notDirectory
        )
        try downloaded.data.write(to: url, options: .atomic)
        return url
    }

    private func safeFilename(_ filename: String) -> String {
        let value = filename
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "\0", with: "")
        return value.isEmpty ? "attachment" : value
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

struct AttachmentGallery: View {
    @ObservedObject var model: AttachmentGalleryModel
    let canEdit: Bool

    @State private var previewURL: URL?
    @State private var shareURL: URL?
    @State private var deleteCandidate: AttachmentDTO?
    @State private var isPreparingFile = false

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
                    .font(.subheadline)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: DPSpacing.small) {
                    ForEach(Array(model.attachments.enumerated()), id: \.element.id) { index, attachment in
                        galleryRow(attachment, at: index)
                    }
                }
            }
        }
        .task { await model.load() }
        .quickLookPreview($previewURL)
        .sheet(
            isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } }
            )
        ) {
            if let shareURL {
                AttachmentShareSheet(items: [shareURL])
            }
        }
        .confirmationDialog(
            AttachmentLocalization.text("attachment.delete.title"),
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(AttachmentLocalization.text("attachment.action.delete"), role: .destructive) {
                guard let deleteCandidate else { return }
                self.deleteCandidate = nil
                Task { await model.delete(deleteCandidate) }
            }
            Button(AttachmentLocalization.text("attachment.action.cancel"), role: .cancel) {
                deleteCandidate = nil
            }
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
        .overlay {
            if isPreparingFile {
                ProgressView()
                    .padding(DPSpacing.medium)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DPRadius.standard))
            }
        }
    }

    private func galleryRow(_ attachment: AttachmentDTO, at index: Int) -> some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                prepare(attachment, forSharing: false)
            } label: {
                HStack(spacing: DPSpacing.small) {
                    AttachmentThumbnail(attachment: attachment)
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        Text(attachment.originalFilename)
                            .font(.subheadline)
                            .foregroundStyle(DPColor.textPrimary)
                            .lineLimit(1)
                        Text(AttachmentFormatting.bytes(attachment.size))
                            .font(.caption)
                            .foregroundStyle(DPColor.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(AttachmentLocalization.text("attachment.action.preview"))

            Menu {
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
                        deleteCandidate = attachment
                    } label: {
                        Label(
                            AttachmentLocalization.text("attachment.action.delete"),
                            systemImage: "trash"
                        )
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(AttachmentLocalization.text("attachment.action.more"))
        }
        .padding(DPSpacing.small)
        .background(DPColor.backgroundCard)
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary)
        }
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
    }

    private func prepare(_ attachment: AttachmentDTO, forSharing: Bool) {
        guard !isPreparingFile else { return }
        isPreparingFile = true
        Task {
            defer { isPreparingFile = false }
            do {
                let url = try await model.localFile(for: attachment)
                if forSharing {
                    shareURL = url
                } else {
                    previewURL = url
                }
            } catch {
                model.failure = .downloadFailed
            }
        }
    }
}

private struct AttachmentShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
