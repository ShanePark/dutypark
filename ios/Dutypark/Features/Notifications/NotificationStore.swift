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
    private var currentPage = 0
    private var totalPages = 0
    private var consecutiveFailures = 0
    private var pollingTask: Task<Void, Never>?
    private var isForeground = true

    init(api: any NotificationAPIProtocol = NotificationAPI()) {
        self.api = api
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
        if !notification.isRead {
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
                try? await Task.sleep(for: .seconds(delay))
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
}
