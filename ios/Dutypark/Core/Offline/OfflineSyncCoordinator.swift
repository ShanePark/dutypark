import Combine
import Foundation

nonisolated protocol OfflineSyncTransport: Sendable {
    /// Legacy state lookup retained for older integrations and diagnostics.
    /// The coordinator does not use content-based matching for queued creates:
    /// it always sends the operation ID with the create request.
    func scheduleAlreadyExists(
        accountID: MemberID,
        request: ScheduleSaveDTO
    ) async throws -> Bool
    func todoAlreadyExists(
        accountID: MemberID,
        request: TodoRequest
    ) async throws -> Bool
    func createSchedule(_ request: ScheduleSaveDTO) async throws -> ScheduleSaveResponse
    func createSchedule(
        _ request: ScheduleSaveDTO,
        operationID: UUID
    ) async throws -> ScheduleSaveResponse
    func createTodo(_ request: TodoRequest) async throws -> TodoDTO
    func createTodo(
        _ request: TodoRequest,
        operationID: UUID
    ) async throws -> TodoDTO
}

extension OfflineSyncTransport {
    /// The operation-aware overload keeps existing in-memory/test transports
    /// source-compatible while production transports send the durable key.
    func createSchedule(
        _ request: ScheduleSaveDTO,
        operationID: UUID
    ) async throws -> ScheduleSaveResponse {
        try await createSchedule(request)
    }

    func createTodo(
        _ request: TodoRequest,
        operationID: UUID
    ) async throws -> TodoDTO {
        try await createTodo(request)
    }

    /// Existing test transports and integrations can retain the legacy lookup
    /// methods. They are not part of the idempotent create path.
    func scheduleAlreadyExists(
        accountID: MemberID,
        request: ScheduleSaveDTO
    ) async throws -> Bool { throw OfflineCreateDedupeError.lookupUnavailable }

    func todoAlreadyExists(
        accountID: MemberID,
        request: TodoRequest
    ) async throws -> Bool { throw OfflineCreateDedupeError.lookupUnavailable }
}

