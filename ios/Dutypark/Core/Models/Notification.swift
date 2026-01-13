import Foundation

enum NotificationType: String, Decodable {
    case friendRequestReceived = "FRIEND_REQUEST_RECEIVED"
    case friendRequestAccepted = "FRIEND_REQUEST_ACCEPTED"
    case familyRequestReceived = "FAMILY_REQUEST_RECEIVED"
    case familyRequestAccepted = "FAMILY_REQUEST_ACCEPTED"
    case scheduleTagged = "SCHEDULE_TAGGED"

    var displayName: String {
        switch self {
        case .friendRequestReceived: return "친구 요청"
        case .friendRequestAccepted: return "친구 수락"
        case .familyRequestReceived: return "가족 요청"
        case .familyRequestAccepted: return "가족 수락"
        case .scheduleTagged: return "일정 태그"
        }
    }

    var iconName: String {
        switch self {
        case .friendRequestReceived: return "person.badge.plus"
        case .friendRequestAccepted: return "person.badge.checkmark"
        case .familyRequestReceived: return "house.badge.plus"
        case .familyRequestAccepted: return "house.badge.checkmark"
        case .scheduleTagged: return "tag"
        }
    }
}

enum NotificationReferenceType: String, Decodable {
    case friendRequest = "FRIEND_REQUEST"
    case schedule = "SCHEDULE"
    case member = "MEMBER"
}

struct NotificationDto: Decodable, Identifiable {
    let id: String
    let type: NotificationType
    let title: String
    let content: String?
    let referenceType: NotificationReferenceType?
    let referenceId: String?
    let actorId: Int?
    let actorName: String?
    let actorHasProfilePhoto: Bool?
    let actorProfilePhotoVersion: Int?
    let isRead: Bool
    let createdAt: String
}

struct NotificationCountDto: Decodable {
    let unreadCount: Int
    let totalCount: Int
}

struct NotificationListResponse: Decodable {
    let notifications: [NotificationDto]
    let totalCount: Int
    let unreadCount: Int
}
