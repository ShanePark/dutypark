import Foundation

nonisolated struct BlockedMemberDTO: Codable, Equatable, Sendable {
    let id: MemberID
    let name: String
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
    let blockedAt: LocalDateTimeValue
}
