import Foundation

struct Attachment: Decodable, Identifiable, Sendable {
    let id: String
    let originalFileName: String
    let thumbnailAvailable: Bool
}

enum AttachmentContextType: String, Codable {
    case schedule = "SCHEDULE"
    case profile = "PROFILE"
    case team = "TEAM"
    case todo = "TODO"
}

struct AttachmentDto: Decodable, Identifiable {
    let id: String
    let contextType: String
    let contextId: String?
    let originalFilename: String
    let contentType: String
    let size: Int
    let hasThumbnail: Bool
    let thumbnailUrl: String?
    let orderIndex: Int
    let createdAt: String
    let createdBy: Int
}

// MARK: - Requests
struct CreateSessionRequest: Encodable {
    let contextType: String
    let targetContextId: String?
}

// MARK: - Responses
struct CreateSessionResponse: Decodable {
    let sessionId: String
    let expiresAt: String
    let contextType: String
}

struct AttachmentListResponse: Decodable {
    let attachments: [AttachmentDto]
}
