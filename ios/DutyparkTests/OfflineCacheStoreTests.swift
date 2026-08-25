import Foundation
import Testing
@testable import Dutypark

@MainActor
struct OfflineCacheStoreTests {
    @Test
    func storesAccountProfileWithoutProviderIdentifiers() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineCacheStore(rootURL: root)
        let member = MemberDTO(
            id: 42,
            name: "Offline user",
            email: "offline@example.com",
            teamId: 7,
            team: "Dutypark",
            calendarVisibility: .friends,
            kakaoId: "kakao-secret",
            naverId: "naver-secret",
            appleId: "apple-secret",
            hasPassword: true,
            hasProfilePhoto: true,
            profilePhotoVersion: 3
        )

        try await store.saveAccount(member: member, now: Date(timeIntervalSince1970: 100))
        let restored = try #require(await store.loadAccount(memberID: 42))

        #expect(restored.memberID == 42)
        #expect(restored.profile.name == "Offline user")
        #expect(restored.profile.email == "offline@example.com")

        let json = try String(
            contentsOf: accountFile(root: root, memberID: 42),
            encoding: .utf8
        )
        #expect(!json.contains("kakao-secret"))
        #expect(!json.contains("naver-secret"))
        #expect(!json.contains("apple-secret"))
        #expect(!json.contains("kakaoId"))
        #expect(!json.contains("naverId"))
        #expect(!json.contains("appleId"))
    }

    @Test
    func rollingPolicyContainsThirteenMonthsCenteredOnCurrentMonth() {
        let policy = OfflineCacheRangePolicy(pastMonths: 6, futureMonths: 6)
        let current = OfflineMonthKey(year: 2026, month: 8)
        let months = policy.months(around: current)

        #expect(months.count == 13)
        #expect(months.first == OfflineMonthKey(year: 2026, month: 2))
        #expect(months.last == OfflineMonthKey(year: 2027, month: 2))
        #expect(policy.contains(OfflineMonthKey(year: 2026, month: 2), around: current))
        #expect(policy.contains(OfflineMonthKey(year: 2027, month: 2), around: current))
        #expect(!policy.contains(OfflineMonthKey(year: 2026, month: 1), around: current))
    }

    @Test
    func savesMonthAndSearchesCachedSchedulesLocally() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineCacheStore(rootURL: root)
        let first = makeSchedule(id: UUID(), content: "Project planning")
        let second = makeSchedule(id: UUID(), content: "Project review")
        var schedules = Array(repeating: [ScheduleDTO](), count: 42)
        schedules[0] = [first, second]
        let month = OfflineMonthSnapshot(
            accountID: 42,
            key: OfflineMonthKey(year: 2026, month: 8),
            calendar: Array(repeating: TeamDayDTO(year: 2026, month: 8, day: 1), count: 42),
            schedules: schedules,
            duties: [],
            holidays: Array(repeating: [], count: 42),
            otherDuties: [],
            storedAt: Date(timeIntervalSince1970: 200)
        )

        try await store.saveMonth(month)
        let restored = try #require(
            await store.loadMonth(accountID: 42, key: OfflineMonthKey(year: 2026, month: 8))
        )
        let results = await store.searchSchedules(
            accountID: 42,
            query: "planning"
        )

        #expect(restored.schedules.flatMap { $0 } == [first, second])
        #expect(results.count == 1)
        #expect(results.first?.content == "Project planning")
    }

    @Test
    func rejectsNonAccountAndNon42DayMonthSnapshots() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineCacheStore(rootURL: root)
        let key = OfflineMonthKey(year: 2026, month: 8)
        let validDays = Array(repeating: TeamDayDTO(year: 2026, month: 8, day: 1), count: 42)
        let validHolidays = Array(repeating: [HolidayDTO](), count: 42)

        await #expect(throws: OfflineCacheStoreError.accountMismatch) {
            try await store.saveMonth(OfflineMonthSnapshot(
                accountID: 0,
                key: key,
                calendar: validDays,
                schedules: Array(repeating: [], count: 42),
                duties: [],
                holidays: validHolidays,
                otherDuties: []
            ))
        }
        await #expect(throws: OfflineCacheStoreError.invalidMonthShape) {
            try await store.saveMonth(OfflineMonthSnapshot(
                accountID: 42,
                key: key,
                calendar: [],
                schedules: [],
                duties: [],
                holidays: [],
                otherDuties: []
            ))
        }
    }

    @Test
    func stripsProviderIdentifiersFromScheduleTagsBeforePersistence() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineCacheStore(rootURL: root)
        let taggedMember = MemberDTO(
            id: 9,
            name: "Tagged",
            email: "tagged@example.com",
            teamId: 7,
            team: "Dutypark",
            calendarVisibility: .friends,
            kakaoId: "kakao-secret",
            naverId: "naver-secret",
            appleId: "apple-secret",
            hasPassword: true,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
        let schedule = makeSchedule(id: UUID(), content: "Tagged schedule", tags: [taggedMember])
        let month = OfflineMonthSnapshot(
            accountID: 42,
            key: OfflineMonthKey(year: 2026, month: 8),
            calendar: Array(repeating: TeamDayDTO(year: 2026, month: 8, day: 1), count: 42),
            schedules: Array(repeating: [schedule], count: 42),
            duties: [],
            holidays: Array(repeating: [], count: 42),
            otherDuties: []
        )

        try await store.saveMonth(month)
        let json = try String(contentsOf: monthFile(
            root: root,
            memberID: 42,
            key: OfflineMonthKey(year: 2026, month: 8)
        ), encoding: .utf8)
        let restored = try #require(await store.loadMonth(
            accountID: 42,
            key: OfflineMonthKey(year: 2026, month: 8)
        ))

        #expect(!json.contains("kakao-secret"))
        #expect(!json.contains("naver-secret"))
        #expect(!json.contains("apple-secret"))
        #expect(restored.schedules[0][0].tags[0].naverId == nil)
    }

    @Test
    func ignoresCorruptAndSchemaMismatchedMonthFiles() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineCacheStore(rootURL: root)
        let key = OfflineMonthKey(year: 2026, month: 8)
        let file = monthFile(root: root, memberID: 42, key: key)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: file)

        #expect(await store.loadMonth(accountID: 42, key: key) == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))

        try Data("{\"schemaVersion\":999}".utf8).write(to: file)
        #expect(await store.loadMonth(accountID: 42, key: key) == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test
    func persistsTodoBoardAndPurgesAllAccountData() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineCacheStore(rootURL: root)
        let board = TodoBoardDTO(
            todo: [],
            inProgress: [],
            done: [],
            counts: TodoCountsDTO(todo: 0, inProgress: 0, done: 0, total: 0)
        )

        try await store.saveTodoBoard(accountID: 42, board: board)
        #expect(await store.loadTodoBoard(accountID: 42) == board)
        try await store.purge(accountID: 42)
        #expect(await store.loadTodoBoard(accountID: 42) == nil)
    }

    @Test
    func prunesMonthsOutsideTheInjectedRollingRange() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 1_786_000_000)
        let current = OfflineMonthKey(year: 2026, month: 8)
        let old = OfflineMonthKey(year: 2024, month: 1)
        let broadStore = OfflineCacheStore(
            rootURL: root,
            rangePolicy: OfflineCacheRangePolicy(pastMonths: 36, futureMonths: 36),
            now: { now }
        )
        try await broadStore.saveMonth(makeMonth(accountID: 42, key: old))
        #expect(await broadStore.loadMonth(accountID: 42, key: old) != nil)

        let rollingStore = OfflineCacheStore(rootURL: root, now: { now })
        try await rollingStore.pruneMonths(accountID: 42, around: current)

        let prunedMonth = await rollingStore.loadMonth(accountID: 42, key: old)
        #expect(prunedMonth == nil)
    }

    @Test
    func purgeAllRemovesEveryAccountCache() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineCacheStore(rootURL: root)
        try await store.saveAccount(member: makeMember(id: 42))
        try await store.saveAccount(member: makeMember(id: 43))
        try await store.purgeAll()

        let firstAccount = await store.loadAccount(memberID: 42)
        let secondAccount = await store.loadAccount(memberID: 43)
        #expect(firstAccount == nil)
        #expect(secondAccount == nil)
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "offline-cache-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func accountFile(root: URL, memberID: MemberID) -> URL {
        root.appending(path: "accounts/\(memberID)/account.json")
    }

    private func monthFile(root: URL, memberID: MemberID, key: OfflineMonthKey) -> URL {
        root.appending(path: "accounts/\(memberID)/months/\(key.fileName)")
    }

    private func makeSchedule(
        id: ScheduleID,
        content: String,
        tags: [MemberDTO] = []
    ) -> ScheduleDTO {
        ScheduleDTO(
            id: id,
            content: content,
            description: "",
            position: 0,
            year: 2026,
            month: 8,
            dayOfMonth: 12,
            startDateTime: LocalDateTimeValue(rawValue: "2026-08-12T09:00:00"),
            endDateTime: LocalDateTimeValue(rawValue: "2026-08-12T10:00:00"),
            isTagged: false,
            owner: "Offline user",
            taggedByMember: nil,
            tags: tags,
            visibility: .privateAccess,
            dateToCompare: DateOnly(rawValue: "2026-08-12"),
            attachments: [],
            startDate: DateOnly(rawValue: "2026-08-12"),
            daysFromStart: 0,
            endDate: DateOnly(rawValue: "2026-08-12"),
            curDate: DateOnly(rawValue: "2026-08-12"),
            totalDays: 1
        )
    }

    private func makeMonth(accountID: MemberID, key: OfflineMonthKey) -> OfflineMonthSnapshot {
        OfflineMonthSnapshot(
            accountID: accountID,
            key: key,
            calendar: Array(repeating: TeamDayDTO(year: key.year, month: key.month, day: 1), count: 42),
            schedules: Array(repeating: [], count: 42),
            duties: [],
            holidays: Array(repeating: [], count: 42),
            otherDuties: []
        )
    }

    private func makeMember(id: MemberID) -> MemberDTO {
        MemberDTO(
            id: id,
            name: "Offline user",
            email: "offline@example.com",
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
    }
}
