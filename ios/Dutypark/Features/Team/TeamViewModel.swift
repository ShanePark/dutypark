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
    private(set) var hasLoaded = false

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
        let selectedDayBeforeLoad = selectedDay
        let requestedYear = year
        let requestedMonth = month
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-team-fixture") {
            self.memberID = memberID
            let fixture = TeamUITestingFixture.make(
                year: year,
                month: month,
                includeShifts: ProcessInfo.processInfo.arguments.contains(
                    "-ui-testing-team-shift-fixture"
                )
            )
            team = fixture.team
            isTeamManager = true
            days = fixture.days
            schedules = fixture.schedules
            duties = fixture.duties
            holidays = fixture.holidays
            shifts = fixture.shifts
            selectedIndex = 0
            loadFailed = false
            showsError = false
            hasLoaded = true
            return
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            self.memberID = memberID
            team = nil
            days = []
            schedules = []
            duties = []
            holidays = []
            shifts = []
            loadFailed = false
            showsError = false
            hasLoaded = true
            return
        }
#endif
        self.memberID = memberID
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            async let calendarDays = repository.calendar(year: requestedYear, month: requestedMonth)
            async let summary = repository.summary(year: requestedYear, month: requestedMonth)
            let (loadedDays, loadedSummary) = try await (calendarDays, summary)

            guard let loadedTeam = loadedSummary.team else {
                days = loadedDays
                team = nil
                isTeamManager = loadedSummary.isTeamManager
                schedules = []
                duties = []
                holidays = []
                shifts = []
                restoreSelection(
                    selectedDayBeforeLoad,
                    targetYear: requestedYear,
                    targetMonth: requestedMonth
                )
                hasLoaded = true
                return
            }
            async let loadedSchedules = repository.schedules(
                teamID: loadedTeam.id,
                year: requestedYear,
                month: requestedMonth
            )
            async let loadedHolidays = repository.holidays(year: requestedYear, month: requestedMonth)
            let loadedScheduleValue: [[TeamScheduleDTO]]
            let loadedHolidayValue: [[HolidayDTO]]
            let loadedDutyValue: [DutyDTO]
            if let memberID {
                async let loadedDuties = repository.duties(
                    memberID: memberID,
                    year: requestedYear,
                    month: requestedMonth
                )
                let (scheduleValue, holidayValue, dutyValue) = try await (
                    loadedSchedules,
                    loadedHolidays,
                    loadedDuties
                )
                loadedScheduleValue = scheduleValue
                loadedHolidayValue = holidayValue
                loadedDutyValue = dutyValue
            } else {
                loadedScheduleValue = try await loadedSchedules
                loadedHolidayValue = try await loadedHolidays
                loadedDutyValue = []
            }
            days = loadedDays
            team = loadedTeam
            isTeamManager = loadedSummary.isTeamManager
            schedules = loadedScheduleValue
            holidays = loadedHolidayValue
            duties = loadedDutyValue
            restoreSelection(
                selectedDayBeforeLoad,
                targetYear: requestedYear,
                targetMonth: requestedMonth
            )
            await loadShifts()
            hasLoaded = true
        } catch {
            loadFailed = true
            showsError = true
        }
    }

    func loadIfNeeded(memberID: MemberID?) async {
        guard !hasLoaded else { return }
        await load(memberID: memberID)
    }

    func previousMonth() async {
        guard !isLoading else { return }
        let previousYear = year
        let previousMonth = month
        if month == 1 {
            month = 12
            year -= 1
        } else {
            month -= 1
        }
        await reloadForChangedMonth()
        if loadFailed {
            year = previousYear
            month = previousMonth
        }
    }

    func nextMonth() async {
        guard !isLoading else { return }
        let previousYear = year
        let previousMonth = month
        if month == 12 {
            month = 1
            year += 1
        } else {
            month += 1
        }
        await reloadForChangedMonth()
        if loadFailed {
            year = previousYear
            month = previousMonth
        }
    }

    func goToToday() async {
        guard !isLoading else { return }
        let previousYear = year
        let previousMonth = month
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        year = components.year ?? year
        month = components.month ?? month
        await reloadForChangedMonth()
        if loadFailed {
            year = previousYear
            month = previousMonth
        }
    }

    func goTo(year: Int, month: Int) async {
        guard !isLoading, (1...12).contains(month) else { return }
        let previousYear = self.year
        let previousMonth = self.month
        self.year = year
        self.month = month
        await reloadForChangedMonth()
        if loadFailed {
            self.year = previousYear
            self.month = previousMonth
        }
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
        guard let draft = scheduleDraft else { return }
        await saveSchedule(draft)
    }

    func saveSchedule(_ draft: TeamScheduleDraft) async {
        guard let team, draft.isValid else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let savedSchedule = try await repository.saveSchedule(
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
            applySavedSchedule(savedSchedule)
            scheduleDraft = nil
        } catch {
            showsError = true
        }
    }

    func deleteSchedule() async {
        guard let schedule = schedulePendingDeletion, team != nil else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await repository.deleteSchedule(id: schedule.id)
            schedules = schedules.map { daySchedules in
                daySchedules.filter { $0.id != schedule.id }
            }
            schedulePendingDeletion = nil
        } catch {
            showsError = true
        }
    }

    func duty(for day: TeamDayDTO) -> DutyDTO? {
        duties.first { $0.year == day.year && $0.month == day.month && $0.day == day.day }
    }

    private func reloadForChangedMonth() async {
        await load(memberID: memberID)
    }

    func applyManagedTeam(_ updatedTeam: TeamDTO) {
        guard team?.id == updatedTeam.id else { return }
        team = updatedTeam
        if let memberID {
            isTeamManager = updatedTeam.members.first { $0.id == memberID }?.isManager == true
        }
    }

    func refreshDutiesAfterBatch(year: Int, month: Int) async {
        guard self.year == year, self.month == month, let memberID else { return }
        do {
            duties = try await repository.duties(memberID: memberID, year: year, month: month)
            await loadShifts()
        } catch {
            showsError = true
        }
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

    private func restoreSelection(
        _ previousDay: TeamDayDTO?,
        targetYear: Int,
        targetMonth: Int
    ) {
        if let previousDay {
            let targetDay = min(previousDay.day, Self.dayCount(year: targetYear, month: targetMonth))
            if let matchingIndex = days.firstIndex(where: {
                $0.year == targetYear && $0.month == targetMonth && $0.day == targetDay
            }) {
                selectedIndex = matchingIndex
                return
            }
        }
        let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        selectedIndex = days.firstIndex {
            $0.year == today.year && $0.month == today.month && $0.day == today.day
        } ?? days.firstIndex { $0.year == year && $0.month == month && $0.day == 1 } ?? 0
    }

    private func applySavedSchedule(_ savedSchedule: TeamScheduleDTO) {
        var updatedSchedules = schedules.map { daySchedules in
            daySchedules.filter { $0.id != savedSchedule.id }
        }
        guard let start = date(from: savedSchedule.startDateTime.rawValue),
              let end = date(from: savedSchedule.endDateTime.rawValue)
        else { return }
        let calendar = Calendar(identifier: .gregorian)
        let totalDays = max((calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1, 1)
        for (index, day) in days.enumerated() where updatedSchedules.indices.contains(index) {
            guard let current = date(for: day), current >= start, current <= end else { continue }
            let daysFromStart = (calendar.dateComponents([.day], from: start, to: current).day ?? 0) + 1
            let occurrence = TeamScheduleDTO(
                id: savedSchedule.id,
                teamId: savedSchedule.teamId,
                content: savedSchedule.content,
                description: savedSchedule.description,
                position: savedSchedule.position,
                year: day.year,
                month: day.month,
                dayOfMonth: day.day,
                daysFromStart: daysFromStart,
                totalDays: totalDays,
                startDateTime: savedSchedule.startDateTime,
                endDateTime: savedSchedule.endDateTime,
                createMember: savedSchedule.createMember,
                updateMember: savedSchedule.updateMember,
                curDate: DateOnly(
                    rawValue: String(format: "%04d-%02d-%02d", day.year, day.month, day.day)
                )
            )
            updatedSchedules[index].append(occurrence)
            updatedSchedules[index].sort {
                ($0.position, $0.startDateTime.rawValue) < ($1.position, $1.startDateTime.rawValue)
            }
        }
        schedules = updatedSchedules
    }

    private static func dayCount(year: Int, month: Int) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return 28
        }
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 28
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
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-team-fixture") {
            team = TeamUITestingFixture.makeManagementTeam()
            templates = [
                DutyBatchTemplateDTO(
                    name: "standard",
                    label: "표준 근무표",
                    fileExtensions: ["xlsx"]
                )
            ]
            showsError = false
            return
        }
