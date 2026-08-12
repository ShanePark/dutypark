import Foundation

nonisolated struct ScheduleDTO: Codable, Equatable, Sendable {
    let id: ScheduleID
    let content: String
    let description: String
    let position: Int
    let year: Int
    let month: Int
    let dayOfMonth: Int
    let startDateTime: LocalDateTimeValue
    let endDateTime: LocalDateTimeValue
    let isTagged: Bool
    let owner: String
    let taggedByMember: MemberPreviewDTO?
    let tags: [MemberDTO]
    let visibility: Visibility?
    let dateToCompare: DateOnly
    let attachments: [AttachmentDTO]
    let startDate: DateOnly
    let daysFromStart: Int
    let endDate: DateOnly
    let curDate: DateOnly
    let totalDays: Int
}

nonisolated struct ScheduleSaveDTO: Codable, Equatable, Sendable {
    let id: ScheduleID?
    let memberId: MemberID
    let content: String
    let description: String
    let visibility: Visibility
    let startDateTime: LocalDateTimeValue
    let endDateTime: LocalDateTimeValue
    let tagFriendIds: [MemberID]?
    let attachmentSessionId: UUID?
    let orderedAttachmentIds: [AttachmentID]
}

nonisolated struct ScheduleSaveResponse: Codable, Equatable, Sendable {
    let id: ScheduleID
}

nonisolated struct ScheduleBasicInfoDTO: Codable, Equatable, Sendable {
    let id: ScheduleID
    let memberId: MemberID
    let memberName: String
    let startDateTime: LocalDateTimeValue
    let content: String
}

nonisolated struct ScheduleSearchResultDTO: Codable, Equatable, Sendable {
    let content: String
    let startDateTime: LocalDateTimeValue
    let endDateTime: LocalDateTimeValue
    let visibility: Visibility
    let isTagged: Bool
    let author: String
}

nonisolated struct TeamScheduleDTO: Codable, Equatable, Sendable {
    let id: ScheduleID
    let teamId: TeamID
    let content: String
    let description: String
    let position: Int
    let year: Int
    let month: Int
    let dayOfMonth: Int
    let daysFromStart: Int?
    let totalDays: Int?
    let startDateTime: LocalDateTimeValue
    let endDateTime: LocalDateTimeValue
    let createMember: String
    let updateMember: String
    let curDate: DateOnly
}

nonisolated struct TeamScheduleSaveDTO: Codable, Equatable, Sendable {
    let id: ScheduleID?
    let teamId: TeamID
    let content: String
    let description: String
    let startDateTime: LocalDateTimeValue
    let endDateTime: LocalDateTimeValue
}
