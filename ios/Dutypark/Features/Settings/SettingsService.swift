import Foundation

nonisolated enum SessionClientType: String, Codable, Equatable, Sendable {
    case browser = "BROWSER"
    case iosApp = "IOS_APP"

    /// Sessions created before the server started sending the marker, and markers this app build does
    /// not know yet, must keep rendering as browser sessions instead of failing the whole decode.
    init(from decoder: any Decoder) throws {
        let raw = try? decoder.singleValueContainer().decode(String.self)
        self = raw.flatMap(SessionClientType.init(rawValue:)) ?? .browser
    }
}

nonisolated struct SettingsRefreshToken: Codable, Equatable, Identifiable, Sendable {
    struct UserAgent: Codable, Equatable, Sendable {
        let os: String
        let browser: String
        let device: String
    }

    let memberName: String
    let memberId: Int64
    let validUntil: String
    let createdDate: String?
    let lastUsed: String?
    let remoteAddr: String?
    let id: Int64
    let userAgent: UserAgent?
    let isCurrentLogin: Bool?
    var clientType: SessionClientType?

    /// The server marker is optional on the wire until the backend change ships, so absent values
    /// resolve to a browser session.
    var resolvedClientType: SessionClientType { clientType ?? .browser }

    private enum CodingKeys: String, CodingKey {
        case memberName, memberId, validUntil, createdDate, lastUsed, remoteAddr
        case id, userAgent, isCurrentLogin, clientType
    }
}

nonisolated enum SettingsSessionPolicy {
    static func canRevoke(_ token: SettingsRefreshToken) -> Bool {
        token.isCurrentLogin != true
    }
}

nonisolated struct PasswordChangeRequest: Encodable, Equatable, Sendable {
    let memberId: Int64
    let currentPassword: String
    let newPassword: String
}

nonisolated struct DeletedSessionsResponse: Decodable, Equatable, Sendable {
    let deletedCount: Int
}

nonisolated struct AccountDeletionPreview: Decodable, Equatable, Sendable {
    let hasPassword: Bool
    let socialProviders: [OAuthProvider]
    let teamImpact: AccountDeletionTeamImpact?
    let auxiliaryImpacts: [AccountDeletionAuxiliaryImpact]
}

nonisolated struct AccountDeletionTeamImpact: Decodable, Equatable, Sendable {
    let teamId: Int64
    let teamName: String
    let isAdmin: Bool
    let activeMemberCount: Int
    let willDeleteTeam: Bool
    let transferCandidates: [AccountDeletionTransferCandidate]
}

nonisolated struct AccountDeletionTransferCandidate: Decodable, Equatable, Identifiable, Sendable {
    let memberId: Int64
    let name: String

    var id: Int64 { memberId }
}

nonisolated struct AccountDeletionAuxiliaryImpact: Decodable, Equatable, Identifiable, Sendable {
    let memberId: Int64
    let name: String
    let willDelete: Bool

    var id: Int64 { memberId }
}

nonisolated struct AccountDeletionReauthRequest: Encodable, Equatable, Sendable {
    let purpose: String
    let password: String
}

nonisolated struct AccountDeletionReauthProof: Decodable, Equatable, Sendable {
    let reauthProof: String
    let expiresIn: Int
}

nonisolated struct AccountDeletionRequest: Encodable, Equatable, Sendable {
    let confirmation: String
    let password: String?
    let reauthProof: String
    let receiptToken: String
    let transferAdminToMemberId: Int64?
}

nonisolated struct AccountDeletionAccepted: Decodable, Equatable, Sendable {
    let jobId: Int64
    let status: String
    let receiptToken: String
    let estimatedCompletionAt: String
    let receiptExpiresAt: String?

    init(
        jobId: Int64,
        status: String,
        receiptToken: String = "",
        estimatedCompletionAt: String = "",
        receiptExpiresAt: String? = nil
    ) {
        self.jobId = jobId
        self.status = status
        self.receiptToken = receiptToken
        self.estimatedCompletionAt = estimatedCompletionAt
        self.receiptExpiresAt = receiptExpiresAt
    }

    func receipt(ownerMemberID: Int64) -> AccountDeletionReceipt? {
        guard ownerMemberID > 0,
              !receiptToken.isEmpty,
              !estimatedCompletionAt.isEmpty
        else { return nil }
        return AccountDeletionReceipt(
            jobId: jobId,
            status: status,
            ownerMemberID: ownerMemberID,
            receiptToken: receiptToken,
            estimatedCompletionAt: estimatedCompletionAt,
            receiptExpiresAt: receiptExpiresAt
        )
    }
}

