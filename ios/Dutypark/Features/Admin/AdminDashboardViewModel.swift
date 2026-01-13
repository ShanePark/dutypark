import Foundation

@MainActor
class AdminDashboardViewModel: ObservableObject {
    @Published var members: [AdminMemberDto] = []
    @Published var tokens: [RefreshTokenDto] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentPage = 0
    @Published var totalPages = 0
    @Published var totalElements = 0

    let pageSize = 10

    func loadDashboard(keyword: String = "", page: Int = 0) async {
        isLoading = true
        error = nil

        do {
            async let membersResponse: PageResponse<AdminMemberDto> = AdminAPIClient.shared.request(
                .members(keyword: keyword, page: page, size: pageSize),
                responseType: PageResponse<AdminMemberDto>.self
            )
            async let tokenResponse: [RefreshTokenDto] = AdminAPIClient.shared.request(
                .refreshTokens,
                responseType: [RefreshTokenDto].self
            )

            let (membersPage, allTokens) = try await (membersResponse, tokenResponse)
            members = membersPage.content
            totalPages = membersPage.totalPages
            totalElements = membersPage.totalElements
            tokens = allTokens
            currentPage = page
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func revokeToken(_ tokenId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.deleteRefreshToken(id: tokenId))
            tokens.removeAll { $0.id == tokenId }
            members = members.map { member in
                var updated = member
                updated.tokens.removeAll { $0.id == tokenId }
                return updated
            }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func changePassword(memberId: Int, newPassword: String) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(
                .changePassword(memberId: memberId, currentPassword: nil, newPassword: newPassword)
            )
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
