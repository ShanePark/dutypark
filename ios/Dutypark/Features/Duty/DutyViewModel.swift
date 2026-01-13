import Foundation

@MainActor
final class DutyViewModel: ObservableObject {
    @Published var duties: [String: DutyInfo] = [:]
    @Published var dutyTypes: [DutyType] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let calendar = Calendar.current

    func loadDuties(for date: Date) async {
        guard let memberId = await AuthManager.shared.currentUser?.id else { return }

        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .duties(memberId: memberId, year: year, month: month),
                responseType: DutyResponse.self
            )
            duties = response.duties
            dutyTypes = response.dutyTypes
        } catch {
            self.error = error
        }
    }
}
