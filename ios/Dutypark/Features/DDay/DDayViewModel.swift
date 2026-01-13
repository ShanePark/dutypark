import Foundation

@MainActor
class DDayViewModel: ObservableObject {
    @Published var ddays: [DDayDto] = []
    @Published var pinnedDDayId: Int?
    @Published var isLoading = false
    @Published var error: String?

    var pinnedDDay: DDayDto? {
        guard let pinnedDDayId else { return nil }
        return ddays.first { $0.id == pinnedDDayId }
    }

    func loadDDays(memberId: Int? = nil) async {
        isLoading = true
        error = nil

        do {
            if let memberId {
                ddays = try await APIClient.shared.request(.memberDdays(memberId: memberId), responseType: [DDayDto].self)
            } else {
                ddays = try await APIClient.shared.request(.ddays, responseType: [DDayDto].self)
            }
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

    func updateDDay(id: Int, title: String, date: Date, isPrivate: Bool) async -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let request = DDaySaveDto(
            id: id,
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

    func loadPinnedDDay(memberId: Int) {
        let key = pinnedKey(memberId: memberId)
        let storedId = UserDefaults.standard.object(forKey: key) as? Int
        pinnedDDayId = storedId
    }

    func togglePinnedDDay(_ dday: DDayDto, memberId: Int) {
        let key = pinnedKey(memberId: memberId)
        if pinnedDDayId == dday.id {
            pinnedDDayId = nil
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            pinnedDDayId = dday.id
            UserDefaults.standard.set(dday.id, forKey: key)
        }
    }

    func clearPinnedDDay(memberId: Int) {
        pinnedDDayId = nil
        UserDefaults.standard.removeObject(forKey: pinnedKey(memberId: memberId))
    }

    private func pinnedKey(memberId: Int) -> String {
        "selectedDday_\(memberId)"
    }
}
