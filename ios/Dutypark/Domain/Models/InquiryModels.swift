import Foundation

/// Body of `POST /api/inquiries`. The endpoint accepts guests, so the reply address is
/// always carried in the request instead of being derived from the session.
nonisolated struct CreateInquiryRequest: Encodable, Equatable, Sendable {
    static let subjectMaximumLength = 100
    static let contentMaximumLength = 2000

    let email: String
    let subject: String?
    let content: String
}
