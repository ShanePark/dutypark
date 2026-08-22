import Foundation
import Combine

nonisolated struct CalendarDayContent: Identifiable, Equatable, Sendable {
    let cell: CalendarCell
    let duty: DutyDTO?
    let schedules: [ScheduleDTO]
    let holidays: [HolidayDTO]
    let todos: [TodoDTO]
    let dDays: [DDayDTO]
    let comparedDuties: [ComparedDuty]

    var id: String { cell.id }
}

nonisolated struct ComparedDuty: Equatable, Sendable {
    let memberID: MemberID
    let name: String
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
    let duty: DutyDTO
}

/// Semantic feedback decisions owned by the calendar state boundary.
///
/// The calendar has several ways to reach the same month (buttons, a swipe and the picker),
/// so the view model keeps the committed month transition in one place. The optional result
/// also makes no-op transitions naturally silent.
nonisolated enum CalendarHapticPolicy {
    static func monthNavigation(
        fromYear: Int,
        fromMonth: Int,
        toYear: Int,
        toMonth: Int
    ) -> DPHapticKind? {
        fromYear == toYear && fromMonth == toMonth ? nil : .routine
    }

    static func selectionChanged(from: DateOnly?, to: DateOnly?) -> DPHapticKind? {
        from == to ? nil : .selection
    }

    static func mutationResult(succeeded: Bool) -> DPHapticKind {
        succeeded ? .success : .error
    }

    static func validationFailure(isActionable: Bool = true) -> DPHapticKind? {
        isActionable ? .warning : nil
    }
}

@MainActor
final class CalendarViewModel: ObservableObject {
    private let repository: CalendarRepositoryProtocol
    @Published private(set) var me: MemberDTO?
    @Published private(set) var targetMember: MemberPreviewDTO?
    @Published private(set) var friends: [FriendDTO] = []
    @Published private(set) var team: TeamDTO?
    @Published private(set) var days: [CalendarDayContent] = []
    @Published private(set) var dDays: [DDayDTO] = []
    @Published private(set) var todoBoard: TodoBoardDTO?
    @Published private(set) var canManage = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var searchResults: [ScheduleSearchResultDTO] = []

    @Published var year: Int
    @Published var month: Int
    @Published var selectedMemberID: MemberID?
    @Published var selectedDay: CalendarDayContent?
    @Published var searchQuery = ""
    @Published var isSearching = false
    @Published var highlightedDate: DateOnly?
    @Published var comparedMemberIDs: Set<MemberID> = []
    @Published var isQuickDutyEditing = false
    @Published private(set) var quickDutyDay: CalendarDayContent?
    @Published private(set) var canLoadMoreSearchResults = false
    @Published private(set) var pinnedDDayID: Int64?
    @Published var dutyBatchMessage: String?
    private var searchPage = 0
    private let initialScheduleID: ScheduleID?
    private let contentFilter: ContentFilterStore
    private let hapticCenter: DPHapticCenter

    init(
        repository: CalendarRepositoryProtocol = CalendarRepository(),
        now: Date = Date(),
        memberID: MemberID? = nil,
        date: DateOnly? = nil,
        scheduleID: ScheduleID? = nil,
        contentFilter: ContentFilterStore = .shared,
        hapticCenter: DPHapticCenter = .shared
    ) {
        self.repository = repository
        self.contentFilter = contentFilter
        self.hapticCenter = hapticCenter
        initialScheduleID = scheduleID
        let initialDate = date.flatMap(CalendarDateSupport.date(from:)) ?? now
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month], from: initialDate)
        year = parts.year ?? 2026
        month = parts.month ?? 1
        selectedMemberID = memberID
        highlightedDate = date
    }

    var targetMemberID: MemberID? { selectedMemberID ?? me?.id }
    var isMyCalendar: Bool { targetMemberID == me?.id }
    var canEdit: Bool { isMyCalendar || canManage }
    var canSearchSchedules: Bool { canEdit }
    var targetName: String {
        guard let targetMemberID else { return me?.name ?? "" }
        if targetMemberID == me?.id { return me?.name ?? "" }
        return friends.first(where: { $0.id == targetMemberID })?.name ?? targetMember?.name ?? ""
    }
    var targetHasProfilePhoto: Bool {
        guard let targetMemberID else { return me?.hasProfilePhoto ?? false }
        if targetMemberID == me?.id { return me?.hasProfilePhoto ?? false }
        return friends.first(where: { $0.id == targetMemberID })?.hasProfilePhoto
            ?? targetMember?.hasProfilePhoto
            ?? false
    }
    var targetProfilePhotoVersion: Int64 {
        guard let targetMemberID else { return me?.profilePhotoVersion ?? 0 }
        if targetMemberID == me?.id { return me?.profilePhotoVersion ?? 0 }
        return friends.first(where: { $0.id == targetMemberID })?.profilePhotoVersion
            ?? targetMember?.profilePhotoVersion
            ?? 0
    }
    var visibleDutyTypes: [DutyTypeDTO] { team?.dutyTypes.filter { !$0.hidden } ?? [] }

    func load(emitErrorFeedback: Bool = false) async {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            loadUITestingFixture()
            return
        }
