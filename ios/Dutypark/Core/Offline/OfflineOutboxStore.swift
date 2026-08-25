import Foundation

nonisolated enum OfflineOutboxOperationKind: String, Codable, Sendable {
    case scheduleCreate
    case todoCreate
}

nonisolated enum OfflineOutboxState: String, Codable, Sendable {
    case pending
    case permanentFailure
}

nonisolated enum OfflineOutboxPayload: Codable, Equatable, Sendable {
    case scheduleCreate(ScheduleSaveDTO)
    case todoCreate(TodoRequest)

    private enum CodingKeys: String, CodingKey {
        case kind
        case schedule
        case todo
    }

    private enum Kind: String, Codable {
        case scheduleCreate
        case todoCreate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .scheduleCreate:
            self = .scheduleCreate(try container.decode(ScheduleSaveDTO.self, forKey: .schedule))
        case .todoCreate:
            self = .todoCreate(try container.decode(TodoRequest.self, forKey: .todo))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .scheduleCreate(let request):
            try container.encode(Kind.scheduleCreate, forKey: .kind)
            try container.encode(request, forKey: .schedule)
        case .todoCreate(let request):
            try container.encode(Kind.todoCreate, forKey: .kind)
            try container.encode(request, forKey: .todo)
        }
    }

    var kind: OfflineOutboxOperationKind {
        switch self {
        case .scheduleCreate: .scheduleCreate
        case .todoCreate: .todoCreate
        }
    }
}

nonisolated struct OfflineOutboxFailure: Codable, Equatable, Sendable {
    let code: String?
    let statusCode: Int?
    let message: String
    let occurredAt: Date

    init(
        code: String?,
        statusCode: Int?,
        message: String,
        occurredAt: Date = .now
    ) {
        self.code = code
        self.statusCode = statusCode
        self.message = message
        self.occurredAt = occurredAt
    }
}

nonisolated struct OfflineOutboxEntry: Codable, Equatable, Sendable {
    let operationID: UUID
    let accountID: MemberID
    let payload: OfflineOutboxPayload
    let createdAt: Date
    var state: OfflineOutboxState
    var attemptCount: Int
    var lastAttemptAt: Date?
    var nextAttemptAt: Date?
    var failure: OfflineOutboxFailure?

    init(
        operationID: UUID,
        accountID: MemberID,
        payload: OfflineOutboxPayload,
        createdAt: Date,
        state: OfflineOutboxState = .pending,
        attemptCount: Int = 0,
        lastAttemptAt: Date? = nil,
        nextAttemptAt: Date? = nil,
        failure: OfflineOutboxFailure? = nil
    ) {
        self.operationID = operationID
        self.accountID = accountID
        self.payload = payload
        self.createdAt = createdAt
        self.state = state
        self.attemptCount = attemptCount
        self.lastAttemptAt = lastAttemptAt
        self.nextAttemptAt = nextAttemptAt
        self.failure = failure
    }

    private enum CodingKeys: String, CodingKey {
        case operationID, accountID, payload, createdAt
        case state, attemptCount, lastAttemptAt, nextAttemptAt, failure
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operationID = try container.decode(UUID.self, forKey: .operationID)
        accountID = try container.decode(MemberID.self, forKey: .accountID)
        payload = try container.decode(OfflineOutboxPayload.self, forKey: .payload)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        state = try container.decode(OfflineOutboxState.self, forKey: .state)
        attemptCount = try container.decode(Int.self, forKey: .attemptCount)
        lastAttemptAt = try container.decodeIfPresent(Date.self, forKey: .lastAttemptAt)
        nextAttemptAt = try container.decodeIfPresent(Date.self, forKey: .nextAttemptAt)
        failure = try container.decodeIfPresent(OfflineOutboxFailure.self, forKey: .failure)
    }

    var kind: OfflineOutboxOperationKind { payload.kind }
}

nonisolated enum OfflineOutboxStoreError: Error, Equatable, Sendable {
    case accountMismatch
    case accountClosed
    case operationConflict
    case operationNotFound
    case unsupportedSchedulePayload
    case unsupportedTodoPayload
    case encodingFailed
}

