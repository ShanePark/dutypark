import Foundation

@MainActor
class NotificationViewModel: ObservableObject {
    @Published var notifications: [NotificationDto] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasMore = true
    private var currentPage = 0
    private let pageSize = 20

    func loadNotifications(refresh: Bool = false) async {
        if refresh {
            currentPage = 0
            hasMore = true
        }

        guard hasMore else { return }

        isLoading = true
        error = nil

        do {
            let response: NotificationPageResponse = try await APIClient.shared.request(
                .notifications(page: currentPage, size: pageSize),
                responseType: NotificationPageResponse.self
            )

            if refresh {
                notifications = response.content
            } else {
                notifications.append(contentsOf: response.content)
            }

            hasMore = !response.last
            currentPage += 1

            // Update unread count
            let countResponse: NotificationCountDto = try await APIClient.shared.request(
                .notificationCount,
                responseType: NotificationCountDto.self
            )
            unreadCount = countResponse.unreadCount
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadUnreadCount() async {
        do {
            let response: NotificationCountDto = try await APIClient.shared.request(
                .notificationCount,
                responseType: NotificationCountDto.self
            )
            unreadCount = response.unreadCount
        } catch {
            print("Failed to load unread count: \(error)")
        }
    }

    func markAsRead(_ notificationId: String) async {
        do {
            try await APIClient.shared.requestVoid(.markNotificationRead(id: notificationId))
            if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
                notifications[index] = NotificationDto(
                    id: notifications[index].id,
                    type: notifications[index].type,
                    title: notifications[index].title,
                    content: notifications[index].content,
                    referenceType: notifications[index].referenceType,
                    referenceId: notifications[index].referenceId,
                    actorId: notifications[index].actorId,
                    actorName: notifications[index].actorName,
                    actorHasProfilePhoto: notifications[index].actorHasProfilePhoto,
                    actorProfilePhotoVersion: notifications[index].actorProfilePhotoVersion,
                    isRead: true,
                    createdAt: notifications[index].createdAt
                )
            }
            unreadCount = max(0, unreadCount - 1)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markAllAsRead() async {
        do {
            try await APIClient.shared.requestVoid(.markAllNotificationsRead)
            notifications = notifications.map { notification in
                NotificationDto(
                    id: notification.id,
                    type: notification.type,
                    title: notification.title,
                    content: notification.content,
                    referenceType: notification.referenceType,
                    referenceId: notification.referenceId,
                    actorId: notification.actorId,
                    actorName: notification.actorName,
                    actorHasProfilePhoto: notification.actorHasProfilePhoto,
                    actorProfilePhotoVersion: notification.actorProfilePhotoVersion,
                    isRead: true,
                    createdAt: notification.createdAt
                )
            }
            unreadCount = 0
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteNotification(_ notificationId: String) async {
        do {
            try await APIClient.shared.requestVoid(.deleteNotification(id: notificationId))
            notifications.removeAll { $0.id == notificationId }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteAllRead() async {
        do {
            try await APIClient.shared.requestVoid(.deleteReadNotifications)
            notifications.removeAll { $0.isRead }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct NotificationPageResponse: Decodable {
    let content: [NotificationDto]
    let totalElements: Int
    let totalPages: Int
    let size: Int
    let number: Int
    let first: Bool
    let last: Bool
}
