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
        updatedAt: Date = .now
    ) -> DutyparkWidgetSnapshot? {
        guard accountID > 0, calendar.count == 42 else { return nil }

        let appCalendar = CalendarDateSupport.calendar
        let days = calendar.compactMap { value -> DutyparkWidgetDay? in
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
            return DutyparkWidgetDay(
                date: dateString,
                weekday: appCalendar.component(.weekday, from: date),
                isCurrentMonth: value.year == key.year && value.month == key.month,
                abbreviation: abbreviation,
                colorHex: duty?.dutyColor,
                isOff: duty?.isOff ?? false
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
            updatedAt: updatedAt ?? snapshot.storedAt
        )
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
        reloadTimelines()
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
        reloadTimelines()
        return true
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

        async let calendarResult = repository.calendar(year: current.year, month: current.month)
        async let dutiesResult = repository.duties(
            memberID: accountID,
            year: current.year,
            month: current.month
        )
        do {
            let calendar = try await calendarResult
            let duties = try await dutiesResult
            guard let snapshot = DutyparkWidgetSnapshotBuilder.make(
                accountID: accountID,
                key: current,
                calendar: calendar,
                duties: duties,
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
        var didSave = false
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
            didSave = store.saveIfMissing(
                widgetSnapshot,
                sessionGeneration: sessionGeneration
            ) || didSave
        }
        if didSave {
            reloadTimelines()
        }
    }

    @inline(__always)
    private static func reloadTimelines() {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: DutyparkWidgetKind.monthly)
#endif
    }
}
