import Foundation

nonisolated protocol ReportRepository: Sendable {
    func createReport(_ request: CreateReportRequest) async throws
    func block(memberID: MemberID) async throws
}

/// Blocking lives here rather than in `SocialRepository` so the report entry points
/// stay independent of the friends screen; both call the same `/api/blocks/{id}`.
nonisolated struct ReportAPIRepository: ReportRepository {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// The server answers `201` for a new report and `200` when the reporter already
    /// has an open report for the same target. Both are successes, so only a non-2xx
    /// status throws.
    func createReport(_ request: CreateReportRequest) async throws {
        let body: Data
        do {
            body = try JSONEncoder().encode(request)
        } catch {
            throw APIError.decoding
        }
        try await client.data("reports", method: .post, body: body)
    }

    func block(memberID: MemberID) async throws {
        try await client.data("blocks/\(memberID)", method: .post)
    }
}