/// Server-side create matching shared by the production transport and its
/// focused tests.  The comparison deliberately ignores IDs and attachment
/// metadata: the offline queue currently accepts only plain personal creates.
/// Unicode composition, line endings, and outer whitespace are normalized;
/// internal whitespace and letter case remain significant.
nonisolated enum OfflineCreateDedupe {
    static func normalizedText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func scheduleMatches(
        _ existing: ScheduleDTO,
        request: ScheduleSaveDTO
    ) -> Bool {
        guard request.tagFriendIds?.isEmpty != false,
              request.attachmentSessionId == nil,
              request.orderedAttachmentIds.isEmpty,
              !request.aiTimeParsingRequested,
              !existing.isTagged,
              existing.tags.isEmpty,
              existing.attachments.isEmpty,
              normalizedText(existing.content) == normalizedText(request.content),
              normalizedText(existing.description) == normalizedText(request.description),
              canonicalLocalDateTime(existing.startDateTime.rawValue)
                == canonicalLocalDateTime(request.startDateTime.rawValue),
              canonicalLocalDateTime(existing.endDateTime.rawValue)
                == canonicalLocalDateTime(request.endDateTime.rawValue),
              canonicalLocalDateTime(request.startDateTime.rawValue) != nil,
              canonicalLocalDateTime(request.endDateTime.rawValue) != nil,
              existing.visibility == request.visibility
        else { return false }
        return true
    }

    static func todoMatches(
        _ existing: TodoDTO,
        request: TodoRequest
    ) -> Bool {
        request.tagFriendIds?.isEmpty != false
            && request.attachmentSessionId == nil
            && request.orderedAttachmentIds.isEmpty
            && !existing.isTagged
            && existing.tags.isEmpty
            && !existing.hasAttachments
            && dateOnlyMatches(existing.dueDate?.rawValue, request.dueDate?.rawValue)
            && normalizedText(existing.title) == normalizedText(request.title)
            && normalizedText(existing.content) == normalizedText(request.content)
            && existing.status == (request.status ?? .todo)
    }

    /// Returns each calendar month touched by an inclusive schedule range.
    /// ISO-like local date strings are used by the existing DTO wrappers; a
    /// malformed range deliberately returns no months so the caller can defer
    /// instead of issuing an unsafe POST.
    static func monthsCovering(
        start: LocalDateTimeValue,
        end: LocalDateTimeValue
    ) -> [(year: Int, month: Int)] {
        guard let startValue = parseLocalDateTime(start.rawValue),
              let endValue = parseLocalDateTime(end.rawValue),
              startValue <= endValue
        else { return [] }

        var current = Month(year: startValue.year, month: startValue.month)
        let endMonth = Month(year: endValue.year, month: endValue.month)
        var result: [(year: Int, month: Int)] = []
        while current <= endMonth {
            result.append((current.year, current.month))
            if current.month == 12 {
                current = Month(year: current.year + 1, month: 1)
            } else {
                current = Month(year: current.year, month: current.month + 1)
            }
        }
        return result
    }

    private static func canonicalLocalDateTime(_ value: String) -> String? {
        parseLocalDateTime(value)?.canonical
    }

    private static func canonicalDateOnly(_ value: String?) -> String? {
        guard let value else { return nil }
        return parseLocalDateTime(value + "T00:00:00")?.canonical.prefix(10).description
    }

    private static func dateOnlyMatches(_ lhs: String?, _ rhs: String?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (.some(let lhs), .some(let rhs)):
            guard let lhs = canonicalDateOnly(lhs),
                  let rhs = canonicalDateOnly(rhs)
            else { return false }
            return lhs == rhs
        default:
            return false
        }
    }

    private static func parseLocalDateTime(_ value: String) -> LocalDateTime? {
        let bytes = Array(value.utf8)
        guard bytes.count == 19,
              bytes[4] == 45,
              bytes[7] == 45,
              bytes[10] == 84,
              bytes[13] == 58,
              bytes[16] == 58
        else { return nil }

        func number(_ range: Range<Int>) -> Int? {
            var result = 0
            for index in range {
                let byte = bytes[index]
                guard (48...57).contains(byte) else { return nil }
                result = result * 10 + Int(byte - 48)
            }
            return result
        }

        guard let year = number(0..<4),
              let month = number(5..<7),
              let day = number(8..<10),
              let hour = number(11..<13),
              let minute = number(14..<16),
              let second = number(17..<19),
              (1...12).contains(month),
              (1...31).contains(day),
              (0...23).contains(hour),
              (0...59).contains(minute),
              (0...59).contains(second)
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        guard let date = calendar.date(from: components) else { return nil }
        let validated = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        guard validated.year == year,
              validated.month == month,
              validated.day == day,
              validated.hour == hour,
              validated.minute == minute,
              validated.second == second
        else { return nil }
        return LocalDateTime(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
    }

    private struct Month: Comparable {
        let year: Int
        let month: Int

        static func < (lhs: Month, rhs: Month) -> Bool {
            lhs.year < rhs.year || (lhs.year == rhs.year && lhs.month < rhs.month)
        }
    }

    private struct LocalDateTime: Comparable {
        let year: Int
        let month: Int
        let day: Int
        let hour: Int
        let minute: Int
        let second: Int

        var canonical: String {
            String(
                format: "%04d-%02d-%02dT%02d:%02d:%02d",
                year,
                month,
                day,
                hour,
                minute,
                second
            )
        }

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.canonical < rhs.canonical
        }
    }
}

nonisolated enum OfflineCreateDedupeError: Error, Sendable {
    case invalidScheduleRange
    case lookupUnavailable
    case multipleCandidates
}

