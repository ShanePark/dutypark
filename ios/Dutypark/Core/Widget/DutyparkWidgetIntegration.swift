import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

/// Converts the app's calendar response into the Foundation-only widget contract.
nonisolated enum DutyparkWidgetSnapshotBuilder {
    static func make(
        accountID: MemberID,
        key: OfflineMonthKey,
        calendar: [TeamDayDTO],
        duties: [DutyDTO],
        schedules: [[ScheduleDTO]]? = nil,
        fallbackScheduleDays: [DutyparkWidgetDay]? = nil,
        updatedAt: Date = .now
    ) -> DutyparkWidgetSnapshot? {
        guard accountID > 0, calendar.count == 42 else { return nil }

        let appCalendar = CalendarDateSupport.calendar
        let days = calendar.enumerated().compactMap { index, value -> DutyparkWidgetDay? in
            guard let date = appCalendar.date(from: DateComponents(
                year: value.year,
                month: value.month,
                day: value.day
            )) else {
                return nil
            }
            let dateString = String(format: "%04d-%02d-%02d", value.year, value.month, value.day)
            let duty = duties.first {
                $0.year == value.year && $0.month == value.month && $0.day == value.day
            }
            let abbreviation = duty?.shortName.isEmpty == false ? duty?.shortName : nil
            let daySchedules = Self.value(schedules, at: index)
            let fallbackScheduleDay = Self.value(fallbackScheduleDays, at: index)
            return DutyparkWidgetDay(
                date: dateString,
                weekday: appCalendar.component(.weekday, from: date),
                isCurrentMonth: value.year == key.year && value.month == key.month,
                abbreviation: abbreviation,
                colorHex: duty?.dutyColor,
                isOff: duty?.isOff ?? false,
                scheduleContent: daySchedules?.first?.content ?? fallbackScheduleDay?.scheduleContent,
                scheduleCount: daySchedules?.count ?? fallbackScheduleDay?.scheduleCount ?? 0
            )
        }
        guard days.count == 42 else { return nil }
        return DutyparkWidgetSnapshot(
            accountID: accountID,
            year: key.year,
            month: key.month,
            days: days,
            updatedAt: updatedAt
        )
    }

    static func make(
        _ snapshot: OfflineMonthSnapshot,
        updatedAt: Date? = nil
    ) -> DutyparkWidgetSnapshot? {
        make(
            accountID: snapshot.accountID,
            key: snapshot.key,
            calendar: snapshot.calendar,
            duties: snapshot.duties,
            schedules: snapshot.schedules,
            updatedAt: updatedAt ?? snapshot.storedAt
        )
    }

    private static func todoItem(
        _ todo: TodoDTO,
        status: DutyparkWidgetTodoStatus
    ) -> DutyparkWidgetTodoItem? {
        let matchesStatus = switch status {
        case .todo: todo.status == .todo
        case .inProgress: todo.status == .inProgress
        }
        guard matchesStatus, !todo.id.isEmpty, !todo.title.isEmpty else { return nil }
        return DutyparkWidgetTodoItem(id: todo.id, title: todo.title, status: status)
    }

    static func make(
        accountID: MemberID,
        board: TodoBoardDTO,
        updatedAt: Date = .now
    ) -> DutyparkWidgetTodoSnapshot? {
        guard accountID > 0 else { return nil }
        let todos = board.todo.compactMap {
            todoItem($0, status: .todo)
        } + board.inProgress.compactMap {
            todoItem($0, status: .inProgress)
        }
        return DutyparkWidgetTodoSnapshot(
            accountID: accountID,
            todos: todos,
            updatedAt: updatedAt
        )
    }

    static func make(
        accountID: MemberID,
        todoBoard: TodoBoardDTO,
        updatedAt: Date = .now
    ) -> DutyparkWidgetTodoSnapshot? {
        make(accountID: accountID, board: todoBoard, updatedAt: updatedAt)
    }

    private static func value<Element>(_ array: [Element]?, at index: Int) -> Element? {
        guard let array, array.indices.contains(index) else { return nil }
        return array[index]
    }
}

/// Publishes cached months on app launch and refreshes the current month with the
/// authenticated API. This keeps the widget useful before the user opens Calendar.
@MainActor
enum DutyparkWidgetRefreshService {
    static func invalidate(
        store: DutyparkWidgetSnapshotStore = .shared
    ) {
        store.invalidateSession()
        reloadTimelines()
    }

