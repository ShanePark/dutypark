import Foundation

// MARK: - Requests
struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RefreshTokenRequest: Encodable {
    let refreshToken: String
}

// MARK: - Responses
struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

struct LoginMember: Decodable {
    let id: Int
    let email: String
    let name: String
    let teamId: Int?
    let team: String?
    let isAdmin: Bool
    let isImpersonating: Bool
    let originalMemberId: Int?
    let hasProfilePhoto: Bool?
    let profilePhotoVersion: Int?
}
