import Foundation

nonisolated enum Visibility: Codable, Hashable, Sendable {
    case publicAccess
    case friends
    case family
    case privateAccess
    case unknown(String)

    var rawValue: String {
        switch self {
        case .publicAccess: "PUBLIC"
        case .friends: "FRIENDS"
        case .family: "FAMILY"
        case .privateAccess: "PRIVATE"
        case .unknown(let value): value
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "PUBLIC": .publicAccess
        case "FRIENDS": .friends
        case "FAMILY": .family
        case "PRIVATE": .privateAccess
        default: .unknown(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct MemberPreviewDTO: Codable, Equatable, Sendable {
    let id: MemberID?
    let name: String
    let teamId: TeamID?
    let team: String?
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
}

nonisolated struct MemberDTO: Codable, Equatable, Sendable {
    let id: MemberID?
    let name: String
    let email: String?
    let teamId: TeamID?
    let team: String?
    let calendarVisibility: Visibility
    let kakaoId: String?
    let naverId: String?
    let appleId: String?
    let hasPassword: Bool
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64

    init(
        id: MemberID?,
        name: String,
        email: String?,
        teamId: TeamID?,
        team: String?,
        calendarVisibility: Visibility,
        kakaoId: String?,
        naverId: String?,
        appleId: String? = nil,
        hasPassword: Bool,
        hasProfilePhoto: Bool,
        profilePhotoVersion: Int64
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.teamId = teamId
        self.team = team
        self.calendarVisibility = calendarVisibility
        self.kakaoId = kakaoId
        self.naverId = naverId
        self.appleId = appleId
        self.hasPassword = hasPassword
        self.hasProfilePhoto = hasProfilePhoto
        self.profilePhotoVersion = profilePhotoVersion
    }
}

nonisolated struct MemberInviteCandidateDTO: Codable, Equatable, Sendable {
    let id: MemberID?
    let name: String
    let email: String?
    let teamId: TeamID?
    let team: String?
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
}

nonisolated struct VisibilityUpdateRequest: Codable, Equatable, Sendable {
    let visibility: Visibility
}

nonisolated struct AuxiliaryAccountCreateRequest: Codable, Equatable, Sendable {
    let name: String
}

nonisolated struct DDayDTO: Codable, Equatable, Sendable {
    let id: Int64
    let title: String
    let date: DateOnly
    let isPrivate: Bool
    let calc: Int64
    let daysLeft: Int64
}

nonisolated struct DDaySaveDTO: Codable, Equatable, Sendable {
    let id: Int64?
    let title: String
    let date: DateOnly
    let isPrivate: Bool
}

nonisolated struct DashboardMyDetailDTO: Codable, Equatable, Sendable {
    let member: MemberDTO
    let duty: DutyDTO?
    let schedules: [ScheduleDTO]
}

nonisolated struct DashboardFriendDetailDTO: Codable, Equatable, Sendable {
    let member: MemberPreviewDTO
    let duty: DutyDTO?
    let schedules: [ScheduleDTO]
    let isFamily: Bool
    let pinOrder: Int64?
}

nonisolated struct DashboardFriendInfoDTO: Codable, Equatable, Sendable {
    let friends: [DashboardFriendDetailDTO]
    let pendingRequestsTo: [FriendRequestDTO]
    let pendingRequestsFrom: [FriendRequestDTO]
}
