import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class CalendarOfflineTests: XCTestCase {
    func testVisibleCalendarObservesNetworkRecoveryWithoutMonthNavigation() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Dutypark/Features/Calendar/CalendarView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("@StateObject private var offlineNetworkMonitor"))
        XCTAssertTrue(source.contains(".onChange(of: offlineNetworkMonitor.status)"))
        XCTAssertTrue(source.contains("await model.handleNetworkBecameReachable()"))
    }

    func testNetworkRecoveryRefreshesCachedMonthWithoutNavigation() async throws {
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            month: Self.monthSnapshot(storedAt: Date(timeIntervalSince1970: 123))
        )
        let repository = CalendarOfflineRepository(monthFailures: [.transport])
        let haptics = DPHapticCenter()
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            memberID: 42,
            accountID: 42,
            hapticCenter: haptics,
            cache: cache,
            outbox: CalendarOfflineOutboxStub(),
            serverRecoverySleeper: { _ in
                try await Task.sleep(for: .seconds(60))
            }
        )

        await model.load()
        XCTAssertTrue(model.isOfflineMode)
        XCTAssertTrue(model.isShowingCachedData)

        await model.handleNetworkBecameReachable()

        XCTAssertFalse(model.isOfflineMode)
        XCTAssertFalse(model.isShowingCachedData)
        XCTAssertNil(model.cacheStoredAt)
        let monthRequestCount = await repository.monthRequestCount
        XCTAssertGreaterThanOrEqual(monthRequestCount, 2)
        XCTAssertNil(haptics.event, "Automatic network recovery must remain haptic-free")
    }

    func testTransportUsesSameAccountMonthCacheAndExposesSnapshotDate() async throws {
        let storedAt = Date(timeIntervalSince1970: 123)
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            month: Self.monthSnapshot(storedAt: storedAt)
        )
        let repository = CalendarOfflineRepository(monthFailure: .transport)
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            accountID: 42,
            cache: cache
        )

        await model.load()

        XCTAssertTrue(model.isShowingCachedData)
        XCTAssertEqual(model.cacheStoredAt, storedAt)
        XCTAssertEqual(
            model.days.first(where: { $0.cell.date.rawValue == "2026-08-12" })?.schedules.first?.content,
            "Cached appointment"
        )
        XCTAssertNil(model.errorMessage, "A complete same-account snapshot is a usable result")
    }

    func testCachedComparisonDutiesAreNotAppliedToADifferentSelection() async throws {
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            month: Self.monthSnapshot(
                storedAt: Date(timeIntervalSince1970: 123),
                comparedMemberIDs: [2],
                otherDuties: [Self.otherDuty(memberID: 2, name: "Friend A")]
            )
        )
        let model = CalendarViewModel(
            repository: CalendarOfflineRepository(),
            now: Self.date(2026, 8, 12),
            accountID: 42,
            isOffline: true,
            cache: cache
        )
        model.comparedMemberIDs = [3]

        await model.load()

        XCTAssertTrue(
            model.days.flatMap(\.comparedDuties).isEmpty,
            "A snapshot captured for another friend must not leak that friend's duties"
        )
    }

    func testCachedComparisonDutiesAreAppliedWhenTheSelectionMatches() async throws {
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            month: Self.monthSnapshot(
                storedAt: Date(timeIntervalSince1970: 123),
                comparedMemberIDs: [2],
                otherDuties: [Self.otherDuty(memberID: 2, name: "Friend A")]
            )
        )
        let model = CalendarViewModel(
            repository: CalendarOfflineRepository(),
            now: Self.date(2026, 8, 12),
            accountID: 42,
            isOffline: true,
            cache: cache
        )
        model.comparedMemberIDs = [2]

        await model.load()

        XCTAssertEqual(
            model.days.first(where: { $0.cell.date.rawValue == "2026-08-12" })?.comparedDuties.map(\.memberID),
            [2]
        )
    }

    func testLegacyCachedComparisonDutiesAreIgnoredWithoutDiscardingTheMonth() async throws {
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            month: Self.monthSnapshot(
                storedAt: Date(timeIntervalSince1970: 123),
                comparedMemberIDs: nil,
                otherDuties: [Self.otherDuty(memberID: 2, name: "Friend A")]
            )
        )
        let model = CalendarViewModel(
            repository: CalendarOfflineRepository(),
            now: Self.date(2026, 8, 12),
            accountID: 42,
            isOffline: true,
            cache: cache
        )
        model.comparedMemberIDs = [2]

        await model.load()

        XCTAssertEqual(
            model.days.first(where: { $0.cell.date.rawValue == "2026-08-12" })?.schedules.first?.content,
            "Cached appointment"
        )
        XCTAssertTrue(model.days.flatMap(\.comparedDuties).isEmpty)
    }

    func testLegacyMonthSnapshotDecodesWithoutComparisonIdentity() throws {
        let legacy = Self.monthSnapshot(
            storedAt: Date(timeIntervalSince1970: 123),
            comparedMemberIDs: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(
            OfflineMonthSnapshot.self,
            from: encoder.encode(legacy)
        )

        XCTAssertNil(decoded.comparedMemberIDs)
        XCTAssertEqual(decoded.calendar.count, 42)
        XCTAssertEqual(decoded.schedules.count, 42)
    }

    func testServerRecoveryRetriesWithoutPathChangeAndClearsCachedState() async throws {
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            month: Self.monthSnapshot(storedAt: Date(timeIntervalSince1970: 123))
        )
        let repository = CalendarOfflineRepository(monthFailures: [.transport])
        let outbox = CalendarOfflineOutboxStub()
        let haptics = DPHapticCenter()
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            memberID: 42,
            hapticCenter: haptics,
            cache: cache,
            outbox: outbox,
            serverRecoverySleeper: { _ in await Task.yield() }
        )

        await model.load()
        for _ in 0..<50 {
            if !model.isOfflineMode { break }
            await Task.yield()
        }

        XCTAssertFalse(model.isOfflineMode)
        XCTAssertFalse(model.isShowingCachedData)
        XCTAssertNil(model.cacheStoredAt)
        let monthRequestCount = await repository.monthRequestCount
        XCTAssertGreaterThanOrEqual(monthRequestCount, 2)
        XCTAssertNil(haptics.event, "Automatic recovery must remain haptic-free")
    }

    func testServerRecoveryRequestsOutboxDrainAfterTheServerReturns() async throws {
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            month: Self.monthSnapshot(storedAt: Date(timeIntervalSince1970: 123))
        )
        let outbox = CalendarOfflineOutboxStub()
        let repository = CalendarOfflineRepository(monthFailures: [.transport])
        let syncRequests = CalendarSyncRequestRecorder()
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            accountID: 42,
            isOffline: true,
            cache: cache,
            outbox: outbox,
            serverRecoverySleeper: { _ in },
            requestOfflineSync: { accountID in
                await syncRequests.append(accountID)
            }
        )
        await model.load()
        let queued = await model.saveSchedule(
            existing: nil,
            content: "Pending appointment",
            description: "",
            visibility: .privateAccess,
            start: Self.date(2026, 8, 12, hour: 18),
            end: Self.date(2026, 8, 12, hour: 19),
            tagFriendIDs: [],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )
        XCTAssertTrue(queued)

        model.configure(accountID: 42, isOffline: false)
        try await model.loadMonth()
        for _ in 0..<50 {
            if !(await syncRequests.values).isEmpty { break }
            await Task.yield()
        }

        let requestedAccounts = await syncRequests.values
        XCTAssertEqual(requestedAccounts, [42])
        XCTAssertFalse(model.isOfflineMode)
    }

    func testServerRecoveryStopsWhenTheAuthenticatedAccountChanges() async throws {
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            month: Self.monthSnapshot(storedAt: Date(timeIntervalSince1970: 123))
        )
        let repository = CalendarOfflineRepository(monthFailures: [.transport])
        let sleeper = CalendarRecoverySleeperRecorder()
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            memberID: 42,
            cache: cache,
            outbox: CalendarOfflineOutboxStub(),
            serverRecoverySleeper: { _ in
                await sleeper.recordStart()
                try await Task.sleep(for: .seconds(60))
            }
        )

        await model.load()
        for _ in 0..<50 {
            if await sleeper.startCount > 0 { break }
            await Task.yield()
        }
        model.configure(accountID: 99, isOffline: true)
        for _ in 0..<10 { await Task.yield() }

        let monthRequestCount = await repository.monthRequestCount
        XCTAssertEqual(monthRequestCount, 1)
    }

    func testOfflineRestoreCannotOverwriteNewerOnlineAccountIdentity() async {
        let gate = CalendarOfflineIdentityRaceGate()
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            accountLoadGate: gate
        )
        let repository = CalendarOfflineRepository(
            member: Self.member(id: 99, name: "Online account")
        )
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            accountID: 42,
            isOffline: true,
            cache: cache
        )

        let offlineLoad = Task { await model.load() }
        await gate.waitForRequest()

        model.configure(accountID: 99, isOffline: false)
        let onlineLoad = Task { await model.load() }
        await onlineLoad.value

        XCTAssertEqual(model.me?.id, 99)
        XCTAssertEqual(model.me?.name, "Online account")
        XCTAssertFalse(model.isOfflineMode)

        await gate.release()
        await offlineLoad.value

        XCTAssertEqual(model.me?.id, 99)
        XCTAssertEqual(model.me?.name, "Online account")
        XCTAssertFalse(model.isOfflineMode)
    }

    func testOfflineRestoreDoesNotPartiallyApplyBeforeDelayedTodoBoardLoad() async {
        let gate = CalendarOfflineIdentityRaceGate()
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            todoBoardLoadGate: gate
        )
        let repository = CalendarOfflineRepository(
            member: Self.member(id: 99, name: "Online account")
        )
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            accountID: 42,
            isOffline: true,
            cache: cache
        )

        let offlineLoad = Task { await model.load() }
        await gate.waitForRequest()
        XCTAssertNil(model.me, "Cached identity must not be published before all cache reads finish")

        model.configure(accountID: 99, isOffline: false)
        let onlineLoad = Task { await model.load() }
        await onlineLoad.value

        await gate.release()
        await offlineLoad.value

        XCTAssertEqual(model.me?.id, 99)
        XCTAssertEqual(model.me?.name, "Online account")
        XCTAssertFalse(model.isOfflineMode)
    }

    func testOfflineCreateUsesOneStableOperationIDAndShowsPendingScheduleWithOneSuccessHaptic() async throws {
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            month: Self.monthSnapshot(storedAt: Date(timeIntervalSince1970: 123))
        )
        let outbox = CalendarOfflineOutboxStub()
        let haptics = DPHapticCenter()
        let model = CalendarViewModel(
            repository: CalendarOfflineRepository(),
            now: Self.date(2026, 8, 12),
            accountID: 42,
            isOffline: true,
            hapticCenter: haptics,
            cache: cache,
            outbox: outbox
        )
        await model.load()

        let saved = await model.saveSchedule(
            existing: nil,
            content: "Offline appointment",
            description: "Keep this until the connection returns",
            visibility: .privateAccess,
            start: Self.date(2026, 8, 12, hour: 18),
            end: Self.date(2026, 8, 12, hour: 19),
            tagFriendIDs: [],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )

        XCTAssertTrue(saved)
        let entries = await outbox.entries(accountID: 42)
        let entry = try XCTUnwrap(entries.first)
        guard case .scheduleCreate = entry.payload else {
            XCTFail("Expected a queued schedule create")
            return
        }
        XCTAssertEqual(
            model.days.first(where: { $0.cell.date.rawValue == "2026-08-12" })?.schedules.last?.id,
            entry.operationID
        )
        XCTAssertEqual(
            model.days.first(where: { $0.cell.date.rawValue == "2026-08-12" })?.schedules.last?.content,
            "Offline appointment"
        )
        XCTAssertEqual(haptics.event?.kind, .success, "Durable local save is a completed user action")
    }

    func testValidationFailureDoesNotEnterOutbox() async throws {
        let repository = CalendarOfflineRepository(saveFailure: .server(status: 400, code: "invalid"))
        let outbox = CalendarOfflineOutboxStub()
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            accountID: 42,
            cache: CalendarOfflineCacheStub(account: Self.accountSnapshot()),
            outbox: outbox
        )
        await model.load()

        let saved = await model.saveSchedule(
            existing: nil,
            content: "Rejected appointment",
            description: "",
            visibility: .privateAccess,
            start: Self.date(2026, 8, 12, hour: 18),
            end: Self.date(2026, 8, 12, hour: 19),
            tagFriendIDs: [],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )

        XCTAssertFalse(saved)
        let queuedEntries = await outbox.entries(accountID: 42)
        XCTAssertTrue(queuedEntries.isEmpty)
    }

    func testRecoverableCreateKeepsRequestAndOutboxOperationIDSeparate() async throws {
        let repository = CalendarOfflineRepository(saveFailure: .transport)
        let outbox = CalendarOfflineOutboxStub()
        let syncRequests = CalendarSyncRequestRecorder()
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            accountID: 42,
            cache: CalendarOfflineCacheStub(account: Self.accountSnapshot()),
            outbox: outbox,
            requestOfflineSync: { accountID in
                await syncRequests.append(accountID)
            }
        )
        await model.load()

        let saved = await model.saveSchedule(
            existing: nil,
            content: "Ambiguous appointment",
            description: "",
            visibility: .privateAccess,
            start: Self.date(2026, 8, 12, hour: 18),
            end: Self.date(2026, 8, 12, hour: 19),
            tagFriendIDs: [],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )
        XCTAssertTrue(saved)

        let requests = await repository.savedRequests
        let request = try XCTUnwrap(requests.first)
        let entries = await outbox.entries(accountID: 42)
        let entry = try XCTUnwrap(entries.first)
        guard case .scheduleCreate(let queuedRequest) = entry.payload else {
            XCTFail("Expected schedule create payload")
            return
        }
        XCTAssertEqual(queuedRequest, request)
        for _ in 0..<20 { await Task.yield() }
        let requestedAccounts = await syncRequests.values
        XCTAssertEqual(requestedAccounts, [42])
    }

    func testAmbiguousCreateResponseQueuesRequestWithOutboxOperationID() async throws {
        let repository = CalendarOfflineRepository(saveFailure: .invalidResponse)
        let outbox = CalendarOfflineOutboxStub()
        let syncRequests = CalendarSyncRequestRecorder()
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            accountID: 42,
            cache: CalendarOfflineCacheStub(account: Self.accountSnapshot()),
            outbox: outbox,
            requestOfflineSync: { accountID in
                await syncRequests.append(accountID)
            }
        )
        await model.load()

        let saved = await model.saveSchedule(
            existing: nil,
            content: "Ambiguous appointment",
            description: "",
            visibility: .privateAccess,
            start: Self.date(2026, 8, 12, hour: 18),
            end: Self.date(2026, 8, 12, hour: 19),
            tagFriendIDs: [],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )
        XCTAssertTrue(saved)

        let savedRequests = await repository.savedRequests
        let request = try XCTUnwrap(savedRequests.first)
        let entries = await outbox.entries(accountID: 42)
        let entry = try XCTUnwrap(entries.first)
        guard case .scheduleCreate(let queuedRequest) = entry.payload else {
            XCTFail("Expected schedule create payload")
            return
        }
        XCTAssertEqual(queuedRequest, request)
        for _ in 0..<20 { await Task.yield() }
        let requestedAccounts = await syncRequests.values
        XCTAssertEqual(requestedAccounts, [42])
    }

    func testEveryRecoverableCreateFailureUsesPreflightAndWakesSync() async throws {
        let failures: [(String, APIError)] = [
            ("transport", .transport),
            ("server-5xx", .server(status: 503, code: "temporarily-unavailable")),
            ("invalid-response", .invalidResponse),
            ("decoding", .decoding)
        ]

        for (label, failure) in failures {
            let repository = CalendarOfflineRepository(saveFailure: failure)
            let outbox = CalendarOfflineOutboxStub()
            let syncRequests = CalendarSyncRequestRecorder()
            let model = CalendarViewModel(
                repository: repository,
                now: Self.date(2026, 8, 12),
                accountID: 42,
                cache: CalendarOfflineCacheStub(account: Self.accountSnapshot()),
                outbox: outbox,
                requestOfflineSync: { accountID in
                    await syncRequests.append(accountID)
                }
            )
            await model.load()

            let saved = await model.saveSchedule(
                existing: nil,
                content: "Recoverable \(label) appointment",
                description: "",
                visibility: .privateAccess,
                start: Self.date(2026, 8, 12, hour: 18),
                end: Self.date(2026, 8, 12, hour: 19),
                tagFriendIDs: [],
                attachmentSessionID: nil,
                orderedAttachmentIDs: [],
                aiTimeParsingRequested: false
            )

            XCTAssertTrue(saved, label)
            let entries = await outbox.entries(accountID: 42)
            let entry = try XCTUnwrap(entries.first, label)

            for _ in 0..<20 { await Task.yield() }
            let requestedAccounts = await syncRequests.values
            XCTAssertEqual(requestedAccounts, [42], label)
        }
    }

    func testSuccessfulCreateStaysSuccessfulWhenRefreshSchedulesFails() async throws {
        let repository = CalendarOfflineRepository(
            scheduleFailures: [.transport],
            scheduleFailureAfter: 2
        )
        let haptics = DPHapticCenter()
        let outbox = CalendarOfflineOutboxStub()
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            memberID: 42,
            hapticCenter: haptics,
            cache: CalendarOfflineCacheStub(account: Self.accountSnapshot()),
            outbox: outbox,
            serverRecoverySleeper: { _ in
                try await Task.sleep(for: .seconds(60))
            },
            requestOfflineSync: { _ in }
        )
        await model.load()

        let saved = await model.saveSchedule(
            existing: nil,
            content: "Created before refresh outage",
            description: "",
            visibility: .privateAccess,
            start: Self.date(2026, 8, 12, hour: 18),
            end: Self.date(2026, 8, 12, hour: 19),
            tagFriendIDs: [],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )

        XCTAssertTrue(saved)
        XCTAssertTrue(model.isOfflineMode)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(haptics.event?.kind, .success)
        let queuedEntries = await outbox.entries(accountID: 42)
        XCTAssertTrue(queuedEntries.isEmpty)
        XCTAssertEqual(
            model.days.first(where: { $0.cell.date.rawValue == "2026-08-12" })?.schedules.last?.content,
            "Created before refresh outage"
        )
    }

    func testSearchFallbackSchedulesServerRecoveryWithoutPathChange() async throws {
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            month: Self.monthSnapshot(storedAt: Date(timeIntervalSince1970: 123)),
            searchResults: [
                ScheduleSearchResultDTO(
                    content: "Cached search result",
                    startDateTime: LocalDateTimeValue(rawValue: "2026-08-12T09:00:00"),
                    endDateTime: LocalDateTimeValue(rawValue: "2026-08-12T10:00:00"),
                    visibility: .privateAccess,
                    isTagged: false,
                    author: "Offline tester"
                )
            ]
        )
        let repository = CalendarOfflineRepository(searchFailure: .transport)
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            accountID: 42,
            cache: cache,
            serverRecoverySleeper: { _ in await Task.yield() }
        )

        await model.load()
        model.searchQuery = "cached"
        await model.search()

        XCTAssertEqual(model.searchResults.first?.content, "Cached search result")
        for _ in 0..<50 {
            if !model.isOfflineMode { break }
            await Task.yield()
        }
        XCTAssertFalse(model.isOfflineMode)
        XCTAssertFalse(model.isShowingCachedData)
    }

    func testPrefetchRangeIsThirteenMonthsAndSequentialCacheMissesCanBeFilled() async throws {
        let cache = CalendarOfflineCacheStub(account: Self.accountSnapshot())
        let repository = CalendarOfflineRepository()
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            accountID: 42,
            cache: cache
        )
        await model.prefetchCachedMonths(around: OfflineMonthKey(year: 2026, month: 8))

        let fetched = await repository.prefetchedMonths
        XCTAssertEqual(fetched.count, 13)
        XCTAssertEqual(fetched, OfflineCacheRangePolicy.rollingThirteenMonths.months(around: OfflineMonthKey(year: 2026, month: 8)))
    }

    func testPrefetchDoesNotPersistOldComparisonSelectionAfterItChanges() async throws {
        let gate = CalendarPrefetchGate()
        let cache = CalendarOfflineCacheStub(account: Self.accountSnapshot())
        let repository = CalendarOfflineRepository(prefetchGate: gate)
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            accountID: 42,
            isOffline: true,
            cache: cache
        )
        await model.load()
        model.configure(accountID: 42, isOffline: false)
        model.comparedMemberIDs = [2]

        let prefetch = Task {
            await model.prefetchCachedMonths(around: OfflineMonthKey(year: 2026, month: 8))
        }
        for _ in 0..<100 {
            if await gate.requestCount > 0 { break }
            await Task.yield()
        }
        let requestCount = await gate.requestCount
        XCTAssertGreaterThan(requestCount, 0)

        model.comparedMemberIDs = [3]
        await gate.open()
        await prefetch.value

        let savedSnapshots = await cache.savedMonths
        XCTAssertTrue(
            savedSnapshots.isEmpty,
            "A prefetch started for friend 2 must not overwrite the cache after friend 3 is selected"
        )
    }

    func testOfflineModeNeverStartsNetworkPrefetch() async throws {
        let repository = CalendarOfflineRepository()
        let model = CalendarViewModel(
            repository: repository,
            now: Self.date(2026, 8, 12),
            accountID: 42,
            isOffline: true,
            cache: CalendarOfflineCacheStub(account: Self.accountSnapshot())
        )

        await model.prefetchCachedMonths(around: OfflineMonthKey(year: 2026, month: 8))

        let prefetched = await repository.prefetchedMonths
        XCTAssertTrue(prefetched.isEmpty)
    }

    func testPendingScheduleIsRestoredByASecondCalendarModel() async throws {
        let cache = CalendarOfflineCacheStub(
            account: Self.accountSnapshot(),
            month: Self.monthSnapshot(storedAt: Date(timeIntervalSince1970: 123))
        )
        let outbox = CalendarOfflineOutboxStub()
        let first = CalendarViewModel(
            repository: CalendarOfflineRepository(),
            now: Self.date(2026, 8, 12),
            accountID: 42,
            isOffline: true,
            cache: cache,
            outbox: outbox
        )
        await first.load()
        let saved = await first.saveSchedule(
            existing: nil,
            content: "Survives relaunch",
            description: "",
            visibility: .privateAccess,
            start: Self.date(2026, 8, 12, hour: 18),
            end: Self.date(2026, 8, 12, hour: 19),
            tagFriendIDs: [],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )
        XCTAssertTrue(saved)

        let second = CalendarViewModel(
            repository: CalendarOfflineRepository(),
            now: Self.date(2026, 8, 12),
            accountID: 42,
            isOffline: true,
            cache: cache,
            outbox: outbox
        )
        await second.load()

        XCTAssertEqual(
            second.days.first(where: { $0.cell.date.rawValue == "2026-08-12" })?.schedules.last?.content,
            "Survives relaunch"
        )
    }
}