/// The production transport deliberately uses the same APIClient as the
/// feature repositories. Its authentication-failure handler is therefore
/// preserved, including the SessionStore logout/purge path for a final 401.
nonisolated struct APIOfflineSyncTransport: OfflineSyncTransport {
    let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func createSchedule(_ request: ScheduleSaveDTO) async throws -> ScheduleSaveResponse {
        try await client.request(
            "schedules",
            method: .post,
            body: request,
            authenticationFailureHandling: .awaitCompletion
        )
    }

    func createSchedule(
        _ request: ScheduleSaveDTO,
        operationID: UUID
    ) async throws -> ScheduleSaveResponse {
        try await client.request(
            "schedules",
            method: .post,
            body: request,
            headers: ["Idempotency-Key": operationID.uuidString],
            authenticationFailureHandling: .awaitCompletion
        )
    }

    func createTodo(_ request: TodoRequest) async throws -> TodoDTO {
        try await client.request(
            "todos",
            method: .post,
            body: request,
            authenticationFailureHandling: .awaitCompletion
        )
    }

    func createTodo(
        _ request: TodoRequest,
        operationID: UUID
    ) async throws -> TodoDTO {
        try await client.request(
            "todos",
            method: .post,
            body: request,
            headers: ["Idempotency-Key": operationID.uuidString],
            authenticationFailureHandling: .awaitCompletion
        )
    }

    func scheduleAlreadyExists(
        accountID: MemberID,
        request: ScheduleSaveDTO
    ) async throws -> Bool {
        let months = OfflineCreateDedupe.monthsCovering(
            start: request.startDateTime,
            end: request.endDateTime
        )
        guard !months.isEmpty else {
            throw OfflineCreateDedupeError.invalidScheduleRange
        }

        var schedulesByID: [ScheduleID: ScheduleDTO] = [:]
        for month in months {
            let days: [[ScheduleDTO]] = try await client.request(
                "schedules",
                queryItems: [
                    URLQueryItem(name: "memberId", value: String(accountID)),
                    URLQueryItem(name: "year", value: String(month.year)),
                    URLQueryItem(name: "month", value: String(month.month))
                ],
                authenticationFailureHandling: .awaitCompletion
            )
            for schedule in days.flatMap({ $0 }) {
                schedulesByID[schedule.id] = schedule
            }
        }

        let candidates = schedulesByID.values.filter {
            OfflineCreateDedupe.scheduleMatches($0, request: request)
        }
        guard candidates.count < 2 else {
            throw OfflineCreateDedupeError.multipleCandidates
        }
        return candidates.count == 1
    }

    func todoAlreadyExists(
        accountID: MemberID,
        request: TodoRequest
    ) async throws -> Bool {
        guard accountID > 0 else { throw OfflineSyncRequestError.accountMismatch }
        let board: TodoBoardDTO = try await client.request(
            "todos/board",
            authenticationFailureHandling: .awaitCompletion
        )
        var todosByID: [String: TodoDTO] = [:]
        for todo in board.todo + board.inProgress + board.done {
            todosByID[todo.id] = todo
        }
        let candidates = todosByID.values.filter {
            OfflineCreateDedupe.todoMatches($0, request: request)
        }
        guard candidates.count < 2 else {
            throw OfflineCreateDedupeError.multipleCandidates
        }
        return candidates.count == 1
    }
}

nonisolated struct OfflineSyncAccountState: Equatable, Sendable {
    var pendingCount = 0
    var permanentFailureCount = 0
    var isSyncing = false
    var lastSyncAt: Date?
}

extension Notification.Name {
    /// Account-specific completion notifications let a calendar or Todo view
    /// refresh only its own provisional rows. A legacy fixed-name notification
    /// is posted alongside it for views created by older app builds.
    static func offlineSyncDidComplete(accountID: MemberID) -> Notification.Name {
        Notification.Name("offlineSyncDidComplete.\(accountID)")
    }
}

