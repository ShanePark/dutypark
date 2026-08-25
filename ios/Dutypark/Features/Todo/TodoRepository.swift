import Foundation

protocol TodoRepository: Sendable {
    func fetchBoard() async throws -> TodoBoardDTO
    func fetchFriends() async throws -> [FriendDTO]
    func fetchAttachments(todoID: TodoID) async throws -> [AttachmentDTO]
    func create(_ request: TodoRequest) async throws -> TodoDTO
    func create(
        _ request: TodoRequest,
        operationID: UUID
    ) async throws -> TodoDTO
    func update(id: TodoID, request: TodoRequest) async throws -> TodoDTO
    func delete(id: TodoID) async throws
    func complete(id: TodoID) async throws -> TodoDTO
    func reopen(id: TodoID) async throws -> TodoDTO
    func changeStatus(id: TodoID, request: TodoStatusChangeRequest) async throws -> TodoDTO
    func updatePositions(_ request: TodoPositionUpdateRequest) async throws
    func leaveTag(id: TodoID) async throws
}

extension TodoRepository {
    /// Keep existing repository fakes and call sites source-compatible;
    /// the production repository overrides this overload to send the key.
    func create(
        _ request: TodoRequest,
        operationID: UUID
    ) async throws -> TodoDTO {
        try await create(request)
    }
}

nonisolated struct TodoAPIRepository: TodoRepository {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func fetchBoard() async throws -> TodoBoardDTO {
        try await client.request("todos/board")
    }

    func fetchFriends() async throws -> [FriendDTO] {
        try await client.request("friends")
    }

    func fetchAttachments(todoID: TodoID) async throws -> [AttachmentDTO] {
        try await client.request(
            "attachments",
            queryItems: [
                URLQueryItem(name: "contextType", value: "TODO"),
                URLQueryItem(name: "contextId", value: todoID.uuidString)
            ]
        )
    }

    func create(_ request: TodoRequest) async throws -> TodoDTO {
        try await client.request("todos", method: .post, body: request)
    }

    func create(
        _ request: TodoRequest,
        operationID: UUID
    ) async throws -> TodoDTO {
        try await client.request(
            "todos",
            method: .post,
            body: request,
            headers: ["Idempotency-Key": operationID.uuidString]
        )
    }

    func update(id: TodoID, request: TodoRequest) async throws -> TodoDTO {
        try await client.request("todos/\(id.uuidString)", method: .put, body: request)
    }

    func delete(id: TodoID) async throws {
        try await client.data("todos/\(id.uuidString)", method: .delete)
    }

    func complete(id: TodoID) async throws -> TodoDTO {
        try await client.request("todos/\(id.uuidString)/complete", method: .patch)
    }

    func reopen(id: TodoID) async throws -> TodoDTO {
        try await client.request("todos/\(id.uuidString)/reopen", method: .patch)
    }

    func changeStatus(id: TodoID, request: TodoStatusChangeRequest) async throws -> TodoDTO {
        try await client.request("todos/\(id.uuidString)/status", method: .patch, body: request)
    }

    func updatePositions(_ request: TodoPositionUpdateRequest) async throws {
        try await sendWithoutResponse("todos/positions", method: .patch, body: request)
    }

    func leaveTag(id: TodoID) async throws {
        try await client.data("todos/\(id.uuidString)/tags", method: .delete)
    }

    private func sendWithoutResponse<Body: Encodable & Sendable>(
        _ path: String,
        method: HTTPMethod,
        body: Body
    ) async throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(body)
        } catch {
            throw APIError.decoding
        }
        try await client.data(
            path,
            method: method,
            body: data,
            headers: ["Content-Type": "application/json"]
        )
    }
}