#endif
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if me == nil {
                let member = try await repository.member()
                me = member
                friends = try await repository.friends()
                if let initialScheduleID {
                    let schedule = try await repository.scheduleBasic(id: initialScheduleID)
                    if selectedMemberID == nil {
                        selectedMemberID = schedule.memberId
                    }
                    if let date = CalendarDateSupport.date(from: schedule.startDateTime) {
                        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: date)
                        year = parts.year ?? year
                        month = parts.month ?? month
                        highlightedDate = DateOnly(rawValue: String(format: "%04d-%02d-%02d", year, month, parts.day ?? 1))
                    }
                }
                if selectedMemberID == nil { selectedMemberID = member.id }
                if let selectedMemberID,
                   selectedMemberID != member.id,
                   !friends.contains(where: { $0.id == selectedMemberID }) {
                    targetMember = try await repository.member(id: selectedMemberID)
                }
                let targetTeamID = selectedMemberID == member.id
                    ? member.teamId
                    : friends.first(where: { $0.id == selectedMemberID })?.teamId ?? targetMember?.teamId
                if let teamID = targetTeamID {
                    team = try await repository.team(id: teamID)
                }
            }
            try await loadMonth()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.load")
            if emitErrorFeedback { emit(.error) }
        }
    }

    func loadMonth() async throws {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            loadUITestingFixture()
            return
        }
#endif
        guard let memberID = targetMemberID else { throw APIError.invalidResponse }
        let mine = memberID == me?.id
        async let calendarResult = repository.calendar(year: year, month: month)
        async let dutiesResult = repository.duties(memberID: memberID, year: year, month: month)
        async let schedulesResult = repository.schedules(memberID: memberID, year: year, month: month)
        async let holidaysResult = repository.holidays(year: year, month: month)
        async let dDaysResult = repository.dDays(memberID: memberID, isMine: mine)
        async let manageResult = mine ? false : repository.canManage(memberID: memberID)
        async let todoResult: TodoBoardDTO? = mine ? repository.todoBoard() : nil
        async let comparedResult = repository.otherDuties(memberIDs: Array(comparedMemberIDs.sorted().prefix(3)), year: year, month: month)

        let serverDays = try await calendarResult
        let cells = CalendarDateSupport.cells(year: year, month: month, serverDays: serverDays)
        guard cells.count == 42 else { throw APIError.invalidResponse }
        let duties = try await dutiesResult
        let schedules = try await schedulesResult
        let holidays = try await holidaysResult
        let loadedDDays = try await dDaysResult
        canManage = try await manageResult
        todoBoard = try await todoResult
        let compared = try await comparedResult
        dDays = loadedDDays.sorted { $0.date.rawValue < $1.date.rawValue }
        let activeTodos = (todoBoard?.todo ?? []) + (todoBoard?.inProgress ?? [])
        let pinKey = pinnedDDayKey(memberID)
        pinnedDDayID = UserDefaults.standard.object(forKey: pinKey) == nil ? nil : Int64(UserDefaults.standard.integer(forKey: pinKey))
        days = cells.enumerated().map { index, cell in
            CalendarDayContent(
                cell: cell,
                duty: duties.first { $0.year == cell.year && $0.month == cell.month && $0.day == cell.day },
                schedules: index < schedules.count ? schedules[index] : [],
                holidays: index < holidays.count ? holidays[index] : [],
                todos: activeTodos.filter { $0.dueDate == cell.date },
                dDays: loadedDDays.filter { $0.date == cell.date },
                comparedDuties: compared.compactMap { response in
                    response.duties.first(where: { $0.year == cell.year && $0.month == cell.month && $0.day == cell.day })
                        .map {
                            ComparedDuty(
                                memberID: response.memberId,
                                name: response.name,
                                hasProfilePhoto: response.hasProfilePhoto,
                                profilePhotoVersion: response.profilePhotoVersion,
                                duty: $0
                            )
                        }
                }
            )
        }
        selectedDay = selectedDay.flatMap { selected in days.first { $0.id == selected.id } }
    }

    func toggleMyDutyComparison() async {
        guard !isMyCalendar, let myID = me?.id else { return }
        comparedMemberIDs = comparedMemberIDs.contains(myID) ? [] : [myID]
        emit(.selection)
        await reloadMonth()
    }

