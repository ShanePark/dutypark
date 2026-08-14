import Foundation

nonisolated struct DutyBatchTemplateDTO: Codable, Equatable, Sendable {
    let name: String
    let label: String
    let fileExtensions: [String]
}

nonisolated struct TeamMemberDTO: Codable, Equatable, Sendable {
    let id: MemberID?
    let name: String
    let email: String?
    let isManager: Bool
    let isAdmin: Bool
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
}

nonisolated struct TeamDTO: Codable, Equatable, Sendable {
    let id: TeamID
    let name: String
    let description: String?
    let dutyTypes: [DutyTypeDTO]
    let members: [TeamMemberDTO]
    let createdDate: LocalDateTimeValue
    let lastModifiedDate: LocalDateTimeValue
    let adminId: MemberID?
    let adminName: String?
    let dutyBatchTemplate: DutyBatchTemplateDTO?
}

nonisolated struct SimpleTeamDTO: Codable, Equatable, Sendable {
    let id: TeamID
    let name: String
    let description: String?
    let memberCount: Int64
}

nonisolated struct TeamDayDTO: Codable, Equatable, Sendable {
    let year: Int
    let month: Int
    let day: Int
}

nonisolated struct MyTeamSummaryDTO: Codable, Equatable, Sendable {
    let year: Int
    let month: Int
    let team: TeamDTO?
    let teamDays: [TeamDayDTO]
    let isTeamManager: Bool
}

nonisolated struct DutyTypeCreateDTO: Codable, Equatable, Sendable {
    let teamId: TeamID
    let name: String
    let color: String
}

nonisolated struct DutyTypeUpdateDTO: Codable, Equatable, Sendable {
    let id: DutyTypeID
    let name: String
    let color: String
}

nonisolated struct DutyTypeVisibilityDTO: Codable, Equatable, Sendable {
    let hidden: Bool
}
