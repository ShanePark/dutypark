import Foundation

@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var schedules: [Schedule] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let calendar = Calendar.current

    func loadSchedules(for date: Date) async {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .schedules(year: year, month: month),
                responseType: ScheduleListResponse.self
            )
            schedules = response.schedules
        } catch {
            self.error = error
        }
    }

    func deleteSchedule(_ schedule: Schedule) async {
        do {
            try await APIClient.shared.requestVoid(.deleteSchedule(id: schedule.id))
            schedules.removeAll { $0.id == schedule.id }
        } catch {
            self.error = error
        }
    }
}
