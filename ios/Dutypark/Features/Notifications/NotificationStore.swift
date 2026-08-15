import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationStore: ObservableObject {
    static let pageSize = 20
    static let basePollingInterval: TimeInterval = 10
    static let maximumPollingInterval: TimeInterval = 5 * 60

    @Published private(set) var notifications: [NotificationDTO] = []
    @Published private(set) var unreadCount = 0
    @Published private(set) var friendRequestCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadFailed = false

    private let api: any NotificationAPIProtocol
    private let pollingSleep: @Sendable (TimeInterval) async throws -> Void
    private var currentPage = 0
    private var totalPages = 0
    private var consecutiveFailures = 0
    private var pollingTask: Task<Void, Never>?
    private var isForeground = true
    private var markingAsReadIDs: Set<NotificationID> = []
    private var isMarkingAllAsRead = false

    init(
        api: any NotificationAPIProtocol = NotificationAPI(),
        pollingSleep: @escaping @Sendable (TimeInterval) async throws -> Void = { interval in
            try await Task.sleep(for: .seconds(interval))
        }
    ) {
        self.api = api
        self.pollingSleep = pollingSleep
    }

    var hasMore: Bool {
        currentPage < totalPages - 1
    }

    var unreadCountLabel: String {
        unreadCount > 99 ? "99+" : String(unreadCount)
    }

    var hasFriendRequests: Bool {
        friendRequestCount > 0
    }

    var friendRequestCountLabel: String {
        friendRequestCount > 99 ? "99+" : String(friendRequestCount)
    }

    func refresh() async {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-notification-fixture") {
            loadUITestingNotificationFixture()
            return
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            notifications = []
            unreadCount = 0
            friendRequestCount = 0
            loadFailed = false
            return
        }
#endif
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let page = api.notifications(page: 0, size: Self.pageSize)
            async let count = api.count()
            async let friendCount = api.friendRequestCount()
            let (pageResult, countResult, friendCountResult) = try await (page, count, friendCount)
            notifications = pageResult.content
            currentPage = pageResult.number
            totalPages = pageResult.totalPages
            unreadCount = countResult.unreadCount
            friendRequestCount = friendCountResult
            loadFailed = false
            consecutiveFailures = 0
            await updateBadge()
        } catch {
            loadFailed = true
            consecutiveFailures += 1
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let result = try await api.notifications(page: currentPage + 1, size: Self.pageSize)
            notifications.append(contentsOf: result.content.filter { next in
                !notifications.contains(where: { $0.id == next.id })
            })
            currentPage = result.number
            totalPages = result.totalPages
            loadFailed = false
            consecutiveFailures = 0
        } catch {
            loadFailed = true
            consecutiveFailures += 1
        }
    }

    @discardableResult
    func open(_ notification: NotificationDTO) async -> NotificationRoute? {
        let storedNotification = notifications.first { $0.id == notification.id }
        let shouldMarkAsRead = !notification.isRead
            && storedNotification?.isRead != true
            && !markingAsReadIDs.contains(notification.id)
        if shouldMarkAsRead {
            markingAsReadIDs.insert(notification.id)
            defer { markingAsReadIDs.remove(notification.id) }
            do {
                let updated = try await api.markAsRead(id: notification.id)
                replace(updated)
                unreadCount = max(0, unreadCount - 1)
                await updateBadge()
            } catch {
                // Navigation should remain available when the read-state request fails.
            }
        }
        return NotificationRoute(notification: notification)
    }

    /// Resolves a notification opened from an APNs payload using the same server contract as the web app.
    func open(id: NotificationID) async throws -> NotificationRoute? {
        let notification = try await api.markAsRead(id: id)
        replace(notification)
        unreadCount = try await api.count().unreadCount
        await updateBadge()
        return NotificationRoute(notification: notification)
    }

    func markAllAsRead() async throws {
        guard !isMarkingAllAsRead else { return }
        isMarkingAllAsRead = true
        defer { isMarkingAllAsRead = false }
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-notification-fixture") {
            notifications = notifications.map(markedAsRead)
            unreadCount = 0
            await updateBadge()
            return
        }