/// Async seam consumed by the sync coordinator. It keeps the coordinator
/// independent from the JSON representation and makes queue behavior easy to
/// exercise with a temporary or in-memory implementation.
nonisolated protocol OfflineOutboxProviding: Sendable {
    func enqueueScheduleCreate(
        accountID: MemberID,
        request: ScheduleSaveDTO,
        operationID: UUID,
        now: Date
    ) async throws -> OfflineOutboxEntry
    func enqueueTodoCreate(
        accountID: MemberID,
        request: TodoRequest,
        operationID: UUID,
        now: Date
    ) async throws -> OfflineOutboxEntry
    func entries(accountID: MemberID) async -> [OfflineOutboxEntry]
    func pendingEntries(accountID: MemberID, now: Date) async -> [OfflineOutboxEntry]
    func recordRetry(
        accountID: MemberID,
        operationID: UUID,
        error: OfflineOutboxFailure,
        nextAttemptAt: Date?
    ) async throws
    func markPermanentFailure(
        accountID: MemberID,
        operationID: UUID,
        error: OfflineOutboxFailure
    ) async throws
    func retryPermanentFailure(
        accountID: MemberID,
        operationID: UUID,
        now: Date
    ) async throws
    func markSucceeded(accountID: MemberID, operationID: UUID) async throws
    func purge(accountID: MemberID) async throws
    func purgeAll() async throws
    func reopen(accountID: MemberID) async
    func reopenAll() async
}

extension OfflineOutboxProviding {
    func purgeAll() async throws {}
    func reopen(accountID: MemberID) async {}
    func reopenAll() async {}
}

