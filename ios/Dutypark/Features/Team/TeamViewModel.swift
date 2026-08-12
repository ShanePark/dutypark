import Foundation
import Combine

@MainActor
final class TeamViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false
    @Published private(set) var isWorking = false
    @Published private(set) var team: TeamDTO?
    @Published private(set) var isTeamManager = false
    @Published private(set) var days: [TeamDayDTO] = []
    @Published private(set) var schedules: [[TeamScheduleDTO]] = []
    @Published private(set) var duties: [DutyDTO] = []
    @Published private(set) var holidays: [[HolidayDTO]] = []
    @Published private(set) var shifts: [DutyByShiftDTO] = []
    @Published var selectedIndex = 0
    @Published var showsError = false
    @Published var scheduleDraft: TeamScheduleDraft?
    @Published var schedulePendingDeletion: TeamScheduleDTO?

    private let repository: TeamRepository
    private var memberID: MemberID?

    var year: Int
    var month: Int

    init(repository: TeamRepository = TeamRepository(), now: Date = Date()) {
        self.repository = repository
        let components = Calendar.current.dateComponents([.year, .month], from: now)
        year = components.year ?? 2000
        month = components.month ?? 1
    }

    var selectedDay: TeamDayDTO? {
        days.indices.contains(selectedIndex) ? days[selectedIndex] : nil
    }

    var selectedSchedules: [TeamScheduleDTO] {
        schedules.indices.contains(selectedIndex) ? schedules[selectedIndex] : []
    }

    func load(memberID: MemberID?) async {
        guard !isLoading else { return }
        self.memberID = memberID
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            async let calendarDays = repository.calendar(year: year, month: month)
            async let summary = repository.summary(year: year, month: month)
            let (loadedDays, loadedSummary) = try await (calendarDays, summary)
            days = loadedDays
            team = loadedSummary.team
            isTeamManager = loadedSummary.isTeamManager
            selectInitialDay()

            guard let team else {
                schedules = []
                duties = []
                holidays = []
                shifts = []
                return
            }
            async let loadedSchedules = repository.schedules(teamID: team.id, year: year, month: month)
            async let loadedHolidays = repository.holidays(year: year, month: month)
            if let memberID {
                async let loadedDuties = repository.duties(memberID: memberID, year: year, month: month)
                let (scheduleValue, holidayValue, dutyValue) = try await (
                    loadedSchedules,
                    loadedHolidays,
                    loadedDuties
                )
                schedules = scheduleValue
                holidays = holidayValue
                duties = dutyValue
            } else {
                schedules = try await loadedSchedules
                holidays = try await loadedHolidays
                duties = []
            }
            await loadShifts()
        } catch {
            loadFailed = true
            showsError = true
        }
    }

    func previousMonth() async {
        if month == 1 {
            month = 12
            year -= 1
        } else {
            month -= 1
        }
        await reloadForChangedMonth()
    }

    func nextMonth() async {
        if month == 12 {
            month = 1
            year += 1
        } else {
            month += 1
        }
        await reloadForChangedMonth()
    }

    func goToToday() async {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        year = components.year ?? year
        month = components.month ?? month
        await reloadForChangedMonth()
    }

    func goTo(year: Int, month: Int) async {
        guard (1...12).contains(month) else { return }
        self.year = year
        self.month = month
        await reloadForChangedMonth()
    }

    func selectDay(at index: Int) async {
        guard days.indices.contains(index) else { return }
        selectedIndex = index
        await loadShifts()
    }

    func newSchedule() {
        guard let day = selectedDay, let date = date(for: day) else { return }
        scheduleDraft = TeamScheduleDraft(
            id: nil,
            content: "",
            description: "",
            startDate: date,
            endDate: date
        )
    }

    func editSchedule(_ schedule: TeamScheduleDTO) {
        let start = date(from: schedule.startDateTime.rawValue) ?? Date()
        let end = date(from: schedule.endDateTime.rawValue) ?? start
        scheduleDraft = TeamScheduleDraft(
            id: schedule.id,
            content: schedule.content,
            description: schedule.description,
            startDate: start,
            endDate: end
        )
    }

    func saveSchedule() async {
        guard let team, let draft = scheduleDraft, draft.isValid else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await repository.saveSchedule(
                TeamScheduleSaveDTO(
                    id: draft.id,
                    teamId: team.id,
                    content: draft.content.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: draft.description,
                    startDateTime: LocalDateTimeValue(
                        rawValue: timestamp(for: draft.startDate, endOfDay: false)
                    ),
                    endDateTime: LocalDateTimeValue(
                        rawValue: timestamp(for: draft.endDate, endOfDay: true)
                    )
                )
            )
            scheduleDraft = nil
            schedules = try await repository.schedules(teamID: team.id, year: year, month: month)
        } catch {
            showsError = true
        }
    }

    func deleteSchedule() async {
        guard let schedule = schedulePendingDeletion, let team else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await repository.deleteSchedule(id: schedule.id)
            schedulePendingDeletion = nil
            schedules = try await repository.schedules(teamID: team.id, year: year, month: month)
        } catch {
            showsError = true
        }
    }

    func duty(for day: TeamDayDTO) -> DutyDTO? {
        duties.first { $0.year == day.year && $0.month == day.month && $0.day == day.day }
    }

    private func reloadForChangedMonth() async {
        days = []
        schedules = []
        shifts = []
        await load(memberID: memberID)
    }

    private func loadShifts() async {
        guard team != nil, let day = selectedDay else {
            shifts = []
            return
        }
        do {
            shifts = try await repository.shifts(year: day.year, month: day.month, day: day.day)
        } catch {
            shifts = []
            showsError = true
        }
    }

    private func selectInitialDay() {
        let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        selectedIndex = days.firstIndex {
            $0.year == today.year && $0.month == today.month && $0.day == today.day
        } ?? days.firstIndex { $0.year == year && $0.month == month && $0.day == 1 } ?? 0
    }

    private func date(for day: TeamDayDTO) -> Date? {
        Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day))
    }

    private func date(from timestamp: String) -> Date? {
        let prefix = String(timestamp.prefix(10))
        return Self.dateFormatter.date(from: prefix)
    }

    private func timestamp(for date: Date, endOfDay: Bool) -> String {
        Self.dateFormatter.string(from: date) + (endOfDay ? "T23:59:59" : "T00:00:00")
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

@MainActor
final class TeamManageViewModel: ObservableObject {
    @Published private(set) var team: TeamDTO?
    @Published private(set) var templates: [DutyBatchTemplateDTO] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false
    @Published var showsError = false
    @Published var showsSuccess = false
    @Published var memberSearchPresented = false
    @Published var dutyEditorPresented = false
    @Published var batchUploadPresented = false
    @Published var editingDutyType: DutyTypeDTO?

    let teamID: TeamID
    let isServiceAdmin: Bool
    private let repository: TeamRepository

    init(
        teamID: TeamID,
        isServiceAdmin: Bool = false,
        repository: TeamRepository = TeamRepository()
    ) {
        self.teamID = teamID
        self.isServiceAdmin = isServiceAdmin
        self.repository = repository
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let loadedTeam = repository.teamForManagement(teamID: teamID)
            async let loadedTemplates = repository.batchTemplates()
            team = try await loadedTeam
            templates = (try? await loadedTemplates) ?? []
        } catch {
            showsError = true
        }
    }

    func canUseAdminTools(loginID: MemberID?) -> Bool {
        Self.canUseAdminTools(
            loginID: loginID,
            team: team,
            isServiceAdmin: isServiceAdmin
        )
    }

    nonisolated static func canUseAdminTools(
        loginID: MemberID?,
        team: TeamDTO?,
        isServiceAdmin: Bool
    ) -> Bool {
        if isServiceAdmin { return true }
        guard let loginID, let team else { return false }
        return team.adminId == loginID
            || team.members.contains { $0.id == loginID && $0.isManager }
    }

    func changeAdmin(memberID: MemberID?) async {
        await perform { try await repository.changeAdmin(teamID: teamID, memberID: memberID) }
    }

    func updateTemplate(_ name: String?) async {
        await perform { try await repository.updateBatchTemplate(teamID: teamID, name: name) }
    }

    func removeMember(_ id: MemberID) async {
        await perform { try await repository.removeMember(teamID: teamID, memberID: id) }
    }

    func addManager(_ id: MemberID) async {
        await perform { try await repository.addManager(teamID: teamID, memberID: id) }
    }

    func removeManager(_ id: MemberID) async {
        await perform { try await repository.removeManager(teamID: teamID, memberID: id) }
    }

    func saveDutyType(name: String, color: String) async {
        let target = editingDutyType
        await perform {
            if let id = target?.id {
                try await repository.updateDutyType(id: id, teamID: teamID, name: name, color: color)
            } else if target?.id == nil, target != nil {
                try await repository.updateDefaultDuty(teamID: teamID, name: name, color: color)
            } else {
                try await repository.addDutyType(teamID: teamID, name: name, color: color)
            }
        }
        if !showsError { dutyEditorPresented = false }
    }

    func moveDutyType(from index: Int, direction: Int) async {
        guard let dutyTypes = team?.dutyTypes,
              let targetIndex = TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: index,
                direction: direction
              ),
              let first = dutyTypes[index].id,
              let second = dutyTypes[targetIndex].id
        else { return }
        await perform { try await repository.swapDutyTypes(teamID: teamID, first: first, second: second) }
    }

    func toggleVisibility(_ dutyType: DutyTypeDTO) async {
        guard let id = dutyType.id else { return }
        await perform {
            try await repository.setDutyTypeVisibility(
                teamID: teamID,
                dutyTypeID: id,
                hidden: !dutyType.hidden
            )
        }
    }

    func upload(fileURL: URL, year: Int, month: Int) async -> TeamBatchResultDTO? {
        isWorking = true
        defer { isWorking = false }
        let granted = fileURL.startAccessingSecurityScopedResource()
        defer { if granted { fileURL.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: fileURL)
            let result = try await repository.uploadDutyBatch(
                teamID: teamID,
                fileName: fileURL.lastPathComponent,
                fileData: data,
                year: year,
                month: month
            )
            if result.result {
                showsSuccess = true
                batchUploadPresented = false
            }
            return result
        } catch {
            showsError = true
            return nil
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        showsError = false
        defer { isWorking = false }
        do {
            try await operation()
            team = try await repository.teamForManagement(teamID: teamID)
            showsSuccess = true
        } catch {
            showsError = true
        }
    }
}

