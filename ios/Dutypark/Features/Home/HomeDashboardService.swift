import Foundation

nonisolated protocol HomeDashboardServing: Sendable {
    func loadMyDashboard() async throws -> DashboardMyDetailDTO
    func loadFriendsDashboard() async throws -> DashboardFriendInfoDTO
}

nonisolated struct HomeDashboardService: HomeDashboardServing {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func loadMyDashboard() async throws -> DashboardMyDetailDTO {
        try await client.request("dashboard/my")
    }

    func loadFriendsDashboard() async throws -> DashboardFriendInfoDTO {
        try await client.request("dashboard/friends")
    }
}