#if DEBUG
    private func loadUITestingFixture() {
        let includesCalendarParity = ProcessInfo.processInfo.arguments.contains("-ui-testing-calendar-parity")
        let member = MemberDTO(
            id: 1,
            name: "UI Test",
            email: nil,
            teamId: nil,
            team: nil,
            calendarVisibility: .friends,
            kakaoId: nil,
            naverId: nil,
            appleId: nil,
            hasPassword: true,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
        me = member
        selectedMemberID = member.id
        targetMember = nil
        let parityFriend = FriendDTO(
            id: 2,
            name: "Profile friend",
            teamId: nil,
            team: "Ward A",
            hasProfilePhoto: false,
            profilePhotoVersion: 17,
            isFamily: false,
            pinOrder: nil
        )
        friends = includesCalendarParity ? [parityFriend] : []
        team = nil
        // A page that already fits its screen cannot show a scroll either way, so the
        // scroll test asks for enough D-Days to push the calendar past the bottom.
        // The dates sit outside the grid so the cells themselves stay as they were.
        dDays = ProcessInfo.processInfo.arguments.contains("-ui-testing-calendar-tall")
            ? (1...6).map { index in
                DDayDTO(
                    id: Int64(900 + index),
                    title: "D-Day \(index)",
                    date: DateOnly(rawValue: String(format: "2030-01-%02d", index)),
                    isPrivate: false,
                    calc: 0,
                    daysLeft: Int64(index)
                )
            }
            : []
        let parityTodo = TodoDTO(
            id: "A11CE000-0000-4000-8000-000000000011",
            title: "Calendar detail check",
            content: "Only this Todo detail should be visible.",
            position: 0,
            status: .inProgress,
            createdDate: LocalDateTimeValue(rawValue: "2026-08-15T09:00:00"),
            completedDate: nil,
            dueDate: DateOnly(rawValue: "2026-08-12"),
            isOverdue: false,
            isTagged: false,
            owner: "UI Test",
            taggedByMember: nil,
            tags: [],
            hasAttachments: false
        )
        todoBoard = TodoBoardDTO(
            todo: [],
            inProgress: includesCalendarParity ? [parityTodo] : [],
            done: [],
            counts: TodoCountsDTO(
                todo: 0,
                inProgress: includesCalendarParity ? 1 : 0,
                done: 0,
                total: includesCalendarParity ? 1 : 0
            )
        )
        comparedMemberIDs = includesCalendarParity ? [parityFriend.id] : []
        canManage = false
        errorMessage = nil
        let firstOfMonth = CalendarDateSupport.calendar.date(
            from: DateComponents(year: year, month: month, day: 1)
        ) ?? Date()
        let weekday = CalendarDateSupport.calendar.component(.weekday, from: firstOfMonth)
        let gridStart = CalendarDateSupport.calendar.date(
            byAdding: .day,
            value: -(weekday - CalendarDateSupport.calendar.firstWeekday + 7) % 7,
            to: firstOfMonth
        ) ?? firstOfMonth
        days = (0..<42).compactMap { offset in
            guard let date = CalendarDateSupport.calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }
            let parts = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: date)
            guard let cellYear = parts.year, let cellMonth = parts.month, let cellDay = parts.day else {
                return nil
            }
            let cell = CalendarCell(
                date: DateOnly(rawValue: String(format: "%04d-%02d-%02d", cellYear, cellMonth, cellDay)),
                year: cellYear,
                month: cellMonth,
                day: cellDay,
                isCurrentMonth: cellYear == year && cellMonth == month
            )
            let comparedDuties: [ComparedDuty] = if includesCalendarParity && cell.isCurrentMonth && cell.day == 12 {
                [ComparedDuty(
                    memberID: parityFriend.id,
                    name: parityFriend.name,
                    hasProfilePhoto: parityFriend.hasProfilePhoto,
                    profilePhotoVersion: parityFriend.profilePhotoVersion,
                    duty: DutyDTO(
                        year: cell.year,
                        month: cell.month,
                        day: cell.day,
                        dutyType: "Day",
                        dutyColor: "#3B82F6",
                        isOff: false,
                        dutyTypeId: 7,
                        source: .override
                    )
                )]
            } else {
                []
            }
            return CalendarDayContent(
                cell: cell,
                duty: nil,
                schedules: [],
                holidays: [],
                todos: includesCalendarParity && parityTodo.dueDate == cell.date ? [parityTodo] : [],
                dDays: [],
                comparedDuties: comparedDuties
            )
        }
    }
