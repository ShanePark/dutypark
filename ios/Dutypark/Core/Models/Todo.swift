import Foundation

struct Todo: Decodable, Identifiable {
    let id: String
    let title: String
    let content: String
    let position: Int?
    let status: TodoStatus
    let createdDate: String
    let completedDate: String?
    let dueDate: String?
    let isOverdue: Bool
    let attachments: [Attachment]?
}

enum TodoStatus: String, Decodable, CaseIterable {
    case todo = "TODO"
    case inProgress = "IN_PROGRESS"
    case done = "DONE"

    var displayName: String {
        switch self {
        case .todo: return "할 일"
        case .inProgress: return "진행중"
        case .done: return "완료"
        }
    }

    var iconName: String {
        switch self {
        case .todo: return "circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .done: return "checkmark.circle.fill"
        }
    }
}

struct TodoBoard: Decodable {
    let todo: [Todo]
    let inProgress: [Todo]
    let done: [Todo]
    let counts: TodoCounts
}

struct TodoCounts: Decodable {
    let todo: Int
    let inProgress: Int
    let done: Int
    let total: Int
}

// MARK: - Requests
struct TodoCreateRequest: Encodable {
    let title: String
    let content: String?
    let status: String?
    let dueDate: String?
    let attachmentSessionId: String?
    let orderedAttachmentIds: [String]?
}

struct TodoUpdateRequest: Encodable {
    let title: String
    let content: String
    let status: String?
    let dueDate: String?
    let attachmentSessionId: String?
    let orderedAttachmentIds: [String]?
}

struct TodoStatusChangeRequest: Encodable {
    let status: String
    let orderedIds: [String]
}

struct TodoPositionUpdateRequest: Encodable {
    let status: String
    let orderedIds: [String]
}