/// Persistent queue for the two write operations supported in offline mode.
/// Entries are account-scoped and operation IDs identify one local create
/// operation, so a retry after an ambiguous network failure cannot enqueue a
/// second local operation. The server owns content-based duplicate handling.
actor OfflineOutboxStore {
    static let shared = OfflineOutboxStore()

    let rootURL: URL
    private let fileSystem: any OfflineFileSystem
    private let writeBarrier: OfflineWriteBarrier
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        rootURL: URL = OfflineCacheStore.defaultRootURL(),
        fileSystem: any OfflineFileSystem = LocalOfflineFileSystem.shared,
        writeBarrier: OfflineWriteBarrier? = nil
    ) {
        self.rootURL = rootURL
        self.fileSystem = fileSystem
        self.writeBarrier = writeBarrier
            ?? OfflineWriteBarrierRegistry.shared.barrier(for: rootURL)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func enqueueScheduleCreate(
        accountID: MemberID,
        request: ScheduleSaveDTO,
        operationID: UUID = UUID(),
        now: Date = .now
    ) throws -> OfflineOutboxEntry {
        guard accountID > 0 else { throw OfflineOutboxStoreError.accountMismatch }
        return try withOpenAccount(accountID) {
            guard request.id == nil,
                  request.memberId == accountID,
                  request.tagFriendIds?.isEmpty != false,
                  request.attachmentSessionId == nil,
                  request.orderedAttachmentIds.isEmpty,
                  !request.aiTimeParsingRequested
            else { throw OfflineOutboxStoreError.unsupportedSchedulePayload }

            let normalizedRequest = try scheduleRequest(request)

            return try enqueue(
                accountID: accountID,
                payload: .scheduleCreate(normalizedRequest),
                operationID: operationID,
                now: now
            )
        }
    }

    func enqueueTodoCreate(
        accountID: MemberID,
        request: TodoRequest,
        operationID: UUID = UUID(),
        now: Date = .now
    ) throws -> OfflineOutboxEntry {
        guard accountID > 0 else { throw OfflineOutboxStoreError.accountMismatch }
        return try withOpenAccount(accountID) {
            guard request.tagFriendIds?.isEmpty != false,
                  request.attachmentSessionId == nil,
                  request.orderedAttachmentIds.isEmpty
            else { throw OfflineOutboxStoreError.unsupportedTodoPayload }

            let normalizedRequest = try todoRequest(request)

            return try enqueue(
                accountID: accountID,
                payload: .todoCreate(normalizedRequest),
                operationID: operationID,
                now: now
            )
        }
    }

    func entries(accountID: MemberID) -> [OfflineOutboxEntry] {
        guard accountID > 0 else { return [] }
        do {
            return try withOpenAccount(accountID) {
                loadFile(accountID: accountID)?.entries.sorted(by: sortEntries) ?? []
            }
        } catch OfflineOutboxStoreError.accountClosed {
            return []
        } catch {
            return []
        }
    }

    func pendingEntries(
        accountID: MemberID,
        now: Date = .now
    ) -> [OfflineOutboxEntry] {
        guard accountID > 0 else { return [] }
        return entries(accountID: accountID).filter { entry in
            entry.state == .pending
                && (entry.nextAttemptAt == nil || entry.nextAttemptAt! <= now)
        }
    }

    /// Records a transient failure and leaves the operation eligible for a
    /// future retry. The caller supplies its backoff deadline.
    func recordRetry(
        accountID: MemberID,
        operationID: UUID,
        error: OfflineOutboxFailure,
        nextAttemptAt: Date? = nil
    ) throws {
        guard accountID > 0 else { throw OfflineOutboxStoreError.accountMismatch }
        try update(accountID: accountID, operationID: operationID) { entry in
            entry.state = .pending
            entry.attemptCount += 1
            entry.lastAttemptAt = error.occurredAt
            entry.nextAttemptAt = nextAttemptAt
            entry.failure = error
        }
    }

    func markPermanentFailure(
        accountID: MemberID,
        operationID: UUID,
        error: OfflineOutboxFailure
    ) throws {
        guard accountID > 0 else { throw OfflineOutboxStoreError.accountMismatch }
        try update(accountID: accountID, operationID: operationID) { entry in
            entry.state = .permanentFailure
            entry.attemptCount += 1
            entry.lastAttemptAt = error.occurredAt
            entry.nextAttemptAt = nil
            entry.failure = error
        }
    }

    /// Allows an explicit user retry after a permanent server validation
    /// failure has been corrected or acknowledged.
    func retryPermanentFailure(
        accountID: MemberID,
        operationID: UUID,
        now: Date = .now
    ) throws {
        guard accountID > 0 else { throw OfflineOutboxStoreError.accountMismatch }
        try update(accountID: accountID, operationID: operationID) { entry in
            entry.state = .pending
            entry.nextAttemptAt = now
            entry.failure = nil
        }
    }

    /// A successful server response removes the durable operation. Repeating
    /// this call is intentionally a no-op to make sync idempotent.
    func markSucceeded(accountID: MemberID, operationID: UUID) throws {
        guard accountID > 0 else { throw OfflineOutboxStoreError.accountMismatch }
        try withOpenAccount(accountID) {
            guard var file = loadFile(accountID: accountID) else { return }
            file.entries.removeAll { $0.operationID == operationID }
            try saveFile(file, accountID: accountID)
        }
    }

    /// Removes only the queue file. The cache store owns the enclosing account
    /// directory and can therefore be purged independently.
    func purge(accountID: MemberID) throws {
        guard accountID > 0 else { throw OfflineOutboxStoreError.accountMismatch }
        writeBarrier.close(accountID: accountID)
        try fileSystem.removeItem(at: outboxURL(accountID: accountID))
    }

    func purgeAll() async throws {
        writeBarrier.closeAll()
        try fileSystem.removeItem(at: rootURL)
    }

    /// Reopens an account after the authenticated session has been restored.
    /// Purge intentionally leaves a tombstone so stale in-flight work cannot
    /// recreate the account directory until this explicit boundary is crossed.
    func reopen(accountID: MemberID) async {
        writeBarrier.reopen(accountID: accountID)
    }

    func reopenAll() async {
        writeBarrier.reopenAll()
    }

    private struct File: Codable, Equatable, Sendable {
        let schemaVersion: Int
        let accountID: MemberID
        var entries: [OfflineOutboxEntry]

        var isCurrentSchema: Bool {
            schemaVersion == OfflineStorageConstants.schemaVersion
        }
    }

    private func enqueue(
        accountID: MemberID,
        payload: OfflineOutboxPayload,
        operationID: UUID,
        now: Date
    ) throws -> OfflineOutboxEntry {
        guard accountID > 0 else { throw OfflineOutboxStoreError.accountMismatch }
        var file = loadFile(accountID: accountID) ?? File(
            schemaVersion: OfflineStorageConstants.schemaVersion,
            accountID: accountID,
            entries: []
        )
        if let existing = file.entries.first(where: { $0.operationID == operationID }) {
            guard existing.payload == payload else {
                throw OfflineOutboxStoreError.operationConflict
            }
            return existing
        }

        let entry = OfflineOutboxEntry(
            operationID: operationID,
            accountID: accountID,
            payload: payload,
            createdAt: now,
        )
        file.entries.append(entry)
        try saveFile(file, accountID: accountID)
        return entry
    }

    private func update(
        accountID: MemberID,
        operationID: UUID,
        mutate: (inout OfflineOutboxEntry) -> Void
    ) throws {
        try withOpenAccount(accountID) {
            guard var file = loadFile(accountID: accountID),
                  let index = file.entries.firstIndex(where: { $0.operationID == operationID })
            else { throw OfflineOutboxStoreError.operationNotFound }
            mutate(&file.entries[index])
            try saveFile(file, accountID: accountID)
        }
    }

    private func loadFile(accountID: MemberID) -> File? {
        guard accountID > 0 else { return nil }
        let url = outboxURL(accountID: accountID)
        guard fileSystem.fileExists(at: url) else { return nil }
        do {
            var file = try decoder.decode(File.self, from: fileSystem.read(from: url))
            // A file-level account/schema mismatch is a security boundary:
            // never salvage data that may belong to another account.
            guard file.accountID == accountID, file.isCurrentSchema else {
                discardInvalidFile(at: url)
                return nil
            }
            // Normalize decoded payloads and enforce account ownership before
            // handing entries to the sync coordinator.
            let normalizedEntries = file.entries
                .filter { $0.accountID == accountID }
                .compactMap(normalizedEntry)
            if normalizedEntries != file.entries {
                file.entries = normalizedEntries
                guard !normalizedEntries.isEmpty else {
                    discardInvalidFile(at: url)
                    return nil
                }
                // Rewrite only after decoding succeeded. Data.write(.atomic)
                // preserves the valid pending operations if the process is
                // interrupted during salvage.
                try? saveFile(file, accountID: accountID)
            }
            guard normalizedEntries.allSatisfy({ $0.accountID == accountID }) else {
                // Defensive check for future payload migrations.
                discardInvalidFile(at: url)
                return nil
            }
            file.entries = normalizedEntries
            return file
        } catch {
            discardInvalidFile(at: url)
            return nil
        }
    }

    private func saveFile(_ file: File, accountID: MemberID) throws {
        guard file.accountID == accountID, file.isCurrentSchema else {
            throw OfflineOutboxStoreError.accountMismatch
        }
        let data: Data
        do {
            data = try encoder.encode(file)
        } catch {
            throw OfflineOutboxStoreError.encodingFailed
        }
        let url = outboxURL(accountID: accountID)
        try fileSystem.createDirectory(at: url.deletingLastPathComponent())
        try fileSystem.write(data, to: url)
    }

    private func withOpenAccount<Value>(
        _ accountID: MemberID,
        operation: () throws -> Value
    ) throws -> Value {
        do {
            return try writeBarrier.withOpenAccount(accountID, operation)
        } catch OfflineWriteBarrierError.accountClosed {
            throw OfflineOutboxStoreError.accountClosed
        }
    }

    private func outboxURL(accountID: MemberID) -> URL {
        rootURL
            .appending(path: "accounts/\(accountID)", directoryHint: .isDirectory)
            .appending(path: "outbox.json")
    }

    private func discardInvalidFile(at url: URL) {
        try? fileSystem.removeItem(at: url)
    }

    private func normalizedEntry(_ entry: OfflineOutboxEntry) -> OfflineOutboxEntry? {
        switch entry.payload {
        case .scheduleCreate(let request):
            guard request.id == nil,
                  request.memberId == entry.accountID,
                  request.tagFriendIds?.isEmpty != false,
                  request.attachmentSessionId == nil,
                  request.orderedAttachmentIds.isEmpty,
                  !request.aiTimeParsingRequested
            else { return nil }
            guard let request = try? scheduleRequest(request)
            else { return nil }
            return OfflineOutboxEntry(
                operationID: entry.operationID,
                accountID: entry.accountID,
                payload: .scheduleCreate(request),
                createdAt: entry.createdAt,
                state: entry.state,
                attemptCount: entry.attemptCount,
                lastAttemptAt: entry.lastAttemptAt,
                nextAttemptAt: entry.nextAttemptAt,
                failure: entry.failure
            )
        case .todoCreate(let request):
            guard request.tagFriendIds?.isEmpty != false,
                  request.attachmentSessionId == nil,
                  request.orderedAttachmentIds.isEmpty
            else { return nil }
            guard let request = try? todoRequest(request)
            else { return nil }
            return OfflineOutboxEntry(
                operationID: entry.operationID,
                accountID: entry.accountID,
                payload: .todoCreate(request),
                createdAt: entry.createdAt,
                state: entry.state,
                attemptCount: entry.attemptCount,
                lastAttemptAt: entry.lastAttemptAt,
                nextAttemptAt: entry.nextAttemptAt,
                failure: entry.failure
            )
        }
    }

    private func scheduleRequest(
        _ request: ScheduleSaveDTO
    ) throws -> ScheduleSaveDTO {
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

    private func todoRequest(
        _ request: TodoRequest
    ) throws -> TodoRequest {
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

    private func sortEntries(
        _ lhs: OfflineOutboxEntry,
        _ rhs: OfflineOutboxEntry
    ) -> Bool {
        if lhs.createdAt == rhs.createdAt {
            return lhs.operationID.uuidString < rhs.operationID.uuidString
        }
        return lhs.createdAt < rhs.createdAt
    }
}

extension OfflineOutboxStore: OfflineOutboxProviding {}
