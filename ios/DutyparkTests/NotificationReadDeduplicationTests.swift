import Foundation
import Testing
@testable import Dutypark

@MainActor
struct NotificationReadDeduplicationTests {
    @Test
    func openingTheSameUnreadRowTwiceOnlyConsumesOneUnreadCount() async throws {
        let unread = try notification(referenceID: UUID())
        let api = NotificationReadDeduplicationAPIMock(notification: unread, unreadCount: 2)
        let store = NotificationStore(api: api)
        await store.refresh()

        _ = await store.open(unread)
        _ = await store.open(unread)

        #expect(store.unreadCount == 1)
        #expect(store.notifications.first?.isRead == true)
        #expect(await api.markAsReadCallCount() == 1)
    }

    private func notification(referenceID: UUID) throws -> NotificationDTO {
        try JSONDecoder().decode(
            NotificationDTO.self,
            from: Data("""
                {
                  "id": "\(UUID().uuidString)",
                  "type": "TODO_STATUS_DONE",
                  "referenceType": "TODO",
                  "referenceId": "\(referenceID.uuidString)",
                  "actorId": 11,
                  "payload": {"version": 1, "actor": null, "todoTitle": "Task"},
                  "isRead": false,
                  "createdAt": "2026-08-12T09:51:51.163702"
                }
                """.utf8)
        )
    }
}

private enum NotificationReadDeduplicationMockError: Error {
    case notificationMissing
}

private actor NotificationReadDeduplicationAPIMock: NotificationAPIProtocol {
    private var notification: NotificationDTO
    private let unreadCount: Int
    private var markCalls = 0

    init(notification: NotificationDTO, unreadCount: Int) {
        self.notification = notification
        self.unreadCount = unreadCount
    }

    func notifications(page: Int, size: Int) async throws -> PageResponse<NotificationDTO> {
        PageResponse(
            content: [notification],
            totalPages: 1,
            totalElements: 1,
            last: true,
            first: true,
            size: size,
            number: page,
            numberOfElements: 1,
            empty: false
        )
    }

    func unreadNotifications() async throws -> [NotificationDTO] {
        notification.isRead ? [] : [notification]
    }

    func count() async throws -> NotificationCountDTO {
        NotificationCountDTO(unreadCount: unreadCount, totalCount: 1)
    }

    func friendRequestCount() async throws -> Int { 0 }

    func markAsRead(id: NotificationID) async throws -> NotificationDTO {
        guard notification.id == id else {
            throw NotificationReadDeduplicationMockError.notificationMissing
        }
        markCalls += 1
        notification = NotificationDTO(
            id: notification.id,
            type: notification.type,
            referenceType: notification.referenceType,
            referenceId: notification.referenceId,
            actorId: notification.actorId,
            payload: notification.payload,
            isRead: true,
            createdAt: notification.createdAt
        )
        return notification
    }

    func markAllAsRead() async throws -> Int { 0 }

    func delete(id: NotificationID) async throws {}

    func deleteAllRead() async throws -> Int { 0 }

    func markAsReadCallCount() -> Int { markCalls }
}
