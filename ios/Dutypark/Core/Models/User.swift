import Foundation

struct User: Decodable, Identifiable {
    let id: Int
    let email: String
    let name: String
    let visibility: Visibility?
    let teamId: Int?
    let teamName: String?

    enum Visibility: String, Decodable {
        case `public` = "PUBLIC"
        case friendsOnly = "FRIENDS_ONLY"
        case `private` = "PRIVATE"
    }
}
