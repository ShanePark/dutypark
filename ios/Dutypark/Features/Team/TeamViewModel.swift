import Foundation

@MainActor
class TeamViewModel: ObservableObject {
    @Published var teamSummary: MyTeamSummary?
    @Published var teamSchedules: [TeamScheduleDto] = []
    @Published var shiftData: [DutyByShift] = []
    @Published var selectedYear: Int
    @Published var selectedMonth: Int
    @Published var selectedDay: Int?
    @Published var isLoading = false
    @Published var error: String?
    @Published var holidays: [Int: [HolidayDto]] = [:]

    init() {
        let now = Date()
        let calendar = Calendar.current
        selectedYear = calendar.component(.year, from: now)
        selectedMonth = calendar.component(.month, from: now)
    }

    func loadTeamData() async {
        isLoading = true
        error = nil

        do {
            teamSummary = try await APIClient.shared.request(
                .myTeam(year: selectedYear, month: selectedMonth),
                responseType: MyTeamSummary.self
            )
            await loadTeamSchedules()
            await loadHolidays()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadTeamSchedules() async {
        do {
            teamSchedules = try await APIClient.shared.request(
                .teamSchedules(year: selectedYear, month: selectedMonth),
                responseType: [TeamScheduleDto].self
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadShiftForDay(_ day: Int) async {
        selectedDay = day

        do {
            shiftData = try await APIClient.shared.request(
                .teamShift(year: selectedYear, month: selectedMonth, day: day),
                responseType: [DutyByShift].self
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadHolidays() async {
        do {
            let response = try await APIClient.shared.request(
                .holidays(year: selectedYear, month: selectedMonth),
                responseType: [[HolidayDto]].self
            )
            var holidaysByDay: [Int: [HolidayDto]] = [:]
            for dayHolidays in response {
                for holiday in dayHolidays {
                    guard let components = parseLocalDate(holiday.localDate) else { continue }
                    guard components.year == selectedYear, components.month == selectedMonth, let day = components.day else { continue }
                    holidaysByDay[day, default: []].append(holiday)
                }
            }
            holidays = holidaysByDay
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createTeamSchedule(content: String, description: String?, startDate: Date, endDate: Date) async -> Bool {
        guard let teamId = teamSummary?.team?.id else { return false }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let request = TeamScheduleSaveDto(
            id: nil,
            teamId: teamId,
            content: content,
            description: description,
            startDateTime: formatter.string(from: startDate),
            endDateTime: formatter.string(from: endDate)
        )

        do {
            try await APIClient.shared.requestVoid(.createTeamSchedule(request: request))
            await loadTeamSchedules()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteTeamSchedule(_ id: String) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.deleteTeamSchedule(id: id))
            await loadTeamSchedules()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func previousMonth() {
        if selectedMonth == 1 {
            selectedMonth = 12
            selectedYear -= 1
        } else {
            selectedMonth -= 1
        }
        Task { await loadTeamData() }
    }

    func nextMonth() {
        if selectedMonth == 12 {
            selectedMonth = 1
            selectedYear += 1
        } else {
            selectedMonth += 1
        }
        Task { await loadTeamData() }
    }

    private func parseLocalDate(_ value: String) -> DateComponents? {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }
        return DateComponents(year: year, month: month, day: day)
    }
}