/// Main-actor owner for all durable offline writes. Calls are intentionally
/// coalesced by account: scene changes, path updates and view refreshes may all
/// request a drain at once, but only one ordered drain can be in flight.
@MainActor
final class OfflineSyncCoordinator: ObservableObject {
    static let shared = OfflineSyncCoordinator()

    static let maximumBackoff: TimeInterval = 5 * 60
    static let initialBackoff: TimeInterval = 5

    @Published private(set) var accountStates: [MemberID: OfflineSyncAccountState] = [:]
    @Published private(set) var activeAccountID: MemberID?

    private let outbox: any OfflineOutboxProviding
    private let transport: any OfflineSyncTransport
    private let now: @Sendable () -> Date
    private let networkStatusProvider: @MainActor @Sendable () -> OfflineNetworkStatus
    private var cancellationGenerationByAccount: [MemberID: Int] = [:]
    private var retryTasks: [MemberID: Task<Void, Never>] = [:]
    private var retryDeadlineByAccount: [MemberID: Date] = [:]

    init(
        outbox: any OfflineOutboxProviding = OfflineOutboxStore.shared,
        transport: any OfflineSyncTransport = APIOfflineSyncTransport(),
        now: @escaping @Sendable () -> Date = { .now },
        networkStatusProvider: @escaping @MainActor @Sendable () -> OfflineNetworkStatus = {
            OfflineNetworkMonitor.shared.status
        }
    ) {
        self.outbox = outbox
        self.transport = transport
        self.now = now
        self.networkStatusProvider = networkStatusProvider
    }

    var pendingCount: Int {
        guard let activeAccountID else { return 0 }
        return accountStates[activeAccountID]?.pendingCount ?? 0
    }

    var permanentFailureCount: Int {
        guard let activeAccountID else { return 0 }
        return accountStates[activeAccountID]?.permanentFailureCount ?? 0
    }

    var isSyncing: Bool {
        guard let activeAccountID else { return false }
        return accountStates[activeAccountID]?.isSyncing == true
    }

    var lastSyncAt: Date? {
        guard let activeAccountID else { return nil }
        return accountStates[activeAccountID]?.lastSyncAt
    }

    func state(for accountID: MemberID) -> OfflineSyncAccountState {
        accountStates[accountID] ?? OfflineSyncAccountState()
    }

    /// Exposes the durable retry deadline to focused tests and diagnostics.
    /// The task itself remains private and cancellable at the account boundary.
    func scheduledRetryDate(for accountID: MemberID) -> Date? {
        retryDeadlineByAccount[accountID]
    }

    /// Called when the authenticated root disappears (logout, account switch,
    /// or an auth purge). In-flight requests cannot always be cancelled at the
    /// URLSession layer, so the generation guard below prevents their result
    /// from mutating a newly authenticated account's local queue.
    func cancel(accountID: MemberID) {
        cancellationGenerationByAccount[accountID, default: 0] &+= 1
        retryTasks[accountID]?.cancel()
        retryTasks[accountID] = nil
        retryDeadlineByAccount[accountID] = nil
        // Remove the complete snapshot at the account boundary. Otherwise a
        // subsequent account could inherit this account's queue counters in
        // the shared offline banner. The generation bump prevents an
        // in-flight drain from re-inserting the old snapshot.
        accountStates[accountID] = nil
        if activeAccountID == accountID {
            activeAccountID = nil
        }
    }

    func cancelAll() {
        var accountIDs = Set(accountStates.keys)
        accountIDs.formUnion(retryTasks.keys)
        accountIDs.formUnion(retryDeadlineByAccount.keys)
        if let activeAccountID {
            accountIDs.insert(activeAccountID)
        }
        for accountID in accountIDs {
            cancellationGenerationByAccount[accountID, default: 0] &+= 1
            retryTasks[accountID]?.cancel()
            retryTasks[accountID] = nil
            retryDeadlineByAccount[accountID] = nil
        }
        accountStates.removeAll()
        activeAccountID = nil
    }