#endif

    func setFriendDutyComparisons(_ memberIDs: Set<MemberID>) async {
        guard isMyCalendar else { return }
        let validIDs = Set(memberIDs.filter { candidate in
            friends.contains(where: { $0.id == candidate })
        }.prefix(3))
        guard validIDs != comparedMemberIDs else { return }
        comparedMemberIDs = validIDs
        emit(.selection)
        await reloadMonth()
    }

    func selectYearMonth(year: Int, month: Int, emitFeedback: Bool = true) async {
        guard (1...12).contains(month) else { return }
        let feedback = CalendarHapticPolicy.monthNavigation(
            fromYear: self.year,
            fromMonth: self.month,
            toYear: year,
            toMonth: month
        )
        self.year = year
        self.month = month
        if emitFeedback, feedback != nil { emit(.routine) }
        await reloadMonth()
    }

    func setQuickDutyEditing(_ enabled: Bool, emitFeedback: Bool = true) {
        guard !enabled || canEdit else { return }
        guard isQuickDutyEditing != enabled else { return }
        isQuickDutyEditing = enabled
        quickDutyDay = enabled ? (days.first(where: { $0.cell.date == highlightedDate && $0.cell.isCurrentMonth }) ?? days.first(where: \.cell.isCurrentMonth)) : nil
        if emitFeedback { emit(.selection) }
    }

    func focusQuickDuty(on day: CalendarDayContent, emitFeedback: Bool = true) {
        guard canEdit, day.cell.isCurrentMonth else { return }
        let previousDate = quickDutyDay?.cell.date
        quickDutyDay = day
        highlightedDate = day.cell.date
        if emitFeedback,
           CalendarHapticPolicy.selectionChanged(from: previousDate, to: day.cell.date) != nil {
            emit(.selection)
        }
    }

    func selectDay(_ day: CalendarDayContent) {
        let previousDate = selectedDay?.cell.date
        selectedDay = day
        highlightedDate = day.cell.date
        if CalendarHapticPolicy.selectionChanged(from: previousDate, to: day.cell.date) != nil {
            emit(.selection)
        }
    }

    func moveQuickDutyFocus(by offset: Int) {
        let currentMonthDays = days.filter(\.cell.isCurrentMonth)
        guard !currentMonthDays.isEmpty else { return }
        let currentIndex = quickDutyDay.flatMap { selected in currentMonthDays.firstIndex(where: { $0.id == selected.id }) } ?? 0
        let index = min(max(currentIndex + offset, 0), currentMonthDays.count - 1)
        focusQuickDuty(on: currentMonthDays[index])
    }

    func applyQuickDuty(dutyTypeID: DutyTypeID?) async {
        guard canEdit, let day = quickDutyDay, let memberID = targetMemberID else { return }
        let currentMonthDays = days.filter(\.cell.isCurrentMonth)
        let nextDate = currentMonthDays.firstIndex(where: { $0.id == day.id }).flatMap { index in
            currentMonthDays.indices.contains(index + 1) ? currentMonthDays[index + 1].cell.date : nil
        }
        do {
            try await repository.updateDuty(DutyUpdateDTO(
                year: day.cell.year, month: day.cell.month, day: day.cell.day,
                dutyTypeId: dutyTypeID, memberId: memberID
            ))
            emit(.success)
            do {
                try await refreshDuties()
            } catch {
                errorMessage = CalendarLocalization.text("calendar.error.save")
            }
            if let nextDate, let next = days.first(where: { $0.cell.date == nextDate }) {
                focusQuickDuty(on: next, emitFeedback: false)
            }
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.save")
            emit(.error)
        }
    }

    func changeMonth(by offset: Int) async {
        var components = DateComponents(year: year, month: month, day: 1)
        guard let date = CalendarDateSupport.calendar.date(from: components),
              let changed = CalendarDateSupport.calendar.date(byAdding: .month, value: offset, to: date)
        else { return }
        components = CalendarDateSupport.calendar.dateComponents([.year, .month], from: changed)
        let nextYear = components.year ?? year
        let nextMonth = components.month ?? month
        guard CalendarHapticPolicy.monthNavigation(
            fromYear: year,
            fromMonth: month,
            toYear: nextYear,
            toMonth: nextMonth
        ) != nil else { return }
        year = nextYear
        month = nextMonth
        emit(.routine)
        await reloadMonth()
    }

    func goToToday(emitFeedback: Bool = true) async {
        let components = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: Date())
        let nextYear = components.year ?? year
        let nextMonth = components.month ?? month
        let nextDate = DateOnly(rawValue: String(format: "%04d-%02d-%02d", nextYear, nextMonth, components.day ?? 1))
        let monthChanged = CalendarHapticPolicy.monthNavigation(
            fromYear: year,
            fromMonth: month,
            toYear: nextYear,
            toMonth: nextMonth
        ) != nil
        let dateChanged = CalendarHapticPolicy.selectionChanged(from: highlightedDate, to: nextDate) != nil
        year = nextYear
        month = nextMonth
        highlightedDate = nextDate
        if emitFeedback, monthChanged || dateChanged { emit(.routine) }
        await reloadMonth()
    }

    var pinnedDDay: DDayDTO? { dDays.first { $0.id == pinnedDDayID } }

    func togglePinnedDDay(_ item: DDayDTO) {
        guard let memberID = targetMemberID else { return }
        if pinnedDDayID == item.id {
            pinnedDDayID = nil
            UserDefaults.standard.removeObject(forKey: pinnedDDayKey(memberID))
        } else {
            pinnedDDayID = item.id
            UserDefaults.standard.set(item.id, forKey: pinnedDDayKey(memberID))
        }
        emit(.selection)
    }

    func refreshTodoBoard() async {
        guard isMyCalendar else { return }
        do {
            todoBoard = try await repository.todoBoard()
            rebuildTodoDays()
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.load")
            emit(.error)
        }
    }

    func updateDuty(day: CalendarDayContent, dutyTypeID: DutyTypeID?) async {
        guard canEdit, let memberID = targetMemberID else { return }
        do {
            try await repository.updateDuty(DutyUpdateDTO(
                year: day.cell.year, month: day.cell.month, day: day.cell.day,
                dutyTypeId: dutyTypeID, memberId: memberID
            ))
            emit(.success)
            do {
                try await refreshDuties()
            } catch {
                errorMessage = CalendarLocalization.text("calendar.error.save")
            }
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.save")
            emit(.error)
        }
    }

    func batchUpdateDuty(dutyTypeID: DutyTypeID?) async {
        guard isMyCalendar, let memberID = targetMemberID else { return }
        do {
            try await repository.batchUpdateDuty(DutyBatchUpdateDTO(
                year: year, month: month, dutyTypeId: dutyTypeID, memberId: memberID
            ))
            emit(.success)
            do {
                try await refreshDuties()
            } catch {
                errorMessage = CalendarLocalization.text("calendar.error.save")
            }
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.save")
            emit(.error)
        }
    }

    func uploadDutyBatch(url: URL) async {
        guard isMyCalendar, let template = team?.dutyBatchTemplate, let memberID = targetMemberID else { return }
        guard CalendarFeatureLogic.isSupportedDutyBatchFile(
            fileName: url.lastPathComponent,
            fileExtensions: template.fileExtensions
        ) else {
            dutyBatchMessage = CalendarFeatureLogic.dutyBatchFailureMessage(
                errorCode: "dutyBatch.notSupportedFile",
                details: [
                    "supportedFile": .string(
                        CalendarFeatureLogic.normalizedFileExtensions(template.fileExtensions)
                            .joined(separator: ", ")
                    )
                ]
            )
            emit(.warning)
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard data.count < AttachmentUploadPolicy.safeMaximumBytes else {
                dutyBatchMessage = CalendarLocalization.text("calendar.duty.excel.tooLarge")
                emit(.warning)
                return
            }
            let result = try await repository.uploadDutyBatch(
                memberID: memberID, year: year, month: month,
                filename: url.lastPathComponent, data: data
            )
            if result.result {
                let period = if let start = result.startDate, let end = result.endDate {
                    CalendarLocalization.format("calendar.duty.excel.period", start.rawValue, end.rawValue)
                } else { "" }
                dutyBatchMessage = [period, CalendarLocalization.format("calendar.duty.excel.success", result.workingDays, result.offDays)]
                    .filter { !$0.isEmpty }.joined(separator: "\n")
                emit(.success)
                do {
                    try await refreshDuties()
                } catch {
                    dutyBatchMessage = CalendarLocalization.text("calendar.duty.excel.failed")
                }
            } else {
                dutyBatchMessage = CalendarFeatureLogic.dutyBatchFailureMessage(result)
                emit(.error)
            }
        } catch {
            dutyBatchMessage = CalendarLocalization.text("calendar.duty.excel.failed")
            emit(.error)
        }
    }

    func saveSchedule(
        existing: ScheduleDTO?, content: String, description: String,
        visibility: Visibility, start: Date, end: Date, tagFriendIDs: [MemberID],
        attachmentSessionID: UUID?, orderedAttachmentIDs: [AttachmentID],
        aiTimeParsingRequested: Bool
    ) async -> Bool {
        guard canEdit, let memberID = targetMemberID else { return false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 50, end >= start else {
            emit(.warning)
            return false
        }
        guard !contentFilter.isBlocked(trimmed, description) else {
            errorMessage = CalendarLocalization.text("calendar.error.contentFilter")
            emit(.error)
            return false
        }
        do {
            _ = try await repository.saveSchedule(ScheduleSaveDTO(
                id: existing?.id, memberId: memberID, content: trimmed, description: description,
                visibility: visibility, startDateTime: CalendarDateSupport.localDateTime(start),
                endDateTime: CalendarDateSupport.localDateTime(end),
                tagFriendIds: isMyCalendar ? tagFriendIDs : nil,
                attachmentSessionId: attachmentSessionID,
                orderedAttachmentIds: orderedAttachmentIDs,
                aiTimeParsingRequested: aiTimeParsingRequested
            ))
            emit(.success)
            do {
                try await refreshSchedules()
            } catch {
                errorMessage = CalendarLocalization.text("calendar.error.save")
                return false
            }
            return true
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.save")
            emit(.error)
            return false
        }
    }

    func deleteSchedule(_ schedule: ScheduleDTO) async -> Bool {
        guard canEdit, !schedule.isTagged else { return false }
        do {
            try await repository.deleteSchedule(id: schedule.id)
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.delete")
            emit(.error)
            return false
        }
        removeSchedule(id: schedule.id)
        emit(.success)
        return true
    }

    func untagSelf(_ schedule: ScheduleDTO) async -> Bool {
        guard isMyCalendar, schedule.isTagged else { return false }
        do {
            try await repository.untagSelf(scheduleID: schedule.id)
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.delete")
            emit(.error)
            return false
        }
        removeSchedule(id: schedule.id)
        emit(.success)
        return true
    }

    func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canEdit, let memberID = targetMemberID, !query.isEmpty else { searchResults = []; return }
        isSearching = true
        defer { isSearching = false }
        do {
            let response = try await repository.searchSchedules(memberID: memberID, query: query, page: 0)
            searchResults = response.content
            searchPage = 0
            canLoadMoreSearchResults = !response.last
        }
        catch {
            errorMessage = CalendarLocalization.text("calendar.error.search")
            emit(.error)
        }
    }

    func loadMoreSearchResults() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canEdit, let memberID = targetMemberID, !query.isEmpty, canLoadMoreSearchResults, !isSearching else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            let nextPage = searchPage + 1
            let response = try await repository.searchSchedules(memberID: memberID, query: query, page: nextPage)
            searchResults.append(contentsOf: response.content)
            searchPage = nextPage
            canLoadMoreSearchResults = !response.last
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.search")
            emit(.error)
        }
    }

    func showSearchResult(_ result: ScheduleSearchResultDTO) async {
        guard let date = CalendarDateSupport.date(from: result.startDateTime) else { return }
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: date)
        let nextYear = parts.year ?? year
        let nextMonth = parts.month ?? month
        let nextDate = DateOnly(rawValue: String(format: "%04d-%02d-%02d", nextYear, nextMonth, parts.day ?? 1))
        year = nextYear
        month = nextMonth
        highlightedDate = nextDate
        await reloadMonth()
    }

    func saveDDay(existing: DDayDTO?, title: String, date: Date, isPrivate: Bool) async -> Bool {
        guard isMyCalendar else { return false }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 30 else {
            emit(.warning)
            return false
        }
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: date)
        let dateOnly = DateOnly(rawValue: String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0))
        do {
            let saved = try await repository.saveDDay(
                DDaySaveDTO(id: existing?.id, title: trimmed, date: dateOnly, isPrivate: isPrivate)
            )
            upsertDDay(saved)
            emit(.success)
            return true
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.save")
            emit(.error)
            return false
        }
    }

    func deleteDDay(_ dDay: DDayDTO) async -> Bool {
        guard isMyCalendar else { return false }
        do {
            try await repository.deleteDDay(id: dDay.id)
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.delete")
            emit(.error)
            return false
        }
        removeDDay(id: dDay.id)
        emit(.success)
        return true
    }

    private func refreshSchedules() async throws {
        guard let memberID = targetMemberID else { throw APIError.invalidResponse }
        let loadedSchedules = try await repository.schedules(
            memberID: memberID,
            year: year,
            month: month
        )
        days = days.enumerated().map { index, day in
            replacing(day, schedules: loadedSchedules.indices.contains(index) ? loadedSchedules[index] : [])
        }
        rebindPresentedDays()
    }

    private func refreshDuties() async throws {
        guard let memberID = targetMemberID else { throw APIError.invalidResponse }
        let loadedDuties = try await repository.duties(
            memberID: memberID,
            year: year,
            month: month
        )
        days = days.map { day in
            let duty = loadedDuties.first {
                $0.year == day.cell.year && $0.month == day.cell.month && $0.day == day.cell.day
            }
            return CalendarDayContent(
                cell: day.cell,
                duty: duty,
                schedules: day.schedules,
                holidays: day.holidays,
                todos: day.todos,
                dDays: day.dDays,
                comparedDuties: day.comparedDuties
            )
        }
        rebindPresentedDays()
    }

    private func rebuildTodoDays() {
        let visibleTodos = (todoBoard?.todo ?? []) + (todoBoard?.inProgress ?? [])
        days = days.map { day in
            replacing(day, todos: visibleTodos.filter { $0.dueDate == day.cell.date })
        }
        rebindPresentedDays()
    }

    private func removeSchedule(id: ScheduleID) {
        days = days.map { day in
            replacing(day, schedules: day.schedules.filter { $0.id != id })
        }
        rebindPresentedDays()
    }

    private func upsertDDay(_ item: DDayDTO) {
        dDays.removeAll { $0.id == item.id }
        dDays.append(item)
        dDays.sort { $0.date.rawValue < $1.date.rawValue }
        rebuildDDayDays()
    }

    private func removeDDay(id: Int64) {
        dDays.removeAll { $0.id == id }
        if pinnedDDayID == id, let memberID = targetMemberID {
            pinnedDDayID = nil
            UserDefaults.standard.removeObject(forKey: pinnedDDayKey(memberID))
        }
        rebuildDDayDays()
    }

    private func rebuildDDayDays() {
        days = days.map { day in
            replacing(day, dDays: dDays.filter { $0.date == day.cell.date })
        }
        rebindPresentedDays()
    }

    private func rebindPresentedDays() {
        selectedDay = selectedDay.flatMap { selected in days.first { $0.id == selected.id } }
        quickDutyDay = quickDutyDay.flatMap { selected in days.first { $0.id == selected.id } }
    }

    private func replacing(
        _ day: CalendarDayContent,
        schedules: [ScheduleDTO]? = nil,
        todos: [TodoDTO]? = nil,
        dDays: [DDayDTO]? = nil
    ) -> CalendarDayContent {
        CalendarDayContent(
            cell: day.cell,
            duty: day.duty,
            schedules: schedules ?? day.schedules,
            holidays: day.holidays,
            todos: todos ?? day.todos,
            dDays: dDays ?? day.dDays,
            comparedDuties: day.comparedDuties
        )
    }

    private func reloadMonth() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { try await loadMonth() }
        catch is CancellationError { return }
        catch {
            errorMessage = CalendarLocalization.text("calendar.error.load")
            emit(.error)
        }
    }

    private func pinnedDDayKey(_ memberID: MemberID) -> String { "selectedDday_\(memberID)" }

    private func emit(_ kind: DPHapticKind) {
        hapticCenter.emit(kind)
    }
}

