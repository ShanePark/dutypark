import Foundation

struct DashboardResponse: Decodable {
    let member: DashboardMember
    let todayDuty: DutyInfo?
    let todaySchedules: [Schedule]
    let pinnedDdays: [DDay]
}

struct DashboardMember: Decodable {
    let id: Int
    let name: String
    let teamId: Int?
    let teamName: String?
}

struct FriendsDashboardResponse: Decodable {
    let friends: [FriendDashboard]
    let pendingRequests: [FriendRequest]
}

struct FriendDashboard: Decodable, Identifiable {
    let id: Int
    let name: String
    let todayDuty: DutyInfo?
    let isPinned: Bool
}

struct FriendRequest: Decodable, Identifiable {
    let id: Int
    let fromMemberId: Int
    let fromMemberName: String
    let createdAt: String
}
