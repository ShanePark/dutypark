import Foundation
import Testing
@testable import Dutypark

/// Another member's calendar has no offline cache, so the swipe preview needs
/// the neighbouring months fetched in memory. Without it the swipe shows
/// date-only cells and the duty colours appear only after the committed load.
@MainActor
struct CalendarMemberMonthPreviewTests {
    @Test func dutySummaryKeepsTheLoadedMonthUntilTheNewResponseArrives() async throws {
        let model = Self.model(repository: MemberMonthPreviewRepository(), memberID: 2)
        await model.load()
        let original = model.dutySummaryDuties
        #expect(original.count == 1)
        #expect(original.first?.month == 8)

        model.month = 9
        #expect(model.dutySummaryDuties == original)

        try await model.loadMonth()
        #expect(model.dutySummaryDuties.count == 1)
        #expect(model.dutySummaryDuties.first?.month == 9)

        model.year = 2027
        model.month = 1
        #expect(model.dutySummaryDuties.first?.year == 2026)
        #expect(model.dutySummaryDuties.first?.month == 9)
        try await model.loadMonth()
        #expect(model.dutySummaryDuties.first?.year == 2027)
        #expect(model.dutySummaryDuties.first?.month == 1)
    }

    @Test func dutySummaryExcludesAdjacentMonthDutiesAndAcceptsAnEmptyLoadedMonth() async throws {
        let repository = MemberMonthPreviewRepository(
            emptyMonths: [OfflineMonthKey(year: 2026, month: 9)],
            includesAdjacentMonthDuties: true
        )
        let model = Self.model(repository: repository, memberID: 2)
        await model.load()
        #expect(model.days.compactMap(\.duty).count == 2)
        #expect(model.dutySummaryDuties.count == 1)

        model.month = 9
        #expect(model.dutySummaryDuties.count == 1)
        try await model.loadMonth()
        #expect(model.days.compactMap(\.duty).count == 1)
        #expect(model.dutySummaryDuties.isEmpty)
    }

    @Test func anotherMembersNeighbouringMonthsCarryTheirRealDutiesAfterTheMonthLoads() async {
        let repository = MemberMonthPreviewRepository()
        let model = Self.model(repository: repository, memberID: 2)

        await model.load()

        let previous = await model.cachedMonthPreview(year: 2026, month: 7)
        let next = await model.cachedMonthPreview(year: 2026, month: 9)
        #expect(Self.dutyColor(in: previous, on: "2026-07-12") == MemberMonthPreviewRepository.color(member: 2, month: 7))
        #expect(Self.dutyColor(in: next, on: "2026-09-12") == MemberMonthPreviewRepository.color(member: 2, month: 9))
        #expect(
            Self.dutyColor(in: model.readyMonthPreview(year: 2026, month: 9), on: "2026-09-12")
                == MemberMonthPreviewRepository.color(member: 2, month: 9),
            "A ready preview must be readable synchronously so the swipe never starts on a placeholder"
        )

        #expect(await model.changeMonth(by: 1))
        let following = await model.cachedMonthPreview(year: 2026, month: 10)
        #expect(Self.dutyColor(in: following, on: "2026-10-12") == MemberMonthPreviewRepository.color(member: 2, month: 10))
    }

    @Test func switchingMemberNeverShowsThePreviousMembersPreview() async throws {
        let repository = MemberMonthPreviewRepository()
        let model = Self.model(repository: repository, memberID: 2)
        await model.load()
        _ = await model.cachedMonthPreview(year: 2026, month: 9)

        model.selectedMemberID = 3

        #expect(model.readyMonthPreview(year: 2026, month: 9) == nil)
        #expect(await model.cachedMonthPreview(year: 2026, month: 9) == nil)

        try await model.loadMonth()
        let next = await model.cachedMonthPreview(year: 2026, month: 9)
        #expect(Self.dutyColor(in: next, on: "2026-09-12") == MemberMonthPreviewRepository.color(member: 3, month: 9))
    }

    @Test func aFailedPreviewIsPassive() async {
        let repository = MemberMonthPreviewRepository(failingMonths: [OfflineMonthKey(year: 2026, month: 9)])
        let haptics = DPHapticCenter()
        let model = Self.model(repository: repository, memberID: 2, haptics: haptics)

        await model.load()

        #expect(await model.cachedMonthPreview(year: 2026, month: 9) == nil)
        #expect(await model.cachedMonthPreview(year: 2026, month: 7) != nil)
        #expect(model.errorMessage == nil)
        #expect(haptics.event == nil)
    }

    @Test func changingTheComparisonRefetchesPreviewsWithTheComparedDuties() async {
        let repository = MemberMonthPreviewRepository()
        let model = Self.model(repository: repository, memberID: 2)
        await model.load()
        let before = await model.cachedMonthPreview(year: 2026, month: 9)
        #expect(Self.day(in: before, on: "2026-09-12")?.comparedDuties.isEmpty == true)

        await model.toggleMyDutyComparison()

        #expect(model.readyMonthPreview(year: 2026, month: 9).map(Self.hasComparedDuties) != false)
        let after = await model.cachedMonthPreview(year: 2026, month: 9)
        #expect(Self.day(in: after, on: "2026-09-12")?.comparedDuties.map(\.memberID) == [1])
    }

    @Test func aManagerEditOnAnotherMembersCalendarRefetchesItsPreviews() async throws {
        let repository = MemberMonthPreviewRepository()
        let model = Self.model(repository: repository, memberID: 2)
        await model.load()
        _ = await model.cachedMonthPreview(year: 2026, month: 9)
        let requestsBefore = await repository.dutyRequestCount(year: 2026, month: 9)

        #expect(await model.deleteSchedule(MemberMonthPreviewRepository.schedule(year: 2026, month: 8)))

        _ = await model.cachedMonthPreview(year: 2026, month: 9)
        #expect(await repository.dutyRequestCount(year: 2026, month: 9) > requestsBefore)
    }

    private static func model(
        repository: MemberMonthPreviewRepository,
        memberID: MemberID,
        haptics: DPHapticCenter = DPHapticCenter()
    ) -> CalendarViewModel {
        CalendarViewModel(
            repository: repository,
            now: CalendarDateSupport.calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!,
            memberID: memberID,
            accountID: 1,
            hapticCenter: haptics,
            cache: MemberMonthPreviewCache(),
            outbox: MemberMonthPreviewOutbox()
        )
    }

    private static func day(in days: [CalendarDayContent]?, on date: String) -> CalendarDayContent? {
        days?.first { $0.cell.date.rawValue == date }
    }

    private static func dutyColor(in days: [CalendarDayContent]?, on date: String) -> String? {
        day(in: days, on: date)?.duty?.dutyColor
    }

    private static func hasComparedDuties(_ days: [CalendarDayContent]) -> Bool {
        days.contains { !$0.comparedDuties.isEmpty }
    }
}

