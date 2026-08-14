import Foundation

nonisolated enum FriendRequestStatus: Codable, Hashable, Sendable {
    case pending
    case accepted
    case rejected
    case unknown(String)

    var rawValue: String {
        switch self {
        case .pending: "PENDING"
        case .accepted: "ACCEPTED"
        case .rejected: "REJECTED"
        case .unknown(let value): value
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "PENDING": .pending
        case "ACCEPTED": .accepted
        case "REJECTED": .rejected
        default: .unknown(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated enum FriendRequestType: Codable, Hashable, Sendable {
    case friend
    case family
    case unknown(String)

    var rawValue: String {
        switch self {
        case .friend: "FRIEND_REQUEST"
        case .family: "FAMILY_REQUEST"
        case .unknown(let value): value
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "FRIEND_REQUEST": .friend
        case "FAMILY_REQUEST": .family
        default: .unknown(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct FriendDTO: Codable, Equatable, Sendable {
    let id: MemberID
    let name: String
    let teamId: TeamID?
    let team: String?
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
    let isFamily: Bool
    let pinOrder: Int64?
}

nonisolated struct FriendRequestDTO: Codable, Equatable, Sendable {
    let id: Int64
    let fromMember: MemberPreviewDTO
    let toMember: MemberPreviewDTO
    let status: FriendRequestStatus
    let createdAt: LocalDateTimeValue?
    let requestType: FriendRequestType
}
