import Foundation
import Testing
@testable import Dutypark

@MainActor
struct OfflineOutboxStoreTests {
    @Test
    func enqueuesScheduleAndTodoCreatesWithStableOperationIDs() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineOutboxStore(rootURL: root)
        let scheduleOperationID = UUID()
        let todoOperationID = UUID()
        let schedule = makeScheduleRequest(memberID: 42)
        let expectedSchedule = makeScheduleRequest(memberID: 42)
        let todo = TodoRequest(
            title: "Offline todo",
            content: "Created without a connection",
            status: .todo,
            dueDate: DateOnly(rawValue: "2026-08-12"),
            tagFriendIds: nil,
            attachmentSessionId: nil,
            orderedAttachmentIds: []
        )
        let expectedTodo = todo

        let scheduleEntry = try await store.enqueueScheduleCreate(
            accountID: 42,
            request: schedule,
            operationID: scheduleOperationID,
            now: Date(timeIntervalSince1970: 100)
        )
        let todoEntry = try await store.enqueueTodoCreate(
            accountID: 42,
            request: todo,
            operationID: todoOperationID,
            now: Date(timeIntervalSince1970: 101)
        )
        let restored = OfflineOutboxStore(rootURL: root)
        let entries = await restored.entries(accountID: 42)

        #expect(scheduleEntry.operationID == scheduleOperationID)
        #expect(todoEntry.operationID == todoOperationID)
        #expect(entries.map(\.operationID) == [scheduleOperationID, todoOperationID])
        #expect(entries.contains {
            guard case .scheduleCreate(let request) = $0.payload else { return false }
            return request == expectedSchedule
        })
        #expect(entries.contains {
            guard case .todoCreate(let request) = $0.payload else { return false }
            return request == expectedTodo
        })
    }

    @Test
    func duplicateOperationIDIsIdempotent() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineOutboxStore(rootURL: root)
        let operationID = UUID()
        let request = makeScheduleRequest(memberID: 42)
        let now = Date(timeIntervalSince1970: 100)

        let first = try await store.enqueueScheduleCreate(
            accountID: 42,
            request: request,
            operationID: operationID,
            now: now
        )
        let second = try await store.enqueueScheduleCreate(
            accountID: 42,
            request: request,
            operationID: operationID,
            now: now
        )

        #expect(first == second)
        #expect(await store.entries(accountID: 42).count == 1)
    }

    @Test
    func duplicateOperationDoesNotChangeTheStoredPayload() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineOutboxStore(rootURL: root)
        let operationID = UUID()
        let request = makeScheduleRequest(memberID: 42)

        let first = try await store.enqueueScheduleCreate(
            accountID: 42,
            request: request,
            operationID: operationID,
            now: Date(timeIntervalSince1970: 100)
        )
        let duplicate = try await store.enqueueScheduleCreate(
            accountID: 42,
            request: request,
            operationID: operationID,
            now: Date(timeIntervalSince1970: 101)
        )
        let restoredEntries = await OfflineOutboxStore(rootURL: root).entries(accountID: 42)
        let restored = try #require(restoredEntries.first)

        #expect(first == duplicate)
        #expect(restored.operationID == operationID)
        #expect(restoredEntries.count == 1)
    }

    @Test
    func legacyEntryWithRemovedPreflightFieldsStillDecodes() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineOutboxStore(rootURL: root)
        let operationID = UUID()
        _ = try await store.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: operationID
        )
        let file = root.appending(path: "accounts/42/outbox.json")
        var object = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        )
        var entries = try #require(object["entries"] as? [[String: Any]])
        entries[0]["serverAttempted"] = true
        entries[0]["requiresPreflight"] = true
        object["entries"] = entries
        try JSONSerialization.data(withJSONObject: object).write(to: file, options: .atomic)

        let restoredEntries = await OfflineOutboxStore(rootURL: root).entries(accountID: 42)
        let restored = try #require(restoredEntries.first)

        #expect(restored.operationID == operationID)
        #expect(restoredEntries.count == 1)
    }

    @Test
    func rejectsInvalidAccounts() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineOutboxStore(rootURL: root)
        let operationID = UUID()

        await #expect(throws: OfflineOutboxStoreError.accountMismatch) {
            try await store.enqueueScheduleCreate(
                accountID: 0,
                request: makeScheduleRequest(memberID: 0),
                operationID: operationID
            )
        }
        await #expect(throws: OfflineOutboxStoreError.accountMismatch) {
            try await store.enqueueTodoCreate(
                accountID: -1,
                request: makeTodoRequest(),
                operationID: operationID
            )
        }

        await #expect(throws: OfflineOutboxStoreError.accountMismatch) {
            try await store.markSucceeded(accountID: 0, operationID: operationID)
        }
    }

    @Test
    func recordsRetryAndPermanentFailureMetadata() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineOutboxStore(rootURL: root)
        let operationID = UUID()
        _ = try await store.enqueueScheduleCreate(
            accountID: 42,
            request: makeScheduleRequest(memberID: 42),
            operationID: operationID
        )
        let retryAt = Date(timeIntervalSince1970: 300)
        try await store.recordRetry(
            accountID: 42,
            operationID: operationID,
            error: OfflineOutboxFailure(
                code: "network.unavailable",
                statusCode: nil,
                message: "No connection",
                occurredAt: Date(timeIntervalSince1970: 200)
            ),
            nextAttemptAt: retryAt
        )
        let pending = await store.pendingEntries(accountID: 42, now: Date(timeIntervalSince1970: 299))
        #expect(pending.isEmpty)

        try await store.markPermanentFailure(
            accountID: 42,
            operationID: operationID,
            error: OfflineOutboxFailure(
                code: "schedule.content.required",
                statusCode: 400,
                message: "Content is required",
                occurredAt: Date(timeIntervalSince1970: 400)
            )
        )
        let entry = try #require(await store.entries(accountID: 42).first)
        #expect(entry.state == .permanentFailure)
        #expect(entry.failure?.statusCode == 400)
        #expect(await store.pendingEntries(accountID: 42).isEmpty)
    }

    @Test
    func ignoresCorruptOutboxAndPurgesAccount() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "accounts/42/outbox.json")
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{\"schemaVersion\":999}".utf8).write(to: file)
        let store = OfflineOutboxStore(rootURL: root)

        #expect(await store.entries(accountID: 42).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        try await store.purge(accountID: 42)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test
    func ignoresUnknownPayloadFieldsWithoutDroppingTheEntry() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineOutboxStore(rootURL: root)
        let operationID = UUID()
        _ = try await store.enqueueScheduleCreate(
            accountID: 42,
            request: makeScheduleRequest(memberID: 42),
            operationID: operationID
        )
        let file = root.appending(path: "accounts/42/outbox.json")
        var object = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        )
        var entries = try #require(object["entries"] as? [[String: Any]])
        var entry = try #require(entries.first)
        var payload = try #require(entry["payload"] as? [String: Any])
        var request = try #require(payload["schedule"] as? [String: Any])
        request["unknownField"] = UUID().uuidString
        payload["schedule"] = request
        entry["payload"] = payload
        entries[0] = entry
        object["entries"] = entries
        try JSONSerialization.data(withJSONObject: object).write(to: file, options: .atomic)

        let restored = OfflineOutboxStore(rootURL: root)
        #expect(await restored.entries(accountID: 42).count == 1)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test
    func salvagesValidEntriesWhenOnePersistedPayloadIsInvalid() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineOutboxStore(rootURL: root)
        let invalidOperationID = UUID()
        let validOperationID = UUID()
        _ = try await store.enqueueScheduleCreate(
            accountID: 42,
            request: makeScheduleRequest(memberID: 42),
            operationID: invalidOperationID,
            now: Date(timeIntervalSince1970: 100)
        )
        _ = try await store.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: validOperationID,
            now: Date(timeIntervalSince1970: 101)
        )
        let file = root.appending(path: "accounts/42/outbox.json")
        var object = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        )
        var entries = try #require(object["entries"] as? [[String: Any]])
        var invalidEntry = try #require(entries.first)
        var payload = try #require(invalidEntry["payload"] as? [String: Any])
        var request = try #require(payload["schedule"] as? [String: Any])
        request["orderedAttachmentIds"] = [UUID().uuidString]
        payload["schedule"] = request
        invalidEntry["payload"] = payload
        entries[0] = invalidEntry
        object["entries"] = entries
        try JSONSerialization.data(withJSONObject: object).write(to: file, options: .atomic)

        let restored = OfflineOutboxStore(rootURL: root)
        let validEntries = await restored.entries(accountID: 42)

        #expect(validEntries.map(\.operationID) == [validOperationID])
        #expect(FileManager.default.fileExists(atPath: file.path))
        let reloaded = await OfflineOutboxStore(rootURL: root).entries(accountID: 42)
        #expect(reloaded.map(\.operationID) == [validOperationID])
    }

    @Test
    func salvagesValidEntriesWhenPersistedScheduleTargetsAnotherAccount() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineOutboxStore(rootURL: root)
        let invalidOperationID = UUID()
        let validOperationID = UUID()
        _ = try await store.enqueueScheduleCreate(
            accountID: 42,
            request: makeScheduleRequest(memberID: 42),
            operationID: invalidOperationID,
            now: Date(timeIntervalSince1970: 100)
        )
        _ = try await store.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: validOperationID,
            now: Date(timeIntervalSince1970: 101)
        )

        let file = root.appending(path: "accounts/42/outbox.json")
        var object = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        )
        var entries = try #require(object["entries"] as? [[String: Any]])
        var invalidEntry = try #require(entries.first)
        var payload = try #require(invalidEntry["payload"] as? [String: Any])
        var request = try #require(payload["schedule"] as? [String: Any])
        request["memberId"] = 43
        payload["schedule"] = request
        invalidEntry["payload"] = payload
        entries[0] = invalidEntry
        object["entries"] = entries
        try JSONSerialization.data(withJSONObject: object).write(to: file, options: .atomic)

        let restored = OfflineOutboxStore(rootURL: root)
        let validEntries = await restored.entries(accountID: 42)

        #expect(validEntries.map(\.operationID) == [validOperationID])
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test
    func purgeAllRemovesEveryAccountQueue() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = OfflineOutboxStore(rootURL: root)
        _ = try await store.enqueueScheduleCreate(
            accountID: 42,
            request: makeScheduleRequest(memberID: 42),
            operationID: UUID()
        )
        _ = try await store.enqueueTodoCreate(
            accountID: 43,
            request: makeTodoRequest(),
            operationID: UUID()
        )
        try await store.purgeAll()

        let firstAccountEntries = await store.entries(accountID: 42)
        let secondAccountEntries = await store.entries(accountID: 43)
        #expect(firstAccountEntries.isEmpty)
        #expect(secondAccountEntries.isEmpty)
    }

    @Test
    func localDataPurgerRemovesOneAccountOrTheWholeOfflineRoot() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = OfflineCacheStore(rootURL: root)
        let outbox = OfflineOutboxStore(rootURL: root)
        try await cache.saveAccount(member: makeMember(id: 42))
        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: UUID()
        )

        let purger = OfflineLocalDataPurger(cache: cache, outbox: outbox)
        await purger.purgeLocalData(for: 42)

        #expect(await cache.loadAccount(memberID: 42) == nil)
        #expect(await outbox.entries(accountID: 42).isEmpty)

        try await cache.saveAccount(member: makeMember(id: 43))
        _ = try await outbox.enqueueTodoCreate(
            accountID: 43,
            request: makeTodoRequest(),
            operationID: UUID()
        )
        await purger.purgeLocalData(for: nil)

        #expect(await cache.loadAccount(memberID: 43) == nil)
        #expect(await outbox.entries(accountID: 43).isEmpty)

        await purger.reopenLocalData(for: 43)
        try await cache.saveAccount(member: makeMember(id: 43))
        _ = try await outbox.enqueueTodoCreate(
            accountID: 43,
            request: makeTodoRequest(),
            operationID: UUID()
        )
        await #expect(throws: OfflineCacheStoreError.accountClosed) {
            try await cache.saveAccount(member: makeMember(id: 42))
        }
    }

    @Test
    func purgeClosesSharedBarrierUntilTheAuthenticatedAccountIsReopened() async throws {
        let root = try makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let barrier = OfflineWriteBarrier()
        let cache = OfflineCacheStore(rootURL: root, writeBarrier: barrier)
        let outbox = OfflineOutboxStore(rootURL: root, writeBarrier: barrier)
        let purger = OfflineLocalDataPurger(cache: cache, outbox: outbox)

        try await cache.saveAccount(member: makeMember(id: 42))
        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: UUID()
        )

        await purger.purgeLocalData(for: 42)

        await #expect(throws: OfflineCacheStoreError.accountClosed) {
            try await cache.saveAccount(member: makeMember(id: 42))
        }
        await #expect(throws: OfflineOutboxStoreError.accountClosed) {
            try await outbox.enqueueTodoCreate(
                accountID: 42,
                request: makeTodoRequest(),
                operationID: UUID()
            )
        }
        #expect(await cache.loadAccount(memberID: 42) == nil)
        #expect(await outbox.entries(accountID: 42).isEmpty)

        await purger.reopenLocalData(for: 42)
        try await cache.saveAccount(member: makeMember(id: 42))
        _ = try await outbox.enqueueTodoCreate(
            accountID: 42,
            request: makeTodoRequest(),
            operationID: UUID()
        )
        #expect(await cache.loadAccount(memberID: 42) != nil)
        #expect(await outbox.entries(accountID: 42).count == 1)
    }

    @Test
    func sharedBarrierWaitsForAnInFlightMutationBeforePurgeClosesTheAccount() async throws {
        let barrier = OfflineWriteBarrier()
        let gate = OfflineBarrierTestGate()

        let writer = Task.detached {
            try barrier.withOpenAccount(42) {
                gate.markEntered()
                gate.waitUntilReleased()
            }
        }
        for _ in 0..<100 where !gate.entered {
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(gate.entered)

        let purger = Task.detached {
            barrier.close(accountID: 42)
            gate.markClosed()
        }
        try await Task.sleep(for: .milliseconds(20))
        #expect(!gate.closed)

        gate.release()
        try await writer.value
        for _ in 0..<100 where !gate.closed {
            try await Task.sleep(for: .milliseconds(1))
        }
        #expect(gate.closed)
        await purger.value
        #expect(!barrier.isOpen(accountID: 42))
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "offline-outbox-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeScheduleRequest(
        memberID: MemberID,
        _unused: UUID? = nil
    ) -> ScheduleSaveDTO {
        ScheduleSaveDTO(
            id: nil,
            memberId: memberID,
            content: "Offline schedule",
            description: "Created without a connection",
            visibility: .privateAccess,
            startDateTime: LocalDateTimeValue(rawValue: "2026-08-12T09:00:00"),
            endDateTime: LocalDateTimeValue(rawValue: "2026-08-12T10:00:00"),
            tagFriendIds: nil,
            attachmentSessionId: nil,
            orderedAttachmentIds: [],
            aiTimeParsingRequested: false,
        )
    }

    private func makeTodoRequest(_unused: UUID? = nil) -> TodoRequest {
        TodoRequest(
            title: "Offline todo",
            content: "Created without a connection",
            status: .todo,
            dueDate: nil,
            tagFriendIds: nil,
            attachmentSessionId: nil,
            orderedAttachmentIds: [],
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

private final class OfflineBarrierTestGate: @unchecked Sendable {
    private let lock = NSLock()
    private var didEnter = false
    private var didRelease = false
    private var didClose = false

    var entered: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didEnter
    }

    var closed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didClose
    }

    func markEntered() {
        lock.lock()
        didEnter = true
        lock.unlock()
    }

    func markClosed() {
        lock.lock()
        didClose = true
        lock.unlock()
    }

    func release() {
        lock.lock()
        didRelease = true
        lock.unlock()
    }

    func waitUntilReleased() {
        while true {
            lock.lock()
            let released = didRelease
            lock.unlock()
            if released { return }
            Thread.sleep(forTimeInterval: 0.001)
        }
    }
}
