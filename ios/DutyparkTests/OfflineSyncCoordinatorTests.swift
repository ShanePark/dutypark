import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class OfflineSyncCoordinatorTests: XCTestCase {
    func testFirstOfflineCreatesSkipPreflightAndRemoveBothCreateKinds() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake()
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        let scheduleID = UUID()
        let todoID = UUID()
        _ = try await outbox.enqueueScheduleCreate(
            accountID: 42,
            request: makeScheduleRequest(),
            operationID: scheduleID,
            now: Date(timeIntervalSince1970: 1)
        )
        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: todoID,
            now: Date(timeIntervalSince1970: 2)
        )

        await coordinator.synchronize(accountID: 42)

        let scheduleRequests = await transport.scheduleRequests
        let todoRequests = await transport.todoRequests
        let schedulePreflights = await transport.schedulePreflightRequests
        let todoPreflights = await transport.todoPreflightRequests
        let sentSchedule = try XCTUnwrap(scheduleRequests.first)
        let sentTodo = try XCTUnwrap(todoRequests.first)
        XCTAssertEqual(sentSchedule.memberId, 42)
        XCTAssertEqual(sentTodo.title, "Offline todo")
        XCTAssertTrue(schedulePreflights.isEmpty)
        XCTAssertTrue(todoPreflights.isEmpty)
        let remainingEntries = await outbox.entries(accountID: 42)
        XCTAssertTrue(remainingEntries.isEmpty)
        XCTAssertEqual(coordinator.state(for: 42).pendingCount, 0)
        XCTAssertEqual(coordinator.state(for: 42).permanentFailureCount, 0)
        XCTAssertNotNil(coordinator.state(for: 42).lastSyncAt)
    }

    func testDoesNotSendScheduleWhoseMemberDiffersFromAccount() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake()
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        let operationID = UUID()
        await outbox.insert(
            OfflineOutboxEntry(
                operationID: operationID,
                accountID: 42,
                payload: .scheduleCreate(
                    makeScheduleRequest(memberID: 43)
                ),
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )

        await coordinator.synchronize(accountID: 42)

        let scheduleRequests = await transport.scheduleRequests
        XCTAssertTrue(scheduleRequests.isEmpty)
        let entries = await outbox.entries(accountID: 42)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.state, .permanentFailure)
    }

    func testEquivalentScheduleStillPostsAsDistinctOperation() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(existingSchedules: [
            makeScheduleDTO(
                content: "Offline schedule",
                description: "Created without a connection"
            )
        ])
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        let operationID = UUID()
        _ = try await outbox.enqueueScheduleCreate(
            accountID: 42,
            request: makeScheduleRequest(
                content: "Offline schedule",
                description: "Created without a connection"
            ),
            operationID: operationID,
            now: Date(timeIntervalSince1970: 1)
        )

        await coordinator.synchronize(accountID: 42)

        let scheduleRequests = await transport.scheduleRequests
        let preflightRequests = await transport.schedulePreflightRequests
        let operationIDs = await transport.scheduleOperationIDs
        XCTAssertEqual(scheduleRequests.count, 1)
        XCTAssertEqual(operationIDs, [operationID])
        XCTAssertTrue(preflightRequests.isEmpty)
        let remaining = await outbox.entries(accountID: 42)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testNonEquivalentScheduleStillPosts() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(existingSchedules: [
            makeScheduleDTO(content: "A different schedule")
        ])
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        _ = try await outbox.enqueueScheduleCreate(
            accountID: 42,
            request: makeScheduleRequest(),
            operationID: UUID(),
            now: Date(timeIntervalSince1970: 1)
        )

        await coordinator.synchronize(accountID: 42)

        let scheduleRequests = await transport.scheduleRequests
        XCTAssertEqual(scheduleRequests.count, 1)
        let remaining = await outbox.entries(accountID: 42)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testScheduleCreateWithAdjacentMonthPostsWithoutStateMatching() async throws {
        let outbox = SyncOutboxFake()
        let request = makeScheduleRequest(
            content: "  Multi-day schedule \r\n",
            description: "Line one\r\nline two\n",
            startDateTime: "2026-08-31T23:00:00",
            endDateTime: "2026-09-01T01:00:00"
        )
        let transport = SyncTransportFake(existingSchedules: [
            makeScheduleDTO(
                content: "Multi-day schedule",
                description: "Line one\nline two",
                startDateTime: "2026-08-31T23:00:00",
                endDateTime: "2026-09-01T01:00:00"
            )
        ])
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        _ = try await outbox.enqueueScheduleCreate(
            accountID: 42,
            request: request,
            operationID: UUID(),
            now: Date(timeIntervalSince1970: 1)
        )

        await coordinator.synchronize(accountID: 42)

        let scheduleRequests = await transport.scheduleRequests
        XCTAssertEqual(scheduleRequests.count, 1)
        let remaining = await outbox.entries(accountID: 42)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testEquivalentTodoInAnyBoardColumnStillPostsAsDistinctOperation() async throws {
        let outbox = SyncOutboxFake()
        let request = makeTodoRequest(
            title: "  Offline todo ",
            content: "Description\r\nwith spaces\n",
            status: .done,
            dueDate: "2026-08-12"
        )
        let existing = makeTodoDTO(
            title: "Offline todo",
            content: "Description\nwith spaces",
            status: .done,
            dueDate: "2026-08-12"
        )
        let transport = SyncTransportFake(
            existingTodoBoard: makeTodoBoard(done: [existing])
        )
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        let operationID = UUID()
        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: request,
            operationID: operationID,
            now: Date(timeIntervalSince1970: 1)
        )

        await coordinator.synchronize(accountID: 42)

        let todoRequests = await transport.todoRequests
        let preflightRequests = await transport.todoPreflightRequests
        let operationIDs = await transport.todoOperationIDs
        XCTAssertEqual(todoRequests.count, 1)
        XCTAssertEqual(operationIDs, [operationID])
        XCTAssertTrue(preflightRequests.isEmpty)
        let remaining = await outbox.entries(accountID: 42)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testPureOfflineCreatePostsEvenWhenAnOlderEquivalentRowExists() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(existingSchedules: [makeScheduleDTO()])
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        _ = try await outbox.enqueueScheduleCreate(
            accountID: 42,
            request: makeScheduleRequest(),
            operationID: UUID(),
            now: Date(timeIntervalSince1970: 1)
        )

        await coordinator.synchronize(accountID: 42)

        let posts = await transport.scheduleRequests
        let preflights = await transport.schedulePreflightRequests
        XCTAssertEqual(posts.count, 1)
        XCTAssertTrue(preflights.isEmpty)
    }

    func testAmbiguousPostFailureRetriesWithTheSameOperationID() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(
            error: .transport,
            existingSchedules: [makeScheduleDTO()]
        )
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        _ = try await outbox.enqueueScheduleCreate(
            accountID: 42,
            request: makeScheduleRequest(),
            operationID: UUID(),
            now: Date(timeIntervalSince1970: 1)
        )

        await coordinator.synchronize(accountID: 42)

        let entriesAfterFailure = await outbox.entries(accountID: 42)
        let afterFailure = try XCTUnwrap(entriesAfterFailure.first)
        XCTAssertTrue(afterFailure.serverAttempted)
        XCTAssertTrue(afterFailure.requiresPreflight)
        XCTAssertEqual(afterFailure.attemptCount, 1)

        await outbox.setNextAttemptAt(
            accountID: 42,
            operationID: afterFailure.operationID,
            date: nil
        )
        await transport.setError(nil)
        await coordinator.synchronize(accountID: 42)

        let posts = await transport.scheduleRequests
        let preflights = await transport.schedulePreflightRequests
        let operationIDs = await transport.scheduleOperationIDs
        let remaining = await outbox.entries(accountID: 42)
        XCTAssertEqual(posts.count, 2, "The server idempotency key makes a retry safe")
        XCTAssertEqual(operationIDs.count, 2)
        XCTAssertEqual(operationIDs[0], operationIDs[1])
        XCTAssertTrue(preflights.isEmpty)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testDuplicateScheduleCandidatesDoNotSuppressASeparateCreate() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(existingSchedules: [
            makeScheduleDTO(),
            makeScheduleDTO()
        ])
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        _ = try await outbox.enqueueScheduleCreate(
            accountID: 42,
            request: makeScheduleRequest(),
            operationID: UUID(),
            now: Date(timeIntervalSince1970: 1)
        )

        await coordinator.synchronize(accountID: 42)

        let posts = await transport.scheduleRequests
        let remaining = await outbox.entries(accountID: 42)
        XCTAssertEqual(posts.count, 1)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testUnavailablePreflightDoesNotBlockIdempotentCreate() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(shouldFailPreflight: true)
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: UUID(),
            now: Date(timeIntervalSince1970: 1)
        )

        await coordinator.synchronize(accountID: 42)

        let posts = await transport.todoRequests
        let remaining = await outbox.entries(accountID: 42)
        XCTAssertEqual(posts.count, 1)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testPreflightErrorsDoNotReplaceTheIdempotentCreateRequest() async throws {
        for status in [408, 425, 429] {
            let outbox = SyncOutboxFake()
            let transport = SyncTransportFake(
                preflightError: .server(status: status, code: "retry")
            )
            let coordinator = OfflineSyncCoordinator(
                outbox: outbox,
                transport: transport,
                now: { Date(timeIntervalSince1970: 100) },
                networkStatusProvider: { .satisfied }
            )
            defer { coordinator.cancelAll() }

            _ = try await outbox.enqueueTodoCreate(
                accountID: 42,
                request: makeTodoRequest(),
                operationID: UUID(),
                now: Date(timeIntervalSince1970: 1),
                requiresPreflight: true
            )

            await coordinator.synchronize(accountID: 42)

            let posts = await transport.todoRequests
            let entries = await outbox.entries(accountID: 42)
            XCTAssertEqual(posts.count, 1)
            XCTAssertTrue(entries.isEmpty)
        }
    }

    func testDedupeKeepsInternalWhitespaceAndRejectsInvalidDates() {
        XCTAssertFalse(
            OfflineCreateDedupe.todoMatches(
                makeTodoDTO(
                    title: "Offline todo",
                    content: "Two spaces",
                    status: .todo,
                    dueDate: nil
                ),
                request: makeTodoRequest(
                    title: "Offline  todo",
                    content: "Two spaces",
                    dueDate: nil
                )
            )
        )
        XCTAssertFalse(
            OfflineCreateDedupe.todoMatches(
                makeTodoDTO(
                    title: "Offline todo",
                    content: "",
                    status: .todo,
                    dueDate: nil
                ),
                request: makeTodoRequest(dueDate: "2026-02-30")
            )
        )
        XCTAssertTrue(
            OfflineCreateDedupe.monthsCovering(
                start: LocalDateTimeValue(rawValue: "2026-02-30T09:00:00"),
                end: LocalDateTimeValue(rawValue: "2026-03-01T09:00:00")
            ).isEmpty
        )
    }

    func testFourHundredMovesOnlyThatOperationToPermanentFailure() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(error: .server(status: 400, code: "invalid"))
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        let operationID = UUID()
        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: operationID,
            now: Date(timeIntervalSince1970: 1)
        )

        await coordinator.synchronize(accountID: 42)

        let entries = await outbox.entries(accountID: 42)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.state, .permanentFailure)
        XCTAssertEqual(coordinator.state(for: 42).pendingCount, 0)
        XCTAssertEqual(coordinator.state(for: 42).permanentFailureCount, 1)
    }

    func testInvalidURLMovesOperationToPermanentFailureWithoutRetrying() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(error: .invalidURL)
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: UUID(),
            now: Date(timeIntervalSince1970: 1)
        )

        await coordinator.synchronize(accountID: 42)

        let entries = await outbox.entries(accountID: 42)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.state, .permanentFailure)
        XCTAssertNil(entry.nextAttemptAt)
        XCTAssertEqual(coordinator.state(for: 42).pendingCount, 0)
        XCTAssertEqual(coordinator.state(for: 42).permanentFailureCount, 1)
    }

    func testRetryPermanentFailuresReturnsAllOperationsToPendingWhenOffline() async throws {
        let outbox = SyncOutboxFake()
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: SyncTransportFake(),
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .unsatisfied }
        )
        defer { coordinator.cancelAll() }

        let operationIDs = [UUID(), UUID()]
        for (offset, operationID) in operationIDs.enumerated() {
            _ = try await outbox.enqueueTodoCreate(
                accountID: 42,
                request: makeTodoRequest(title: "Failed (offset)"),
                operationID: operationID,
                now: Date(timeIntervalSince1970: Double(offset + 1))
            )
            try await outbox.markPermanentFailure(
                accountID: 42,
                operationID: operationID,
                error: OfflineOutboxFailure(
                    code: "offline.server.400",
                    statusCode: 400,
                    message: "Rejected",
                    occurredAt: Date(timeIntervalSince1970: 10)
                )
            )
        }
        await coordinator.refreshState(accountID: 42)
        XCTAssertEqual(coordinator.state(for: 42).permanentFailureCount, 2)

        await coordinator.retryPermanentFailures(
            accountID: 42,
            networkStatus: .unsatisfied
        )

        let entries = await outbox.entries(accountID: 42)
        XCTAssertTrue(entries.allSatisfy { $0.state == .pending })
        XCTAssertTrue(entries.allSatisfy { $0.nextAttemptAt == Date(timeIntervalSince1970: 100) })
        XCTAssertEqual(coordinator.state(for: 42).pendingCount, 2)
        XCTAssertEqual(coordinator.state(for: 42).permanentFailureCount, 0)
    }

    func testRetryPermanentFailuresWakesOnlineSynchronization() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake()
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        let operationID = UUID()
        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: operationID,
            now: Date(timeIntervalSince1970: 1)
        )
        try await outbox.markPermanentFailure(
            accountID: 42,
            operationID: operationID,
            error: OfflineOutboxFailure(
                code: "offline.server.400",
                statusCode: 400,
                message: "Rejected",
                occurredAt: Date(timeIntervalSince1970: 10)
            )
        )

        await coordinator.retryPermanentFailures(
            accountID: 42,
            networkStatus: .satisfied
        )

        let remainingEntries = await outbox.entries(accountID: 42)
        let todoRequests = await transport.todoRequests
        XCTAssertTrue(remainingEntries.isEmpty)
        XCTAssertEqual(todoRequests.count, 1)
    }

    func testTransportFailureBacksOffAndLeavesPendingOperation() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(error: .transport)
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .unsatisfied }
        )
        defer { coordinator.cancelAll() }

        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: UUID(),
            now: Date(timeIntervalSince1970: 1)
        )
        await coordinator.synchronize(accountID: 42, networkStatus: .satisfied)

        let entries = await outbox.entries(accountID: 42)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.state, .pending)
        XCTAssertEqual(entry.attemptCount, 1)
        XCTAssertEqual(entry.nextAttemptAt, Date(timeIntervalSince1970: 105))
        XCTAssertEqual(coordinator.state(for: 42).pendingCount, 1)
    }

    func testUnauthorizedDoesNotWriteRetryAfterAuthenticationHandlerMayPurge() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(error: .server(status: 401, code: "auth"))
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: UUID(),
            now: Date(timeIntervalSince1970: 1)
        )
        await coordinator.synchronize(accountID: 42)

        let entries = await outbox.entries(accountID: 42)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.attemptCount, 0)
        XCTAssertNil(entry.nextAttemptAt)
        XCTAssertEqual(entry.state, .pending)
    }

    func testBackoffIsExponentialAndCappedAtFiveMinutes() {
        XCTAssertEqual(OfflineSyncCoordinator.backoffDelay(afterAttemptCount: 0), 5)
        XCTAssertEqual(OfflineSyncCoordinator.backoffDelay(afterAttemptCount: 1), 10)
        XCTAssertEqual(OfflineSyncCoordinator.backoffDelay(afterAttemptCount: 6), 300)
        XCTAssertEqual(OfflineSyncCoordinator.backoffDelay(afterAttemptCount: 100), 300)
    }

    func testCancelClearsAccountScopedStateAndActiveAccount() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(error: .server(status: 400, code: "invalid"))
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: UUID(),
            now: Date(timeIntervalSince1970: 1)
        )
        await coordinator.synchronize(accountID: 42)
        XCTAssertEqual(coordinator.state(for: 42).permanentFailureCount, 1)
        XCTAssertEqual(coordinator.activeAccountID, 42)

        coordinator.cancel(accountID: 42)

        XCTAssertEqual(coordinator.state(for: 42), OfflineSyncAccountState())
        XCTAssertNil(coordinator.activeAccountID)
        XCTAssertEqual(coordinator.pendingCount, 0)
        XCTAssertEqual(coordinator.permanentFailureCount, 0)

        _ = try await outbox.enqueueTodoCreate(
            accountID: 43,
            request: makeTodoRequest(),
            operationID: UUID(),
            now: Date(timeIntervalSince1970: 2)
        )
        await coordinator.synchronize(accountID: 43, networkStatus: .unsatisfied)
        XCTAssertEqual(coordinator.pendingCount, 1)
        XCTAssertEqual(coordinator.activeAccountID, 43)

        coordinator.cancelAll()

        XCTAssertEqual(coordinator.state(for: 42), OfflineSyncAccountState())
        XCTAssertEqual(coordinator.state(for: 43), OfflineSyncAccountState())
        XCTAssertNil(coordinator.activeAccountID)
        XCTAssertEqual(coordinator.pendingCount, 0)
        XCTAssertEqual(coordinator.permanentFailureCount, 0)
    }

    func testSuccessfulEntryKeepsEarliestRetryDeadlineForAnotherPendingEntry() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(error: .transport)
        let coordinator = OfflineSyncCoordinator(
            outbox: outbox,
            transport: transport,
            now: { Date(timeIntervalSince1970: 100) },
            networkStatusProvider: { .satisfied }
        )
        defer { coordinator.cancelAll() }

        let firstID = UUID()
        let secondID = UUID()
        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: firstID,
            now: Date(timeIntervalSince1970: 1)
        )
        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: secondID,
            now: Date(timeIntervalSince1970: 2)
        )
        await outbox.setNextAttemptAt(
            accountID: 42,
            operationID: secondID,
            date: Date(timeIntervalSince1970: 106)
        )

        await coordinator.synchronize(accountID: 42)
        XCTAssertEqual(
            coordinator.scheduledRetryDate(for: 42),
            Date(timeIntervalSince1970: 105)
        )

        await outbox.setNextAttemptAt(
            accountID: 42,
            operationID: firstID,
            date: nil
        )
        await transport.setError(nil)
        await coordinator.synchronize(accountID: 42)

        XCTAssertEqual(
            coordinator.scheduledRetryDate(for: 42),
            Date(timeIntervalSince1970: 106),
            "A successful operation must not cancel another pending operation's retry timer"
        )
        let remaining = await outbox.entries(accountID: 42)
        XCTAssertEqual(remaining.map(\.operationID), [secondID])
    }
}

