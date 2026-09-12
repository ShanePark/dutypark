import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class DutyparkWidgetSnapshotTests: XCTestCase {
    func testSnapshotBuilderPublishesFirstScheduleContentAndTotalCount() throws {
        let calendar = CalendarDateSupport.calendar
        let firstDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 30)))
        let serverDays = try (0..<42).map { offset -> TeamDayDTO in
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: firstDate))
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return TeamDayDTO(year: parts.year!, month: parts.month!, day: parts.day!)
        }
        let firstSchedule = makeSchedule(content: "가나다라마바")
        let secondSchedule = makeSchedule(content: "두 번째 일정")
        var schedules = Array(repeating: [ScheduleDTO](), count: 42)
        schedules[2] = [firstSchedule, secondSchedule]

        let snapshot = try XCTUnwrap(
            DutyparkWidgetSnapshotBuilder.make(
                accountID: 42,
                key: OfflineMonthKey(year: 2026, month: 9),
                calendar: serverDays,
                duties: [],
                schedules: schedules
            )
        )

        let day = try XCTUnwrap(snapshot.days[2])
        XCTAssertEqual(day.scheduleContent, "가나다라마바")
        XCTAssertEqual(day.scheduleCount, 2)
        XCTAssertNil(snapshot.days[3].scheduleContent)
        XCTAssertEqual(snapshot.days[3].scheduleCount, 0)
    }

    func testScheduleTextUsesCharacterBoundaryAndLeavesExactFiveUntouched() {
        XCTAssertEqual(DutyparkWidgetScheduleText.shortened("12345"), "12345")
        XCTAssertEqual(DutyparkWidgetScheduleText.shortened("123456"), "12345...")
        XCTAssertEqual(DutyparkWidgetScheduleText.shortened("가나다라마"), "가나다라마")
        XCTAssertEqual(DutyparkWidgetScheduleText.shortened("가나다라마바"), "가나다라마...")
        XCTAssertEqual(DutyparkWidgetScheduleText.shortened("😀😃😄😁😆"), "😀😃😄😁😆")
        XCTAssertEqual(DutyparkWidgetScheduleText.shortened("😀😃😄😁😆😅"), "😀😃😄😁😆...")
    }

    func testTodoSnapshotBuilderKeepsTodoThenInProgressAndDropsDone() throws {
        let board = TodoBoardDTO(
            todo: [makeTodo(id: "todo-1", title: "First", status: .todo)],
            inProgress: [makeTodo(id: "doing-1", title: "Second", status: .inProgress)],
            done: [makeTodo(id: "done-1", title: "Completed", status: .done)],
            counts: TodoCountsDTO(todo: 1, inProgress: 1, done: 1, total: 3)
        )

        let snapshot = try XCTUnwrap(
            DutyparkWidgetSnapshotBuilder.make(accountID: 42, board: board)
        )

        XCTAssertEqual(snapshot.todos.map(\.id), ["todo-1", "doing-1"])
        XCTAssertEqual(snapshot.todos.map(\.status), [.todo, .inProgress])
    }

    func testLegacyMonthlySnapshotDecodesWithoutNewScheduleFields() throws {
        let legacyDay: [String: Any] = [
            "date": "2026-09-01",
            "weekday": 3,
            "isCurrentMonth": true,
            "abbreviation": "E",
            "colorHex": "#123456",
            "isOff": false
        ]
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "accountID": 42,
            "year": 2026,
            "month": 9,
            "days": Array(repeating: legacyDay, count: 42),
            "updatedAt": 100_000
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let snapshot = try decoder.decode(DutyparkWidgetSnapshot.self, from: data)

        XCTAssertTrue(snapshot.isCurrentSchema)
        XCTAssertNil(snapshot.days[0].scheduleContent)
        XCTAssertEqual(snapshot.days[0].scheduleCount, 0)
    }

    func testTodoSnapshotStoreIsAccountAndSessionScoped() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-widget-todo-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = DutyparkWidgetSnapshotStore(rootURL: root)
        store.activate(accountID: 42, sessionGeneration: 7)
        let snapshot = DutyparkWidgetTodoSnapshot(
            accountID: 42,
            todos: [
                DutyparkWidgetTodoItem(id: "todo-1", title: "Todo", status: .todo),
                DutyparkWidgetTodoItem(id: "todo-2", title: "Doing", status: .inProgress)
            ],
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertTrue(store.saveTodo(snapshot, sessionGeneration: 7))
        XCTAssertEqual(store.loadTodo(), snapshot)

        store.activate(accountID: 99, sessionGeneration: 8)
        XCTAssertNil(store.loadTodo())
        XCTAssertFalse(store.saveTodo(snapshot, sessionGeneration: 8))
    }

    func testTodoSnapshotStoreDoesNotReplaceNewerOnlineDataWithCachedData() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-widget-todo-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = DutyparkWidgetSnapshotStore(rootURL: root)
        store.activate(accountID: 42, sessionGeneration: 7)
        let newer = DutyparkWidgetTodoSnapshot(
            accountID: 42,
            todos: [DutyparkWidgetTodoItem(id: "new", title: "Online", status: .todo)],
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let older = DutyparkWidgetTodoSnapshot(
            accountID: 42,
            todos: [DutyparkWidgetTodoItem(id: "old", title: "Cached", status: .todo)],
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertTrue(store.saveTodo(newer, sessionGeneration: 7))
        XCTAssertFalse(store.saveTodoIfMissing(older, sessionGeneration: 7))
        XCTAssertFalse(store.saveTodo(older, sessionGeneration: 7))
        XCTAssertEqual(store.loadTodo(), newer)
    }

    func testSnapshotStoreRoundTripsAndRejectsAStaleSessionWriteAfterClear() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-widget-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = DutyparkWidgetSnapshotStore(rootURL: root)
        store.activate(accountID: 42, sessionGeneration: 7)

        let snapshot = DutyparkWidgetSnapshot(
            accountID: 42,
            year: 2026,
            month: 9,
            days: Array(repeating: DutyparkWidgetDay(
                date: "2026-09-01",
                weekday: 3,
                isCurrentMonth: true,
                abbreviation: "E",
                colorHex: "#35B779",
                isOff: false
            ), count: 42),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertTrue(store.save(snapshot, sessionGeneration: 7))
        XCTAssertEqual(store.load(year: 2026, month: 9), snapshot)

        store.clear(accountID: 42)

        XCTAssertFalse(store.save(snapshot, sessionGeneration: 7))
        XCTAssertNil(store.load(year: 2026, month: 9))
    }

    func testSnapshotStoreDoesNotExposeAnotherAccountAfterActivation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-widget-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = DutyparkWidgetSnapshotStore(rootURL: root)
        store.activate(accountID: 42, sessionGeneration: 1)
        XCTAssertTrue(store.save(makeSnapshot(accountID: 42), sessionGeneration: 1))

        store.activate(accountID: 99, sessionGeneration: 2)

        XCTAssertNil(store.load(year: 2026, month: 9))
        XCTAssertFalse(store.save(makeSnapshot(accountID: 42), sessionGeneration: 2))
        XCTAssertTrue(store.save(makeSnapshot(accountID: 99), sessionGeneration: 2))
        XCTAssertEqual(store.load(year: 2026, month: 9)?.accountID, 99)
    }

    func testSnapshotStoreKeepsNewerSnapshotWhenOlderCachePublishesLater() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-widget-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = DutyparkWidgetSnapshotStore(rootURL: root)
        store.activate(accountID: 42, sessionGeneration: 1)

        let newer = makeSnapshot(
            accountID: 42,
            updatedAt: Date(timeIntervalSince1970: 100.900)
        )
        let older = makeSnapshot(
            accountID: 42,
            updatedAt: Date(timeIntervalSince1970: 100.100)
        )

        XCTAssertTrue(store.save(newer, sessionGeneration: 1))
        XCTAssertFalse(store.save(older, sessionGeneration: 1))
        XCTAssertEqual(
            store.load(year: newer.year, month: newer.month)?.updatedAt,
            newer.updatedAt
        )
    }

    func testSnapshotStoreInvalidatesTheOldGenerationBeforeCleanup() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-widget-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = DutyparkWidgetSnapshotStore(rootURL: root)
        store.activate(accountID: 42, sessionGeneration: 1)
        let snapshot = makeSnapshot(accountID: 42)
        XCTAssertTrue(store.save(snapshot, sessionGeneration: 1))

        store.invalidateSession()

        XCTAssertFalse(store.isActive(accountID: 42, sessionGeneration: 1))
        XCTAssertFalse(store.save(snapshot, sessionGeneration: 1))
        XCTAssertEqual(store.load(year: 2026, month: 9), snapshot)
    }

    func testSnapshotStoreKeepsEachMonthAndSharesItWithANewReader() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-widget-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let writer = DutyparkWidgetSnapshotStore(rootURL: root)
        writer.activate(accountID: 42, sessionGeneration: 1)
        let september = makeSnapshot(accountID: 42, month: 9)
        let october = makeSnapshot(accountID: 42, month: 10)
        XCTAssertTrue(writer.save(september, sessionGeneration: 1))
        XCTAssertTrue(writer.save(october, sessionGeneration: 1))

        let reader = DutyparkWidgetSnapshotStore(rootURL: root)
        XCTAssertEqual(reader.load(year: 2026, month: 9), september)
        XCTAssertEqual(reader.load(year: 2026, month: 10), october)

        writer.clear(accountID: 42)

        XCTAssertNil(reader.load(year: 2026, month: 9))
        XCTAssertNil(reader.load(year: 2026, month: 10))
    }

    func testSnapshotBuilderKeepsResolvedDutyLabelColorAndOffState() throws {
        let calendar = CalendarDateSupport.calendar
        let firstDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 30)))
        let serverDays = try (0..<42).map { offset -> TeamDayDTO in
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: firstDate))
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return TeamDayDTO(
                year: try XCTUnwrap(parts.year),
                month: try XCTUnwrap(parts.month),
                day: try XCTUnwrap(parts.day)
            )
        }
        let duties = [
            DutyDTO(
                year: 2026,
                month: 9,
                day: 1,
                dutyType: "Evening",
                dutyColor: "#123456",
                isOff: false,
                dutyTypeId: 7,
                source: .pattern,
                dutyAbbreviation: "E"
            ),
            DutyDTO(
                year: 2026,
                month: 9,
                day: 2,
                dutyType: "off",
                dutyColor: "#EF4444",
                isOff: true,
                dutyTypeId: nil,
                source: .defaultOff,
                dutyAbbreviation: "off"
            ),
        ]

        let snapshot = try XCTUnwrap(
            DutyparkWidgetSnapshotBuilder.make(
                accountID: 42,
                key: OfflineMonthKey(year: 2026, month: 9),
                calendar: serverDays,
                duties: duties,
                updatedAt: Date(timeIntervalSince1970: 100)
            )
        )

        let evening = try XCTUnwrap(snapshot.days.first { $0.date == "2026-09-01" })
        XCTAssertEqual(evening.weekday, 3)
        XCTAssertTrue(evening.isCurrentMonth)
        XCTAssertEqual(evening.abbreviation, "E")
        XCTAssertEqual(evening.colorHex, "#123456")
        XCTAssertFalse(evening.isOff)

        let off = try XCTUnwrap(snapshot.days.first { $0.date == "2026-09-02" })
        XCTAssertEqual(off.abbreviation, "off")
        XCTAssertEqual(off.colorHex, "#EF4444")
        XCTAssertTrue(off.isOff)
        XCTAssertTrue(snapshot.isCurrentSchema)
    }

    func testPublishCachedMonthsMigratesOfflineCacheIntoTheWidgetStore() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-widget-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = DutyparkWidgetSnapshotStore(rootURL: root)
        store.activate(accountID: 42, sessionGeneration: 7)
        let key = OfflineMonthKey(year: 2026, month: 9)
        let cached = makeOfflineMonthSnapshot(
            accountID: 42,
            key: key,
            storedAt: Date(timeIntervalSince1970: 100)
        )
        let cache = DutyparkWidgetCacheStub(snapshots: [cached])

        await DutyparkWidgetRefreshService.publishCachedMonths(
            accountID: 42,
            sessionGeneration: 7,
            around: key,
            cache: cache,
            store: store
        )

        XCTAssertEqual(
            store.load(year: key.year, month: key.month),
            DutyparkWidgetSnapshotBuilder.make(cached)
        )
    }

    func testPublishCachedMonthsDoesNotReplaceAnExistingWidgetSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-widget-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = DutyparkWidgetSnapshotStore(rootURL: root)
        store.activate(accountID: 42, sessionGeneration: 7)
        let key = OfflineMonthKey(year: 2026, month: 9)
        let cached = makeOfflineMonthSnapshot(
            accountID: 42,
            key: key,
            storedAt: Date(timeIntervalSince1970: 900)
        )
        let existing = DutyparkWidgetSnapshot(
            accountID: 42,
            year: key.year,
            month: key.month,
            days: Array(repeating: DutyparkWidgetDay(
                date: "2026-09-01",
                weekday: 3,
                isCurrentMonth: true,
                abbreviation: "N",
                colorHex: "#654321",
                isOff: false
            ), count: 42),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        XCTAssertTrue(store.save(existing, sessionGeneration: 7))

        await DutyparkWidgetRefreshService.publishCachedMonths(
            accountID: 42,
            sessionGeneration: 7,
            around: key,
            cache: DutyparkWidgetCacheStub(snapshots: [cached]),
            store: store
        )

        XCTAssertEqual(store.load(year: key.year, month: key.month), existing)
    }

    func testRefreshCurrentMonthPublishesSchedulesAndTodos() async throws {
        let now = try XCTUnwrap(
            CalendarDateSupport.date(from: DateOnly(rawValue: "2026-09-15"))
        )
        let key = OfflineMonthKey(year: 2026, month: 9)
        var schedules = Array(repeating: [ScheduleDTO](), count: 42)
        schedules[2] = [makeSchedule(content: "원문 일정 여섯자")]
        let todo = makeTodo(id: "todo-widget", title: "Widget task", status: .todo)
        let board = TodoBoardDTO(
            todo: [todo],
            inProgress: [],
            done: [makeTodo(id: "done-widget", title: "Done task", status: .done)],
            counts: TodoCountsDTO(todo: 1, inProgress: 0, done: 1, total: 2)
        )
        let cachedBoard = TodoBoardDTO(
            todo: [makeTodo(id: "cached-widget", title: "Cached task", status: .todo)],
            inProgress: [],
            done: [],
            counts: TodoCountsDTO(todo: 1, inProgress: 0, done: 0, total: 1)
        )
        let store = DutyparkWidgetSnapshotStore(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("dutypark-widget-\(UUID().uuidString)", isDirectory: true)
        )
        defer { store.clear() }
        store.activate(accountID: 42, sessionGeneration: 7)
        let refreshStartedAt = Date.now

        await DutyparkWidgetRefreshService.refreshCurrentMonth(
            accountID: 42,
            sessionGeneration: 7,
            now: now,
            repository: DutyparkWidgetRepositoryStub(
                schedules: schedules,
                todoBoard: board
            ),
            // The cache publish intentionally has no reliable board timestamp;
            // the authenticated result must still replace it below.
            cache: DutyparkWidgetCacheStub(snapshots: [], todoBoard: cachedBoard),
            store: store
        )

        let monthly = try XCTUnwrap(store.load(year: key.year, month: key.month))
        XCTAssertEqual(monthly.days[2].scheduleContent, "원문 일정 여섯자")
        XCTAssertEqual(monthly.days[2].scheduleCount, 1)
        XCTAssertEqual(store.loadTodo()?.todos.map(\.id), [todo.id])
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(store.loadTodo()).updatedAt, refreshStartedAt)
    }

    func testRefreshCurrentMonthStillPublishesDutiesWhenSchedulesFail() async throws {
        let now = try XCTUnwrap(
            CalendarDateSupport.date(from: DateOnly(rawValue: "2026-09-15"))
        )
        let key = OfflineMonthKey(year: 2026, month: 9)
        var cachedSchedules = Array(repeating: [ScheduleDTO](), count: 42)
        cachedSchedules[2] = [makeSchedule(content: "Cached schedule")]
        let cached = makeOfflineMonthSnapshot(
            accountID: 42,
            key: key,
            schedules: cachedSchedules,
            storedAt: Date(timeIntervalSince1970: 100)
        )
        let store = DutyparkWidgetSnapshotStore(
            rootURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("dutypark-widget-\(UUID().uuidString)", isDirectory: true)
        )
        defer { store.clear() }
        store.activate(accountID: 42, sessionGeneration: 7)

        await DutyparkWidgetRefreshService.refreshCurrentMonth(
            accountID: 42,
            sessionGeneration: 7,
            now: now,
            repository: DutyparkWidgetRepositoryStub(
                schedulesError: .transport,
                todoBoardError: .transport
            ),
            cache: DutyparkWidgetCacheStub(snapshots: [cached]),
            store: store
        )

        let monthly = try XCTUnwrap(store.load(year: key.year, month: key.month))
        XCTAssertEqual(monthly.days[2].scheduleContent, "Cached schedule")
        XCTAssertEqual(monthly.days[2].scheduleCount, 1)
        XCTAssertEqual(monthly.accountID, 42)
    }

    func testRefreshCurrentMonthDoesNotStartAnApiRequestAfterAccountSwitchDuringCacheLoad() async {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-widget-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = DutyparkWidgetSnapshotStore(rootURL: root)
        store.activate(accountID: 42, sessionGeneration: 1)
        let cache = DutyparkWidgetCacheStub(
            snapshots: [],
            onLoad: {
                store.activate(accountID: 99, sessionGeneration: 2)
            }
        )
        let repository = DutyparkWidgetRepositoryStub()

        await DutyparkWidgetRefreshService.refreshCurrentMonth(
            accountID: 42,
            sessionGeneration: 1,
            now: Date(timeIntervalSince1970: 100),
            repository: repository,
            cache: cache,
            store: store
        )

        let counts = await repository.requestCounts()
        XCTAssertEqual(counts.calendar, 0)
        XCTAssertEqual(counts.duties, 0)
    }

    private func makeSnapshot(
        accountID: Int64,
        month: Int = 9,
        updatedAt: Date = Date(timeIntervalSince1970: 200)
    ) -> DutyparkWidgetSnapshot {
        DutyparkWidgetSnapshot(
            accountID: accountID,
            year: 2026,
            month: month,
            days: Array(repeating: DutyparkWidgetDay(
                date: String(format: "2026-%02d-01", month),
                weekday: 3,
                isCurrentMonth: true,
                abbreviation: nil,
                colorHex: nil,
                isOff: true
            ), count: 42),
            updatedAt: updatedAt
        )
    }

    private func makeOfflineMonthSnapshot(
        accountID: Int64,
        key: OfflineMonthKey,
        schedules: [[ScheduleDTO]] = Array(repeating: [], count: 42),
        storedAt: Date
    ) -> OfflineMonthSnapshot {
        OfflineMonthSnapshot(
            accountID: accountID,
            key: key,
            calendar: DutyparkWidgetRepositoryStub.gridDays(year: key.year, month: key.month),
            schedules: schedules,
            duties: [DutyDTO(
                year: key.year,
                month: key.month,
                day: 1,
                dutyType: "Evening",
                dutyColor: "#123456",
                isOff: false,
                dutyTypeId: 7,
                source: .pattern,
                dutyAbbreviation: "E"
            )],
            holidays: Array(repeating: [], count: 42),
            otherDuties: [],
            comparedMemberIDs: [],
            storedAt: storedAt
        )
    }

    private func makeSchedule(content: String) -> ScheduleDTO {
        ScheduleDTO(
            id: UUID(),
            content: content,
            description: "",
            position: 0,
            year: 2026,
            month: 9,
            dayOfMonth: 1,
            startDateTime: LocalDateTimeValue(rawValue: "2026-09-01T09:00:00"),
            endDateTime: LocalDateTimeValue(rawValue: "2026-09-01T10:00:00"),
            isTagged: false,
            owner: "Me",
            taggedByMember: nil,
            tags: [],
            visibility: .privateAccess,
            dateToCompare: DateOnly(rawValue: "2026-09-01"),
            attachments: [],
            startDate: DateOnly(rawValue: "2026-09-01"),
            daysFromStart: 0,
            endDate: DateOnly(rawValue: "2026-09-01"),
            curDate: DateOnly(rawValue: "2026-09-01"),
            totalDays: 1
        )
    }

    private func makeTodo(
        id: String,
        title: String,
        status: TodoStatus
    ) -> TodoDTO {
        TodoDTO(
            id: id,
            title: title,
            content: "Details",
            position: 0,
            status: status,
            createdDate: LocalDateTimeValue(rawValue: "2026-09-01T09:00:00"),
            completedDate: nil,
            dueDate: nil,
            isOverdue: false,
            isTagged: false,
            owner: "Me",
            taggedByMember: nil,
            tags: [],
            hasAttachments: false
        )
    }
}

