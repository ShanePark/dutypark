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
    func pickerLoadsEachSelectedFileLazilyBeforeUploadingIt() async throws {
        let firstAttachment = attachment(id: UUID(), filename: "first.txt")
        let secondAttachment = attachment(id: UUID(), filename: "second.txt")
        let client = AttachmentFlowClientStub(
            uploadOutcomes: [
                .success(firstAttachment),
                .success(secondAttachment)
            ]
        )
        let model = AttachmentPickerModel(contextType: .todo, client: client)
        let loadRecorder = AttachmentLoadRecorder()

        await model.add(totalFileCount: 2) { index in
            await loadRecorder.record(index)
            return try AttachmentUploadFile(
                filename: index == 0 ? "first.txt" : "second.txt",
                contentType: "text/plain",
                data: Data([UInt8(index + 1)])
            )
        }

        #expect(await loadRecorder.indices() == [0, 1])
        #expect((await client.snapshot()).uploadedFilenames == ["first.txt", "second.txt"])
        #expect(model.attachments.map(\.id) == [firstAttachment.id, secondAttachment.id])
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

    @Test
    func galleryWritesDownloadedFilesThroughThePurgeableStore() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-attachment-gallery-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let attachment = embeddedAttachment(
            contextId: UUID().uuidString,
            filename: "private.pdf"
        )
        let model = AttachmentGalleryModel(
            contextType: .schedule,
            contextId: attachment.contextId ?? "",
            attachments: [attachment],
            client: AttachmentGalleryFlowClientStub(),
            temporaryFileStore: AttachmentTemporaryFileStore(directoryURL: directory)
        )

        let url = try await model.localFile(for: attachment)
        #expect(FileManager.default.fileExists(atPath: url.path))

        model.removeTemporaryFile(at: url)

        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    /// A file being attached previews the way the gallery does: downloaded into the purgeable
    /// temporary store, with a routine impact once Quick Look can open it.
    @Test
    func pickerPreviewWritesTheDownloadThroughThePurgeableStore() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-attachment-picker-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let pending = attachment(id: UUID(), filename: "photo.jpg")
        let haptics = DPHapticCenter()
        let model = AttachmentPickerModel(
            contextType: .todo,
            existingAttachments: [pending],
            client: AttachmentFlowClientStub(downloadOutcome: .success(Data([0x01, 0x02]))),
            haptics: haptics,
            temporaryFileStore: AttachmentTemporaryFileStore(directoryURL: directory)
        )

        let url = try #require(await model.previewFile(for: pending))
        #expect(url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL)
        #expect(try Data(contentsOf: url) == Data([0x01, 0x02]))
        #expect(haptics.event?.kind == .routine)
        #expect(haptics.event?.id == 1)
        #expect(model.failure == nil)

        model.releasePreviewFile(at: url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    /// An upload not yet bound to its schedule or todo cannot be downloaded back (the server
    /// answers `attachment.context.missing`), so a file added here previews from a local copy
    /// of the bytes that were uploaded, which outlives each preview.
    @Test
    func aNewlyAddedFilePreviewsFromItsLocalCopyWithoutDownloading() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-attachment-picker-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let uploaded = attachment(id: UUID(), filename: "photo.jpg")
        let client = AttachmentFlowClientStub(uploadOutcomes: [.success(uploaded)])
        let haptics = DPHapticCenter()
        let model = AttachmentPickerModel(
            contextType: .schedule,
            client: client,
            haptics: haptics,
            temporaryFileStore: AttachmentTemporaryFileStore(directoryURL: directory)
        )
        let bytes = Data([0xFF, 0xD8, 0xFF])
        await model.add(files: [try AttachmentUploadFile(filename: "photo.jpg", contentType: "image/jpeg", data: bytes)])

        let url = try #require(await model.previewFile(for: uploaded))
        #expect(try Data(contentsOf: url) == bytes)
        #expect((await client.snapshot()).downloadCount == 0)
        #expect(model.failure == nil)
        #expect(haptics.event?.kind == .routine)

        model.releasePreviewFile(at: url)
        #expect(FileManager.default.fileExists(atPath: url.path), "Kept for the next preview")
        let again = try #require(await model.previewFile(for: uploaded))
        #expect(again == url)
        #expect((await client.snapshot()).downloadCount == 0)
    }

    @Test
    func aSavedAttachmentStillPreviewsByDownloading() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-attachment-picker-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let saved = embeddedAttachment(contextId: UUID().uuidString, filename: "saved.jpg")
        let client = AttachmentFlowClientStub(downloadOutcome: .success(Data([0x07])))
        let model = AttachmentPickerModel(
            contextType: .schedule,
            targetContextId: saved.contextId,
            existingAttachments: [saved],
            client: client,
            temporaryFileStore: AttachmentTemporaryFileStore(directoryURL: directory)
        )

        let url = try #require(await model.previewFile(for: saved))
        #expect(try Data(contentsOf: url) == Data([0x07]))
        #expect((await client.snapshot()).downloadCount == 1)

        model.releasePreviewFile(at: url)
        #expect(!FileManager.default.fileExists(atPath: url.path), "A downloaded copy lasts one preview")
    }

    @Test
    func localCopiesAreRemovedWithTheirFileAndWhenThePickerIsDone() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-attachment-picker-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = attachment(id: UUID(), filename: "first.jpg")
        let second = attachment(id: UUID(), filename: "second.jpg")
        let client = AttachmentFlowClientStub(uploadOutcomes: [.success(first), .success(second)])
        let model = AttachmentPickerModel(
            contextType: .todo,
            client: client,
            temporaryFileStore: AttachmentTemporaryFileStore(directoryURL: directory)
        )
        await model.add(files: [try uploadFile(named: "first.jpg"), try uploadFile(named: "second.jpg")])
        let firstURL = try #require(await model.previewFile(for: first))
        let secondURL = try #require(await model.previewFile(for: second))

        model.remove(first.id)
        #expect(!FileManager.default.fileExists(atPath: firstURL.path))
        #expect(FileManager.default.fileExists(atPath: secondURL.path))

        model.releaseLocalFiles()
        #expect(!FileManager.default.fileExists(atPath: secondURL.path))
    }

    @Test
    func discardingTheSessionRemovesItsLocalCopies() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-attachment-picker-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let added = attachment(id: UUID(), filename: "added.jpg")
        let model = AttachmentPickerModel(
            contextType: .todo,
            client: AttachmentFlowClientStub(uploadOutcomes: [.success(added)]),
            temporaryFileStore: AttachmentTemporaryFileStore(directoryURL: directory)
        )
        await model.add(files: [try uploadFile(named: "added.jpg")])
        let url = try #require(await model.previewFile(for: added))

        #expect(await model.discard())
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func pickerPreviewFailureIsReportedAsADownloadError() async {
        let pending = attachment(id: UUID(), filename: "photo.jpg")
        let haptics = DPHapticCenter()
        let model = AttachmentPickerModel(
            contextType: .todo,
            existingAttachments: [pending],
            client: AttachmentFlowClientStub(downloadOutcome: .failure(.transport)),
            haptics: haptics
        )

        #expect(await model.previewFile(for: pending) == nil)
        #expect(model.failure == .downloadFailed)
        #expect(model.failure?.messageKey == "attachment.error.download")
        #expect(haptics.event?.kind == .error)
    }

    @Test
    func aCancelledPickerPreviewIsSilentAndLeavesNoFile() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-attachment-picker-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let pending = attachment(id: UUID(), filename: "photo.jpg")
        let haptics = DPHapticCenter()
        let model = AttachmentPickerModel(
            contextType: .todo,
            existingAttachments: [pending],
            client: AttachmentFlowClientStub(downloadOutcome: .suspended),
            haptics: haptics,
            temporaryFileStore: AttachmentTemporaryFileStore(directoryURL: directory)
        )

        let task = Task { await model.previewFile(for: pending) }
        try await Task.sleep(for: .milliseconds(20))
        task.cancel()

        #expect(await task.value == nil)
        #expect(model.failure == nil)
        #expect(haptics.event == nil)
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        #expect(leftovers.isEmpty)
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

    enum DownloadOutcome: Sendable {
        case success(Data)
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
        let downloadCount: Int
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
    private let downloadOutcome: DownloadOutcome
    private var downloadCount = 0

    init(
        sessionId: UUID = UUID(),
        uploadOutcomes: [UploadOutcome] = [],
        downloadOutcome: DownloadOutcome = .failure(.transport)
    ) {
        self.sessionId = sessionId
        self.uploadOutcomes = uploadOutcomes
        self.downloadOutcome = downloadOutcome
    }

    func download(_ attachment: AttachmentDTO, inline: Bool) async throws -> DownloadedAttachment {
        downloadCount += 1
        switch downloadOutcome {
        case .success(let data):
            return DownloadedAttachment(data: data, filename: attachment.originalFilename, contentType: attachment.contentType)
        case .failure(let error):
            throw error
        case .suspended:
            try await Task.sleep(for: .seconds(30))
            throw APIError.transport
        }
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
            discardedSessionIds: discardedSessionIds,
            downloadCount: downloadCount
        )
    }
}

private actor AttachmentLoadRecorder {
    private var recordedIndices: [Int] = []

    func record(_ index: Int) {
        recordedIndices.append(index)
    }

    func indices() -> [Int] {
        recordedIndices
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