nonisolated struct AccountDeletionReceipt: Codable, Equatable, Sendable {
    let jobId: Int64
    let status: String
    let ownerMemberID: Int64
    let receiptToken: String
    let estimatedCompletionAt: String
    let receiptExpiresAt: String?

    init(
        jobId: Int64,
        status: String,
        ownerMemberID: Int64,
        receiptToken: String,
        estimatedCompletionAt: String,
        receiptExpiresAt: String? = nil
    ) {
        self.jobId = jobId
        self.status = status
        self.ownerMemberID = ownerMemberID
        self.receiptToken = receiptToken
        self.estimatedCompletionAt = estimatedCompletionAt
        self.receiptExpiresAt = receiptExpiresAt
    }
}

nonisolated struct AccountDeletionStatusRequest: Encodable, Equatable, Sendable {
    let receiptToken: String
}

nonisolated struct AccountDeletionStatusResponse: Decodable, Equatable, Sendable {
    let status: String
    let estimatedCompletionAt: String
    let completedAt: String?
    let receiptExpiresAt: String?

    init(
        status: String,
        estimatedCompletionAt: String,
        completedAt: String? = nil,
        receiptExpiresAt: String? = nil
    ) {
        self.status = status
        self.estimatedCompletionAt = estimatedCompletionAt
        self.completedAt = completedAt
        self.receiptExpiresAt = receiptExpiresAt
    }
}

nonisolated enum AccountDeletionReceiptError: Error, Equatable, Sendable {
    case invalidResponse
}

nonisolated protocol AccountDeletionStatusServicing: Sendable {
    func accountDeletionStatus(receiptToken: String) async throws -> AccountDeletionStatusResponse
}

nonisolated protocol AccountDeletionServicing: Sendable {
    func accountDeletionPreview() async throws -> AccountDeletionPreview
    func reauthenticateForAccountDeletion(password: String) async throws -> AccountDeletionReauthProof
    func requestAccountDeletion(
        reauthProof: String,
        receiptToken: String,
        transferAdminToMemberId: Int64?
    ) async throws -> AccountDeletionAccepted
}