    /// Refreshes the observable queue counters without making a network call.
    func refreshState(accountID: MemberID) async {
        guard accountID > 0 else { return }
        let generation = cancellationGenerationByAccount[accountID, default: 0]
        await refreshState(
            accountID: accountID,
            expectedGeneration: generation
        )
    }

    /// Reopens all permanently failed writes for an explicit user retry.
    /// The queue is made pending even while offline; a later path/foreground
    /// event can then drain it without requiring the user to press retry again.
    func retryPermanentFailures(
        accountID: MemberID,
        networkStatus: OfflineNetworkStatus? = nil
    ) async {
        guard accountID > 0 else { return }
        activeAccountID = accountID
        let generation = cancellationGenerationByAccount[accountID, default: 0]
        let entries = await outbox.entries(accountID: accountID)
        for entry in entries where entry.state == .permanentFailure {
            guard isCurrent(accountID: accountID, generation: generation) else {
                return
            }
            do {
                try await outbox.retryPermanentFailure(
                    accountID: accountID,
                    operationID: entry.operationID,
                    now: now()
                )
            } catch {
                guard isCurrent(accountID: accountID, generation: generation) else {
                    return
                }
            }
        }
        guard isCurrent(accountID: accountID, generation: generation) else { return }
        let status = networkStatus ?? networkStatusProvider()
        if status.isSatisfied {
            await synchronize(accountID: accountID, networkStatus: status)
        } else {
            await refreshState(
                accountID: accountID,
                expectedGeneration: generation
            )
        }
    }

    private func refreshState(
        accountID: MemberID,
        expectedGeneration: Int?
    ) async {
        guard accountID > 0 else { return }
        guard isGenerationCurrent(
            accountID: accountID,
            expectedGeneration: expectedGeneration
        ) else { return }
        let entries = await outbox.entries(accountID: accountID)
        guard isGenerationCurrent(
            accountID: accountID,
            expectedGeneration: expectedGeneration
        ) else { return }
        updateState(for: accountID) { state in
            state.pendingCount = entries.filter { $0.state == .pending }.count
            state.permanentFailureCount = entries.filter {
                $0.state == .permanentFailure
            }.count
        }
    }

    /// Drains eligible operations in creation order. The path monitor is only a
    /// guard against known-disconnected starts; request errors still determine
    /// whether we back off, stop for authentication, or permanently fail an
    /// operation.
    func synchronize(
        accountID: MemberID,
        networkStatus: OfflineNetworkStatus = .satisfied
    ) async {
        guard accountID > 0 else { return }
        activeAccountID = accountID
        let generation = cancellationGenerationByAccount[accountID, default: 0]

        guard networkStatus.isSatisfied else {
            await refreshState(
                accountID: accountID,
                expectedGeneration: generation
            )
            return
        }

        let existingState = state(for: accountID)
        guard !existingState.isSyncing else { return }
        updateState(for: accountID) { $0.isSyncing = true }
        defer {
            // A logout/account switch clears the snapshot and increments the
            // generation. Do not recreate that snapshot from an old task's
            // defer after the account boundary has moved on.
            if isGenerationCurrent(
                accountID: accountID,
                expectedGeneration: generation
            ) {
                updateState(for: accountID) { $0.isSyncing = false }
            }
        }

        var didSucceed = false
        var didRun = false
        var shouldStop = false

        while !shouldStop && !Task.isCancelled {
            let currentNow = now()
            let entries = await outbox.pendingEntries(
                accountID: accountID,
                now: currentNow
            )
            guard let entry = entries.first else { break }
            didRun = true

            guard isCurrent(accountID: accountID, generation: generation) else { break }
            switch await send(entry, generation: generation) {
            case .succeeded:
                didSucceed = true
            case .retry:
                // A transient transport/server error should leave the entry in
                // the queue and stop this run; the next trigger observes the
                // durable deadline rather than hammering the API.
                shouldStop = true
            case .unauthorized:
                // APIClient has already invoked its configured auth handler;
                // SessionStore owns that auth boundary and may purge this
                // account's queue. Stop without writing retry metadata here.
                shouldStop = true
            case .permanentFailure:
                // Validation/permission errors are isolated to this operation;
                // later independent creates can still be sent.
                continue
            case .cancelled:
                shouldStop = true
            }
        }

        guard isCurrent(accountID: accountID, generation: generation) else { return }
        let completedAt = now()
        await refreshState(
            accountID: accountID,
            expectedGeneration: generation
        )
        await rescheduleEarliestRetry(
            accountID: accountID,
            generation: generation
        )
        if didRun || didSucceed {
            updateState(for: accountID) { $0.lastSyncAt = completedAt }
        }
        if didSucceed {
            postCompletion(accountID: accountID)
        }
    }

