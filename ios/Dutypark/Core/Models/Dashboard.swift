import Foundation

// MARK: - Dashboard Member
struct DashboardMemberDto: Decodable, Identifiable {
    let id: Int?
    let name: String
    let email: String?
    let teamId: Int?
    let team: String?
    let calendarVisibility: CalendarVisibility
    let kakaoId: String?
    let hasPassword: Bool?
    let hasProfilePhoto: Bool?
    let profilePhotoVersion: Int?
}

// MARK: - Dashboard Friend
struct DashboardFriendDto: Decodable {
    let id: Int?
    let name: String
    let teamId: Int?
    let team: String?
    let hasProfilePhoto: Bool?
    let profilePhotoVersion: Int?
}

// MARK: - Dashboard Duty
struct DashboardDutyDto: Decodable {
    let year: Int
    let month: Int
    let day: Int
    let dutyType: String?
    let dutyColor: String?
    let isOff: Bool
}

// MARK: - Dashboard Schedule
struct DashboardScheduleDto: Decodable, Identifiable {
    let id: String
    let content: String
    let description: String
    let position: Int
    let year: Int
    let month: Int
    let dayOfMonth: Int
    let startDateTime: String
    let endDateTime: String
    let isTagged: Bool
    let owner: String
    let tags: [DashboardMemberDto]
    let visibility: CalendarVisibility?
    let dateToCompare: String
    let attachments: [Attachment]
    let startDate: String
    let daysFromStart: Int
    let endDate: String
    let totalDays: Int
    let curDate: String
}

// MARK: - Dashboard Friend Request
struct DashboardFriendRequestDto: Decodable, Identifiable {
    let id: Int
    let fromMember: DashboardFriendDto
    let toMember: DashboardFriendDto
    let status: String
    let createdAt: String?
    let requestType: String
}

// MARK: - Dashboard My Detail
struct DashboardMyDetail: Decodable {
    let member: DashboardMemberDto
    let duty: DashboardDutyDto?
    let schedules: [DashboardScheduleDto]
}

// MARK: - Dashboard Friend Detail
struct DashboardFriendDetail: Decodable, Identifiable {
    var id: Int? { member.id }
    let member: DashboardFriendDto
    let duty: DashboardDutyDto?
    let schedules: [DashboardScheduleDto]
    let isFamily: Bool
    let pinOrder: Int?
}

// MARK: - Dashboard Friend Info
struct DashboardFriendInfo: Decodable {
    let friends: [DashboardFriendDetail]
    let pendingRequestsTo: [DashboardFriendRequestDto]
    let pendingRequestsFrom: [DashboardFriendRequestDto]
}

// MARK: - Legacy support (can be removed after full migration)
typealias DashboardResponse = DashboardMyDetail
typealias DashboardMember = DashboardMemberDto
typealias FriendsDashboardResponse = DashboardFriendInfo
typealias FriendDashboard = DashboardFriendDetail
