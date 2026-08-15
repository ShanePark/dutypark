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

        let firstOpen = Task { await store.open(unread) }
        await api.waitUntilFirstMarkStarts()

        let secondRoute = await store.open(unread)
        #expect(secondRoute == NotificationRoute(notification: unread))
        #expect(await api.markAsReadCallCount() == 1)

        await api.releaseFirstMark()
        _ = await firstOpen.value

        #expect(store.unreadCount == 1)
        #expect(store.notifications.first?.isRead == true)
        #expect(await api.markAsReadCallCount() == 1)
    }

    @Test
    func markingAllAsReadWhileARequestIsInFlightDoesNotStartAnotherRequest() async throws {
        let unread = try notification(referenceID: UUID())
        let api = NotificationReadDeduplicationAPIMock(notification: unread, unreadCount: 1)
        let store = NotificationStore(api: api)
        await store.refresh()

        let firstMarkAll = Task { try await store.markAllAsRead() }
        await api.waitUntilFirstMarkAllStarts()

        try await store.markAllAsRead()
        #expect(await api.markAllAsReadCallCount() == 1)

        await api.releaseFirstMarkAll()
        try await firstMarkAll.value

        #expect(store.unreadCount == 0)
        let allNotificationsAreRead = store.notifications.allSatisfy(\.isRead)
        #expect(allNotificationsAreRead)
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
    private var firstMarkStarted = false
    private var firstMarkStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstMarkReleaseRequested = false
    private var firstMarkReleaseContinuation: CheckedContinuation<Void, Never>?
    private var markAllCalls = 0
    private var firstMarkAllStarted = false
    private var firstMarkAllStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstMarkAllReleaseRequested = false
    private var firstMarkAllReleaseContinuation: CheckedContinuation<Void, Never>?

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
        if markCalls == 1 {
            firstMarkStarted = true
            let startWaiters = firstMarkStartWaiters
            firstMarkStartWaiters.removeAll()
            startWaiters.forEach { $0.resume() }
            if !firstMarkReleaseRequested {
                await withCheckedContinuation { continuation in
                    firstMarkReleaseContinuation = continuation
                }
            }
        }
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

    func markAllAsRead() async throws -> Int {
        markAllCalls += 1
        if markAllCalls == 1 {
            firstMarkAllStarted = true
            let startWaiters = firstMarkAllStartWaiters
            firstMarkAllStartWaiters.removeAll()
            startWaiters.forEach { $0.resume() }
            if !firstMarkAllReleaseRequested {
                await withCheckedContinuation { continuation in
                    firstMarkAllReleaseContinuation = continuation
                }
            }
        }
        return 1
    }

    func delete(id: NotificationID) async throws {}

    func deleteAllRead() async throws -> Int { 0 }

    func markAsReadCallCount() -> Int { markCalls }

    func markAllAsReadCallCount() -> Int { markAllCalls }

    func waitUntilFirstMarkStarts() async {
        guard !firstMarkStarted else { return }
        await withCheckedContinuation { continuation in
            firstMarkStartWaiters.append(continuation)
        }
    }

    func releaseFirstMark() {
        firstMarkReleaseRequested = true
        firstMarkReleaseContinuation?.resume()
        firstMarkReleaseContinuation = nil
    }

    func waitUntilFirstMarkAllStarts() async {
        guard !firstMarkAllStarted else { return }
        await withCheckedContinuation { continuation in
            firstMarkAllStartWaiters.append(continuation)
        }
    }

    func releaseFirstMarkAll() {
        firstMarkAllReleaseRequested = true
        firstMarkAllReleaseContinuation?.resume()
        firstMarkAllReleaseContinuation = nil
    }
}
