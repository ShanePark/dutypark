import Foundation

enum CalendarVisibility: String, Decodable, Sendable {
    case `public` = "PUBLIC"
    case friends = "FRIENDS"
    case family = "FAMILY"
    case `private` = "PRIVATE"

    var displayName: String {
        switch self {
        case .public: return "전체 공개"
        case .friends: return "친구에게만"
        case .family: return "가족에게만"
        case .private: return "비공개"
        }
    }

    var iconName: String {
        switch self {
        case .public: return "globe"
        case .friends: return "person.2"
        case .family: return "house"
        case .private: return "lock"
        }
    }
}

struct Schedule: Decodable, Identifiable, Sendable {
    let id: String
    let content: String
    let description: String?
    let position: Int
    let year: Int
    let month: Int
    let dayOfMonth: Int
    let startDateTime: String
    let endDateTime: String
    let isTagged: Bool
    let owner: String?
    let tags: [ScheduleTag]
    let visibility: CalendarVisibility?
    let dateToCompare: String?
    let attachments: [Attachment]
    let daysFromStart: Int?
    let totalDays: Int?

    // Computed property to extract time from startDateTime
    var startTime: String? {
        guard startDateTime.contains("T") else { return nil }
        let parts = startDateTime.split(separator: "T")
        guard parts.count == 2 else { return nil }
        let timePart = String(parts[1].prefix(5)) // "HH:mm"
        return timePart == "00:00" ? nil : timePart
    }

    // Computed property to extract time from endDateTime
    var endTime: String? {
        guard endDateTime.contains("T") else { return nil }
        let parts = endDateTime.split(separator: "T")
        guard parts.count == 2 else { return nil }
        let timePart = String(parts[1].prefix(5)) // "HH:mm"
        return timePart == "00:00" ? nil : timePart
    }
}

struct ScheduleTag: Decodable, Identifiable, Sendable {
    var id: Int { memberId }
    let memberId: Int
    let memberName: String
}

struct ScheduleListResponse: Decodable, Sendable {
    let schedules: [Schedule]
}

// MARK: - Requests
struct CreateScheduleRequest: Encodable {
    let content: String
    let description: String?
    let year: Int
    let month: Int
    let dayOfMonth: Int
    let startDateTime: String
    let endDateTime: String
    let visibility: String?
    let taggedMemberIds: [Int]?
    let attachmentSessionId: String?
    let orderedAttachmentIds: [String]?
}

struct UpdateScheduleRequest: Encodable {
    let content: String
    let description: String?
    let year: Int
    let month: Int
    let dayOfMonth: Int
    let startDateTime: String
    let endDateTime: String
    let visibility: String?
    let taggedMemberIds: [Int]?
    let attachmentSessionId: String?
    let orderedAttachmentIds: [String]?
}
