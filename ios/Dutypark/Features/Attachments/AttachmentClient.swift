import Foundation

nonisolated struct AttachmentUploadFile: Equatable, Sendable {
    let filename: String
    let contentType: String
    let data: Data

    init(filename: String, contentType: String, data: Data) throws {
        guard !data.isEmpty else {
            throw AttachmentUploadError.emptyFile
        }
        guard data.count < AttachmentUploadPolicy.safeMaximumBytes else {
            throw AttachmentUploadError.tooLarge
        }
        self.filename = filename
        self.contentType = contentType.isEmpty ? "application/octet-stream" : contentType
        self.data = data
    }
}

nonisolated enum AttachmentUploadPolicy {
    /// The application server accepts 50 MB, but the production proxy currently accepts requests below 10 MB.
    static let safeMaximumBytes = 10 * 1_024 * 1_024
}

nonisolated enum AttachmentUploadError: Error, Equatable, Sendable {
    case emptyFile
    case tooLarge
    case unreadableFile
    case imageConversionFailed
}

nonisolated struct AttachmentPickerResult: Equatable, Sendable {
    let attachmentSessionId: UUID?
    let attachments: [AttachmentDTO]

    var orderedAttachmentIds: [AttachmentID] {
        attachments.map(\.id)
    }
}

nonisolated struct DownloadedAttachment: Sendable {
    let data: Data
    let filename: String
    let contentType: String
}

nonisolated enum MultipartFormData {
    static func body(
        sessionId: UUID,
        file: AttachmentUploadFile,
        boundary: String
    ) -> Data {
        var data = Data()
        data.appendUTF8("--\(boundary)\r\n")
        data.appendUTF8("Content-Disposition: form-data; name=\"sessionId\"\r\n\r\n")
        data.appendUTF8("\(sessionId.uuidString)\r\n")
        data.appendUTF8("--\(boundary)\r\n")
        data.appendUTF8(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(escaped(file.filename))\"\r\n"
        )
        data.appendUTF8("Content-Type: \(file.contentType)\r\n\r\n")
        data.append(file.data)
        data.appendUTF8("\r\n--\(boundary)--\r\n")
        return data
    }

    private static func escaped(_ filename: String) -> String {
        filename
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}

nonisolated protocol AttachmentPickerClient: Sendable {
    func createSession(
        contextType: AttachmentContextType,
        targetContextId: String?
    ) async throws -> CreateAttachmentSessionResponse

    func discardSession(_ sessionId: UUID) async throws

    func upload(
        _ file: AttachmentUploadFile,
        sessionId: UUID
    ) async throws -> AttachmentDTO
}

nonisolated final class AttachmentClient: AttachmentPickerClient, Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func createSession(
        contextType: AttachmentContextType,
        targetContextId: String? = nil
    ) async throws -> CreateAttachmentSessionResponse {
        try await apiClient.request(
            "attachments/sessions",
            method: .post,
            body: CreateAttachmentSessionRequest(
                contextType: contextType,
                targetContextId: targetContextId
            )
        )
    }

    func discardSession(_ sessionId: UUID) async throws {
        try await apiClient.data(
            "attachments/sessions/\(sessionId.uuidString)",
            method: .delete
        )
    }

    func upload(
        _ file: AttachmentUploadFile,
        sessionId: UUID
    ) async throws -> AttachmentDTO {
        let boundary = "Dutypark-\(UUID().uuidString)"
        let data = try await apiClient.data(
            "attachments",
            method: .post,
            body: MultipartFormData.body(
                sessionId: sessionId,
                file: file,
                boundary: boundary
            ),
            headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
        )
        do {
            return try JSONDecoder().decode(AttachmentDTO.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    func list(
        contextType: AttachmentContextType,
        contextId: String
    ) async throws -> [AttachmentDTO] {
        try await apiClient.request(
            "attachments",
            queryItems: [
                URLQueryItem(name: "contextType", value: contextType.rawValue),
                URLQueryItem(name: "contextId", value: contextId)
            ]
        )
    }

    func delete(_ attachmentId: AttachmentID) async throws {
        try await apiClient.data(
            "attachments/\(attachmentId.uuidString)",
            method: .delete
        )
    }

    func reorder(
        contextType: AttachmentContextType,
        contextId: String,
        orderedAttachmentIds: [AttachmentID]
    ) async throws {
        try await apiClient.data(
            "attachments/reorder",
            method: .post,
            body: try encoded(
                ReorderAttachmentsRequest(
                    contextType: contextType,
                    contextId: contextId,
                    orderedAttachmentIds: orderedAttachmentIds
                )
            )
        )
    }

    func thumbnailData(for attachmentId: AttachmentID) async throws -> Data {
        try await apiClient.data("attachments/\(attachmentId.uuidString)/thumbnail")
    }

    func download(_ attachment: AttachmentDTO, inline: Bool = false) async throws -> DownloadedAttachment {
        let data = try await apiClient.data(
            "attachments/\(attachment.id.uuidString)/download",
            queryItems: inline ? [URLQueryItem(name: "inline", value: "true")] : []
        )
        return DownloadedAttachment(
            data: data,
            filename: attachment.originalFilename,
            contentType: attachment.contentType
        )
    }

    private func encoded<Value: Encodable>(_ value: Value) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw APIError.decoding
        }
    }
}

private extension Data {
    nonisolated mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}