#endif
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

    func changeAdmin(memberID: MemberID?) async -> Bool {
        await perform(
            operation: { try await repository.changeAdmin(teamID: teamID, memberID: memberID) },
            update: { team in
                let adminName = memberID.flatMap { id in
                    team.members.first { $0.id == id }?.name
                }
                let members = team.members.map { member in
                    Self.copy(
                        member,
                        isAdmin: memberID.map { member.id == $0 } ?? false
                    )
                }
                return Self.copy(
                    team,
                    members: members,
                    admin: (memberID, adminName)
                )
            }
        )
    }

    func updateTemplate(_ name: String?) async {
        await perform(
            operation: { try await repository.updateBatchTemplate(teamID: teamID, name: name) },
            update: { [templates] team in
                let template = name.flatMap { selectedName in
                    templates.first { $0.name == selectedName }
                }
                return Self.copy(team, batchTemplate: .some(template))
            }
        )
    }

    func removeMember(_ id: MemberID) async -> Bool {
        await perform(
            operation: { try await repository.removeMember(teamID: teamID, memberID: id) },
            update: { team in
                let removingAdmin = team.adminId == id
                return Self.copy(
                    team,
                    members: team.members.filter { $0.id != id },
                    admin: removingAdmin ? (nil, nil) : nil
                )
            }
        )
    }

    func addManager(_ id: MemberID) async -> Bool {
        await perform(
            operation: { try await repository.addManager(teamID: teamID, memberID: id) },
            update: { team in
                Self.copy(
                    team,
                    members: team.members.map { member in
                        member.id == id ? Self.copy(member, isManager: true) : member
                    }
                )
            }
        )
    }

    func removeManager(_ id: MemberID) async -> Bool {
        await perform(
            operation: { try await repository.removeManager(teamID: teamID, memberID: id) },
            update: { team in
                Self.copy(
                    team,
                    members: team.members.map { member in
                        member.id == id ? Self.copy(member, isManager: false) : member
                    }
                )
            }
        )
    }

    func saveDutyType(name: String, color: String) async {
        let target = editingDutyType
        let needsServerIdentity = target == nil
        await perform(
            operation: {
                if let id = target?.id {
                    try await repository.updateDutyType(
                        id: id,
                        teamID: teamID,
                        name: name,
                        color: color
                    )
                } else if target?.id == nil, target != nil {
                    try await repository.updateDefaultDuty(
                        teamID: teamID,
                        name: name,
                        color: color
                    )
                } else {
                    try await repository.addDutyType(
                        teamID: teamID,
                        name: name,
                        color: color
                    )
                }
            },
            update: needsServerIdentity ? nil : { team in
                let dutyTypes = team.dutyTypes.map { dutyType in
                    guard dutyType.id == target?.id else { return dutyType }
                    return Self.copy(dutyType, name: name, color: color)
                }
                return Self.copy(team, dutyTypes: dutyTypes)
            },
            reconcile: needsServerIdentity
        )
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
        await perform(
            operation: {
                try await repository.swapDutyTypes(teamID: teamID, first: first, second: second)
            },
            update: { team in
                guard team.dutyTypes.indices.contains(index),
                      team.dutyTypes.indices.contains(targetIndex)
                else { return team }
                var dutyTypes = team.dutyTypes
                let firstDuty = dutyTypes[index]
                let secondDuty = dutyTypes[targetIndex]
                dutyTypes[index] = Self.copy(firstDuty, position: secondDuty.position)
                dutyTypes[targetIndex] = Self.copy(secondDuty, position: firstDuty.position)
                dutyTypes.swapAt(index, targetIndex)
                return Self.copy(team, dutyTypes: dutyTypes)
            }
        )
    }

    func toggleVisibility(_ dutyType: DutyTypeDTO) async -> Bool {
        guard let id = dutyType.id else { return false }
        return await perform(
            operation: {
                try await repository.setDutyTypeVisibility(
                    teamID: teamID,
                    dutyTypeID: id,
                    hidden: !dutyType.hidden
                )
            },
            update: { team in
                Self.copy(
                    team,
                    dutyTypes: team.dutyTypes.map { current in
                        current.id == id
                            ? Self.copy(current, hidden: !dutyType.hidden)
                            : current
                    }
                )
            }
        )
    }

    func appendMember(_ candidate: MemberInviteCandidateDTO) {
        guard let team, let id = candidate.id,
              !team.members.contains(where: { $0.id == id })
        else { return }
        let member = TeamMemberDTO(
            id: id,
            name: candidate.name,
            email: candidate.email,
            isManager: false,
            isAdmin: false,
            hasProfilePhoto: candidate.hasProfilePhoto,
            profilePhotoVersion: candidate.profilePhotoVersion
        )
        self.team = Self.copy(team, members: team.members + [member])
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

    @discardableResult
    private func perform(
        operation: () async throws -> Void,
        update: ((TeamDTO) -> TeamDTO)? = nil,
        reconcile: Bool = false
    ) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        showsError = false
        defer { isWorking = false }
        do {
            try await operation()
            if let team, let update {
                self.team = update(team)
            }
            if reconcile, let refreshedTeam = try? await repository.teamForManagement(teamID: teamID) {
                team = refreshedTeam
            }
            showsSuccess = true
            return true
        } catch {
            showsError = true
            return false
        }
    }

    private static func copy(
        _ team: TeamDTO,
        dutyTypes: [DutyTypeDTO]? = nil,
        members: [TeamMemberDTO]? = nil,
        admin: (MemberID?, String?)? = nil,
        batchTemplate: DutyBatchTemplateDTO?? = nil
    ) -> TeamDTO {
        TeamDTO(
            id: team.id,
            name: team.name,
            description: team.description,
            dutyTypes: dutyTypes ?? team.dutyTypes,
            members: members ?? team.members,
            createdDate: team.createdDate,
            lastModifiedDate: team.lastModifiedDate,
            adminId: admin.map { $0.0 } ?? team.adminId,
            adminName: admin.map { $0.1 } ?? team.adminName,
            dutyBatchTemplate: batchTemplate ?? team.dutyBatchTemplate
        )
    }

    private static func copy(
        _ member: TeamMemberDTO,
        isManager: Bool? = nil,
        isAdmin: Bool? = nil
    ) -> TeamMemberDTO {
        TeamMemberDTO(
            id: member.id,
            name: member.name,
            email: member.email,
            isManager: isManager ?? member.isManager,
            isAdmin: isAdmin ?? member.isAdmin,
            hasProfilePhoto: member.hasProfilePhoto,
            profilePhotoVersion: member.profilePhotoVersion
        )
    }

    private static func copy(
        _ dutyType: DutyTypeDTO,
        name: String? = nil,
        position: Int? = nil,
        color: String? = nil,
        hidden: Bool? = nil
    ) -> DutyTypeDTO {
        DutyTypeDTO(
            id: dutyType.id,
            teamId: dutyType.teamId,
            name: name ?? dutyType.name,
            position: position ?? dutyType.position,
            color: color ?? dutyType.color,
            hidden: hidden ?? dutyType.hidden
        )
    }
}

