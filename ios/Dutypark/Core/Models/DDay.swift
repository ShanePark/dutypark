import Foundation

struct DDay: Decodable, Identifiable {
    let id: Int
    let title: String
    let targetDate: String
    let isPrivate: Bool
    let isPinned: Bool
    let daysRemaining: Int

    var displayText: String {
        if daysRemaining == 0 {
            return "D-Day"
        } else if daysRemaining > 0 {
            return "D-\(daysRemaining)"
        } else {
            return "D+\(abs(daysRemaining))"
        }
    }
}

struct DDayListResponse: Decodable {
    let ddays: [DDay]
}