private actor SyncOutboxFake: OfflineOutboxProviding {
    private var storedEntries: [OfflineOutboxEntry] = []

    func insert(_ entry: OfflineOutboxEntry) {
        storedEntries.append(entry)
    }

    func enqueueScheduleCreate(
        accountID: MemberID,
        request: ScheduleSaveDTO,
        operationID: UUID,
        now: Date
    ) throws -> OfflineOutboxEntry {
        try enqueueScheduleCreate(
            accountID: accountID,
            request: request,
            operationID: operationID,
            now: now,
            requiresPreflight: false
        )
    }

    func enqueueScheduleCreate(
        accountID: MemberID,
        request: ScheduleSaveDTO,
        operationID: UUID,
        now: Date,
        requiresPreflight: Bool
    ) throws -> OfflineOutboxEntry {
        let entry = OfflineOutboxEntry(
            operationID: operationID,
            accountID: accountID,
            payload: .scheduleCreate(request),
            createdAt: now,
            serverAttempted: requiresPreflight,
            requiresPreflight: requiresPreflight
        )
        storedEntries.append(entry)
        return entry
    }

    func enqueueTodoCreate(
        accountID: MemberID,
        request: TodoRequest,
        operationID: UUID,
        now: Date
    ) throws -> OfflineOutboxEntry {
        try enqueueTodoCreate(
            accountID: accountID,
            request: request,
            operationID: operationID,
            now: now,
            requiresPreflight: false
        )
    }

    func enqueueTodoCreate(
        accountID: MemberID,
        request: TodoRequest,
        operationID: UUID,
        now: Date,
        requiresPreflight: Bool
    ) throws -> OfflineOutboxEntry {
        let entry = OfflineOutboxEntry(
            operationID: operationID,
            accountID: accountID,
            payload: .todoCreate(request),
            createdAt: now,
            serverAttempted: requiresPreflight,
            requiresPreflight: requiresPreflight
        )
        storedEntries.append(entry)
        return entry
    }

    func entries(accountID: MemberID) -> [OfflineOutboxEntry] {
        storedEntries.filter { $0.accountID == accountID }.sorted { $0.createdAt < $1.createdAt }
    }

    func pendingEntries(accountID: MemberID, now: Date) -> [OfflineOutboxEntry] {
        entries(accountID: accountID).filter {
            $0.state == .pending && ($0.nextAttemptAt == nil || $0.nextAttemptAt! <= now)
        }
    }

    func setNextAttemptAt(
        accountID: MemberID,
        operationID: UUID,
        date: Date?
    ) {
        guard let index = storedEntries.firstIndex(where: {
            $0.accountID == accountID && $0.operationID == operationID
        }) else { return }
        storedEntries[index].nextAttemptAt = date
    }

    func recordRetry(
        accountID: MemberID,
        operationID: UUID,
        error: OfflineOutboxFailure,
        nextAttemptAt: Date?
    ) throws {
        guard let index = storedEntries.firstIndex(where: {
            $0.accountID == accountID && $0.operationID == operationID
        }) else { throw OfflineOutboxStoreError.operationNotFound }
        storedEntries[index].state = .pending
        storedEntries[index].attemptCount += 1
        storedEntries[index].lastAttemptAt = error.occurredAt
        storedEntries[index].nextAttemptAt = nextAttemptAt
        storedEntries[index].failure = error
    }

    func markPermanentFailure(
        accountID: MemberID,
        operationID: UUID,
        error: OfflineOutboxFailure
    ) throws {
        guard let index = storedEntries.firstIndex(where: {
            $0.accountID == accountID && $0.operationID == operationID
        }) else { throw OfflineOutboxStoreError.operationNotFound }
        storedEntries[index].state = .permanentFailure
        storedEntries[index].attemptCount += 1
        storedEntries[index].lastAttemptAt = error.occurredAt
        storedEntries[index].nextAttemptAt = nil
        storedEntries[index].failure = error
    }

    func retryPermanentFailure(accountID: MemberID, operationID: UUID, now: Date) throws {
        guard let index = storedEntries.firstIndex(where: {
            $0.accountID == accountID && $0.operationID == operationID
        }) else { throw OfflineOutboxStoreError.operationNotFound }
        storedEntries[index].state = .pending
        storedEntries[index].nextAttemptAt = now
        storedEntries[index].failure = nil
    }

    func markSucceeded(accountID: MemberID, operationID: UUID) throws {
        storedEntries.removeAll {
            $0.accountID == accountID && $0.operationID == operationID
        }
    }

    func markServerAttempted(accountID: MemberID, operationID: UUID) throws {
        guard let index = storedEntries.firstIndex(where: {
            $0.accountID == accountID && $0.operationID == operationID
        }) else { throw OfflineOutboxStoreError.operationNotFound }
        storedEntries[index].serverAttempted = true
        storedEntries[index].requiresPreflight = true
    }

    func purge(accountID: MemberID) throws {}
    func purgeAll() throws {}
}

