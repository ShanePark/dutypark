import Foundation

struct Schedule: Decodable, Identifiable {
    let id: String
    let content: String
    let contentWithoutTime: String?
    let date: String
    let startTime: String?
    let endTime: String?
    let memberId: Int
    let memberName: String?
    let attachmentCount: Int
    let taggedFriends: [TaggedFriend]?
}

struct TaggedFriend: Decodable, Identifiable {
    let id: Int
    let name: String
}

struct ScheduleListResponse: Decodable {
    let schedules: [Schedule]
}

// MARK: - Requests
struct CreateScheduleRequest: Encodable {
    let content: String
    let date: String
    let startTime: String?
    let endTime: String?
    let taggedFriendIds: [Int]?
}

struct UpdateScheduleRequest: Encodable {
    let content: String
    let date: String
    let startTime: String?
    let endTime: String?
    let taggedFriendIds: [Int]?
}
