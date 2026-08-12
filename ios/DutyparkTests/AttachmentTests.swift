import Foundation
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import Dutypark

@MainActor
@Suite(.serialized)
struct AttachmentTests {
    private let baseURL = URL(string: "https://dutypark.test/api/")!

    @Test
    func resolvesEveryAttachmentStringFromDedicatedTable() throws {
        let keys = [
            "attachment.action.cancel",
            "attachment.action.cancelUpload",
            "attachment.action.delete",
            "attachment.action.files",
            "attachment.action.more",
            "attachment.action.moveDown",
            "attachment.action.moveUp",
            "attachment.action.ok",
            "attachment.action.photos",
            "attachment.action.preview",
            "attachment.action.remove",
            "attachment.action.share",
            "attachment.delete.title",
            "attachment.empty",
            "attachment.error.blockedExtension",
            "attachment.error.conversion",
            "attachment.error.delete",
            "attachment.error.discard",
            "attachment.error.download",
            "attachment.error.empty",
            "attachment.error.load",
            "attachment.error.reorder",
            "attachment.error.title",
            "attachment.error.tooLarge",
            "attachment.error.unreadable",
            "attachment.error.upload",
            "attachment.gallery.label",
            "attachment.loading",
            "attachment.upload.current",
            "attachment.upload.overall",
            "attachment.uploading"
        ]

        #expect(keys.allSatisfy { AttachmentLocalization.text($0) != $0 })
        for locale in ["en", "ko"] {
            let url = try #require(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try #require(Bundle(url: url))
            #expect(keys.allSatisfy {
                bundle.localizedString(forKey: $0, value: $0, table: "Attachments") != $0
            })
        }
    }

    @Test
    func galleryCountUsesTheWebAttachmentLabel() {
        let label = AttachmentLocalization.format("attachment.gallery.label", Int64(3))

        #expect(label.contains("3"))
        #expect(!label.contains("%lld"))
    }

    @Test
    func multipartBodyIncludesSessionAndUnmodifiedFileBytes() throws {
        let sessionId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let bytes = Data([0x00, 0x01, 0xFE, 0xFF])
        let file = try AttachmentUploadFile(
            filename: "test\"\r\n.png",
            contentType: "image/png",
            data: bytes
        )

        let body = MultipartFormData.body(
            sessionId: sessionId,
            file: file,
            boundary: "BOUNDARY"
        )

        #expect(body.range(of: Data("name=\"sessionId\"".utf8)) != nil)
        #expect(body.range(of: Data(sessionId.uuidString.utf8)) != nil)
        #expect(body.range(of: Data("filename=\"test_.png\"".utf8)) != nil)
        #expect(body.range(of: Data("Content-Type: image/png".utf8)) != nil)
        #expect(body.range(of: bytes) != nil)
        let ending = Data("--BOUNDARY--\r\n".utf8)
        #expect(Data(body.suffix(ending.count)) == ending)
    }

    @Test
    func rejectsEmptyAndTenMegabyteFilesBeforeUpload() {
        #expect(throws: AttachmentUploadError.emptyFile) {
            try AttachmentUploadFile(
                filename: "empty.txt",
                contentType: "text/plain",
                data: Data()
            )
        }
        #expect(throws: AttachmentUploadError.tooLarge) {
            try AttachmentUploadFile(
                filename: "large.bin",
                contentType: "application/octet-stream",
                data: Data(count: AttachmentUploadPolicy.safeMaximumBytes)
            )
        }
    }

    @Test
    func rejectsTenMegabyteFileFromMetadataBeforeLoadingContents() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-attachment-limit-\(UUID().uuidString).bin")
        _ = FileManager.default.createFile(
            atPath: url.path,
            contents: nil
        )
        defer { try? FileManager.default.removeItem(at: url) }
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(AttachmentUploadPolicy.safeMaximumBytes))
        try handle.close()

        #expect(throws: AttachmentUploadError.tooLarge) {
            try AttachmentFileLoader.validateFileSize(at: url)
        }
    }

    @Test
    func uploadProgressReportsOverallAndCurrentFile() {
        let progress = AttachmentUploadProgress(
            completedFileCount: 1,
            totalFileCount: 4,
            currentFilename: "schedule.pdf"
        )

        #expect(progress.overallFraction == 0.25)
        #expect(progress.currentFileNumber == 2)
        #expect(progress.currentFilename == "schedule.pdf")
    }

    @Test
    func convertsHEICSelectionToJPEG() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        let source = renderer.pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }

        let file = try AttachmentFileLoader.preparedFile(
            data: source,
            filename: "photo.heic",
            type: .heic
        )

        #expect(file.filename == "photo.jpg")
        #expect(file.contentType == "image/jpeg")
        #expect(file.data.starts(with: [0xFF, 0xD8]))
    }

    @Test
    func clientUsesAttachmentSessionAndMultipartContracts() async throws {
        let sessionId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let attachmentId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let recorder = AttachmentRequestRecorder()
        AttachmentURLProtocol.handler = { request in
            recorder.record(request)
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/attachments/sessions"):
                return Self.response(
                    request,
                    status: 200,
                    body: """
                    {"sessionId":"\(sessionId)","expiresAt":"2026-08-13T00:00:00Z","contextType":"TODO"}
                    """
                )
            case ("POST", "/api/attachments"):
                return Self.response(
                    request,
                    status: 200,
                    body: Self.attachmentJSON(id: attachmentId)
                )
            case ("DELETE", "/api/attachments/sessions/\(sessionId.uuidString)"):
                return Self.response(request, status: 204)
            default:
                return Self.response(request, status: 404)
            }
        }
        defer { AttachmentURLProtocol.handler = nil }

        let client = AttachmentClient(apiClient: makeAPIClient())
        let session = try await client.createSession(contextType: .todo, targetContextId: "42")
        let attachment = try await client.upload(
            try AttachmentUploadFile(
                filename: "memo.txt",
                contentType: "text/plain",
                data: Data("hello".utf8)
            ),
            sessionId: session.sessionId
        )
        try await client.discardSession(session.sessionId)

        #expect(attachment.id == attachmentId)
        let requests = recorder.requests
        #expect(requests.count == 3)
        #expect(requests[0].url?.path == "/api/attachments/sessions")
        #expect(requests[1].value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data; boundary=") == true)
        #expect(requests[2].url?.path == "/api/attachments/sessions/\(sessionId.uuidString)")
    }

    @Test
    func clientPreservesRequestedAttachmentOrder() async throws {
        let first = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let second = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let recorder = AttachmentRequestRecorder()
        AttachmentURLProtocol.handler = { request in
            recorder.record(request)
            return Self.response(request, status: 204)
        }
        defer { AttachmentURLProtocol.handler = nil }

        let payload = ReorderAttachmentsRequest(
            contextType: .schedule,
            contextId: "73",
            orderedAttachmentIds: [second, first]
        )
        let decoded = try JSONDecoder().decode(
            ReorderAttachmentsRequest.self,
            from: JSONEncoder().encode(payload)
        )
        try await AttachmentClient(apiClient: makeAPIClient()).reorder(
            contextType: payload.contextType,
            contextId: payload.contextId,
            orderedAttachmentIds: payload.orderedAttachmentIds
        )

        let request = try #require(recorder.requests.first)
        #expect(request.url?.path == "/api/attachments/reorder")
        #expect(request.httpMethod == "POST")
        #expect(decoded.contextType == .schedule)
        #expect(decoded.contextId == "73")
        #expect(decoded.orderedAttachmentIds == [second, first])
    }

    @Test
    func discardKeepsSessionAndReportsFailureWhenServerRejectsIt() async throws {
        let sessionId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        AttachmentURLProtocol.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/attachments/sessions"):
                return Self.response(
                    request,
                    status: 200,
                    body: """
                    {"sessionId":"\(sessionId)","expiresAt":"2026-08-13T00:00:00Z","contextType":"TODO"}
                    """
                )
            case ("POST", "/api/attachments"):
                return Self.response(
                    request,
                    status: 200,
                    body: Self.attachmentJSON(id: UUID())
                )
            case ("DELETE", "/api/attachments/sessions/\(sessionId.uuidString)"):
                return Self.response(request, status: 500)
            default:
                return Self.response(request, status: 404)
            }
        }
        defer { AttachmentURLProtocol.handler = nil }

        let model = AttachmentPickerModel(
            contextType: .todo,
            client: AttachmentClient(apiClient: makeAPIClient())
        )
        await model.add(files: [
            try AttachmentUploadFile(
                filename: "memo.txt",
                contentType: "text/plain",
                data: Data("hello".utf8)
            )
        ])

        #expect(await model.discard() == false)
        #expect(model.attachmentSessionId == sessionId)
        #expect(model.failure == .discardFailed)
    }

    @Test
    func savingAfterRemovingEveryNewUploadDiscardsItsSession() async throws {
        let sessionId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let attachmentId = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let recorder = AttachmentRequestRecorder()
        AttachmentURLProtocol.handler = { request in
            recorder.record(request)
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/attachments/sessions"):
                return Self.response(
                    request,
                    status: 200,
                    body: """
                    {"sessionId":"\(sessionId)","expiresAt":"2026-08-13T00:00:00Z","contextType":"TODO"}
                    """
                )
            case ("POST", "/api/attachments"):
                return Self.response(
                    request,
                    status: 200,
                    body: Self.attachmentJSON(id: attachmentId)
                )
            case ("DELETE", "/api/attachments/sessions/\(sessionId.uuidString)"):
                return Self.response(request, status: 204)
            default:
                return Self.response(request, status: 404)
            }
        }
        defer { AttachmentURLProtocol.handler = nil }

        let model = AttachmentPickerModel(
            contextType: .todo,
            client: AttachmentClient(apiClient: makeAPIClient())
        )
        await model.add(files: [
            try AttachmentUploadFile(
                filename: "memo.txt",
                contentType: "text/plain",
                data: Data("hello".utf8)
            )
        ])
        model.remove(attachmentId)

        let result = await model.resultForSave()

        #expect(result?.attachmentSessionId == nil)
        #expect(result?.orderedAttachmentIds.isEmpty == true)
        #expect(model.attachmentSessionId == nil)
        #expect(recorder.requests.last?.url?.path == "/api/attachments/sessions/\(sessionId.uuidString)")
    }

    @Test
    func preparationParticipatesInTheSharedBusyGuard() {
        let model = AttachmentPickerModel(contextType: .todo)

        model.beginPreparing()
        #expect(model.isPreparing)
        #expect(model.isBusy)

        model.endPreparing()
        #expect(!model.isPreparing)
        #expect(!model.isBusy)
    }

    private func makeAPIClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AttachmentURLProtocol.self]
        return APIClient(
            baseURL: baseURL,
            session: URLSession(configuration: configuration)
        )
    }

    nonisolated private static func response(
        _ request: URLRequest,
        status: Int,
        body: String = ""
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!,
            Data(body.utf8)
        )
    }

    nonisolated private static func attachmentJSON(id: UUID) -> String {
        """
        {"id":"\(id)","contextType":"TODO","contextId":null,"originalFilename":"memo.txt","contentType":"text/plain","size":5,"hasThumbnail":false,"thumbnailUrl":null,"orderIndex":0,"createdAt":"2026-08-12T10:00:00+09:00","createdBy":42}
        """
    }
}

private final class AttachmentRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequests: [URLRequest] = []

    var requests: [URLRequest] {
        lock.withLock { storedRequests }
    }

    func record(_ request: URLRequest) {
        lock.withLock { storedRequests.append(request) }
    }
}

private final class AttachmentURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("AttachmentURLProtocol.handler was not set")
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
