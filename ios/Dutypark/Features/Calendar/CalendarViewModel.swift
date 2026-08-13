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
    let name: String
    let duty: DutyDTO
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
    @Published var showTodoItems: Bool {
        didSet { UserDefaults.standard.set(showTodoItems, forKey: "dutyViewShowTodo") }
    }
    @Published private(set) var pinnedDDayID: Int64?
    @Published var dutyBatchMessage: String?
    private var searchPage = 0
    private let initialScheduleID: ScheduleID?

    init(
        repository: CalendarRepositoryProtocol = CalendarRepository(),
        now: Date = Date(),
        memberID: MemberID? = nil,
        date: DateOnly? = nil,
        scheduleID: ScheduleID? = nil
    ) {
        self.repository = repository
        initialScheduleID = scheduleID
        let initialDate = date.flatMap(CalendarDateSupport.date(from:)) ?? now
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month], from: initialDate)
        year = parts.year ?? 2026
        month = parts.month ?? 1
        selectedMemberID = memberID
        highlightedDate = date
        showTodoItems = UserDefaults.standard.bool(forKey: "dutyViewShowTodo")
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

    func load() async {
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
        }
    }

    func loadMonth() async throws {
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
        let activeTodos = (showTodoItems ? (todoBoard?.todo ?? []) : []) + (todoBoard?.inProgress ?? [])
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
                        .map { ComparedDuty(name: response.name, duty: $0) }
                }
            )
        }
        selectedDay = selectedDay.flatMap { selected in days.first { $0.id == selected.id } }
    }

    func toggleMyDutyComparison() async {
        guard !isMyCalendar, let myID = me?.id else { return }
        comparedMemberIDs = comparedMemberIDs.contains(myID) ? [] : [myID]
        await reloadMonth()
    }

    func setFriendDutyComparisons(_ memberIDs: Set<MemberID>) async {
        guard isMyCalendar else { return }
        let validIDs = Set(memberIDs.filter { candidate in
            friends.contains(where: { $0.id == candidate })
        }.prefix(3))
        guard validIDs != comparedMemberIDs else { return }
        comparedMemberIDs = validIDs
        await reloadMonth()
    }

    func selectYearMonth(year: Int, month: Int) async {
        guard (1...12).contains(month) else { return }
        self.year = year
        self.month = month
        await reloadMonth()
    }

    func setQuickDutyEditing(_ enabled: Bool) {
        guard !enabled || canEdit else { return }
        isQuickDutyEditing = enabled
        quickDutyDay = enabled ? (days.first(where: { $0.cell.date == highlightedDate && $0.cell.isCurrentMonth }) ?? days.first(where: \.cell.isCurrentMonth)) : nil
    }

    func focusQuickDuty(on day: CalendarDayContent) {
        guard canEdit, day.cell.isCurrentMonth else { return }
        quickDutyDay = day
        highlightedDate = day.cell.date
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
        do {
            try await repository.updateDuty(DutyUpdateDTO(
                year: day.cell.year, month: day.cell.month, day: day.cell.day,
                dutyTypeId: dutyTypeID, memberId: memberID
            ))
            let currentMonthDays = days.filter(\.cell.isCurrentMonth)
            let nextDate = currentMonthDays.firstIndex(where: { $0.id == day.id }).flatMap { index in
                currentMonthDays.indices.contains(index + 1) ? currentMonthDays[index + 1].cell.date : nil
            }
            try await loadMonth()
            if let nextDate, let next = days.first(where: { $0.cell.date == nextDate }) { focusQuickDuty(on: next) }
        } catch { errorMessage = CalendarLocalization.text("calendar.error.save") }
    }

    func changeMonth(by offset: Int) async {
        var components = DateComponents(year: year, month: month, day: 1)
        guard let date = CalendarDateSupport.calendar.date(from: components),
              let changed = CalendarDateSupport.calendar.date(byAdding: .month, value: offset, to: date)
        else { return }
        components = CalendarDateSupport.calendar.dateComponents([.year, .month], from: changed)
        year = components.year ?? year
        month = components.month ?? month
        await reloadMonth()
    }

    func goToToday() async {
        let components = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: Date())
        year = components.year ?? year
        month = components.month ?? month
        highlightedDate = DateOnly(rawValue: String(format: "%04d-%02d-%02d", year, month, components.day ?? 1))
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
    }

    func toggleTodoItems() async {
        showTodoItems.toggle()
        await reloadMonth()
    }

    func updateDuty(day: CalendarDayContent, dutyTypeID: DutyTypeID?) async {
        guard canEdit, let memberID = targetMemberID else { return }
        do {
            try await repository.updateDuty(DutyUpdateDTO(
                year: day.cell.year, month: day.cell.month, day: day.cell.day,
                dutyTypeId: dutyTypeID, memberId: memberID
            ))
            try await loadMonth()
        } catch { errorMessage = CalendarLocalization.text("calendar.error.save") }
    }

    func batchUpdateDuty(dutyTypeID: DutyTypeID?) async {
        guard isMyCalendar, let memberID = targetMemberID else { return }
        do {
            try await repository.batchUpdateDuty(DutyBatchUpdateDTO(
                year: year, month: month, dutyTypeId: dutyTypeID, memberId: memberID
            ))
            try await loadMonth()
        } catch { errorMessage = CalendarLocalization.text("calendar.error.save") }
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
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard data.count < AttachmentUploadPolicy.safeMaximumBytes else {
                dutyBatchMessage = CalendarLocalization.text("calendar.duty.excel.tooLarge")
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
                try await loadMonth()
            } else {
                dutyBatchMessage = CalendarFeatureLogic.dutyBatchFailureMessage(result)
            }
        } catch { dutyBatchMessage = CalendarLocalization.text("calendar.duty.excel.failed") }
    }

    func saveSchedule(
        existing: ScheduleDTO?, content: String, description: String,
        visibility: Visibility, start: Date, end: Date, tagFriendIDs: [MemberID],
        attachmentSessionID: UUID?, orderedAttachmentIDs: [AttachmentID],
        aiTimeParsingRequested: Bool
    ) async -> Bool {
        guard canEdit, let memberID = targetMemberID else { return false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 50, end >= start else { return false }
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
            try await loadMonth()
            return true
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.save")
            return false
        }
    }

    func deleteSchedule(_ schedule: ScheduleDTO) async -> Bool {
        guard canEdit, !schedule.isTagged else { return false }
        do {
            try await repository.deleteSchedule(id: schedule.id)
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.delete")
            return false
        }
        do { try await loadMonth() }
        catch { errorMessage = CalendarLocalization.text("calendar.error.load") }
        return true
    }

    func untagSelf(_ schedule: ScheduleDTO) async -> Bool {
        guard isMyCalendar, schedule.isTagged else { return false }
        do {
            try await repository.untagSelf(scheduleID: schedule.id)
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.delete")
            return false
        }
        do { try await loadMonth() }
        catch { errorMessage = CalendarLocalization.text("calendar.error.load") }
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
        catch { errorMessage = CalendarLocalization.text("calendar.error.search") }
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
        } catch { errorMessage = CalendarLocalization.text("calendar.error.search") }
    }

    func showSearchResult(_ result: ScheduleSearchResultDTO) async {
        guard let date = CalendarDateSupport.date(from: result.startDateTime) else { return }
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? year
        month = parts.month ?? month
        highlightedDate = DateOnly(rawValue: String(format: "%04d-%02d-%02d", year, month, parts.day ?? 1))
        await reloadMonth()
    }

    func saveDDay(existing: DDayDTO?, title: String, date: Date, isPrivate: Bool) async -> Bool {
        guard isMyCalendar else { return false }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 30 else { return false }
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: date)
        let dateOnly = DateOnly(rawValue: String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0))
        do {
            _ = try await repository.saveDDay(DDaySaveDTO(id: existing?.id, title: trimmed, date: dateOnly, isPrivate: isPrivate))
            try await loadMonth()
            return true
        } catch { errorMessage = CalendarLocalization.text("calendar.error.save"); return false }
    }

    func deleteDDay(_ dDay: DDayDTO) async -> Bool {
        guard isMyCalendar else { return false }
        do {
            try await repository.deleteDDay(id: dDay.id)
        } catch {
            errorMessage = CalendarLocalization.text("calendar.error.delete")
            return false
        }
        do { try await loadMonth() }
        catch { errorMessage = CalendarLocalization.text("calendar.error.load") }
        return true
    }

    private func reloadMonth() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do { try await loadMonth() }
        catch is CancellationError { return }
        catch { errorMessage = CalendarLocalization.text("calendar.error.load") }
    }

    private func pinnedDDayKey(_ memberID: MemberID) -> String { "selectedDday_\(memberID)" }
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