private actor MemberMonthPreviewRepository: CalendarRepositoryProtocol {
    private let failingMonths: Set<OfflineMonthKey>
    private let emptyMonths: Set<OfflineMonthKey>
    private let includesAdjacentMonthDuties: Bool
    private var dutyRequests: [OfflineMonthKey: Int] = [:]

    init(
        failingMonths: Set<OfflineMonthKey> = [],
        emptyMonths: Set<OfflineMonthKey> = [],
        includesAdjacentMonthDuties: Bool = false
    ) {
        self.failingMonths = failingMonths
        self.emptyMonths = emptyMonths
        self.includesAdjacentMonthDuties = includesAdjacentMonthDuties
    }

    nonisolated static func color(member: MemberID, month: Int) -> String {
        String(format: "#%02d%02d00", Int(member), month)
    }

    nonisolated static func schedule(year: Int, month: Int) -> ScheduleDTO {
        let date = String(format: "%04d-%02d-12", year, month)
        return ScheduleDTO(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
            content: "Meeting", description: "", position: 0,
            year: year, month: month, dayOfMonth: 12,
            startDateTime: LocalDateTimeValue(rawValue: "\(date)T00:00:00"),
            endDateTime: LocalDateTimeValue(rawValue: "\(date)T01:00:00"),
            isTagged: false, owner: "Friend", taggedByMember: nil, tags: [], visibility: .friends,
            dateToCompare: DateOnly(rawValue: date), attachments: [],
            startDate: DateOnly(rawValue: date), daysFromStart: 1,
            endDate: DateOnly(rawValue: date), curDate: DateOnly(rawValue: date), totalDays: 1
        )
    }

    func dutyRequestCount(year: Int, month: Int) -> Int {
        dutyRequests[OfflineMonthKey(year: year, month: month), default: 0]
    }

    func member() async throws -> MemberDTO {
        MemberDTO(
            id: 1, name: "Owner", email: "test@duty.park", teamId: nil, team: nil,
            calendarVisibility: .friends, kakaoId: nil, naverId: nil, hasPassword: true,
            hasProfilePhoto: false, profilePhotoVersion: 0
        )
    }
    func member(id: MemberID) async throws -> MemberPreviewDTO {
        MemberPreviewDTO(id: id, name: "Member \(id)", teamId: nil, team: nil, hasProfilePhoto: false, profilePhotoVersion: 0)
    }
    func friends() async throws -> [FriendDTO] {
        [2, 3].map {
            FriendDTO(
                id: $0, name: "Friend \($0)", teamId: nil, team: nil,
                hasProfilePhoto: false, profilePhotoVersion: 0, isFamily: false, displayOrder: nil
            )
        }
    }
    func team(id: TeamID) async throws -> TeamDTO { throw APIError.invalidResponse }
    func canManage(memberID: MemberID) async throws -> Bool { true }
    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO] {
        CalendarDateSupport.placeholderCells(year: year, month: month).map {
            TeamDayDTO(year: $0.year, month: $0.month, day: $0.day)
        }
    }
    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO] {
        let key = OfflineMonthKey(year: year, month: month)
        dutyRequests[key, default: 0] += 1
        if failingMonths.contains(key) { throw APIError.transport }
        var duties = emptyMonths.contains(key) ? [] : [Self.duty(member: memberID, year: year, month: month)]
        if includesAdjacentMonthDuties,
           let cell = CalendarDateSupport.placeholderCells(year: year, month: month).first(where: { !$0.isCurrentMonth }) {
            duties.append(DutyDTO(
                year: cell.year, month: cell.month, day: cell.day, dutyType: "Day", dutyColor: "#000000",
                isOff: false, dutyTypeId: 7, source: .override
            ))
        }
        return duties
    }
    func otherDuties(memberIDs: [MemberID], year: Int, month: Int) async throws -> [OtherDutyResponse] {
        memberIDs.map {
            OtherDutyResponse(
                memberId: $0, name: "Member \($0)", hasProfilePhoto: false, profilePhotoVersion: 0,
                duties: [Self.duty(member: $0, year: year, month: month)]
            )
        }
    }
    func schedules(memberID: MemberID, year: Int, month: Int) async throws -> [[ScheduleDTO]] {
        Array(repeating: [], count: 42)
    }
    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]] { Array(repeating: [], count: 42) }
    func dDays(memberID: MemberID, isMine: Bool) async throws -> [DDayDTO] { [] }
    func todoBoard() async throws -> TodoBoardDTO {
        TodoBoardDTO(todo: [], inProgress: [], done: [], counts: TodoCountsDTO(todo: 0, inProgress: 0, done: 0, total: 0))
    }
    func saveSchedule(_ request: ScheduleSaveDTO) async throws -> ScheduleSaveResponse { throw APIError.invalidResponse }
    func deleteSchedule(id: ScheduleID) async throws {}
    func untagSelf(scheduleID: ScheduleID) async throws {}
    func searchSchedules(memberID: MemberID, query: String, page: Int) async throws -> PageResponse<ScheduleSearchResultDTO> {
        throw APIError.invalidResponse
    }
    func scheduleBasic(id: ScheduleID) async throws -> ScheduleBasicInfoDTO { throw APIError.invalidResponse }
    func updateDuty(_ request: DutyUpdateDTO) async throws {}
    func uploadDutyBatch(memberID: MemberID, year: Int, month: Int, filename: String, data: Data) async throws -> DutyBatchUploadResult {
        throw APIError.invalidResponse
    }
    func saveDDay(_ request: DDaySaveDTO) async throws -> DDayDTO { throw APIError.invalidResponse }
    func deleteDDay(id: Int64) async throws {}

    private static func duty(member: MemberID, year: Int, month: Int) -> DutyDTO {
        DutyDTO(
            year: year, month: month, day: 12, dutyType: "Day", dutyColor: color(member: member, month: month),
            isOff: false, dutyTypeId: 7, source: .override, dutyAbbreviation: "D"
        )
    }
}

