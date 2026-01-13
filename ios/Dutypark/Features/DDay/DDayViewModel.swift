import Foundation

@MainActor
class DDayViewModel: ObservableObject {
    @Published var ddays: [DDayDto] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadDDays() async {
        isLoading = true
        error = nil

        do {
            ddays = try await APIClient.shared.request(.ddays, responseType: [DDayDto].self)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func createDDay(title: String, date: Date, isPrivate: Bool) async -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let request = DDaySaveDto(
            id: nil,
            title: title,
            date: formatter.string(from: date),
            isPrivate: isPrivate
        )

        do {
            let _: DDayDto = try await APIClient.shared.request(
                .createDday(request: request),
                responseType: DDayDto.self
            )
            await loadDDays()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteDDay(_ id: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.deleteDday(id: id))
            await loadDDays()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
