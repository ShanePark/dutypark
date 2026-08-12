import Foundation
import Testing
@testable import Dutypark

@MainActor
struct NotificationFeatureTests {
    @Test
    func mapsNotificationReferencesToNativeRoutes() throws {
        let page: PageResponse<NotificationDTO> = try decodeNotificationFixture()
        let notification = try #require(page.content.first)

        #expect(NotificationRoute(notification: notification) == .taggedSchedule(
            UUID(uuidString: "9a53c095-c8b0-4de7-91be-b2fef4134e2a")!
        ))
    }

    @Test
    func distinguishesTaggedScheduleFromOrdinaryScheduleRoute() throws {
        let scheduleID = UUID(uuidString: "9a53c095-c8b0-4de7-91be-b2fef4134e2a")!
        let notification = try decodeNotification(
            type: "SCHEDULE_TAGGED",
            referenceType: "SCHEDULE",
            referenceID: scheduleID.uuidString
        )

        #expect(NotificationRoute(notification: notification) == .taggedSchedule(scheduleID))
    }

    @Test
    func preservesTodoReferenceIdentifierForDetailRouting() throws {
        let todoID = UUID(uuidString: "60fd4faf-ecda-48d4-a128-362791a599e7")!
        let notification = try decodeNotification(
            type: "TODO_TAGGED",
            referenceType: "TODO",
            referenceID: todoID.uuidString
        )

        #expect(NotificationRoute(notification: notification) == .todo(todoID))
    }

    @Test
    func keepsTodoRouteAvailableWhenLegacyReferenceIsMissing() throws {
        let notification = try decodeNotification(
            type: "TODO_STATUS_DONE",
            referenceType: "TODO",
            referenceID: nil
        )

        #expect(NotificationRoute(notification: notification) == .todo(nil))
    }

    @Test
    func sceneResumeRefreshesListAndBothCounts() async throws {
        let page: PageResponse<NotificationDTO> = try decodeNotificationFixture()
        let api = NotificationAPIMock(page: page)
        let store = NotificationStore(api: api)

        await store.setForeground(false)
        #expect(await api.callCounts() == .zero)

        await store.setForeground(true)

        #expect(await api.callCounts() == NotificationAPICallCounts(list: 1, count: 1, friendCount: 1))
        #expect(store.notifications.map(\.id) == page.content.map(\.id))
        #expect(store.unreadCount == 1)
        #expect(store.friendRequestCount == 2)
        #expect(store.hasFriendRequests)
        #expect(store.friendRequestCountLabel == "2")
    }

    @Test
    func pollingBackoffMatchesWebLimits() {
        #expect(NotificationStore.pollingInterval(afterFailures: 0) == 10)
        #expect(NotificationStore.pollingInterval(afterFailures: 1) == 20)
        #expect(NotificationStore.pollingInterval(afterFailures: 10) == 300)
    }

    @Test
    func convertsAPNsDeviceTokenToLowercaseHex() {
        #expect(APNsRegistrationManager.hexString(for: Data([0x00, 0x7F, 0xA4, 0xFF])) == "007fa4ff")
    }

    @Test
    func persistsExplicitPushPreferenceAndDefaultsToEnabled() throws {
        let suiteName = "NotificationFeatureTests.pushPreference.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let manager = APNsRegistrationManager(defaults: defaults)
        #expect(manager.isEnabled)

        manager.setEnabled(false)
        let restoredManager = APNsRegistrationManager(defaults: defaults)
        #expect(!restoredManager.isEnabled)

        restoredManager.setEnabled(true)
        #expect(APNsRegistrationManager(defaults: defaults).isEnabled)
    }

    @Test
    func readsNotificationIdentifierFromSupportedAPNsPayloadShapes() {
        let id = UUID(uuidString: "ae71ee7d-3af9-4936-a6e8-75b9c0d37822")!

        #expect(NotificationPushCenter.notificationID(from: ["notificationId": id.uuidString]) == id)
        #expect(NotificationPushCenter.notificationID(from: [
            "data": ["notificationId": id.uuidString]
        ]) == id)
        #expect(NotificationPushCenter.notificationID(from: ["notificationId": "invalid"]) == nil)
    }

    private func decodeNotificationFixture() throws -> PageResponse<NotificationDTO> {
        let bundle = Bundle(for: NotificationFixtureBundleToken.self)
        let url = try #require(
            bundle.url(forResource: "notification-page", withExtension: "json", subdirectory: "Fixtures")
                ?? bundle.url(forResource: "notification-page", withExtension: "json")
        )
        return try JSONDecoder().decode(PageResponse<NotificationDTO>.self, from: Data(contentsOf: url))
    }

    private func decodeNotification(
        type: String,
        referenceType: String,
        referenceID: String?
    ) throws -> NotificationDTO {
        let referenceJSON = referenceID.map { #", "referenceId": "\#($0)""# } ?? ""
        return try JSONDecoder().decode(
            NotificationDTO.self,
            from: Data("""
                {
                  "id": "ae71ee7d-3af9-4936-a6e8-75b9c0d37822",
                  "type": "\(type)",
                  "referenceType": "\(referenceType)"\(referenceJSON),
                  "actorId": 11,
                  "payload": {"version": 1, "actor": null, "todoTitle": "Task"},
                  "isRead": false,
                  "createdAt": "2026-08-12T09:51:51.163702"
                }
                """.utf8)
        )
    }
}

private final class NotificationFixtureBundleToken {}

private struct NotificationAPICallCounts: Equatable, Sendable {
    let list: Int
    let count: Int
    let friendCount: Int

    static let zero = NotificationAPICallCounts(list: 0, count: 0, friendCount: 0)
}

private actor NotificationAPIMock: NotificationAPIProtocol {
    private let page: PageResponse<NotificationDTO>
    private var listCalls = 0
    private var countCalls = 0
    private var friendCountCalls = 0

    init(page: PageResponse<NotificationDTO>) {
        self.page = page
    }

    func notifications(page: Int, size: Int) async throws -> PageResponse<NotificationDTO> {
        listCalls += 1
        return self.page
    }

    func unreadNotifications() async throws -> [NotificationDTO] {
        self.page.content.filter { !$0.isRead }
    }

    func count() async throws -> NotificationCountDTO {
        countCalls += 1
        return NotificationCountDTO(unreadCount: 1, totalCount: 1)
    }

    func friendRequestCount() async throws -> Int {
        friendCountCalls += 1
        return 2
    }

    func markAsRead(id: NotificationID) async throws -> NotificationDTO {
        try #require(page.content.first)
    }

    func markAllAsRead() async throws -> Int { 0 }

    func delete(id: NotificationID) async throws {}

    func deleteAllRead() async throws -> Int { 0 }

    func callCounts() -> NotificationAPICallCounts {
        NotificationAPICallCounts(
            list: listCalls,
            count: countCalls,
            friendCount: friendCountCalls
        )
    }
}