private actor DutyparkWidgetCacheStub: OfflineCacheProviding {
    private let snapshots: [OfflineMonthSnapshot]
    private let todoBoard: TodoBoardDTO?
    private let onLoad: (@Sendable () -> Void)?

    init(
        snapshots: [OfflineMonthSnapshot],
        todoBoard: TodoBoardDTO? = nil,
        onLoad: (@Sendable () -> Void)? = nil
    ) {
        self.snapshots = snapshots
        self.todoBoard = todoBoard
        self.onLoad = onLoad
    }

    func saveAccount(_ snapshot: OfflineAccountSnapshot) async throws {}

    func saveAccount(
        member: LoginMember,
        friends: [FriendDTO],
        dDays: [DDayDTO],
        now: Date
    ) async throws {}

    func loadAccount(memberID: MemberID) async -> OfflineAccountSnapshot? { nil }
    func saveMonth(_ snapshot: OfflineMonthSnapshot) async throws {}
    func loadMonth(accountID: MemberID, key: OfflineMonthKey) async -> OfflineMonthSnapshot? {
        snapshots.first { $0.accountID == accountID && $0.key == key }
    }

    func loadCachedMonths(
        accountID: MemberID,
        around current: OfflineMonthKey
    ) async -> [OfflineMonthSnapshot] {
        onLoad?()
        return snapshots.filter { $0.accountID == accountID }
    }

    func saveTodoBoard(accountID: MemberID, board: TodoBoardDTO, now: Date) async throws {}
    func loadTodoBoard(accountID: MemberID) async -> TodoBoardDTO? { todoBoard }

    func searchSchedules(
        accountID: MemberID,
        query: String,
        keys: [OfflineMonthKey]?
    ) async -> [ScheduleSearchResultDTO] { [] }

    func purge(accountID: MemberID) async throws {}
}