    static func activate(
        accountID: MemberID,
        sessionGeneration: UInt64,
        store: DutyparkWidgetSnapshotStore = .shared
    ) {
        store.activate(
            accountID: accountID,
            sessionGeneration: sessionGeneration
        )
        reloadTimelines()
    }

    static func clear(
        accountID: MemberID? = nil,
        store: DutyparkWidgetSnapshotStore = .shared
    ) {
        store.clear(accountID: accountID)
        reloadTimelines()
    }

    @discardableResult
    static func publish(
        _ snapshot: DutyparkWidgetSnapshot,
        sessionGeneration: UInt64,
        store: DutyparkWidgetSnapshotStore = .shared
    ) -> Bool {
        guard store.save(snapshot, sessionGeneration: sessionGeneration) else {
            return false
        }
        reloadMonthlyTimeline()
        return true
    }

    @discardableResult
    static func publishIfMissing(
        _ snapshot: DutyparkWidgetSnapshot,
        sessionGeneration: UInt64,
        store: DutyparkWidgetSnapshotStore = .shared
    ) -> Bool {
        guard store.saveIfMissing(
            snapshot,
            sessionGeneration: sessionGeneration
        ) else {
            return false
        }
        reloadMonthlyTimeline()
        return true
    }

    @discardableResult
    static func publishTodo(
        _ snapshot: DutyparkWidgetTodoSnapshot,
        sessionGeneration: UInt64,
        store: DutyparkWidgetSnapshotStore = .shared
    ) -> Bool {
        guard store.saveTodo(snapshot, sessionGeneration: sessionGeneration) else {
            return false
        }
        reloadTodoTimeline()
        return true
    }

    @discardableResult
    static func publishTodoBoard(
        accountID: MemberID,
        board: TodoBoardDTO,
        updatedAt: Date = .now,
        sessionGeneration: UInt64,
        store: DutyparkWidgetSnapshotStore = .shared
    ) -> Bool {
        guard let snapshot = DutyparkWidgetSnapshotBuilder.make(
            accountID: accountID,
            board: board,
            updatedAt: updatedAt
        ) else { return false }
        return publishTodo(
            snapshot,
            sessionGeneration: sessionGeneration,
            store: store
        )
    }

    static func refreshCurrentMonth(
        accountID: MemberID,
        sessionGeneration: UInt64,
        now: Date = .now,
        repository: CalendarRepositoryProtocol = CalendarRepository(),
        cache: any OfflineCacheProviding = OfflineCacheStore.shared,
        store: DutyparkWidgetSnapshotStore = .shared
    ) async {
        let current = OfflineMonthKey(date: now)
        let requestStartedAt = now
        await publishCachedMonths(
            accountID: accountID,
            sessionGeneration: sessionGeneration,
            around: current,
            cache: cache,
            store: store
        )

        guard !Task.isCancelled,
              store.isActive(
                  accountID: accountID,
                  sessionGeneration: sessionGeneration
              )
        else { return }

        let cachedMonth = await cache.loadMonth(
            accountID: accountID,
            key: current
        )
        guard !Task.isCancelled,
              store.isActive(
                  accountID: accountID,
                  sessionGeneration: sessionGeneration
              )
        else { return }

        async let calendarResult = repository.calendar(year: current.year, month: current.month)
        async let dutiesResult = repository.duties(
            memberID: accountID,
            year: current.year,
            month: current.month
        )
        async let schedulesResult = repository.schedules(
            memberID: accountID,
            year: current.year,
            month: current.month
        )
        async let todoBoardResult: TodoBoardDTO? = try? await repository.todoBoard()
        // Todo is an independent widget surface. Publish a successful board
        // even when the monthly calendar/duty request below fails.
        let todoBoard = await todoBoardResult
        if let todoBoard,
           store.isActive(
               accountID: accountID,
               sessionGeneration: sessionGeneration
           ),
           let todoSnapshot = DutyparkWidgetSnapshotBuilder.make(
               accountID: accountID,
               board: todoBoard,
               updatedAt: requestStartedAt
           ) {
            _ = publishTodo(
                todoSnapshot,
                sessionGeneration: sessionGeneration,
                store: store
            )
        }
        do {
            let calendar = try await calendarResult
            let duties = try await dutiesResult
            let existingSnapshot = store.load(year: current.year, month: current.month)
            let scheduleData: (schedules: [[ScheduleDTO]]?, fallbackDays: [DutyparkWidgetDay]?)
            do {
                let loadedSchedules = try await schedulesResult
                if loadedSchedules.count == calendar.count {
                    scheduleData = (loadedSchedules, nil)
                } else {
                    scheduleData = fallbackScheduleData(
                        cachedMonth: cachedMonth,
                        existingSnapshot: existingSnapshot
                    )
                }
            } catch {
                // A schedule outage must not discard a successful calendar and
                // duty response. Prefer the freshest known schedules; when none
                // exist, the builder safely produces an empty schedule display.
                scheduleData = fallbackScheduleData(
                    cachedMonth: cachedMonth,
                    existingSnapshot: existingSnapshot
                )
            }
            guard store.isActive(
                accountID: accountID,
                sessionGeneration: sessionGeneration
            ) else { return }
            guard let snapshot = DutyparkWidgetSnapshotBuilder.make(
                accountID: accountID,
                key: current,
                calendar: calendar,
                duties: duties,
                schedules: scheduleData.schedules,
                fallbackScheduleDays: scheduleData.fallbackDays,
                updatedAt: now
            ) else { return }
            _ = publish(
                snapshot,
                sessionGeneration: sessionGeneration,
                store: store
            )
        } catch is CancellationError {
            return
        } catch {
            // The last successful App Group snapshot remains available when an
            // app-open refresh cannot reach the server.
        }
    }

