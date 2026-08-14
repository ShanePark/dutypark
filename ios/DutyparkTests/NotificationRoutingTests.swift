import Foundation
import Testing
@testable import Dutypark

@MainActor
struct NotificationRoutingTests {
    @Test
    func unknownOrMissingReferencesDoNotProduceDestinations() throws {
        let unknown = try notification(referenceType: "SOMETHING_NEW", referenceID: "42")
        let missing = try notification(referenceType: nil, referenceID: nil)

        #expect(NotificationRoute(notification: unknown) == nil)
        #expect(NotificationRoute(notification: missing) == nil)
    }

    @Test
    func readFailureDoesNotBlockNavigationOrChangeUnreadState() async throws {
        let scheduleID = UUID()
        let unread = try notification(referenceType: "SCHEDULE", referenceID: scheduleID.uuidString)
        let api = NotificationRoutingAPIMock(
            notifications: [unread],
            unreadCount: 1,
            failsMarkAsRead: true
        )
        let store = NotificationStore(api: api)
        await store.refresh()

        let route = await store.open(unread)

        #expect(route == .schedule(scheduleID))
        #expect(store.unreadCount == 1)
        #expect(store.notifications.first?.isRead == false)
    }

    @Test
    func markAllAndDeleteUnreadKeepListAndCountInSync() async throws {
        let first = try notification(id: UUID(), referenceType: "TODO", referenceID: nil)
        let second = try notification(id: UUID(), referenceType: "FRIEND_REQUEST", referenceID: nil)
        let api = NotificationRoutingAPIMock(notifications: [first, second], unreadCount: 2)
        let store = NotificationStore(api: api)
        await store.refresh()

        try await store.delete(first)
        #expect(store.notifications.map(\.id) == [second.id])
        #expect(store.unreadCount == 1)

        try await store.markAllAsRead()
        let allNotificationsAreRead = store.notifications.allSatisfy { $0.isRead }
        #expect(allNotificationsAreRead)
        #expect(store.unreadCount == 0)
    }

    @Test
    func pollingStartIsIdempotentAndStopCancelsThePendingSleep() async throws {
        let api = NotificationRoutingAPIMock(notifications: [], unreadCount: 0)
        let sleepProbe = NotificationPollingSleepProbe()
        let store = NotificationStore(api: api, pollingSleep: { interval in
            try await sleepProbe.sleep(interval: interval)
        })

        store.startPolling()
        store.startPolling()
        await sleepProbe.waitUntilFirstCall()
        #expect(await sleepProbe.recordedIntervals() == [NotificationStore.basePollingInterval])

        store.stopPolling()
        await sleepProbe.waitUntilFirstCancellation()
        #expect(await sleepProbe.callCount() == 1)
        #expect(await api.countCallCount() == 0)
    }

