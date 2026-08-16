import Foundation

nonisolated protocol PublicContentServicing: Sendable {
    func guide(locale: String) async throws -> PublicGuideContent
    func releaseNotes(locale: String, page: Int, size: Int) async throws -> PublicReleaseNotesPage
}

nonisolated final class PublicContentService: PublicContentServicing, Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func guide(locale: String) async throws -> PublicGuideContent {
        try await get(
            "public-content/guide",
            queryItems: [URLQueryItem(name: "locale", value: locale)]
        )
    }

    func releaseNotes(
        locale: String,
        page: Int,
        size: Int
    ) async throws -> PublicReleaseNotesPage {
        try await get(
            "public-content/release-notes",
            queryItems: [
                URLQueryItem(name: "locale", value: locale),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        )
    }

    private func get<Response: PublicContentEnvelope>(
        _ path: String,
        queryItems: [URLQueryItem]
    ) async throws -> Response {
        let data = try await client.data(
            path,
            queryItems: queryItems,
            retryingAfterUnauthorized: false
        )
        do {
            let response = try JSONDecoder().decode(Response.self, from: data)
            guard response.schemaVersion == 1 else { throw APIError.decoding }
            return response
        } catch {
            throw APIError.decoding
        }
    }
}
