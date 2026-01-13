import Foundation
import SwiftUI

// MARK: - Pagination Response
struct PageResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let content: [T]
    let totalElements: Int
    let totalPages: Int
    let size: Int
    let number: Int
    let first: Bool
    let last: Bool
}

struct TeamDto: Decodable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let workType: String
    let dutyTypes: [DutyTypeDto]
    let members: [TeamMemberDto]
    let createdDate: String
    let lastModifiedDate: String
    let adminId: Int?
    let adminName: String?
    let dutyBatchTemplate: DutyBatchTemplateDto?
}

struct DutyTypeDto: Decodable, Identifiable {
    let id: Int?
    let name: String
    let position: Int
    let color: String?

    var swiftUIColor: Color {
        guard let color = color else { return .gray }
        return Color(hex: color) ?? .gray
    }
}

struct TeamMemberDto: Decodable, Identifiable {
    let id: Int
    let name: String
    let email: String?
    let isManager: Bool
    let isAdmin: Bool
    let hasProfilePhoto: Bool?
    let profilePhotoVersion: Int?
}

struct DutyBatchTemplateDto: Decodable {
    let name: String
    let label: String
    let fileExtensions: [String]
}

struct MyTeamSummary: Decodable {
    let year: Int
    let month: Int
    let team: TeamDto?
    let teamDays: [TeamDay]
    let isTeamManager: Bool
}

struct TeamDay: Decodable {
    let year: Int
    let month: Int
    let day: Int
}

struct SimpleMemberDto: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let team: String?
    let hasProfilePhoto: Bool?
    let profilePhotoVersion: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        team = try container.decodeIfPresent(String.self, forKey: .team)
        hasProfilePhoto = try container.decodeIfPresent(Bool.self, forKey: .hasProfilePhoto)
        profilePhotoVersion = try container.decodeIfPresent(Int.self, forKey: .profilePhotoVersion)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, team, hasProfilePhoto, profilePhotoVersion
    }
}

struct DutyByShift: Decodable {
    let dutyType: DutyTypeDto
    let members: [SimpleMemberDto]
}

struct TeamScheduleDto: Decodable, Identifiable {
    let id: String
    let teamId: Int
    let content: String
    let description: String
    let position: Int
    let year: Int
    let month: Int
    let dayOfMonth: Int
    let daysFromStart: Int?
    let totalDays: Int?
    let startDateTime: String
    let endDateTime: String
    let createMember: String
    let updateMember: String
}

// MARK: - Requests
struct TeamScheduleSaveDto: Encodable {
    let id: String?
    let teamId: Int
    let content: String
    let description: String?
    let startDateTime: String
    let endDateTime: String
}

struct TeamCreateDto: Encodable {
    let name: String
    let description: String
}

struct DutyTypeCreateDto: Encodable {
    let teamId: Int
    let name: String
    let color: String
}

struct DutyTypeUpdateDto: Encodable {
    let id: Int
    let name: String
    let color: String
}

// MARK: - Simple Team (for admin lists)
struct SimpleTeam: Decodable, Identifiable {
    let id: Int
    let name: String
    let description: String
    let memberCount: Int
}

enum TeamNameCheckResult: String, Decodable {
    case ok = "OK"
    case tooShort = "TOO_SHORT"
    case tooLong = "TOO_LONG"
    case duplicated = "DUPLICATED"
}