private actor SyncTransportFake: OfflineSyncTransport {
    private var error: APIError?
    private let existingSchedules: [ScheduleDTO]
    private let existingTodoBoard: TodoBoardDTO?
    private let shouldFailPreflight: Bool
    private let preflightError: APIError?
    private(set) var scheduleRequests: [ScheduleSaveDTO] = []
    private(set) var todoRequests: [TodoRequest] = []
    private(set) var scheduleOperationIDs: [UUID] = []
    private(set) var todoOperationIDs: [UUID] = []
    private(set) var schedulePreflightRequests: [ScheduleSaveDTO] = []
    private(set) var todoPreflightRequests: [TodoRequest] = []

    init(
        error: APIError? = nil,
        existingSchedules: [ScheduleDTO] = [],
        existingTodoBoard: TodoBoardDTO? = nil,
        shouldFailPreflight: Bool = false,
        preflightError: APIError? = nil
    ) {
        self.error = error
        self.existingSchedules = existingSchedules
        self.existingTodoBoard = existingTodoBoard
        self.shouldFailPreflight = shouldFailPreflight
        self.preflightError = preflightError
    }

    func setError(_ error: APIError?) {
        self.error = error
    }

    func scheduleAlreadyExists(
        accountID: MemberID,
        request: ScheduleSaveDTO
    ) async throws -> Bool {
        schedulePreflightRequests.append(request)
        if let preflightError { throw preflightError }
        if shouldFailPreflight { throw OfflineCreateDedupeError.lookupUnavailable }
        let candidates = existingSchedules.filter {
            OfflineCreateDedupe.scheduleMatches($0, request: request)
        }
        if candidates.count > 1 { throw OfflineCreateDedupeError.multipleCandidates }
        return candidates.count == 1
    }

    func todoAlreadyExists(
        accountID: MemberID,
        request: TodoRequest
    ) async throws -> Bool {
        todoPreflightRequests.append(request)
        if let preflightError { throw preflightError }
        if shouldFailPreflight { throw OfflineCreateDedupeError.lookupUnavailable }
        let todos = [
            existingTodoBoard?.todo ?? [],
            existingTodoBoard?.inProgress ?? [],
            existingTodoBoard?.done ?? []
        ].flatMap { $0 }
        let candidates = todos.filter {
            OfflineCreateDedupe.todoMatches($0, request: request)
        }
        if candidates.count > 1 { throw OfflineCreateDedupeError.multipleCandidates }
        return candidates.count == 1
    }

    func createSchedule(_ request: ScheduleSaveDTO) throws -> ScheduleSaveResponse {
        scheduleRequests.append(request)
        if let error { throw error }
        return ScheduleSaveResponse(id: UUID())
    }

    func createSchedule(
        _ request: ScheduleSaveDTO,
        operationID: UUID
    ) throws -> ScheduleSaveResponse {
        scheduleOperationIDs.append(operationID)
        return try createSchedule(request)
    }

    func createTodo(_ request: TodoRequest) throws -> TodoDTO {
        todoRequests.append(request)
        if let error { throw error }
        return TodoDTO(
            id: UUID().uuidString,
            title: request.title,
            content: request.content,
            position: 0,
            status: request.status ?? .todo,
            createdDate: LocalDateTimeValue(rawValue: "2026-08-23T00:00:00"),
            completedDate: nil,
            dueDate: request.dueDate,
            isOverdue: false,
            isTagged: false,
            owner: "Tester",
            taggedByMember: nil,
            tags: [],
            hasAttachments: false
        )
    }

    func createTodo(
        _ request: TodoRequest,
        operationID: UUID
    ) throws -> TodoDTO {
        todoOperationIDs.append(operationID)
        return try createTodo(request)
    }
}

