import Foundation

nonisolated enum TodoStatus: Codable, Hashable, Sendable {
    case todo
    case inProgress
    case done
    case unknown(String)

    var rawValue: String {
        switch self {
        case .todo: "TODO"
        case .inProgress: "IN_PROGRESS"
        case .done: "DONE"
        case .unknown(let value): value
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "TODO": .todo
        case "IN_PROGRESS": .inProgress
        case "DONE": .done
        default: .unknown(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct TodoDTO: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let content: String
    let position: Int?
    let status: TodoStatus
    let createdDate: LocalDateTimeValue
    let completedDate: LocalDateTimeValue?
    let dueDate: DateOnly?
    let isOverdue: Bool
    let isTagged: Bool
    let owner: String
    let taggedByMember: MemberPreviewDTO?
    let tags: [MemberPreviewDTO]
    let hasAttachments: Bool
}

nonisolated struct TodoCountsDTO: Codable, Equatable, Sendable {
    let todo: Int
    let inProgress: Int
    let done: Int
    let total: Int
}

nonisolated struct TodoBoardDTO: Codable, Equatable, Sendable {
    let todo: [TodoDTO]
    let inProgress: [TodoDTO]
    let done: [TodoDTO]
    let counts: TodoCountsDTO
}

nonisolated struct TodoRequest: Codable, Equatable, Sendable {
    let title: String
    let content: String
    let status: TodoStatus?
    let dueDate: DateOnly?
    let tagFriendIds: [MemberID]?
    let attachmentSessionId: UUID?
    let orderedAttachmentIds: [AttachmentID]
}

nonisolated struct TodoStatusChangeRequest: Codable, Equatable, Sendable {
    let status: TodoStatus
    let orderedIds: [TodoID]
}

nonisolated struct TodoPositionUpdateRequest: Codable, Equatable, Sendable {
    let status: TodoStatus
    let orderedIds: [TodoID]
}
