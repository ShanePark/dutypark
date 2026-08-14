import Foundation

nonisolated protocol AdminRepositoryProtocol: Sendable {
    func members(keyword: String, page: Int, size: Int) async throws -> PageResponse<AdminMemberDTO>
    func memberDetail(id: MemberID) async throws -> AdminMemberDetailDTO
    func sessions() async throws -> [SettingsRefreshToken]
    func revokeSession(id: Int64) async throws
    func changePassword(memberID: MemberID, newPassword: String) async throws
    func teams(keyword: String, page: Int, size: Int) async throws -> PageResponse<SimpleTeamDTO>
    func checkTeamName(_ name: String) async throws -> AdminTeamNameCheckResult
    func createTeam(name: String, description: String) async throws -> TeamDTO
    func deleteTeam(id: TeamID) async throws
}

nonisolated struct AdminRepository: AdminRepositoryProtocol, Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func members(keyword: String, page: Int, size: Int) async throws -> PageResponse<AdminMemberDTO> {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size))
        ]
        if !keyword.isEmpty {
            queryItems.append(URLQueryItem(name: "keyword", value: keyword))
        }
        return try await client.request(
            "members",
            queryItems: queryItems,
            scope: .admin
        )
    }

    func memberDetail(id: MemberID) async throws -> AdminMemberDetailDTO {
        try await client.request("members/\(id)", scope: .admin)
    }

    func sessions() async throws -> [SettingsRefreshToken] {
        try await client.request("refresh-tokens", scope: .admin)
    }

    func revokeSession(id: Int64) async throws {
        _ = try await client.data("auth/refresh-tokens/\(id)", method: .delete)
    }

    func changePassword(memberID: MemberID, newPassword: String) async throws {
        _ = try await client.data(
            "auth/password",
            method: .put,
            body: try JSONEncoder().encode(
                AdminPasswordChangeRequest(
                    memberId: memberID,
                    currentPassword: nil,
                    newPassword: newPassword
                )
            ),
            headers: ["Content-Type": "application/json"]
        )
    }

    func teams(keyword: String, page: Int, size: Int) async throws -> PageResponse<SimpleTeamDTO> {
        try await client.request(
            "teams",
            queryItems: [
                URLQueryItem(name: "keyword", value: keyword),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ],
            scope: .admin
        )
    }

    func checkTeamName(_ name: String) async throws -> AdminTeamNameCheckResult {
        try await client.request(
            "teams/check",
            method: .post,
            body: ["name": name],
            scope: .admin
        )
    }

    func createTeam(name: String, description: String) async throws -> TeamDTO {
        try await client.request(
            "teams",
            method: .post,
            body: AdminTeamCreateDTO(name: name, description: description),
            scope: .admin
        )
    }

    func deleteTeam(id: TeamID) async throws {
        _ = try await client.data("teams/\(id)", method: .delete, scope: .admin)
    }
}