    private enum SendResult {
        case succeeded
        case retry
        case unauthorized
        case permanentFailure
        case cancelled
    }

    private func send(
        _ entry: OfflineOutboxEntry,
        generation: Int
    ) async -> SendResult {
        guard isCurrent(accountID: entry.accountID, generation: generation) else {
            return .cancelled
        }
        do {
            switch entry.payload {
            case .scheduleCreate(let request):
                let request = try normalizedScheduleRequest(
                    request,
                    accountID: entry.accountID
                )
                try await outbox.markServerAttempted(
                    accountID: entry.accountID,
                    operationID: entry.operationID
                )
                _ = try await transport.createSchedule(
                    request,
                    operationID: entry.operationID
                )
            case .todoCreate(let request):
                let request = try normalizedTodoRequest(
                    request
                )
                try await outbox.markServerAttempted(
                    accountID: entry.accountID,
                    operationID: entry.operationID
                )
                _ = try await transport.createTodo(
                    request,
                    operationID: entry.operationID
                )
            }
            guard isCurrent(accountID: entry.accountID, generation: generation) else {
                return .cancelled
            }
            do {
                try await outbox.markSucceeded(
                    accountID: entry.accountID,
                    operationID: entry.operationID
                )
            } catch {
                // The server accepted the create (or preflight found it), but
                // the local delete failed. Keep the preflight marker so the
                // next attempt never repeats the POST blindly.
                await recordRetry(
                    entry,
                    code: "offline.outbox.persist",
                    message: "The local queue could not be updated.",
                    generation: generation
                )
                return .retry
            }
            return .succeeded
        } catch let error as APIError {
            guard isCurrent(accountID: entry.accountID, generation: generation) else {
                return .cancelled
            }
            return await handle(
                error,
                entry: entry,
                generation: generation
            )
        } catch is CancellationError {
            return .cancelled
        } catch let error as OfflineSyncRequestError {
            guard isCurrent(accountID: entry.accountID, generation: generation) else {
                return .cancelled
            }
            switch error {
            case .accountMismatch:
                await markPermanent(
                    entry,
                    code: "offline.account.mismatch",
                    message: error.localizedDescription,
                    generation: generation
                )
            }
            return .permanentFailure
        } catch is OfflineCreateDedupeError {
            guard isCurrent(accountID: entry.accountID, generation: generation) else {
                return .cancelled
            }
            await recordRetry(
                entry,
                code: "offline.dedupe.inconclusive",
                message: "The server state could not be matched safely.",
                generation: generation
            )
            return .retry
        } catch {
            guard isCurrent(accountID: entry.accountID, generation: generation) else {
                return .cancelled
            }
            await recordRetry(
                entry,
                code: "offline.transport",
                message: "The server could not be reached.",
                generation: generation
            )
            return .retry
        }
    }