private actor MemberMonthPreviewCache: OfflineCacheProviding {
    func saveAccount(_ snapshot: OfflineAccountSnapshot) async throws {}
    func saveAccount(member: LoginMember, friends: [FriendDTO], dDays: [DDayDTO], now: Date) async throws {}
    func loadAccount(memberID: MemberID) async -> OfflineAccountSnapshot? { nil }
    func saveMonth(_ snapshot: OfflineMonthSnapshot) async throws {}
    func loadMonth(accountID: MemberID, key: OfflineMonthKey) async -> OfflineMonthSnapshot? { nil }
    func loadCachedMonths(accountID: MemberID, around current: OfflineMonthKey) async -> [OfflineMonthSnapshot] { [] }
    func saveTodoBoard(accountID: MemberID, board: TodoBoardDTO, now: Date) async throws {}
    func loadTodoBoard(accountID: MemberID) async -> TodoBoardDTO? { nil }
    func searchSchedules(accountID: MemberID, query: String, keys: [OfflineMonthKey]?) async -> [ScheduleSearchResultDTO] { [] }
    func purge(accountID: MemberID) async throws {}
}

private actor MemberMonthPreviewOutbox: OfflineOutboxProviding {
    func enqueueScheduleCreate(
        accountID: MemberID, request: ScheduleSaveDTO, operationID: UUID, now: Date
    ) async throws -> OfflineOutboxEntry {
        throw APIError.invalidResponse
    }
    func enqueueTodoCreate(
        accountID: MemberID, request: TodoRequest, operationID: UUID, now: Date
    ) async throws -> OfflineOutboxEntry {
        throw APIError.invalidResponse
    }
    func entries(accountID: MemberID) async -> [OfflineOutboxEntry] { [] }
    func pendingEntries(accountID: MemberID, now: Date) async -> [OfflineOutboxEntry] { [] }
    func recordRetry(
        accountID: MemberID, operationID: UUID, error: OfflineOutboxFailure, nextAttemptAt: Date?
    ) async throws {}
    func markPermanentFailure(accountID: MemberID, operationID: UUID, error: OfflineOutboxFailure) async throws {}
    func retryPermanentFailure(accountID: MemberID, operationID: UUID, now: Date) async throws {}
    func markSucceeded(accountID: MemberID, operationID: UUID) async throws {}
    func purge(accountID: MemberID) async throws {}
}