private func makeScheduleRequest(
    memberID: MemberID = 42,
    content: String = "Offline schedule",
    description: String = "",
    startDateTime: String = "2026-08-23T09:00:00",
    endDateTime: String = "2026-08-23T10:00:00"
) -> ScheduleSaveDTO {
    ScheduleSaveDTO(
        id: nil,
        memberId: memberID,
        content: content,
        description: description,
        visibility: .privateAccess,
        startDateTime: LocalDateTimeValue(rawValue: startDateTime),
        endDateTime: LocalDateTimeValue(rawValue: endDateTime),
        tagFriendIds: nil,
        attachmentSessionId: nil,
        orderedAttachmentIds: [],
        aiTimeParsingRequested: false
    )
}

private func makeScheduleDTO(
    content: String = "Offline schedule",
    description: String = "",
    startDateTime: String = "2026-08-23T09:00:00",
    endDateTime: String = "2026-08-23T10:00:00"
) -> ScheduleDTO {
    ScheduleDTO(
        id: UUID(),
        content: content,
        description: description,
        position: 0,
        year: 2026,
        month: 8,
        dayOfMonth: 23,
        startDateTime: LocalDateTimeValue(rawValue: startDateTime),
        endDateTime: LocalDateTimeValue(rawValue: endDateTime),
        isTagged: false,
        owner: "Tester",
        taggedByMember: nil,
        tags: [],
        visibility: .privateAccess,
        dateToCompare: DateOnly(rawValue: "2026-08-23"),
        attachments: [],
        startDate: DateOnly(rawValue: "2026-08-23"),
        daysFromStart: 0,
        endDate: DateOnly(rawValue: "2026-08-23"),
        curDate: DateOnly(rawValue: "2026-08-23"),
        totalDays: 1
    )
}

