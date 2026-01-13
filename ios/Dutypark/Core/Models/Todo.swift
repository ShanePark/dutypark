import Foundation

struct Todo: Decodable, Identifiable {
    let id: String
    let content: String
    let status: TodoStatus
    let position: Int
    let createdAt: String
    let completedAt: String?
}

enum TodoStatus: String, Decodable, CaseIterable {
    case pending = "PENDING"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"

    var displayName: String {
        switch self {
        case .pending: return "대기"
        case .inProgress: return "진행중"
        case .completed: return "완료"
        }
    }
}

struct TodoListResponse: Decodable {
    let todos: [Todo]
}

// MARK: - Requests
struct CreateTodoRequest: Encodable {
    let content: String
    let status: String
}

struct UpdateTodoRequest: Encodable {
    let content: String?
    let status: String?
    let position: Int?
}
