import Foundation

nonisolated enum AttachmentContextType: Codable, Hashable, Sendable {
    case schedule
    case profile
    case team
    case todo
    case unknown(String)

    var rawValue: String {
        switch self {
        case .schedule: "SCHEDULE"
        case .profile: "PROFILE"
        case .team: "TEAM"
        case .todo: "TODO"
        case .unknown(let value): value
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "SCHEDULE": .schedule
        case "PROFILE": .profile
        case "TEAM": .team
        case "TODO": .todo
        default: .unknown(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct AttachmentDTO: Codable, Equatable, Sendable {
    let id: AttachmentID
    let contextType: AttachmentContextType
    let contextId: String?
    let originalFilename: String
    let contentType: String
    let size: Int64
    let hasThumbnail: Bool
    let thumbnailUrl: String?
    let orderIndex: Int
    let createdAt: String
    let createdBy: MemberID
}

nonisolated struct CreateAttachmentSessionRequest: Codable, Equatable, Sendable {
    let contextType: AttachmentContextType
    let targetContextId: String?
}

nonisolated struct CreateAttachmentSessionResponse: Codable, Equatable, Sendable {
    let sessionId: UUID
    let expiresAt: String
    let contextType: AttachmentContextType
}

nonisolated struct ReorderAttachmentsRequest: Codable, Equatable, Sendable {
    let contextType: AttachmentContextType
    let contextId: String
    let orderedAttachmentIds: [AttachmentID]
}
