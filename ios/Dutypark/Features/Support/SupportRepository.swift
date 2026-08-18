import Foundation

nonisolated protocol SupportRepository: Sendable {
    func submitInquiry(_ request: CreateInquiryRequest) async throws
}

nonisolated struct LiveSupportRepository: SupportRepository {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// The endpoint is open to guests, so a missing session must surface the server's
    /// own response instead of driving the shared refresh/logout path.
    func submitInquiry(_ request: CreateInquiryRequest) async throws {
        let body: Data
        do {
            body = try JSONEncoder().encode(request)
        } catch {
            throw APIError.decoding
        }
        _ = try await client.data(
            "inquiries",
            method: .post,
            body: body,
            retryingAfterUnauthorized: false
        )
    }
}
