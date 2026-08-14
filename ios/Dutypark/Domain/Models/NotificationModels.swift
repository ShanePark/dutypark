import Foundation

nonisolated enum NotificationType: Codable, Hashable, Sendable {
    case friendRequestReceived
    case friendRequestAccepted
    case familyRequestReceived
    case familyRequestAccepted
    case scheduleTagged
    case todoTagged
    case todoStatusTodo
    case todoStatusInProgress
    case todoStatusDone
    case unknown(String)

    var rawValue: String {
        switch self {
        case .friendRequestReceived: "FRIEND_REQUEST_RECEIVED"
        case .friendRequestAccepted: "FRIEND_REQUEST_ACCEPTED"
        case .familyRequestReceived: "FAMILY_REQUEST_RECEIVED"
        case .familyRequestAccepted: "FAMILY_REQUEST_ACCEPTED"
        case .scheduleTagged: "SCHEDULE_TAGGED"
        case .todoTagged: "TODO_TAGGED"
        case .todoStatusTodo: "TODO_STATUS_TODO"
        case .todoStatusInProgress: "TODO_STATUS_IN_PROGRESS"
        case .todoStatusDone: "TODO_STATUS_DONE"
        case .unknown(let value): value
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "FRIEND_REQUEST_RECEIVED": .friendRequestReceived
        case "FRIEND_REQUEST_ACCEPTED": .friendRequestAccepted
        case "FAMILY_REQUEST_RECEIVED": .familyRequestReceived
        case "FAMILY_REQUEST_ACCEPTED": .familyRequestAccepted
        case "SCHEDULE_TAGGED": .scheduleTagged
        case "TODO_TAGGED": .todoTagged
        case "TODO_STATUS_TODO": .todoStatusTodo
        case "TODO_STATUS_IN_PROGRESS": .todoStatusInProgress
        case "TODO_STATUS_DONE": .todoStatusDone
        default: .unknown(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated enum NotificationReferenceType: Codable, Hashable, Sendable {
    case friendRequest
    case schedule
    case todo
    case member
    case unknown(String)

    var rawValue: String {
        switch self {
        case .friendRequest: "FRIEND_REQUEST"
        case .schedule: "SCHEDULE"
        case .todo: "TODO"
        case .member: "MEMBER"
        case .unknown(let value): value
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "FRIEND_REQUEST": .friendRequest
        case "SCHEDULE": .schedule
        case "TODO": .todo
        case "MEMBER": .member
        default: .unknown(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct NotificationActorDTO: Codable, Equatable, Sendable {
    let name: String?
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
}

nonisolated struct NotificationPayloadDTO: Codable, Equatable, Sendable {
    let version: Int
    let actor: NotificationActorDTO?
    let scheduleTitle: String?
    let todoTitle: String?

    private enum CodingKeys: String, CodingKey {
        case version, actor, scheduleTitle, todoTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
        actor = try container.decodeIfPresent(NotificationActorDTO.self, forKey: .actor)
        scheduleTitle = try container.decodeIfPresent(String.self, forKey: .scheduleTitle)
        todoTitle = try container.decodeIfPresent(String.self, forKey: .todoTitle)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(actor, forKey: .actor)
        try container.encodeIfPresent(scheduleTitle, forKey: .scheduleTitle)
        try container.encodeIfPresent(todoTitle, forKey: .todoTitle)
    }
}

nonisolated struct NotificationDTO: Codable, Equatable, Sendable {
    let id: NotificationID
    let type: NotificationType
    let referenceType: NotificationReferenceType?
    let referenceId: String?
    let actorId: MemberID?
    let payload: NotificationPayloadDTO
    let isRead: Bool
    let createdAt: LocalDateTimeValue
}

nonisolated struct NotificationCountDTO: Codable, Equatable, Sendable {
    let unreadCount: Int
    let totalCount: Int
}
