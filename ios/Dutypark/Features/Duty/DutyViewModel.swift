import Foundation

struct OtherDutySummary: Identifiable {
    let id = UUID()
    let name: String
    let dutyType: String?
    let dutyColor: String?
    let isOff: Bool
}

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
    @Published var holidays: [Int: [HolidayDto]] = [:]
    @Published var schedulesByDay: [Int: [Schedule]] = [:]
    @Published var todosByDay: [Int: [Todo]] = [:]
    @Published var otherDutiesByDay: [Int: [OtherDutySummary]] = [:]
    @Published var selectedCompareMemberIds: [Int] = []

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
                responseType: [DutyCalendarDay].self
            )

            var byDay: [Int: DutyCalendarDay] = [:]
            for duty in response where duty.year == selectedYear && duty.month == selectedMonth {
                byDay[duty.day] = duty
            }
            duties = byDay
            await loadDutyTypes()

            let canManageResponse = try await APIClient.shared.request(
                .canManageMember(memberId: memberId),
                responseType: Bool.self
            )
            canManage = canManageResponse

            await loadHolidays()
            await loadSchedules()
            await loadTodos()
            await loadOtherDuties()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
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
            print("Failed to load holidays: \(error)")
        }
    }

    func loadSchedules() async {
        guard let memberId = memberId ?? AuthManager.shared.currentUser?.id else { return }

        do {
            let response = try await APIClient.shared.request(
                .schedules(memberId: memberId, year: selectedYear, month: selectedMonth),
                responseType: [[Schedule]].self
            )
            var byDay: [Int: [Schedule]] = [:]
            for schedules in response {
                for schedule in schedules {
                    guard schedule.year == selectedYear, schedule.month == selectedMonth else { continue }
                    byDay[schedule.dayOfMonth, default: []].append(schedule)
                }
            }
            for day in byDay.keys {
                byDay[day]?.sort { $0.position < $1.position }
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

    func updateCompareMembers(_ memberIds: [Int]) async {
        selectedCompareMemberIds = memberIds
        await loadOtherDuties()
    }

    func loadOtherDuties() async {
        guard !selectedCompareMemberIds.isEmpty else {
            otherDutiesByDay = [:]
            return
        }

        do {
            let response = try await APIClient.shared.request(
                .otherDuties(memberIds: selectedCompareMemberIds, year: selectedYear, month: selectedMonth),
                responseType: [OtherDutyResponse].self
            )

            var byDay: [Int: [OtherDutySummary]] = [:]
            for friend in response {
                for duty in friend.duties where duty.year == selectedYear && duty.month == selectedMonth {
                    let summary = OtherDutySummary(
                        name: friend.name,
                        dutyType: duty.dutyType,
                        dutyColor: duty.dutyColor,
                        isOff: duty.isOff
                    )
                    byDay[duty.day, default: []].append(summary)
                }
            }

            otherDutiesByDay = byDay
        } catch {
            otherDutiesByDay = [:]
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

    private func loadDutyTypes() async {
        guard let teamId = AuthManager.shared.currentUser?.teamId else {
            dutyTypes = []
            return
        }

        do {
            let team = try await APIClient.shared.request(
                .team(id: teamId),
                responseType: TeamDto.self
            )
            dutyTypes = team.dutyTypes.compactMap { type in
                guard let id = type.id else { return nil }
                return DutyType(
                    id: id,
                    name: type.name,
                    color: type.color ?? "#9CA3AF",
                    shortName: nil
                )
            }
        } catch {
            print("Failed to load duty types: \(error)")
            dutyTypes = []
        }
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
