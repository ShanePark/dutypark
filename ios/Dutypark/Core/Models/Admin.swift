import Foundation

struct AdminMemberDto: Decodable, Identifiable {
    let id: Int
    let name: String
    let email: String?
    let teamId: Int?
    let teamName: String?
    var tokens: [RefreshTokenDto]
    let hasProfilePhoto: Bool?
    let profilePhotoVersion: Int?
}

struct TeamNameCheckRequest: Encodable {
    let name: String
}