    static func publishCachedMonths(
        accountID: MemberID,
        sessionGeneration: UInt64,
        around current: OfflineMonthKey,
        cache: any OfflineCacheProviding = OfflineCacheStore.shared,
        store: DutyparkWidgetSnapshotStore = .shared
    ) async {
        let snapshots = await cache.loadCachedMonths(accountID: accountID, around: current)
        var didSaveMonthly = false
        for snapshot in snapshots {
            guard !Task.isCancelled,
                  store.isActive(
                      accountID: accountID,
                      sessionGeneration: sessionGeneration
                  )
            else { return }
            guard snapshot.accountID == accountID,
                  let widgetSnapshot = DutyparkWidgetSnapshotBuilder.make(snapshot)
            else { continue }
            didSaveMonthly = store.saveIfMissing(
                widgetSnapshot,
                sessionGeneration: sessionGeneration
            ) || didSaveMonthly
        }
        guard !Task.isCancelled,
              store.isActive(
                  accountID: accountID,
                  sessionGeneration: sessionGeneration
              )
        else { return }
        var didSaveTodo = false
        if let board = await cache.loadTodoBoard(accountID: accountID) {
            guard !Task.isCancelled,
                  store.isActive(
                      accountID: accountID,
                      sessionGeneration: sessionGeneration
                  )
            else { return }
            if let todoSnapshot = DutyparkWidgetSnapshotBuilder.make(
                accountID: accountID,
                board: board,
                updatedAt: .distantPast
            ) {
            didSaveTodo = store.saveTodoIfMissing(
                todoSnapshot,
                sessionGeneration: sessionGeneration
            ) || didSaveTodo
            }
        }
        if didSaveMonthly {
            reloadMonthlyTimeline()
        }
        if didSaveTodo {
            reloadTodoTimeline()
        }
    }

    private static func fallbackScheduleData(
        cachedMonth: OfflineMonthSnapshot?,
        existingSnapshot: DutyparkWidgetSnapshot?
    ) -> (schedules: [[ScheduleDTO]]?, fallbackDays: [DutyparkWidgetDay]?) {
        if let cachedMonth,
           cachedMonth.schedules.count == 42,
           existingSnapshot == nil || cachedMonth.storedAt >= (existingSnapshot?.updatedAt ?? .distantPast) {
            return (cachedMonth.schedules, nil)
        }
        if let existingSnapshot {
            return (nil, existingSnapshot.days)
        }
        let schedules = cachedMonth.flatMap { snapshot in
            snapshot.schedules.count == 42 ? snapshot.schedules : nil
        }
        return (schedules, nil)
    }

    @inline(__always)
    private static func reloadTimelines() {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: DutyparkWidgetKind.monthly)
        WidgetCenter.shared.reloadTimelines(ofKind: DutyparkWidgetKind.todo)
#endif
    }

    @inline(__always)
    private static func reloadMonthlyTimeline() {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: DutyparkWidgetKind.monthly)
#endif
    }

    @inline(__always)
    private static func reloadTodoTimeline() {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: DutyparkWidgetKind.todo)
#endif
    }
}
