import Foundation

struct Friend: Decodable, Identifiable {
    let id: Int
    let name: String
    let team: String?
    let isFamily: Bool
    let isPinned: Bool
    let hasProfilePhoto: Bool?
    let profilePhotoVersion: Int?
}

struct FriendListResponse: Decodable {
    let friends: [Friend]
}

// MARK: - Friend Requests
struct FriendRequest: Decodable, Identifiable {
    let id: Int
    let fromMemberId: Int
    let fromMemberName: String
    let toMemberId: Int
    let toMemberName: String
    let status: String
    let requestType: String
    let createdAt: String?
}

struct FriendRequestResponse: Decodable {
    let requests: [FriendRequest]
}