#if DEBUG
private nonisolated enum TeamUITestingFixture {
    struct CalendarFixture {
        let team: TeamDTO
        let days: [TeamDayDTO]
        let schedules: [[TeamScheduleDTO]]
        let duties: [DutyDTO]
        let holidays: [[HolidayDTO]]
        let shifts: [DutyByShiftDTO]
    }

    static func make(year: Int, month: Int, includeShifts: Bool) -> CalendarFixture {
        let team = makeManagementTeam()
        let dayCount = Calendar(identifier: .gregorian).range(
            of: .day,
            in: .month,
            for: Calendar(identifier: .gregorian).date(
                from: DateComponents(year: year, month: month, day: 1)
            ) ?? Date()
        )?.count ?? 28
        let days = (1...dayCount).map { TeamDayDTO(year: year, month: month, day: $0) }
        let date = String(format: "%04d-%02d-01", year, month)
        let schedule = TeamScheduleDTO(
            id: UUID(uuidString: "B4F66F4B-95C2-4E52-B9BA-8840185C8843")!,
            teamId: team.id,
            content: "정기 팀 회의",
            description: "이번 달 근무 일정 공유",
            position: 0,
            year: year,
            month: month,
            dayOfMonth: 1,
            daysFromStart: 1,
            totalDays: 1,
            startDateTime: LocalDateTimeValue(rawValue: "\(date)T09:00:00"),
            endDateTime: LocalDateTimeValue(rawValue: "\(date)T10:00:00"),
            createMember: "테스트 관리자",
            updateMember: "테스트 관리자",
            curDate: DateOnly(rawValue: date)
        )
        var schedules = Array(repeating: [TeamScheduleDTO](), count: days.count)
        schedules[0] = [schedule]
        let shiftMembers = team.members.map { member in
            MemberPreviewDTO(
                id: member.id,
                name: member.name,
                teamId: team.id,
                team: team.name,
                hasProfilePhoto: member.hasProfilePhoto,
                profilePhotoVersion: member.profilePhotoVersion
            )
        }
        let shifts: [DutyByShiftDTO]
        if includeShifts, let dutyType = team.dutyTypes.first {
            shifts = [DutyByShiftDTO(dutyType: dutyType, members: shiftMembers)]
        } else {
            shifts = []
        }
        return CalendarFixture(
            team: team,
            days: days,
            schedules: schedules,
            duties: [],
            holidays: Array(repeating: [], count: days.count),
            shifts: shifts
        )
    }

    static func makeManagementTeam() -> TeamDTO {
        TeamDTO(
            id: 91,
            name: "듀티파크 테스트팀",
            description: "UI 시각 검증용 가입 팀",
            dutyTypes: [
                DutyTypeDTO(
                    id: 701,
                    teamId: 91,
                    name: "주간",
                    position: 0,
                    color: "#4F7CAC",
                    hidden: false
                ),
                DutyTypeDTO(
                    id: 702,
                    teamId: 91,
                    name: "야간",
                    position: 1,
                    color: "#263238",
                    hidden: true
                )
            ],
            members: [
                TeamMemberDTO(
                    id: 1,
                    name: "테스트 관리자",
                    email: "test@duty.park",
                    isManager: true,
                    isAdmin: false,
                    hasProfilePhoto: false,
                    profilePhotoVersion: 0
                ),
                TeamMemberDTO(
                    id: 2,
                    name: "김듀티",
                    email: "member@duty.park",
                    isManager: true,
                    isAdmin: true,
                    hasProfilePhoto: false,
                    profilePhotoVersion: 0
                )
            ],
            createdDate: LocalDateTimeValue(rawValue: "2026-01-01T00:00:00"),
            lastModifiedDate: LocalDateTimeValue(rawValue: "2026-01-01T00:00:00"),
            adminId: 2,
            adminName: "김듀티",
            dutyBatchTemplate: nil
        )
    }
}
#endif

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