#endif
        _ = try await api.markAllAsRead()
        notifications = notifications.map(markedAsRead)
        unreadCount = 0
        await updateBadge()
    }

    func delete(_ notification: NotificationDTO) async throws {
        try await api.delete(id: notification.id)
        notifications.removeAll { $0.id == notification.id }
        if !notification.isRead {
            unreadCount = max(0, unreadCount - 1)
            await updateBadge()
        }
    }

    func deleteAllRead() async throws {
        _ = try await api.deleteAllRead()
        notifications.removeAll(where: \.isRead)
    }

    func startPolling() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            return
        }
#endif
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = Self.pollingInterval(afterFailures: self.consecutiveFailures)
                try? await self.pollingSleep(delay)
                guard !Task.isCancelled else { return }
                if self.isForeground {
                    await self.synchronizeCounts()
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func setForeground(_ foreground: Bool) async {
        isForeground = foreground
        if foreground {
            // A scene resume can include changes made by another session, including
            // read-notification deletion that does not alter the unread count.
            await refresh()
        }
    }

    static func pollingInterval(afterFailures failures: Int) -> TimeInterval {
        guard failures > 0 else { return basePollingInterval }
        return min(basePollingInterval * pow(2, Double(failures)), maximumPollingInterval)
    }

    private func synchronizeCounts() async {
        do {
            let previousCount = unreadCount
            let countResult = try await api.count()
            unreadCount = countResult.unreadCount
            consecutiveFailures = 0
            await updateBadge()

            if countResult.unreadCount > previousCount {
                let unread = try await api.unreadNotifications()
                if unread.contains(where: {
                    $0.type == .friendRequestReceived || $0.type == .familyRequestReceived
                }) {
                    friendRequestCount = try await api.friendRequestCount()
                }
            }
        } catch {
            consecutiveFailures += 1
        }
    }

    private func replace(_ notification: NotificationDTO) {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index] = notification
    }

    private func markedAsRead(_ notification: NotificationDTO) -> NotificationDTO {
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

    private func updateBadge() async {
        try? await UNUserNotificationCenter.current().setBadgeCount(unreadCount)
    }

#if DEBUG
    private func loadUITestingNotificationFixture() {
        let data = Data(Self.uiTestingNotificationFixture.utf8)
        notifications = (try? JSONDecoder().decode([NotificationDTO].self, from: data)) ?? []
        unreadCount = notifications.filter { !$0.isRead }.count
        friendRequestCount = 1
        currentPage = 0
        totalPages = 1
        loadFailed = false
    }

    private static let uiTestingNotificationFixture = #"""
    [
      {
        "id": "00000000-0000-0000-0000-000000000101",
        "type": "FRIEND_REQUEST_RECEIVED",
        "referenceType": "FRIEND_REQUEST",
        "referenceId": "101",
        "actorId": 101,
        "payload": {
          "version": 1,
          "actor": {
            "name": "민지",
            "hasProfilePhoto": false,
            "profilePhotoVersion": 0
          }
        },
        "isRead": false,
        "createdAt": "2026-08-15T08:30:00"
      },
      {
        "id": "00000000-0000-0000-0000-000000000102",
        "type": "TODO_STATUS_DONE",
        "referenceType": "TODO",
        "referenceId": "00000000-0000-0000-0000-000000000202",
        "actorId": 102,
        "payload": {
          "version": 1,
          "actor": {
            "name": "알렉스",
            "hasProfilePhoto": false,
            "profilePhotoVersion": 0
          },
          "todoTitle": "근무표 확인"
        },
        "isRead": true,
        "createdAt": "2026-08-14T18:15:00"
      }
    ]
    """#
#endif
}