    private func handle(
        _ error: APIError,
        entry: OfflineOutboxEntry,
        generation: Int
    ) async -> SendResult {
        guard isCurrent(accountID: entry.accountID, generation: generation) else {
            return .cancelled
        }
        switch error {
        case .server(status: 401, _),
             .serverWithDetails(status: 401, _, _):
            // APIClient invokes the configured authentication handler before
            // returning this error. Never write a retry deadline here: logout
            // may have just purged the account directory.
            return .unauthorized
        case .server(let status, _),
             .serverWithDetails(let status, _, _):
            if [408, 425, 429].contains(status) {
                await recordRetry(
                    entry,
                    code: "offline.server.\(status)",
                    message: "The server asked this operation to be retried.",
                    statusCode: status,
                    generation: generation
                )
                return .retry
            }
            if (400..<500).contains(status) {
                await markPermanent(
                    entry,
                    code: "offline.server.\(status)",
                    message: "The server rejected this operation.",
                    generation: generation
                )
                return .permanentFailure
            }
            await recordRetry(
                entry,
                code: "offline.server.\(status)",
                message: "The server is temporarily unavailable.",
                generation: generation
            )
            return .retry
        case .transport, .invalidResponse, .decoding:
            await recordRetry(
                entry,
                code: "offline.transport",
                message: "The server could not be reached.",
                generation: generation
            )
            return .retry
        case .invalidURL:
            await markPermanent(
                entry,
                code: "offline.invalidURL",
                message: "The queued request could not be constructed.",
                generation: generation
            )
            return .permanentFailure
        }
    }

    private func recordRetry(
        _ entry: OfflineOutboxEntry,
        code: String,
        message: String,
        statusCode: Int? = nil,
        delay: TimeInterval? = nil,
        generation: Int
    ) async {
        guard isCurrent(accountID: entry.accountID, generation: generation) else { return }
        let retryDelay = delay ?? Self.backoffDelay(
            afterAttemptCount: entry.attemptCount
        )
        let failure = OfflineOutboxFailure(
            code: code,
            statusCode: statusCode ?? (code == "auth.unauthorized" ? 401 : nil),
            message: message,
            occurredAt: now()
        )
        let nextAttemptAt = failure.occurredAt.addingTimeInterval(retryDelay)
        do {
            try await outbox.recordRetry(
                accountID: entry.accountID,
                operationID: entry.operationID,
                error: failure,
                nextAttemptAt: nextAttemptAt
            )
            guard isCurrent(accountID: entry.accountID, generation: generation) else {
                return
            }
            scheduleRetry(
                accountID: entry.accountID,
                at: nextAttemptAt,
                generation: cancellationGenerationByAccount[entry.accountID, default: 0]
            )
        } catch {
            // The queue may have been purged by the authentication handler.
            // Do not recreate it with a retry task.
        }
    }

    private func markPermanent(
        _ entry: OfflineOutboxEntry,
        code: String,
        message: String,
        generation: Int
    ) async {
        guard isCurrent(accountID: entry.accountID, generation: generation) else { return }
        let failure = OfflineOutboxFailure(
            code: code,
            statusCode: nil,
            message: message,
            occurredAt: now()
        )
        try? await outbox.markPermanentFailure(
            accountID: entry.accountID,
            operationID: entry.operationID,
            error: failure
        )
    }

    private func normalizedScheduleRequest(
        _ request: ScheduleSaveDTO,
        accountID: MemberID
    ) throws -> ScheduleSaveDTO {
        guard request.memberId == accountID else {
            throw OfflineSyncRequestError.accountMismatch
        }
        // The operation ID is transported in the Idempotency-Key header, not
        // in the request body, so this normalization remains API-compatible.
        return ScheduleSaveDTO(
            id: request.id,
            memberId: request.memberId,
            content: request.content,
            description: request.description,
            visibility: request.visibility,
            startDateTime: request.startDateTime,
            endDateTime: request.endDateTime,
            tagFriendIds: request.tagFriendIds,
            attachmentSessionId: request.attachmentSessionId,
            orderedAttachmentIds: request.orderedAttachmentIds,
            aiTimeParsingRequested: request.aiTimeParsingRequested
        )
    }

