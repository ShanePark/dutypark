import Foundation

nonisolated protocol SupportRepository: Sendable {
    func submitInquiry(_ request: CreateInquiryRequest, authenticated: Bool) async throws
    func fetchMyInquiries(page: Int, size: Int) async throws -> PageResponse<MyInquiryDTO>
    func fetchMyReports(page: Int, size: Int) async throws -> PageResponse<MyReportDTO>
    func cancelReport(id: UUID) async throws -> MyReportDTO
}

nonisolated struct LiveSupportRepository: SupportRepository {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func submitInquiry(_ request: CreateInquiryRequest, authenticated: Bool) async throws {
        if authenticated {
            // The create endpoint also accepts guests, so an expired access cookie would
            // otherwise return 201 while silently dropping the member association. Probe
            // a protected endpoint first to use the shared refresh/logout lifecycle.
            _ = try await client.data(
                "inquiries/me",
                queryItems: [
                    URLQueryItem(name: "page", value: "0"),
                    URLQueryItem(name: "size", value: "1")
                ]
            )
        }

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
            // Guests must be able to use the public endpoint without entering the
            // authenticated session failure path. Members were verified above.
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

    /// Members only, and scoped to the caller's own reports the same way.
    func fetchMyReports(page: Int, size: Int) async throws -> PageResponse<MyReportDTO> {
        try await client.request(
            "reports/me",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
        )
    }

    /// Withdraws the caller's own open report. The server answers with the updated row,
    /// so the list can show the new state without refetching the page the reporter is on.
    /// A report that is not the caller's own is answered `404` exactly like one that does
    /// not exist, so nothing here can confirm another member's report.
    func cancelReport(id: UUID) async throws -> MyReportDTO {
        try await client.request("reports/\(id.uuidString)/cancel", method: .post)
    }
}
