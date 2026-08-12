import Foundation

nonisolated struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
    let rememberMe: Bool
}

nonisolated struct LoginMember: Codable, Equatable, Sendable {
    let id: Int64
    let email: String?
    let name: String
    let teamId: Int64?
    let team: String?
    let isAdmin: Bool
    let isImpersonating: Bool
    let originalMemberId: Int64?
}

nonisolated struct TokenResponse: Decodable, Sendable {
    let expiresIn: Int
}

nonisolated struct AuthService: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func login(email: String, password: String, rememberMe: Bool) async throws -> LoginMember {
        let request = LoginRequest(
            email: email,
            password: password,
            rememberMe: rememberMe
        )
        let _: TokenResponse = try await client.request(
            "auth/token",
            method: .post,
            body: request,
            retryingAfterUnauthorized: false
        )
        guard let member = try await status() else {
            throw APIError.invalidResponse
        }
        return member
    }

    func status() async throws -> LoginMember? {
        try await client.optional("auth/status")
    }

    func restore() async throws -> LoginMember? {
        if let member = try await status() {
            return member
        }
        do {
            let _: TokenResponse = try await client.request(
                "auth/refresh",
                method: .post,
                body: EmptyRequest(),
                retryingAfterUnauthorized: false
            )
        } catch APIError.server(status: 401, code: _) {
            return nil
        }
        return try await status()
    }

    func impersonate(memberId: Int64) async throws -> (LoginMember, expiresIn: Int) {
        let response: TokenResponse = try await client.request(
            "auth/impersonate/\(memberId)",
            method: .post,
            body: EmptyRequest(),
            retryingAfterUnauthorized: false
        )
        await client.setImpersonating(true)
        guard let member = try await status() else {
            throw APIError.invalidResponse
        }
        return (member, response.expiresIn)
    }

    func restoreOriginalAccount() async throws -> LoginMember {
        let _: TokenResponse = try await client.request(
            "auth/restore",
            method: .post,
            body: EmptyRequest(),
            retryingAfterUnauthorized: false
        )
        await client.setImpersonating(false)
        guard let member = try await status() else {
            throw APIError.invalidResponse
        }
        return member
    }

    func setImpersonating(_ value: Bool) async {
        await client.setImpersonating(value)
    }

    func setAuthenticationFailureHandler(
        _ handler: (@Sendable () async -> Void)?
    ) async {
        await client.setAuthenticationFailureHandler(handler)
    }

    func logout() async throws {
        _ = try await client.data(
            "auth/logout",
            method: .post,
            retryingAfterUnauthorized: false
        )
    }

    func clearLocalAuthentication() async {
        await client.clearLocalAuthentication()
    }
}

nonisolated private struct EmptyRequest: Encodable, Sendable {}
