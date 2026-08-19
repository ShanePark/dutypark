import Foundation

/// Body of `POST /api/inquiries`. A guest is answered by e-mail and must name an address;
/// a member reads the answer in the app, so the field is left out and the server records
/// the account e-mail on its own — a social account has none to send anyway.
nonisolated struct CreateInquiryRequest: Encodable, Equatable, Sendable {
    static let subjectMaximumLength = 100
    static let contentMaximumLength = 2000

    let email: String?
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
    /// Null when a member sent the inquiry without an account e-mail to reply to.
    let email: String?
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
