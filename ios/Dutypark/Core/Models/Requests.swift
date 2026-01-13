import Foundation

// MARK: - Auth Requests
struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let newPassword: String
}

// MARK: - Duty Requests
struct DutyChangeRequest: Encodable {
    let memberId: Int
    let date: String
    let dutyTypeId: Int?
}

struct DutyBatchRequest: Encodable {
    let memberId: Int
    let year: Int
    let month: Int
    let dutyTypeId: Int?
}

// MARK: - Schedule Requests
struct OrderedIdsRequest: Encodable {
    let orderedIds: [String]
}

// MARK: - Member Requests
struct VisibilityRequest: Encodable {
    let visibility: String
}

// MARK: - Friends Requests
struct PinOrderRequest: Encodable {
    let orderedIds: [Int]
}