enum CalendarFeatureLogic {
    static func dutyBatchFailureMessage(_ result: DutyBatchUploadResult) -> String {
        dutyBatchFailureMessage(errorCode: result.errorCode, details: result.errorDetails)
    }

    static func dutyBatchFailureMessage(errorCode: String?, details: [String: JSONValue]?) -> String {
        if let errorCode {
            let localized = CalendarLocalization.text(errorCode, table: "Errors")
            if localized != errorCode { return interpolate(localized, details: details) }
        }
        return CalendarLocalization.text("calendar.duty.excel.failed")
    }

    static func normalizedFileExtensions(_ fileExtensions: [String]) -> [String] {
        var seen = Set<String>()
        return fileExtensions.compactMap { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                .lowercased()
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return ".\(normalized)"
        }
    }

    static func isSupportedDutyBatchFile(fileName: String, fileExtensions: [String]) -> Bool {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        return normalizedFileExtensions(fileExtensions).contains(".\(fileExtension)")
    }

    private static func interpolate(_ message: String, details: [String: JSONValue]?) -> String {
        details?.reduce(into: message) { result, entry in
            result = result.replacingOccurrences(of: "{\(entry.key)}", with: display(entry.value))
        } ?? message
    }

    private static func display(_ value: JSONValue) -> String {
        switch value {
        case .string(let value): value
        case .integer(let value): String(value)
        case .number(let value): String(value)
        case .boolean(let value): String(value)
        case .array(let values): values.map(display).joined(separator: ", ")
        case .object(let values): values.sorted(by: { $0.key < $1.key }).map { "\($0.key): \(display($0.value))" }.joined(separator: ", ")
        case .null: "-"
        }
    }
}
