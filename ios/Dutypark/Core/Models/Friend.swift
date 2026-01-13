import Foundation

struct Friend: Identifiable, Decodable {
    let id: Int
    let name: String
    let team: String?
    let isFamily: Bool
    let isPinned: Bool
    let hasProfilePhoto: Bool?
    let profilePhotoVersion: Int?

    init(id: Int, name: String, team: String?, isFamily: Bool, isPinned: Bool, hasProfilePhoto: Bool?, profilePhotoVersion: Int?) {
        self.id = id
        self.name = name
        self.team = team
        self.isFamily = isFamily
        self.isPinned = isPinned
        self.hasProfilePhoto = hasProfilePhoto
        self.profilePhotoVersion = profilePhotoVersion
    }

    init(from detail: DashboardFriendDetail) {
        self.id = detail.member.id ?? 0
        self.name = detail.member.name
        self.team = detail.member.team
        self.isFamily = detail.isFamily
        self.isPinned = detail.pinOrder != nil
        self.hasProfilePhoto = detail.member.hasProfilePhoto
        self.profilePhotoVersion = detail.member.profilePhotoVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        team = try container.decodeIfPresent(String.self, forKey: .team)
        isFamily = try container.decodeIfPresent(Bool.self, forKey: .isFamily) ?? false
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        hasProfilePhoto = try container.decodeIfPresent(Bool.self, forKey: .hasProfilePhoto)
        profilePhotoVersion = try container.decodeIfPresent(Int.self, forKey: .profilePhotoVersion)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, team, isFamily, isPinned, hasProfilePhoto, profilePhotoVersion
    }
}
