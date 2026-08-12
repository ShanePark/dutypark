import Foundation

nonisolated struct AdminMemberDTO: Codable, Equatable, Identifiable, Sendable {
    let id: MemberID
    let name: String
    let email: String?
    let teamId: TeamID?
    let teamName: String?
    let tokens: [SettingsRefreshToken]
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
}
nonisolated struct AdminMemberDetailDTO: Codable, Equatable, Identifiable, Sendable {
    let id: MemberID
    let name: String
    let email: String?
    let teamId: TeamID?
    let teamName: String?
    let calendarVisibility: Visibility
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
    let serviceAdmin: Bool
    let teamAdmin: Bool
    let teamManager: Bool
    let auxiliaryAccount: Bool
    let hasPassword: Bool
    let authProviders: [String]
    let createdDate: LocalDateTimeValue
    let lastModifiedDate: LocalDateTimeValue
    let activeSessionCount: Int
    let pushEnabledSessionCount: Int
    let lastActiveAt: LocalDateTimeValue?
    let totalScheduleCount: Int64
    let upcomingScheduleCount: Int64
    let taggedScheduleCount: Int64
    let totalTodoCount: Int64
    let todoCount: Int64
    let inProgressTodoCount: Int64
    let doneTodoCount: Int64
    let overdueTodoCount: Int64
    let dueTodayTodoCount: Int64
    let dDays: [DDayDTO]
    let friendCount: Int64
    let familyCount: Int64
    let pendingReceivedFriendRequestCount: Int64
    let pendingSentFriendRequestCount: Int64
    let managerCount: Int64
    let managedMemberCount: Int64
    let managerNames: [String]
    let managedMemberNames: [String]
    let totalNotificationCount: Int64
    let unreadNotificationCount: Int64
}

nonisolated struct AdminTeamCreateDTO: Encodable, Equatable, Sendable {
    let name: String
    let description: String
}

nonisolated enum AdminTeamNameCheckResult: String, Codable, Equatable, Sendable {
    case ok = "OK"
    case duplicated = "DUPLICATED"
    case tooLong = "TOO_LONG"
    case tooShort = "TOO_SHORT"
}

nonisolated struct AdminPasswordChangeRequest: Encodable, Equatable, Sendable {
    let memberId: MemberID
    let currentPassword: String?
    let newPassword: String
}

nonisolated enum AdminMenuDestination: String, CaseIterable, Equatable, Sendable {
    case members
    case teams
    case development
    case apiDocumentation

    static func visibleDestinations(isAdmin: Bool) -> [Self] {
        isAdmin ? allCases : []
    }
}
