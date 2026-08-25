import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class OfflineSyncCoordinatorTests: XCTestCase {
    func testFirstOfflineCreatesPostBothCreateKinds() async throws {
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
        let sentSchedule = try XCTUnwrap(scheduleRequests.first)
        let sentTodo = try XCTUnwrap(todoRequests.first)
        XCTAssertEqual(sentSchedule.memberId, 42)
        XCTAssertEqual(sentTodo.title, "Offline todo")
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

    func testTransportFailureRetriesTheSameLocalOperation() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake(error: .transport)
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
        XCTAssertEqual(afterFailure.attemptCount, 1)

        await outbox.setNextAttemptAt(
            accountID: 42,
            operationID: afterFailure.operationID,
            date: nil
        )
        await transport.setError(nil)
        await coordinator.synchronize(accountID: 42)

        let posts = await transport.scheduleRequests
        let remaining = await outbox.entries(accountID: 42)
        XCTAssertEqual(posts.count, 2)
        XCTAssertEqual(remaining.count, 0)
    }

    func testDuplicateLocalOperationIDIsNotEnqueuedTwice() async throws {
        let outbox = SyncOutboxFake()
        let operationID = UUID()
        let request = makeScheduleRequest()
        let first = try await outbox.enqueueScheduleCreate(
            accountID: 42,
            request: request,
            operationID: operationID,
            now: Date(timeIntervalSince1970: 1)
        )
        let second = try await outbox.enqueueScheduleCreate(
            accountID: 42,
            request: request,
            operationID: operationID,
            now: Date(timeIntervalSince1970: 2)
        )
        XCTAssertEqual(first.operationID, second.operationID)
        let entries = await outbox.entries(accountID: 42)
        XCTAssertEqual(entries.count, 1)
    }

    func testPlainCreateAlwaysPostsAndLeavesDuplicatePolicyToServer() async throws {
        let outbox = SyncOutboxFake()
        let transport = SyncTransportFake()
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
        let requests = await transport.scheduleRequests
        let entries = await outbox.entries(accountID: 42)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(entries.isEmpty)
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
        let entry = OfflineOutboxEntry(
            operationID: operationID,
            accountID: accountID,
            payload: .scheduleCreate(request),
            createdAt: now
        )
        if let existing = storedEntries.first(where: {
            $0.accountID == accountID && $0.operationID == operationID
        }) { return existing }
        storedEntries.append(entry)
        return entry
    }

    func enqueueTodoCreate(
        accountID: MemberID,
        request: TodoRequest,
        operationID: UUID,
        now: Date
    ) throws -> OfflineOutboxEntry {
        let entry = OfflineOutboxEntry(
            operationID: operationID,
            accountID: accountID,
            payload: .todoCreate(request),
            createdAt: now
        )
        if let existing = storedEntries.first(where: {
            $0.accountID == accountID && $0.operationID == operationID
        }) { return existing }
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

    func purge(accountID: MemberID) throws {}
    func purgeAll() throws {}
}

private actor SyncTransportFake: OfflineSyncTransport {
    private var error: APIError?
    private(set) var scheduleRequests: [ScheduleSaveDTO] = []
    private(set) var todoRequests: [TodoRequest] = []

    init(error: APIError? = nil) {
        self.error = error
    }

    func setError(_ error: APIError?) {
        self.error = error
    }

    func createSchedule(_ request: ScheduleSaveDTO) throws -> ScheduleSaveResponse {
        scheduleRequests.append(request)
        if let error { throw error }
        return ScheduleSaveResponse(id: UUID())
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
