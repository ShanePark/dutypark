import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var dashboard: DashboardResponse?
    @Published var isLoading = false
    @Published var error: Error?

    func loadDashboard() async {
        isLoading = true
        defer { isLoading = false }

        do {
            dashboard = try await APIClient.shared.request(
                .dashboard,
                responseType: DashboardResponse.self
            )
        } catch {
            self.error = error
        }
    }
}
