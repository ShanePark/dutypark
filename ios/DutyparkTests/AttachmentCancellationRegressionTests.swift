import Foundation
import Testing
@testable import Dutypark

@MainActor
@Suite
struct AttachmentCancellationRegressionTests {
    @Test
    func cancelledPreparationCannotCreateSessionOrUploadLateFile() async throws {
        let client = AttachmentCancellationClient()
        let model = AttachmentPickerModel(contextType: .todo, client: client)
        let lateFile = try AttachmentUploadFile(
            filename: "late.jpg",
            contentType: "image/jpeg",
            data: Data([0x01])
        )

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await model.add(files: [lateFile])
        }
        await task.value

        let snapshot = await client.snapshot()
        #expect(snapshot.createSessionCount == 0)
        #expect(snapshot.uploadCount == 0)
        #expect(model.attachmentSessionId == nil)
        #expect(model.attachments.isEmpty)
        #expect(model.failure == nil)
    }
}

private actor AttachmentCancellationClient: AttachmentPickerClient {
    struct Snapshot: Sendable {
        let createSessionCount: Int
        let uploadCount: Int
    }

    private var createSessionCount = 0
    private var uploadCount = 0

    func createSession(
        contextType: AttachmentContextType,
        targetContextId: String?
    ) async throws -> CreateAttachmentSessionResponse {
        createSessionCount += 1
        return CreateAttachmentSessionResponse(
            sessionId: UUID(),
            expiresAt: "2026-08-15T00:00:00Z",
            contextType: contextType
        )
    }

    func discardSession(_ sessionId: UUID) async throws {}

    func upload(
        _ file: AttachmentUploadFile,
        sessionId: UUID
    ) async throws -> AttachmentDTO {
        uploadCount += 1
        return AttachmentDTO(
            id: UUID(),
            contextType: .todo,
            contextId: nil,
            originalFilename: file.filename,
            contentType: file.contentType,
            size: Int64(file.data.count),
            hasThumbnail: false,
            thumbnailUrl: nil,
            orderIndex: 0,
            createdAt: "2026-08-14T00:00:00Z",
            createdBy: 42
        )
    }

    func snapshot() -> Snapshot {
        Snapshot(
            createSessionCount: createSessionCount,
            uploadCount: uploadCount
        )
    }
}
