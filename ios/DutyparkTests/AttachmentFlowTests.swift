import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Dutypark

@MainActor
@Suite(.serialized)
struct AttachmentFlowTests {
    @Test
    func fileLoaderPreservesKnownTypeAndFallsBackForUnknownType() throws {
        let text = Data("plain text".utf8)
        let textURL = try temporaryFile(contents: text, extension: "txt")
        let unknownURL = try temporaryFile(contents: Data([0x01]), extension: "dutypark-unknown")
        defer {
            try? FileManager.default.removeItem(at: textURL)
            try? FileManager.default.removeItem(at: unknownURL)
        }

        let textFile = try AttachmentFileLoader.load(from: textURL)
        let unknownFile = try AttachmentFileLoader.load(from: unknownURL)

        #expect(textFile.filename == textURL.lastPathComponent)
        #expect(textFile.contentType == "text/plain")
        #expect(textFile.data == text)
        #expect(unknownFile.contentType == "application/octet-stream")
    }

    @Test
    func fileLoaderMapsMissingFileToUnreadable() {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-missing-\(UUID().uuidString).txt")

        #expect(throws: AttachmentUploadError.unreadableFile) {
            try AttachmentFileLoader.load(from: url)
        }
    }

    @Test
    func uploadPolicyAcceptsOneByteBelowLimitAndRejectsExactLimit() throws {
        let accepted = try AttachmentUploadFile(
            filename: "accepted.bin",
            contentType: "",
            data: Data(count: AttachmentUploadPolicy.safeMaximumBytes - 1)
        )

        #expect(accepted.data.count == AttachmentUploadPolicy.safeMaximumBytes - 1)
        #expect(accepted.contentType == "application/octet-stream")
        #expect(throws: AttachmentUploadError.tooLarge) {
            try AttachmentUploadFile(
                filename: "rejected.bin",
                contentType: "application/octet-stream",
                data: Data(count: AttachmentUploadPolicy.safeMaximumBytes)
            )
        }
    }

    @Test
    func invalidHEICPayloadFailsConversion() {
        #expect(throws: AttachmentUploadError.imageConversionFailed) {
            try AttachmentFileLoader.preparedFile(
                data: Data("not an image".utf8),
                filename: "photo.heic",
                type: .heic
            )
        }
    }

    @Test
    func fileLoaderBalancesSecurityScopedAccessWhenPreparationFails() throws {
        let url = try temporaryFile(contents: Data())
        defer { try? FileManager.default.removeItem(at: url) }
        var startCount = 0
        var stopCount = 0

        #expect(throws: AttachmentUploadError.emptyFile) {
            try AttachmentFileLoader.load(
                from: url,
                startAccessing: { _ in
                    startCount += 1
                    return true
                },
                stopAccessing: { _ in stopCount += 1 }
            )
        }
        #expect(startCount == 1)
        #expect(stopCount == 1)
    }

    @Test
    func fileLoaderDoesNotStopSecurityScopedAccessItDidNotAcquire() throws {
        let bytes = Data("plain text".utf8)
        let url = try temporaryFile(contents: bytes, extension: "txt")
        defer { try? FileManager.default.removeItem(at: url) }
        var stopCount = 0

        let file = try AttachmentFileLoader.load(
            from: url,
            startAccessing: { _ in false },
            stopAccessing: { _ in stopCount += 1 }
        )

        #expect(file.filename == url.lastPathComponent)
        #expect(file.contentType == "text/plain")
        #expect(file.data == bytes)
        #expect(stopCount == 0)
    }

    @Test
    func pickerUploadsSequentiallyAndPreservesResponseOrder() async throws {
        let sessionId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let firstAttachment = attachment(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            filename: "first.txt"
        )
        let secondAttachment = attachment(
            id: UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!,
            filename: "second.txt"
        )
        let client = AttachmentFlowClientStub(
            sessionId: sessionId,
            uploadOutcomes: [.success(firstAttachment), .success(secondAttachment)]
        )
        let model = AttachmentPickerModel(contextType: .todo, client: client)

        await model.add(files: [
            try uploadFile(named: "first.txt"),
            try uploadFile(named: "second.txt")
        ])

        let snapshot = await client.snapshot()
        #expect(snapshot.createSessionCount == 1)
        #expect(snapshot.uploadedFilenames == ["first.txt", "second.txt"])
        #expect(snapshot.uploadSessionIds == [sessionId, sessionId])
        #expect(model.attachmentSessionId == sessionId)
        #expect(model.attachments.map(\.id) == [firstAttachment.id, secondAttachment.id])
        #expect(!model.isBusy)
        #expect(model.uploadProgress == nil)
        #expect(model.failure == nil)
    }

    @Test
    func pickerEmitsOneOutcomeForAnEntireUploadBatch() async throws {
        let haptics = DPHapticCenter()
        let client = AttachmentFlowClientStub(
            uploadOutcomes: [
                .success(attachment(id: UUID(), filename: "first.txt")),
                .success(attachment(id: UUID(), filename: "second.txt"))
            ]
        )
        let model = AttachmentPickerModel(
            contextType: .todo,
            client: client,
            haptics: haptics
        )

        await model.add(files: [
            try uploadFile(named: "first.txt"),
            try uploadFile(named: "second.txt")
        ])

        #expect(haptics.event?.kind == .success)
        #expect(haptics.event?.id == 1)
    }

    @Test
    func pickerUsesSelectionForValidReorderWhileRemovalReliesOnItsWarningButton() async throws {
        let first = attachment(id: UUID(), filename: "first.txt")
        let second = attachment(id: UUID(), filename: "second.txt")
        let haptics = DPHapticCenter()
        let model = AttachmentPickerModel(
            contextType: .todo,
            existingAttachments: [first, second],
            haptics: haptics
        )

        model.move(from: 0, by: 1)
        #expect(haptics.event?.kind == .selection)
        #expect(haptics.event?.id == 1)

        model.move(from: 0, by: -1)
        #expect(haptics.event?.id == 1)

        model.remove(first.id)
        #expect(haptics.event?.kind == .selection)
        #expect(haptics.event?.id == 1)

        model.remove(first.id)
        #expect(haptics.event?.id == 1)
    }

    @Test
    func galleryUsesSelectionForReorderAndSuccessForCompletedDeletion() async {
        let first = attachment(id: UUID(), filename: "first.txt")
        let second = attachment(id: UUID(), filename: "second.txt")
        let haptics = DPHapticCenter()
        let model = AttachmentGalleryModel(
            contextType: .todo,
            contextId: "todo-1",
            attachments: [first, second],
            client: AttachmentGalleryFlowClientStub(),
            haptics: haptics
        )

        await model.move(from: 0, by: 1)
        #expect(haptics.event?.kind == .selection)
        #expect(haptics.event?.id == 1)

        await model.delete(second)
        #expect(haptics.event?.kind == .success)
        #expect(haptics.event?.id == 2)
    }

    @Test
    func pickerStopsAfterFailureThenRetriesWithTheExistingSession() async throws {
        let sessionId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let firstAttachment = attachment(id: UUID(), filename: "first.txt")
        let retriedAttachment = attachment(id: UUID(), filename: "retry.txt")
        let client = AttachmentFlowClientStub(
            sessionId: sessionId,
            uploadOutcomes: [
                .success(firstAttachment),
                .failure(.server(status: 400, code: "attachment.extension.blocked")),
                .success(retriedAttachment)
            ]
        )
        let model = AttachmentPickerModel(
            contextType: .schedule,
            targetContextId: "73",
            client: client
        )

        await model.add(files: [
            try uploadFile(named: "first.txt"),
            try uploadFile(named: "blocked.exe"),
            try uploadFile(named: "never-uploaded.txt")
        ])

        #expect(model.failure == .blockedExtension)
        #expect(model.attachments.map(\.id) == [firstAttachment.id])
        #expect((await client.snapshot()).uploadedFilenames == ["first.txt", "blocked.exe"])

        model.failure = nil
        await model.add(files: [try uploadFile(named: "retry.txt")])

        let snapshot = await client.snapshot()
        #expect(snapshot.createSessionCount == 1)
        #expect(snapshot.createdContextTypes == [.schedule])
        #expect(snapshot.createdTargetContextIds == ["73"])
        #expect(snapshot.uploadedFilenames == ["first.txt", "blocked.exe", "retry.txt"])
        #expect(model.attachments.map(\.id) == [firstAttachment.id, retriedAttachment.id])
        #expect(model.failure == nil)
    }

    @Test
    func cancellingUploadClearsTransientStateAndEmptySaveDiscardsSession() async throws {
        let sessionId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let client = AttachmentFlowClientStub(
            sessionId: sessionId,
            uploadOutcomes: [.suspended]
        )
        let model = AttachmentPickerModel(contextType: .todo, client: client)
        let file = try uploadFile(named: "slow.mov")

        let uploadTask = Task { await model.add(files: [file]) }
        #expect(await waitUntil { await client.snapshot().uploadedFilenames == ["slow.mov"] })
        #expect(model.isUploading)
        #expect(model.uploadProgress?.currentFilename == "slow.mov")

        uploadTask.cancel()
        await uploadTask.value

        #expect(!model.isBusy)
        #expect(model.uploadProgress == nil)
        #expect(model.failure == nil)
        #expect(model.attachmentSessionId == sessionId)
        #expect((await client.snapshot()).cancelledUploadCount == 1)

        let result = await model.resultForSave()

        #expect(result?.attachmentSessionId == nil)
        #expect(result?.attachments.isEmpty == true)
        #expect(model.attachmentSessionId == nil)
        #expect((await client.snapshot()).discardedSessionIds == [sessionId])
    }

    @Test
    func pickerIgnoresASecondBatchWhileAnUploadIsRunning() async throws {
        let client = AttachmentFlowClientStub(uploadOutcomes: [.suspended])
        let model = AttachmentPickerModel(contextType: .todo, client: client)
        let first = try uploadFile(named: "first.mov")
        let ignored = try uploadFile(named: "ignored.txt")
        let uploadTask = Task { await model.add(files: [first]) }
        #expect(await waitUntil { await client.snapshot().uploadedFilenames == ["first.mov"] })

        await model.add(files: [ignored])

        #expect((await client.snapshot()).uploadedFilenames == ["first.mov"])
        uploadTask.cancel()
        await uploadTask.value
    }

    @Test
    func pickerMoveAndSaveResultKeepTheVisibleOrderWithoutDiscardingNonemptySession() async throws {
        let sessionId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let first = attachment(id: UUID(), filename: "first.txt")
        let second = attachment(id: UUID(), filename: "second.txt")
        let client = AttachmentFlowClientStub(
            sessionId: sessionId,
            uploadOutcomes: [.success(first), .success(second)]
        )
        let model = AttachmentPickerModel(contextType: .todo, client: client)
        await model.add(files: [
            try uploadFile(named: "first.txt"),
            try uploadFile(named: "second.txt")
        ])

        model.move(from: 0, by: 1)
        model.move(from: 0, by: -1)
        model.move(from: 1, by: 1)
        let result = await model.resultForSave()

        #expect(result?.attachmentSessionId == sessionId)
        #expect(result?.orderedAttachmentIds == [second.id, first.id])
        #expect((await client.snapshot()).discardedSessionIds.isEmpty)
    }

    @Test
    func pickerMapsServerSizeAndUnknownFailures() async throws {
        let client = AttachmentFlowClientStub(
            uploadOutcomes: [
                .failure(.server(status: 413, code: "attachment.size.exceeded")),
                .failure(.server(status: 500, code: "unexpected"))
            ]
        )
        let model = AttachmentPickerModel(contextType: .todo, client: client)

        await model.add(files: [try uploadFile(named: "large.bin")])
        #expect(model.failure == .tooLarge)

        model.failure = nil
        await model.add(files: [try uploadFile(named: "retry.bin")])
        #expect(model.failure == .uploadFailed)
        #expect((await client.snapshot()).createSessionCount == 1)
    }

    @Test
    func discardWithoutSessionIsANetworkNoOp() async {
        let client = AttachmentFlowClientStub()
        let model = AttachmentPickerModel(contextType: .todo, client: client)

        #expect(await model.discard())
        #expect((await client.snapshot()).discardedSessionIds.isEmpty)
    }

    @Test
    func embeddedAttachmentsAreVisibleBeforeAnyRemoteLoad() async {
        let contextId = UUID().uuidString
        let attachment = embeddedAttachment(contextId: contextId, filename: "photo.jpg")
        let model = AttachmentGalleryModel(
            contextType: .schedule,
            contextId: contextId,
            attachments: [attachment]
        )

        #expect(model.attachments.map(\.id) == [attachment.id])

        await model.load()
        #expect(model.attachments.map(\.id) == [attachment.id])

        let added = embeddedAttachment(contextId: contextId, filename: "second.jpg")
        model.apply([attachment, added])
        #expect(model.attachments.map(\.id) == [attachment.id, added.id])
    }

    private func temporaryFile(
        contents: Data,
        extension pathExtension: String = "bin"
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-attachment-flow-\(UUID().uuidString)")
            .appendingPathExtension(pathExtension)
        try contents.write(to: url, options: .atomic)
        return url
    }

    private func embeddedAttachment(contextId: String, filename: String) -> AttachmentDTO {
        AttachmentDTO(
            id: UUID(),
            contextType: .schedule,
            contextId: contextId,
            originalFilename: filename,
            contentType: "image/jpeg",
            size: 2048,
            hasThumbnail: true,
            thumbnailUrl: nil,
            orderIndex: 0,
            createdAt: "2026-08-17T00:00:00Z",
            createdBy: 1
        )
    }

    private func uploadFile(named filename: String) throws -> AttachmentUploadFile {
        try AttachmentUploadFile(
            filename: filename,
            contentType: "application/octet-stream",
            data: Data([0x01])
        )
    }

    private func attachment(id: UUID, filename: String) -> AttachmentDTO {
        AttachmentDTO(
            id: id,
            contextType: .todo,
            contextId: nil,
            originalFilename: filename,
            contentType: "text/plain",
            size: 1,
            hasThumbnail: false,
            thumbnailUrl: nil,
            orderIndex: 0,
            createdAt: "2026-08-14T00:00:00Z",
            createdBy: 42
        )
    }

    private func waitUntil(
        _ condition: @escaping () async -> Bool
    ) async -> Bool {
        for _ in 0..<1_000 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return false
    }
}