nonisolated struct SettingsService: AccountDeletionServicing, AccountDeletionStatusServicing, Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func member() async throws -> MemberDTO {
        try await client.request("members/me")
    }

    func familyMembers() async throws -> [MemberPreviewDTO] {
        try await client.request("members/family")
    }

    func friends() async throws -> [FriendDTO] {
        try await client.request("friends")
    }

    func managers() async throws -> [MemberDTO] {
        try await client.request("members/managers")
    }

    func managedMembers() async throws -> [MemberDTO] {
        try await client.request("members/managed")
    }

    func sessions() async throws -> [SettingsRefreshToken] {
        try await client.request(
            "auth/refresh-tokens",
            queryItems: [URLQueryItem(name: "validOnly", value: "true")]
        )
    }

    func policies() async throws -> CurrentPoliciesDTO {
        try await client.request("policies/current")
    }

    func dutyPattern() async throws -> DutyPatternDTO {
        try await client.request("duty/pattern/me")
    }

    func updateDutyPattern(_ request: DutyPatternUpdateDTO) async throws -> DutyPatternDTO {
        try await client.request("duty/pattern/me", method: .put, body: request)
    }

    func deleteDutyPattern() async throws {
        _ = try await client.data("duty/pattern/me", method: .delete)
    }

    func updateVisibility(memberID: Int64, visibility: Visibility) async throws {
        let body = try JSONEncoder().encode(VisibilityUpdateRequest(visibility: visibility))
        _ = try await client.data(
            "members/\(memberID)/visibility",
            method: .put,
            body: body,
            headers: ["Content-Type": "application/json"]
        )
    }

    func uploadProfilePhoto(jpegData: Data) async throws {
        guard jpegData.count <= ProfilePhotoProcessingPolicy.maxUploadBytes else {
            throw ProfilePhotoUploadError.tooLarge(
                maxBytes: ProfilePhotoProcessingPolicy.maxUploadBytes
            )
        }

        let boundary = "Dutypark-\(UUID().uuidString)"
        let header = "--\(boundary)\r\n"
            + "Content-Disposition: form-data; name=\"file\"; filename=\"profile.jpg\"\r\n"
            + "Content-Type: image/jpeg\r\n\r\n"
        let footer = "\r\n--\(boundary)--\r\n"
        var body = Data(capacity: header.utf8.count + jpegData.count + footer.utf8.count)
        body.append(contentsOf: header.utf8)
        body.append(jpegData)
        body.append(contentsOf: footer.utf8)

        _ = try await client.data(
            "members/profile-photo",
            method: .put,
            body: body,
            headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
        )
    }

    func deleteProfilePhoto() async throws {
        _ = try await client.data("members/profile-photo", method: .delete)
    }

    func profilePhotoData(memberID: Int64) async throws -> Data {
        try await client.data(
            "members/\(memberID)/profile-photo",
            queryItems: [URLQueryItem(name: "thumbnail", value: "false")]
        )
    }

    func assignManager(_ memberID: Int64) async throws {
        _ = try await client.data("members/manager/\(memberID)", method: .post)
    }

    func unassignManager(_ memberID: Int64) async throws {
        _ = try await client.data("members/manager/\(memberID)", method: .delete)
    }

    func createAuxiliaryAccount(name: String) async throws -> MemberDTO {
        try await client.request(
            "members/auxiliary",
            method: .post,
            body: AuxiliaryAccountCreateRequest(name: name)
        )
    }

    func impersonate(memberID: Int64) async throws {
        _ = try await client.data("auth/impersonate/\(memberID)", method: .post)
    }

    func restoreImpersonation() async throws {
        _ = try await client.data("auth/restore", method: .post)
    }

    func changePassword(_ request: PasswordChangeRequest) async throws {
        let body = try JSONEncoder().encode(request)
        _ = try await client.data(
            "auth/password",
            method: .put,
            body: body,
            headers: ["Content-Type": "application/json"]
        )
    }

    func revokeSession(id: Int64) async throws {
        _ = try await client.data("auth/refresh-tokens/\(id)", method: .delete)
    }

    func revokeOtherSessions() async throws -> Int {
        let response: DeletedSessionsResponse = try await client.request(
            "auth/refresh-tokens/others",
            method: .delete
        )
        return response.deletedCount
    }

    func unlinkSocialAccount(_ provider: OAuthProvider) async throws {
        _ = try await client.data(
            "members/me/social-accounts/\(provider.rawValue)",
            method: .delete
        )
    }

    func accountDeletionPreview() async throws -> AccountDeletionPreview {
        try await client.request("members/me/deletion")
    }

    func reauthenticateForAccountDeletion(password: String) async throws -> AccountDeletionReauthProof {
        try await client.request(
            "auth/reauth/password",
            method: .post,
            body: AccountDeletionReauthRequest(purpose: "DELETE_ACCOUNT", password: password),
            retryingAfterUnauthorized: false
        )
    }

    func requestAccountDeletion(
        reauthProof: String,
        receiptToken: String,
        transferAdminToMemberId: Int64?
    ) async throws -> AccountDeletionAccepted {
        try await client.request(
            "members/me/deletion",
            method: .post,
            body: AccountDeletionRequest(
                confirmation: "DELETE",
                password: nil,
                reauthProof: reauthProof,
                receiptToken: receiptToken,
                transferAdminToMemberId: transferAdminToMemberId
            ),
            retryingAfterUnauthorized: false
        )
    }

    func accountDeletionStatus(receiptToken: String) async throws -> AccountDeletionStatusResponse {
        try await client.request(
            "account-deletions/status",
            method: .post,
            body: AccountDeletionStatusRequest(receiptToken: receiptToken),
            retryingAfterUnauthorized: false
        )
    }

    func profilePhotoURL(memberID: Int64, version: Int64) -> URL {
        client.baseURL
            .appending(path: "members/\(memberID)/profile-photo")
            .appending(queryItems: [
                URLQueryItem(name: "thumbnail", value: "true"),
                URLQueryItem(name: "v", value: String(version)),
            ])
    }
}