private extension CalendarOfflineTests {
    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        CalendarDateSupport.calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        )!
    }

    static func member(id: MemberID, name: String) -> MemberDTO {
        MemberDTO(
            id: id,
            name: name,
            email: "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@example.com",
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

    static func accountSnapshot() -> OfflineAccountSnapshot {
        OfflineAccountSnapshot(
            member: MemberDTO(
                id: 42,
                name: "Offline tester",
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
            ),
            friends: [
                FriendDTO(
                    id: 2,
                    name: "Friend A",
                    teamId: 7,
                    team: "Team",
                    hasProfilePhoto: false,
                    profilePhotoVersion: 0,
                    isFamily: false,
                    pinOrder: nil
                ),
                FriendDTO(
                    id: 3,
                    name: "Friend B",
                    teamId: 7,
                    team: "Team",
                    hasProfilePhoto: false,
                    profilePhotoVersion: 0,
                    isFamily: false,
                    pinOrder: nil
                ),
            ],
            storedAt: Date(timeIntervalSince1970: 100)
        )
    }

    static func monthSnapshot(
        storedAt: Date,
        comparedMemberIDs: Set<MemberID>? = [],
        otherDuties: [OtherDutyResponse] = []
    ) -> OfflineMonthSnapshot {
        let key = OfflineMonthKey(year: 2026, month: 8)
        let days = CalendarOfflineRepository.gridDays(year: key.year, month: key.month)
        var schedules = Array(repeating: [ScheduleDTO](), count: 42)
        let schedule = ScheduleDTO(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000042")!,
            content: "Cached appointment",
            description: "",
            position: 0,
            year: 2026,
            month: 8,
            dayOfMonth: 12,
            startDateTime: LocalDateTimeValue(rawValue: "2026-08-12T09:00:00"),
            endDateTime: LocalDateTimeValue(rawValue: "2026-08-12T10:00:00"),
            isTagged: false,
            owner: "Offline tester",
            taggedByMember: nil,
            tags: [],
            visibility: .privateAccess,
            dateToCompare: DateOnly(rawValue: "2026-08-12"),
            attachments: [],
            startDate: DateOnly(rawValue: "2026-08-12"),
            daysFromStart: 0,
            endDate: DateOnly(rawValue: "2026-08-12"),
            curDate: DateOnly(rawValue: "2026-08-12"),
            totalDays: 1
        )
        if let index = days.firstIndex(where: { $0.day == 12 && $0.month == 8 }) {
            schedules[index] = [schedule]
        }
        return OfflineMonthSnapshot(
            accountID: 42,
            key: key,
            calendar: days,
            schedules: schedules,
            duties: [],
            holidays: Array(repeating: [], count: 42),
            otherDuties: otherDuties,
            comparedMemberIDs: comparedMemberIDs,
            storedAt: storedAt
        )
    }

    static func otherDuty(memberID: MemberID, name: String) -> OtherDutyResponse {
        OtherDutyResponse(
            memberId: memberID,
            name: name,
            hasProfilePhoto: false,
            profilePhotoVersion: 0,
            duties: [DutyDTO(
                year: 2026,
                month: 8,
                day: 12,
                dutyType: "Day",
                dutyColor: "#3B82F6",
                isOff: false,
                dutyTypeId: 7,
                source: .override
            )]
        )
    }
}

private actor CalendarOfflineCacheStub: OfflineCacheProviding {
    var account: OfflineAccountSnapshot?
    var month: OfflineMonthSnapshot?
    private let searchResults: [ScheduleSearchResultDTO]
    private let accountLoadGate: CalendarOfflineIdentityRaceGate?
    private let todoBoardLoadGate: CalendarOfflineIdentityRaceGate?
    private(set) var savedMonths: [OfflineMonthSnapshot] = []

    init(
        account: OfflineAccountSnapshot? = nil,
        month: OfflineMonthSnapshot? = nil,
        searchResults: [ScheduleSearchResultDTO] = [],
        accountLoadGate: CalendarOfflineIdentityRaceGate? = nil,
        todoBoardLoadGate: CalendarOfflineIdentityRaceGate? = nil
    ) {
        self.account = account
        self.month = month
        self.searchResults = searchResults
        self.accountLoadGate = accountLoadGate
        self.todoBoardLoadGate = todoBoardLoadGate
    }

    func saveAccount(_ snapshot: OfflineAccountSnapshot) async throws { account = snapshot }
    func saveAccount(member: LoginMember, friends: [FriendDTO], dDays: [DDayDTO], now: Date) async throws {}
    func loadAccount(memberID: MemberID) async -> OfflineAccountSnapshot? {
        let snapshot = account?.memberID == memberID ? account : nil
        await accountLoadGate?.waitForLoad()
        return snapshot
    }
    func saveMonth(_ snapshot: OfflineMonthSnapshot) async throws {
        savedMonths.append(snapshot)
        month = snapshot
    }
    func loadMonth(accountID: MemberID, key: OfflineMonthKey) async -> OfflineMonthSnapshot? {
        guard let month, month.accountID == accountID, month.key == key else { return nil }
        return month
    }
    func loadCachedMonths(accountID: MemberID, around current: OfflineMonthKey) async -> [OfflineMonthSnapshot] {
        month.map { [$0] } ?? []
    }
    func saveTodoBoard(accountID: MemberID, board: TodoBoardDTO, now: Date) async throws {}
    func loadTodoBoard(accountID: MemberID) async -> TodoBoardDTO? {
        await todoBoardLoadGate?.waitForLoad()
        return nil
    }
    func searchSchedules(accountID: MemberID, query: String, keys: [OfflineMonthKey]?) async -> [ScheduleSearchResultDTO] {
        searchResults
    }
    func purge(accountID: MemberID) async throws {}
}

private actor CalendarOfflineOutboxStub: OfflineOutboxProviding {
    private var storedEntries: [OfflineOutboxEntry] = []

    func enqueueScheduleCreate(
        accountID: MemberID,
        request: ScheduleSaveDTO,
        operationID: UUID,
        now: Date
    ) async throws -> OfflineOutboxEntry {
        let entry = OfflineOutboxEntry(
            operationID: operationID,
            accountID: accountID,
            payload: .scheduleCreate(request),
            createdAt: now
        )
        storedEntries.append(entry)
        return entry
    }
    func enqueueTodoCreate(accountID: MemberID, request: TodoRequest, operationID: UUID, now: Date) async throws -> OfflineOutboxEntry {
        fatalError("Not used by Calendar offline tests")
    }
    func entries(accountID: MemberID) async -> [OfflineOutboxEntry] { storedEntries.filter { $0.accountID == accountID } }
    func pendingEntries(accountID: MemberID, now: Date) async -> [OfflineOutboxEntry] { await entries(accountID: accountID) }
    func recordRetry(accountID: MemberID, operationID: UUID, error: OfflineOutboxFailure, nextAttemptAt: Date?) async throws {}
    func markPermanentFailure(accountID: MemberID, operationID: UUID, error: OfflineOutboxFailure) async throws {}
    func retryPermanentFailure(accountID: MemberID, operationID: UUID, now: Date) async throws {}
    func markSucceeded(accountID: MemberID, operationID: UUID) async throws {}
    func purge(accountID: MemberID) async throws {}
}

private actor CalendarSyncRequestRecorder {
    private(set) var values: [MemberID] = []

    func append(_ accountID: MemberID) {
        values.append(accountID)
    }
}

private actor CalendarRecoverySleeperRecorder {
    private(set) var startCount = 0

    func recordStart() {
        startCount += 1
    }
}

private actor CalendarOfflineIdentityRaceGate {
    private var requestObserved = false
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []
    private var isReleased = false
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func waitForLoad() async {
        requestObserved = true
        requestWaiters.forEach { $0.resume() }
        requestWaiters.removeAll()
        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func waitForRequest() async {
        guard !requestObserved else { return }
        await withCheckedContinuation { continuation in
            requestWaiters.append(continuation)
        }
    }

    func release() {
        isReleased = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters.removeAll()
    }
}

private actor CalendarOfflineRepository: CalendarRepositoryProtocol {
    private var monthFailures: [APIError]
    private var scheduleFailures: [APIError]
    private var scheduleRequestCount = 0
    let saveFailure: APIError?
    let searchFailure: APIError?
    let scheduleFailureAfter: Int?
    private(set) var prefetchedMonths: [OfflineMonthKey] = []
    private(set) var savedRequests: [ScheduleSaveDTO] = []
    private(set) var monthRequestCount = 0
    let prefetchGate: CalendarPrefetchGate?
    let memberValue: MemberDTO

    init(
        monthFailure: APIError? = nil,
        monthFailures: [APIError] = [],
        saveFailure: APIError? = nil,
        searchFailure: APIError? = nil,
        scheduleFailures: [APIError] = [],
        scheduleFailureAfter: Int? = nil,
        prefetchGate: CalendarPrefetchGate? = nil,
        member: MemberDTO? = nil
    ) {
        self.monthFailures = monthFailures.isEmpty
            ? monthFailure.map { [$0] } ?? []
            : monthFailures
        self.saveFailure = saveFailure
        self.searchFailure = searchFailure
        self.scheduleFailures = scheduleFailures
        self.scheduleFailureAfter = scheduleFailureAfter
        self.prefetchGate = prefetchGate
        self.memberValue = member ?? Self.memberDTO()
    }

    func member() async throws -> MemberDTO { memberValue }
    func member(id: MemberID) async throws -> MemberPreviewDTO { MemberPreviewDTO(id: id, name: "Member", teamId: nil, team: nil, hasProfilePhoto: false, profilePhotoVersion: 0) }
    func friends() async throws -> [FriendDTO] { [] }
    func team(id: TeamID) async throws -> TeamDTO { throw APIError.invalidResponse }
    func canManage(memberID: MemberID) async throws -> Bool { false }
    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO] {
        recordPrefetch(year: year, month: month)
        try failIfNeeded()
        return Self.gridDays(year: year, month: month)
    }
    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO] { try failIfNeeded(); return [] }
    func otherDuties(memberIDs: [MemberID], year: Int, month: Int) async throws -> [OtherDutyResponse] {
        await prefetchGate?.wait()
        try failIfNeeded()
        return []
    }
    func schedules(memberID: MemberID, year: Int, month: Int) async throws -> [[ScheduleDTO]] {
        try failIfNeeded()
        scheduleRequestCount += 1
        let shouldFail = scheduleFailureAfter.map { scheduleRequestCount >= $0 } ?? true
        if shouldFail, !scheduleFailures.isEmpty {
            throw scheduleFailures.removeFirst()
        }
        return Array(repeating: [], count: 42)
    }
    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]] { try failIfNeeded(); return Array(repeating: [], count: 42) }
    func dDays(memberID: MemberID, isMine: Bool) async throws -> [DDayDTO] { [] }
    func todoBoard() async throws -> TodoBoardDTO { TodoBoardDTO(todo: [], inProgress: [], done: [], counts: TodoCountsDTO(todo: 0, inProgress: 0, done: 0, total: 0)) }
    func saveSchedule(_ request: ScheduleSaveDTO) async throws -> ScheduleSaveResponse {
        savedRequests.append(request)
        if let saveFailure { throw saveFailure }
        return ScheduleSaveResponse(id: request.id ?? UUID())
    }
    func deleteSchedule(id: ScheduleID) async throws {}
    func untagSelf(scheduleID: ScheduleID) async throws {}
    func searchSchedules(memberID: MemberID, query: String, page: Int) async throws -> PageResponse<ScheduleSearchResultDTO> {
        if let searchFailure { throw searchFailure }
        return PageResponse(
            content: [],
            totalPages: 1,
            totalElements: 0,
            last: true,
            first: true,
            size: 10,
            number: page,
            numberOfElements: 0,
            empty: true
        )
    }
    func scheduleBasic(id: ScheduleID) async throws -> ScheduleBasicInfoDTO { fatalError("Not used") }
    func updateDuty(_ request: DutyUpdateDTO) async throws {}
    func uploadDutyBatch(memberID: MemberID, year: Int, month: Int, filename: String, data: Data) async throws -> DutyBatchUploadResult { fatalError("Not used") }
    func saveDDay(_ request: DDaySaveDTO) async throws -> DDayDTO { fatalError("Not used") }
    func deleteDDay(id: Int64) async throws {}

    private func failIfNeeded() throws {
        if !monthFailures.isEmpty {
            throw monthFailures.removeFirst()
        }
    }

    private func recordPrefetch(year: Int, month: Int) {
        monthRequestCount += 1
        prefetchedMonths.append(OfflineMonthKey(year: year, month: month))
    }

    static func memberDTO() -> MemberDTO {
        MemberDTO(id: 42, name: "Offline tester", email: "offline@example.com", teamId: nil, team: nil, calendarVisibility: .friends, kakaoId: nil, naverId: nil, appleId: nil, hasPassword: true, hasProfilePhoto: false, profilePhotoVersion: 0)
    }

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

private actor CalendarPrefetchGate {
    private(set) var requestCount = 0
    private var isOpen = false

    func wait() async {
        requestCount += 1
        while !isOpen {
            guard !Task.isCancelled else { return }
            await Task.yield()
        }
    }

    func open() {
        isOpen = true
    }
}
