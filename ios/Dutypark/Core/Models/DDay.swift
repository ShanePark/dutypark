import Foundation

struct DDayDto: Decodable, Identifiable {
    let id: Int
    let title: String
    let date: String
    let isPrivate: Bool
    let calc: Int
    let daysLeft: Int

    var displayText: String {
        if daysLeft == 0 {
            return "D-Day"
        } else if daysLeft > 0 {
            return "D-\(daysLeft)"
        } else {
            return "D+\(abs(daysLeft))"
        }
    }
}

// MARK: - Requests
struct DDaySaveDto: Encodable {
    let id: Int?
    let title: String
    let date: String
    let isPrivate: Bool
}

// MARK: - Responses
struct DDayListResponse: Decodable {
    let ddays: [DDayDto]
}

// MARK: - Legacy support (can be removed after full migration)
typealias DDay = DDayDto
