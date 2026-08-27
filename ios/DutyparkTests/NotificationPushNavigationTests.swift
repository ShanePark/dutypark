import Foundation
import Testing
@testable import Dutypark

@MainActor
struct NotificationPushNavigationTests {
    @Test(arguments: [
        (isAuthenticated: false, isOnline: true, isActive: true),
        (isAuthenticated: true, isOnline: false, isActive: true),
        (isAuthenticated: true, isOnline: true, isActive: false),
    ])
    func pendingPushRemainsUnconsumedUntilTheAuthenticatedRootIsReady(
        readiness: (isAuthenticated: Bool, isOnline: Bool, isActive: Bool)
    ) async {
        let notificationID = UUID()
        var consumeCount = 0
        var presentedTargets: [NotificationID] = []

        await RootPendingPushAction.perform(
            isAuthenticated: readiness.isAuthenticated,
            isOnline: readiness.isOnline,
            isActive: readiness.isActive,
            consume: {
                consumeCount += 1
                return notificationID
            },
            showNotificationCenter: { presentedTargets.append($0) }
        )

        #expect(consumeCount == 0)
        #expect(presentedTargets.isEmpty)
    }

    @Test
    func readyPendingPushPresentsTheNotificationCenterTargetWithoutOpeningTheNotification() async {
        let notificationID = UUID()
        var consumeCount = 0
        var presentedTargets: [NotificationID] = []

        await RootPendingPushAction.perform(
            isAuthenticated: true,
            isOnline: true,
            isActive: true,
            consume: {
                consumeCount += 1
                return notificationID
            },
            showNotificationCenter: { presentedTargets.append($0) }
        )

        #expect(consumeCount == 1)
        #expect(presentedTargets == [notificationID])
    }

    @Test
    func malformedPushDoesNotEraseAnExistingPendingNotification() {
        let notificationID = UUID()
        let center = NotificationPushCenter()
        center.receive(notificationID: notificationID)

        center.receive(notificationID: nil)
        center.receive(userInfo: ["notificationId": "not-a-uuid"])

        #expect(center.pendingNotificationID == notificationID)
    }

    @Test
    func targetedNotificationRefreshesTheFirstPageEvenWhenCachedRowsExist() {
        #expect(NotificationCenterLoadPolicy.shouldRefresh(
            targetID: UUID(),
            notificationsAreEmpty: false
        ))
        #expect(!NotificationCenterLoadPolicy.shouldRefresh(
            targetID: nil,
            notificationsAreEmpty: false
        ))
        #expect(NotificationCenterLoadPolicy.shouldRefresh(
            targetID: nil,
            notificationsAreEmpty: true
        ))
    }

    @Test
    func targetLocatorHighlightsANotificationAlreadyInTheFirstPage() {
        let targetID = UUID()

        let action = NotificationCenterTargetLocator.nextAction(
            targetID: targetID,
            loadedNotificationIDs: [targetID, UUID()],
            hasMore: true
        )

        #expect(action == .highlight)
    }

    @Test
    func targetLocatorLoadsAdditionalPagesUntilTheTargetAppears() {
        let targetID = UUID()

        let beforeLoading = NotificationCenterTargetLocator.nextAction(
            targetID: targetID,
            loadedNotificationIDs: [UUID()],
            hasMore: true
        )
        let afterLoading = NotificationCenterTargetLocator.nextAction(
            targetID: targetID,
            loadedNotificationIDs: [UUID(), targetID],
            hasMore: false
        )

        #expect(beforeLoading == .loadMore)
        #expect(afterLoading == .highlight)
    }

    @Test
    func targetLocatorFinishesSafelyWhenTheTargetNoLongerExists() {
        let action = NotificationCenterTargetLocator.nextAction(
            targetID: UUID(),
            loadedNotificationIDs: [UUID(), UUID()],
            hasMore: false
        )

        #expect(action == .finished)
    }

    @Test
    func notificationRowStillRoutesWhenMarkAsReadFails() async throws {
        let scheduleID = UUID()
        let notification = try makeNotification(scheduleID: scheduleID)
        let api = NotificationPushNavigationAPIMock(notification: notification)
        let store = NotificationStore(api: api)
        await store.refresh()

        let route = await store.open(notification)

        #expect(route == .schedule(scheduleID))
        #expect(await api.markAsReadCallCount() == 1)
        #expect(store.notifications.first?.isRead == false)
        #expect(store.unreadCount == 1)
    }

    private func makeNotification(scheduleID: ScheduleID) throws -> NotificationDTO {
        try JSONDecoder().decode(
            NotificationDTO.self,
            from: Data("""
                {
                  "id": "\(UUID().uuidString)",
                  "type": "TODO_STATUS_DONE",
                  "referenceType": "SCHEDULE",
                  "referenceId": "\(scheduleID.uuidString)",
                  "actorId": 11,
                  "payload": {"version": 1, "actor": null, "todoTitle": "Task"},
                  "isRead": false,
                  "createdAt": "2026-08-27T09:00:00"
                }
                """.utf8)
        )
    }
}

private enum NotificationPushNavigationMockError: Error {
    case markAsReadFailed
}

private actor NotificationPushNavigationAPIMock: NotificationAPIProtocol {
    private let notification: NotificationDTO
    private var markAsReadCalls = 0

    init(notification: NotificationDTO) {
        self.notification = notification
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
        [notification]
    }

    func count() async throws -> NotificationCountDTO {
        NotificationCountDTO(unreadCount: 1, totalCount: 1)
    }

    func friendRequestCount() async throws -> Int { 0 }

    func markAsRead(id: NotificationID) async throws -> NotificationDTO {
        markAsReadCalls += 1
        throw NotificationPushNavigationMockError.markAsReadFailed
    }

    func markAllAsRead() async throws -> Int { 0 }

    func delete(id: NotificationID) async throws {}

    func deleteAllRead() async throws -> Int { 0 }

    func markAsReadCallCount() -> Int { markAsReadCalls }
}
