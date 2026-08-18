import Foundation

nonisolated protocol SupportRepository: Sendable {
    func submitInquiry(_ request: CreateInquiryRequest) async throws
    func fetchMyInquiries(page: Int, size: Int) async throws -> PageResponse<MyInquiryDTO>
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

    /// Members only. The server scopes the page to the caller's own inquiries, so no
    /// member identifier is sent.
    func fetchMyInquiries(page: Int, size: Int) async throws -> PageResponse<MyInquiryDTO> {
        try await client.request(
            "inquiries/me",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
        )
    }
}