@MainActor
final class TeamMemberSearchViewModel: ObservableObject {
    @Published private(set) var results: [MemberInviteCandidateDTO] = []
    @Published private(set) var isWorking = false
    @Published private(set) var currentPage = 0
    @Published private(set) var totalPages = 1
    @Published private(set) var totalElements: Int64 = 0
    @Published var keyword = ""
    @Published var showsError = false

    private let teamID: TeamID
    private let repository: TeamRepository

    init(teamID: TeamID, repository: TeamRepository = TeamRepository()) {
        self.teamID = teamID
        self.repository = repository
    }

    var canLoadPreviousPage: Bool { currentPage > 0 }
    var canLoadNextPage: Bool { currentPage + 1 < totalPages }

    func search(resetPage: Bool = false) async {
        if resetPage { currentPage = 0 }
        await load(page: currentPage)
    }

    func previousPage() async {
        guard canLoadPreviousPage else { return }
        await load(page: currentPage - 1)
    }

    func nextPage() async {
        guard canLoadNextPage else { return }
        await load(page: currentPage + 1)
    }

    private func load(page: Int) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let response = try await repository.searchMembers(
                teamID: teamID,
                keyword: keyword,
                page: page
            )
            results = response.content
            currentPage = response.number
            totalPages = max(response.totalPages, 1)
            totalElements = response.totalElements
        } catch {
            showsError = true
        }
    }

    func add(_ member: MemberInviteCandidateDTO) async -> Bool {
        guard let id = member.id else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try await repository.addMember(teamID: teamID, memberID: id)
            return true
        } catch {
            showsError = true
            return false
        }
    }
}
