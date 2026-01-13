import Foundation

struct Friend: Decodable, Identifiable {
    let id: Int
    let name: String
    let teamName: String?
    let isPinned: Bool
}

struct FriendListResponse: Decodable {
    let friends: [Friend]
}
