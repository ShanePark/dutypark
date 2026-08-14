import Foundation

nonisolated protocol NotificationAPIProtocol: Sendable {
    func notifications(page: Int, size: Int) async throws -> PageResponse<NotificationDTO>
    func unreadNotifications() async throws -> [NotificationDTO]
    func count() async throws -> NotificationCountDTO
    func friendRequestCount() async throws -> Int
    func markAsRead(id: NotificationID) async throws -> NotificationDTO
    func markAllAsRead() async throws -> Int
    func delete(id: NotificationID) async throws
    func deleteAllRead() async throws -> Int
}

nonisolated struct NotificationAPI: NotificationAPIProtocol {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func notifications(page: Int, size: Int) async throws -> PageResponse<NotificationDTO> {
        try await client.request(
            "notifications",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        )
    }

    func unreadNotifications() async throws -> [NotificationDTO] {
        try await client.request("notifications/unread")
    }

    func count() async throws -> NotificationCountDTO {
        try await client.request("notifications/count")
    }

    func friendRequestCount() async throws -> Int {
        let response: CountResponse = try await client.request("notifications/friend-request-count")
        return response.count
    }

    func markAsRead(id: NotificationID) async throws -> NotificationDTO {
        try await client.request("notifications/\(id.uuidString)/read", method: .patch)
    }

    func markAllAsRead() async throws -> Int {
        let response: CountResponse = try await client.request("notifications/read-all", method: .patch)
        return response.count
    }

    func delete(id: NotificationID) async throws {
        _ = try await client.data("notifications/\(id.uuidString)", method: .delete)
    }

    func deleteAllRead() async throws -> Int {
        let response: CountResponse = try await client.request("notifications/read", method: .delete)
        return response.count
    }
}
