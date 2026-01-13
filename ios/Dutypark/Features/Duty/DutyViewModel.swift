import Foundation

@MainActor
final class DutyViewModel: ObservableObject {
    @Published var duties: [Int: DutyCalendarDay] = [:]
    @Published var dutyTypes: [DutyType] = []
    @Published var memberInfo: (id: Int, name: String)?
    @Published var selectedYear: Int
    @Published var selectedMonth: Int
    @Published var selectedDay: Int?
    @Published var isLoading = false
    @Published var error: String?
    @Published var canManage = false
    @Published var holidays: [Int: String] = [:]
    @Published var schedulesByDay: [Int: [Schedule]] = [:]
    @Published var todosByDay: [Int: [Todo]] = [:]

    var memberId: Int?

    // Computed properties for legend display
    var dutyTypeNames: [String] {
        dutyTypes.map { $0.name }
    }

    var dutyTypeCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for (_, duty) in duties {
            if let typeName = duty.dutyType {
                counts[typeName, default: 0] += 1
            }
        }
        // Add OFF count
        let offCount = duties.values.filter { $0.isOff }.count
        if offCount > 0 {
            counts["OFF"] = offCount
        }
        return counts
    }

    var dutyTypeColors: [String: String] {
        var colors: [String: String] = [:]
        for type in dutyTypes {
            colors[type.name] = type.color
        }
        colors["OFF"] = "#9CA3AF"
        return colors
    }

    init(memberId: Int? = nil) {
        let now = Date()
        let calendar = Calendar.current
        selectedYear = calendar.component(.year, from: now)
        selectedMonth = calendar.component(.month, from: now)
        self.memberId = memberId
    }

    func loadDutyData() async {
        guard let memberId = memberId ?? AuthManager.shared.currentUser?.id else { return }

        isLoading = true
        error = nil

        do {
            let response = try await APIClient.shared.request(
                .duties(memberId: memberId, year: selectedYear, month: selectedMonth),
                responseType: DutyResponse.self
            )

            var byDay: [Int: DutyCalendarDay] = [:]
            for (dayString, dutyInfo) in response.duties {
                if let day = Int(dayString) {
                    byDay[day] = DutyCalendarDay(
                        year: selectedYear,
                        month: selectedMonth,
                        day: day,
                        dutyType: dutyInfo.name,
                        dutyColor: dutyInfo.color,
                        isOff: false
                    )
                }
            }
            duties = byDay
            dutyTypes = response.dutyTypes
            memberInfo = (response.memberId, response.memberName)

            let canManageResponse = try await APIClient.shared.request(
                .canManageMember(memberId: memberId),
                responseType: Bool.self
            )
            canManage = canManageResponse

            await loadHolidays()
            await loadSchedules()
            await loadTodos()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadHolidays() async {
        do {
            let response = try await APIClient.shared.request(
                .holidays(year: selectedYear, month: selectedMonth),
                responseType: [HolidayDto].self
            )
            var holidaysByDay: [Int: String] = [:]
            for holiday in response {
                let components = holiday.localDate.split(separator: "-")
                if let day = Int(components.last ?? "") {
                    holidaysByDay[day] = holiday.dateName
                }
            }
            holidays = holidaysByDay
        } catch {
            print("Failed to load holidays: \(error)")
        }
    }

    func loadSchedules() async {
        do {
            let response = try await APIClient.shared.request(
                .schedules(year: selectedYear, month: selectedMonth),
                responseType: [[Schedule]].self
            )
            var byDay: [Int: [Schedule]] = [:]
            for (index, schedules) in response.enumerated() {
                byDay[index + 1] = schedules
            }
            schedulesByDay = byDay
        } catch {
            print("Failed to load schedules: \(error)")
        }
    }

    func loadTodos() async {
        do {
            let todos = try await APIClient.shared.request(
                .todosByMonth(year: selectedYear, month: selectedMonth),
                responseType: [Todo].self
            )
            var byDay: [Int: [Todo]] = [:]
            for todo in todos {
                if let dueDate = todo.dueDate {
                    let components = dueDate.split(separator: "-")
                    if let day = Int(components.last ?? "") {
                        if byDay[day] == nil {
                            byDay[day] = []
                        }
                        byDay[day]?.append(todo)
                    }
                }
            }
            todosByDay = byDay
        } catch {
            print("Failed to load todos: \(error)")
        }
    }

    func changeDuty(day: Int, dutyTypeId: Int?) async -> Bool {
        guard let memberId = memberId ?? AuthManager.shared.currentUser?.id else { return false }

        let date = String(format: "%04d-%02d-%02d", selectedYear, selectedMonth, day)

        let request = DutyChangeRequest(
            memberId: memberId,
            date: date,
            dutyTypeId: dutyTypeId
        )

        do {
            try await APIClient.shared.requestVoid(.changeDuty(request: request))
            await loadDutyData()
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
        Task { await loadDutyData() }
    }

    func nextMonth() {
        if selectedMonth == 12 {
            selectedMonth = 1
            selectedYear += 1
        } else {
            selectedMonth += 1
        }
        Task { await loadDutyData() }
    }

    func goToToday() {
        let now = Date()
        let calendar = Calendar.current
        selectedYear = calendar.component(.year, from: now)
        selectedMonth = calendar.component(.month, from: now)
        Task { await loadDutyData() }
    }

    func loadDuties(for date: Date) async {
        let calendar = Calendar.current
        selectedYear = calendar.component(.year, from: date)
        selectedMonth = calendar.component(.month, from: date)
        await loadDutyData()
    }
}