    private func normalizedTodoRequest(
        _ request: TodoRequest
    ) throws -> TodoRequest {
        // The operation ID is transported in the Idempotency-Key header, not
        // in the request body, so this normalization remains API-compatible.
        return TodoRequest(
            title: request.title,
            content: request.content,
            status: request.status,
            dueDate: request.dueDate,
            tagFriendIds: request.tagFriendIds,
            attachmentSessionId: request.attachmentSessionId,
            orderedAttachmentIds: request.orderedAttachmentIds
        )
    }

    private func updateState(
        for accountID: MemberID,
        _ update: (inout OfflineSyncAccountState) -> Void
    ) {
        var state = accountStates[accountID] ?? OfflineSyncAccountState()
        update(&state)
        accountStates[accountID] = state
    }

    private func isCurrent(accountID: MemberID, generation: Int) -> Bool {
        !Task.isCancelled
            && cancellationGenerationByAccount[accountID, default: 0] == generation
    }

    private func isGenerationCurrent(
        accountID: MemberID,
        expectedGeneration: Int?
    ) -> Bool {
        guard let expectedGeneration else { return true }
        return cancellationGenerationByAccount[accountID, default: 0] == expectedGeneration
    }

    private func scheduleRetry(
        accountID: MemberID,
        at date: Date,
        generation: Int
    ) {
        guard isCurrent(accountID: accountID, generation: generation) else { return }
        retryTasks[accountID]?.cancel()
        retryDeadlineByAccount[accountID] = date
        let delay = max(0, date.timeIntervalSince(now()))
        retryTasks[accountID] = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard let self,
                  self.isCurrent(accountID: accountID, generation: generation),
                  self.retryDeadlineByAccount[accountID] == date
            else { return }
            self.retryTasks[accountID] = nil
            self.retryDeadlineByAccount[accountID] = nil
            await self.synchronize(
                accountID: accountID,
                networkStatus: self.networkStatusProvider()
            )
        }
    }

    private func rescheduleEarliestRetry(
        accountID: MemberID,
        generation: Int
    ) async {
        guard isCurrent(accountID: accountID, generation: generation) else { return }
        let now = now()
        let entries = await outbox.entries(accountID: accountID)
        guard isCurrent(accountID: accountID, generation: generation) else { return }

        let earliest = entries
            .filter { $0.state == .pending }
            .compactMap(\.nextAttemptAt)
            .filter { $0 > now }
            .min()

        if let earliest {
            scheduleRetry(
                accountID: accountID,
                at: earliest,
                generation: generation
            )
        } else {
            retryTasks[accountID]?.cancel()
            retryTasks[accountID] = nil
            retryDeadlineByAccount[accountID] = nil
        }
    }

    private func postCompletion(accountID: MemberID) {
        let userInfo: [AnyHashable: Any] = ["accountID": accountID]
        NotificationCenter.default.post(
            name: .offlineSyncDidComplete(accountID: accountID),
            object: accountID,
            userInfo: userInfo
        )
        // Calendar/Todo views from the first offline implementation listen to
        // this stable name. Keep it during the migration to account-specific
        // names so a server acknowledgement always replaces provisional rows.
        NotificationCenter.default.post(
            name: Notification.Name("offlineSyncDidComplete"),
            object: accountID,
            userInfo: userInfo
        )
    }

    static func backoffDelay(afterAttemptCount count: Int) -> TimeInterval {
        let exponent = min(max(count, 0), 6)
        return min(
            Self.maximumBackoff,
            Self.initialBackoff * pow(2, Double(exponent))
        )
    }
}

private enum OfflineSyncRequestError: Error, LocalizedError {
    case accountMismatch

    var errorDescription: String? {
        switch self {
        case .accountMismatch:
            "The queued schedule belongs to a different account."
        }
    }
}