private actor DutyparkWidgetRepositoryStub: CalendarRepositoryProtocol {
    private static let emptyTodoBoard = TodoBoardDTO(
        todo: [],
        inProgress: [],
        done: [],
        counts: TodoCountsDTO(todo: 0, inProgress: 0, done: 0, total: 0)
    )

    private let schedulePayload: [[ScheduleDTO]]
    private let schedulesError: APIError?
    private let todoBoardPayload: TodoBoardDTO
    private let todoBoardError: APIError?
    private var calendarRequestCount = 0
    private var dutiesRequestCount = 0

    init(
        schedules: [[ScheduleDTO]] = Array(repeating: [], count: 42),
        schedulesError: APIError? = nil,
        todoBoard: TodoBoardDTO? = nil,
        todoBoardError: APIError? = nil
    ) {
        self.schedulePayload = schedules
        self.schedulesError = schedulesError
        self.todoBoardPayload = todoBoard ?? Self.emptyTodoBoard
        self.todoBoardError = todoBoardError
    }

    func requestCounts() -> (calendar: Int, duties: Int) {
        (calendarRequestCount, dutiesRequestCount)
    }

    func member() async throws -> MemberDTO { fatalError("Not used") }
    func member(id: MemberID) async throws -> MemberPreviewDTO { fatalError("Not used") }
    func friends() async throws -> [FriendDTO] { fatalError("Not used") }
    func team(id: TeamID) async throws -> TeamDTO { fatalError("Not used") }
    func canManage(memberID: MemberID) async throws -> Bool { fatalError("Not used") }

    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO] {
        calendarRequestCount += 1
        return Self.gridDays(year: year, month: month)
    }

    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO] {
        dutiesRequestCount += 1
        return []
    }

    func otherDuties(memberIDs: [MemberID], year: Int, month: Int) async throws -> [OtherDutyResponse] { fatalError("Not used") }
    func schedules(memberID: MemberID, year: Int, month: Int) async throws -> [[ScheduleDTO]] {
        if let schedulesError { throw schedulesError }
        return schedulePayload
    }
    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]] { fatalError("Not used") }
    func dDays(memberID: MemberID, isMine: Bool) async throws -> [DDayDTO] { fatalError("Not used") }
    func todoBoard() async throws -> TodoBoardDTO {
        if let todoBoardError { throw todoBoardError }
        return todoBoardPayload
    }
    func saveSchedule(_ request: ScheduleSaveDTO) async throws -> ScheduleSaveResponse { fatalError("Not used") }
    func deleteSchedule(id: ScheduleID) async throws { fatalError("Not used") }
    func untagSelf(scheduleID: ScheduleID) async throws { fatalError("Not used") }
    func searchSchedules(memberID: MemberID, query: String, page: Int) async throws -> PageResponse<ScheduleSearchResultDTO> { fatalError("Not used") }
    func scheduleBasic(id: ScheduleID) async throws -> ScheduleBasicInfoDTO { fatalError("Not used") }
    func updateDuty(_ request: DutyUpdateDTO) async throws { fatalError("Not used") }
    func uploadDutyBatch(memberID: MemberID, year: Int, month: Int, filename: String, data: Data) async throws -> DutyBatchUploadResult { fatalError("Not used") }
    func saveDDay(_ request: DDaySaveDTO) async throws -> DDayDTO { fatalError("Not used") }
    func deleteDDay(id: Int64) async throws { fatalError("Not used") }

    static func gridDays(year: Int, month: Int) -> [TeamDayDTO] {
        let calendar = CalendarDateSupport.calendar
        let first = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let offset = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -offset, to: first)!
        return (0..<42).map { index in
            let date = calendar.date(byAdding: .day, value: index, to: start)!
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            return TeamDayDTO(year: parts.year!, month: parts.month!, day: parts.day!)
        }
    }
}