    private func notification(
        id: UUID = UUID(),
        referenceType: String?,
        referenceID: String?
    ) throws -> NotificationDTO {
        let referenceTypeJSON = referenceType.map { #", "referenceType": "\#($0)""# } ?? ""
        let referenceIDJSON = referenceID.map { #", "referenceId": "\#($0)""# } ?? ""
        return try JSONDecoder().decode(
            NotificationDTO.self,
            from: Data("""
                {
                  "id": "\(id.uuidString)",
                  "type": "TODO_STATUS_DONE"\(referenceTypeJSON)\(referenceIDJSON),
                  "actorId": 11,
                  "payload": {"version": 1, "actor": null, "todoTitle": "Task"},
                  "isRead": false,
                  "createdAt": "2026-08-12T09:51:51.163702"
                }
                """.utf8)
        )
    }
}

private enum NotificationRoutingMockError: Error {
    case markAsReadFailed
}

private actor NotificationRoutingAPIMock: NotificationAPIProtocol {
    private var storedNotifications: [NotificationDTO]
    private let initialUnreadCount: Int
    private let failsMarkAsRead: Bool
    private var markCalls = 0
    private var countCalls = 0

    init(
        notifications: [NotificationDTO],
        unreadCount: Int,
        failsMarkAsRead: Bool = false
    ) {
        storedNotifications = notifications
        initialUnreadCount = unreadCount
        self.failsMarkAsRead = failsMarkAsRead
    }

    func notifications(page: Int, size: Int) async throws -> PageResponse<NotificationDTO> {
        PageResponse(
            content: storedNotifications,
            totalPages: 1,
            totalElements: Int64(storedNotifications.count),
            last: true,
            first: true,
            size: size,
            number: page,
            numberOfElements: storedNotifications.count,
            empty: storedNotifications.isEmpty
        )
    }

    func unreadNotifications() async throws -> [NotificationDTO] {
        storedNotifications.filter { !$0.isRead }
    }

    func count() async throws -> NotificationCountDTO {
        countCalls += 1
        return NotificationCountDTO(unreadCount: initialUnreadCount, totalCount: storedNotifications.count)
    }

    func friendRequestCount() async throws -> Int { 0 }

    func markAsRead(id: NotificationID) async throws -> NotificationDTO {
        markCalls += 1
        if failsMarkAsRead {
            throw NotificationRoutingMockError.markAsReadFailed
        }
        guard let notification = storedNotifications.first(where: { $0.id == id }) else {
            throw NotificationRoutingMockError.markAsReadFailed
        }
        let updated = NotificationDTO(
            id: notification.id,
            type: notification.type,
            referenceType: notification.referenceType,
            referenceId: notification.referenceId,
            actorId: notification.actorId,
            payload: notification.payload,
            isRead: true,
            createdAt: notification.createdAt
        )
        storedNotifications = storedNotifications.map { $0.id == id ? updated : $0 }
        return updated
    }

    func markAllAsRead() async throws -> Int {
        let count = storedNotifications.count(where: { !$0.isRead })
        storedNotifications = storedNotifications.map { notification in
            NotificationDTO(
                id: notification.id,
                type: notification.type,
                referenceType: notification.referenceType,
                referenceId: notification.referenceId,
                actorId: notification.actorId,
                payload: notification.payload,
                isRead: true,
                createdAt: notification.createdAt
            )
        }
        return count
    }

    func delete(id: NotificationID) async throws {
        storedNotifications.removeAll { $0.id == id }
    }

    func deleteAllRead() async throws -> Int {
        let count = storedNotifications.count(where: \.isRead)
        storedNotifications.removeAll(where: \.isRead)
        return count
    }

    func markAsReadCallCount() -> Int { markCalls }

    func countCallCount() -> Int { countCalls }
}

private actor NotificationPollingSleepProbe {
    private var intervals: [TimeInterval] = []
    private var cancellationCount = 0
    private var firstCallWaiters: [CheckedContinuation<Void, Never>] = []
    private var firstCancellationWaiters: [CheckedContinuation<Void, Never>] = []

    func sleep(interval: TimeInterval) async throws {
        intervals.append(interval)
        let callWaiters = firstCallWaiters
        firstCallWaiters.removeAll()
        callWaiters.forEach { $0.resume() }
        do {
            try await Task.sleep(for: .seconds(60))
        } catch {
            cancellationCount += 1
            let cancellationWaiters = firstCancellationWaiters
            firstCancellationWaiters.removeAll()
            cancellationWaiters.forEach { $0.resume() }
            throw error
        }
    }

    func waitUntilFirstCall() async {
        guard intervals.isEmpty else { return }
        await withCheckedContinuation { continuation in
            firstCallWaiters.append(continuation)
        }
    }

    func waitUntilFirstCancellation() async {
        guard cancellationCount == 0 else { return }
        await withCheckedContinuation { continuation in
            firstCancellationWaiters.append(continuation)
        }
    }

    func recordedIntervals() -> [TimeInterval] { intervals }

    func callCount() -> Int { intervals.count }
}