private actor AttachmentFlowClientStub: AttachmentPickerClient {
    enum UploadOutcome: Sendable {
        case success(AttachmentDTO)
        case failure(APIError)
        case suspended
    }

    struct Snapshot: Sendable {
        let createSessionCount: Int
        let createdContextTypes: [AttachmentContextType]
        let createdTargetContextIds: [String?]
        let uploadedFilenames: [String]
        let uploadSessionIds: [UUID]
        let cancelledUploadCount: Int
        let discardedSessionIds: [UUID]
    }

    private let sessionId: UUID
    private var uploadOutcomes: [UploadOutcome]
    private var createSessionCount = 0
    private var createdContextTypes: [AttachmentContextType] = []
    private var createdTargetContextIds: [String?] = []
    private var uploadedFilenames: [String] = []
    private var uploadSessionIds: [UUID] = []
    private var cancelledUploadCount = 0
    private var discardedSessionIds: [UUID] = []

    init(
        sessionId: UUID = UUID(),
        uploadOutcomes: [UploadOutcome] = []
    ) {
        self.sessionId = sessionId
        self.uploadOutcomes = uploadOutcomes
    }

    func createSession(
        contextType: AttachmentContextType,
        targetContextId: String?
    ) async throws -> CreateAttachmentSessionResponse {
        createSessionCount += 1
        createdContextTypes.append(contextType)
        createdTargetContextIds.append(targetContextId)
        return CreateAttachmentSessionResponse(
            sessionId: sessionId,
            expiresAt: "2026-08-15T00:00:00Z",
            contextType: contextType
        )
    }

    func discardSession(_ sessionId: UUID) async throws {
        discardedSessionIds.append(sessionId)
    }

    func upload(
        _ file: AttachmentUploadFile,
        sessionId: UUID
    ) async throws -> AttachmentDTO {
        uploadedFilenames.append(file.filename)
        uploadSessionIds.append(sessionId)
        guard !uploadOutcomes.isEmpty else { throw APIError.transport }

        switch uploadOutcomes.removeFirst() {
        case .success(let attachment):
            return attachment
        case .failure(let error):
            throw error
        case .suspended:
            do {
                try await Task.sleep(for: .seconds(30))
                throw APIError.transport
            } catch is CancellationError {
                cancelledUploadCount += 1
                throw CancellationError()
            }
        }
    }

    func snapshot() -> Snapshot {
        Snapshot(
            createSessionCount: createSessionCount,
            createdContextTypes: createdContextTypes,
            createdTargetContextIds: createdTargetContextIds,
            uploadedFilenames: uploadedFilenames,
            uploadSessionIds: uploadSessionIds,
            cancelledUploadCount: cancelledUploadCount,
            discardedSessionIds: discardedSessionIds
        )
    }
}

private struct AttachmentGalleryFlowClientStub: AttachmentGalleryClient, Sendable {
    func list(
        contextType: AttachmentContextType,
        contextId: String
    ) async throws -> [AttachmentDTO] {
        []
    }

    func delete(_ attachmentId: AttachmentID) async throws {}

    func reorder(
        contextType: AttachmentContextType,
        contextId: String,
        orderedAttachmentIds: [AttachmentID]
    ) async throws {}

    func download(
        _ attachment: AttachmentDTO,
        inline: Bool
    ) async throws -> DownloadedAttachment {
        DownloadedAttachment(
            data: Data([0x01]),
            filename: attachment.originalFilename,
            contentType: attachment.contentType
        )
    }
}
