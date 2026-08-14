import Foundation

nonisolated protocol SocialRepository: Sendable {
    func friendInfo() async throws -> DashboardFriendInfoDTO
    func search(keyword: String, page: Int, size: Int) async throws -> PageResponse<MemberPreviewDTO>
    func sendFriendRequest(to memberID: MemberID) async throws
    func cancelRequest(to memberID: MemberID) async throws
    func acceptRequest(from memberID: MemberID) async throws
    func rejectRequest(from memberID: MemberID) async throws
    func sendFamilyRequest(to memberID: MemberID) async throws
    func removeFromFamily(_ memberID: MemberID) async throws
    func removeFriend(_ memberID: MemberID) async throws
    func pin(_ memberID: MemberID) async throws
    func unpin(_ memberID: MemberID) async throws
    func updatePinnedOrder(_ memberIDs: [MemberID]) async throws
}

nonisolated struct LiveSocialRepository: SocialRepository {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func friendInfo() async throws -> DashboardFriendInfoDTO {
        try await client.request("dashboard/friends")
    }

    func search(keyword: String, page: Int, size: Int) async throws -> PageResponse<MemberPreviewDTO> {
        try await client.request(
            "friends/search",
            queryItems: [
                URLQueryItem(name: "keyword", value: keyword),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
        )
    }

    func sendFriendRequest(to memberID: MemberID) async throws {
        try await mutation("friends/request/send/\(memberID)", method: .post)
    }

    func cancelRequest(to memberID: MemberID) async throws {
        try await mutation("friends/request/cancel/\(memberID)", method: .delete)
    }

    func acceptRequest(from memberID: MemberID) async throws {
        try await mutation("friends/request/accept/\(memberID)", method: .post)
    }

    func rejectRequest(from memberID: MemberID) async throws {
        try await mutation("friends/request/reject/\(memberID)", method: .post)
    }

    func sendFamilyRequest(to memberID: MemberID) async throws {
        try await mutation("friends/family/\(memberID)", method: .put)
    }

    func removeFromFamily(_ memberID: MemberID) async throws {
        try await mutation("friends/family/\(memberID)", method: .delete)
    }

    func removeFriend(_ memberID: MemberID) async throws {
        try await mutation("friends/\(memberID)", method: .delete)
    }

    func pin(_ memberID: MemberID) async throws {
        try await mutation("friends/pin/\(memberID)", method: .patch)
    }

    func unpin(_ memberID: MemberID) async throws {
        try await mutation("friends/unpin/\(memberID)", method: .patch)
    }

    func updatePinnedOrder(_ memberIDs: [MemberID]) async throws {
        let body: Data
        do {
            body = try JSONEncoder().encode(memberIDs)
        } catch {
            throw APIError.decoding
        }
        _ = try await client.data("friends/pin/order", method: .patch, body: body)
    }

    private func mutation(_ path: String, method: HTTPMethod) async throws {
        _ = try await client.data(path, method: method)
    }
}
