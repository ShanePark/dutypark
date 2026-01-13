import Foundation

struct MemberDto: Decodable, Identifiable {
    let id: Int?
    let name: String
    let email: String?
    let teamId: Int?
    let team: String?
    let calendarVisibility: CalendarVisibility
    let kakaoId: String?
    let hasPassword: Bool
    let hasProfilePhoto: Bool?
    let profilePhotoVersion: Int?
}

struct RefreshTokenDto: Decodable, Identifiable {
    let id: Int
    let token: String
    let memberName: String
    let memberId: Int
    let validUntil: String
    let createdDate: String?
    let lastUsed: String?
    let remoteAddr: String?
    let userAgent: RefreshTokenUserAgent?
    let isCurrentLogin: Bool?
}

struct RefreshTokenUserAgent: Decodable {
    let os: String
    let browser: String
    let device: String
}

// MARK: - Legacy support (can be removed after full migration)
typealias User = MemberDto