private func makeTodoRequest(
    title: String = "Offline todo",
    content: String = "",
    status: TodoStatus? = .todo,
    dueDate: String? = nil
) -> TodoRequest {
    TodoRequest(
        title: title,
        content: content,
        status: status,
        dueDate: dueDate.map(DateOnly.init(rawValue:)),
        tagFriendIds: nil,
        attachmentSessionId: nil,
        orderedAttachmentIds: []
    )
}

private func makeTodoDTO(
    title: String,
    content: String,
    status: TodoStatus,
    dueDate: String?
) -> TodoDTO {
    TodoDTO(
        id: UUID().uuidString,
        title: title,
        content: content,
        position: 0,
        status: status,
        createdDate: LocalDateTimeValue(rawValue: "2026-08-23T00:00:00"),
        completedDate: nil,
        dueDate: dueDate.map(DateOnly.init(rawValue:)),
        isOverdue: false,
        isTagged: false,
        owner: "Tester",
        taggedByMember: nil,
        tags: [],
        hasAttachments: false
    )
}

private func makeTodoBoard(
    todo: [TodoDTO] = [],
    inProgress: [TodoDTO] = [],
    done: [TodoDTO] = []
) -> TodoBoardDTO {
    TodoBoardDTO(
        todo: todo,
        inProgress: inProgress,
        done: done,
        counts: TodoCountsDTO(
            todo: todo.count,
            inProgress: inProgress.count,
            done: done.count,
            total: todo.count + inProgress.count + done.count
        )
    )
}
