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

nonisolated enum InquiryStatus: String, Codable, Equatable, Sendable {
    case open = "OPEN"
    case closed = "CLOSED"
}

/// One row of `GET /api/inquiries/me`. The endpoint deliberately omits the
/// administrator-only fields (`adminMemo`, `ipAddress`, `answeredBy`), so nothing here
/// can leak them into the member-facing list.
nonisolated struct MyInquiryDTO: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let email: String
    let subject: String?
    let content: String
    let status: InquiryStatus
    let createdAt: LocalDateTimeValue
    let answer: String?
    let answeredAt: LocalDateTimeValue?

    /// A blank answer is treated as no answer so the row never promises a reply the
    /// member cannot read.
    var answerText: String? {
        guard let trimmed = answer?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }

    var hasAnswer: Bool {
        answerText != nil
    }
}
