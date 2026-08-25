import Foundation

nonisolated enum OfflineCacheStoreError: Error, Equatable, Sendable {
    case accountMismatch
    case accountClosed
    case invalidSnapshot
    case invalidMonthShape
    case encodingFailed
}

/// Dependency-injection surface for view models and sync coordinators. The
/// concrete actor below is the production implementation; tests can provide
/// another actor with the same async API.
nonisolated protocol OfflineCacheProviding: Sendable {
    func saveAccount(_ snapshot: OfflineAccountSnapshot) async throws
    func saveAccount(
        member: LoginMember,
        friends: [FriendDTO],
        dDays: [DDayDTO],
        now: Date
    ) async throws
    func loadAccount(memberID: MemberID) async -> OfflineAccountSnapshot?
    func saveMonth(_ snapshot: OfflineMonthSnapshot) async throws
    func loadMonth(accountID: MemberID, key: OfflineMonthKey) async -> OfflineMonthSnapshot?
    func loadCachedMonths(accountID: MemberID, around current: OfflineMonthKey) async -> [OfflineMonthSnapshot]
    func saveTodoBoard(accountID: MemberID, board: TodoBoardDTO, now: Date) async throws
    func loadTodoBoard(accountID: MemberID) async -> TodoBoardDTO?
    func searchSchedules(accountID: MemberID, query: String, keys: [OfflineMonthKey]?) async -> [ScheduleSearchResultDTO]
    func purge(accountID: MemberID) async throws
    func purgeAll() async throws
    func pruneMonths(accountID: MemberID, around current: OfflineMonthKey) async throws
    func reopen(accountID: MemberID) async
    func reopenAll() async
}

extension OfflineCacheProviding {
    /// Test doubles and lightweight feature adapters can opt into only the
    /// read/write operations they need. Production OfflineCacheStore provides
    /// the destructive maintenance operations below.
    func purgeAll() async throws {}
    func pruneMonths(accountID: MemberID, around current: OfflineMonthKey) async throws {}
    func reopen(accountID: MemberID) async {}
    func reopenAll() async {}
}

/// Durable, account-scoped cache for the read-only offline experience.
///
/// Every public operation is serialized by this actor. Callers can therefore
/// refresh a month and render a cached month concurrently without racing a
/// JSON replacement on disk.
actor OfflineCacheStore {
    static let shared = OfflineCacheStore()

    let rootURL: URL
    let rangePolicy: OfflineCacheRangePolicy
    private let fileSystem: any OfflineFileSystem
    private let writeBarrier: OfflineWriteBarrier
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let now: @Sendable () -> Date

    init(
        rootURL: URL = OfflineCacheStore.defaultRootURL(),
        fileSystem: any OfflineFileSystem = LocalOfflineFileSystem.shared,
        rangePolicy: OfflineCacheRangePolicy = .rollingThirteenMonths,
        now: @escaping @Sendable () -> Date = { .now },
        writeBarrier: OfflineWriteBarrier? = nil
    ) {
        self.rootURL = rootURL
        self.fileSystem = fileSystem
        self.writeBarrier = writeBarrier
            ?? OfflineWriteBarrierRegistry.shared.barrier(for: rootURL)
        self.rangePolicy = rangePolicy
        self.now = now

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    nonisolated static func defaultRootURL(
        fileManager: FileManager = .default
    ) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return applicationSupport
            .appending(path: "Dutypark", directoryHint: .isDirectory)
            .appending(path: OfflineStorageConstants.rootDirectoryName, directoryHint: .isDirectory)
    }

    func saveAccount(_ snapshot: OfflineAccountSnapshot) throws {
        guard snapshot.memberID > 0 else { throw OfflineCacheStoreError.accountMismatch }
        guard snapshot.isCurrentSchema else { throw OfflineCacheStoreError.invalidSnapshot }
        try withOpenAccount(snapshot.memberID) {
            try write(snapshot, to: accountURL(memberID: snapshot.memberID))
        }
    }

    func saveAccount(
        member: MemberDTO,
        friends: [FriendDTO] = [],
        dDays: [DDayDTO] = [],
        now: Date = .now
    ) throws {
        try saveAccount(
            OfflineAccountSnapshot(
                member: member,
                friends: friends,
                dDays: dDays,
                storedAt: now
            )
        )
    }

    func saveAccount(
        member: LoginMember,
        friends: [FriendDTO] = [],
        dDays: [DDayDTO] = [],
        now: Date = .now
    ) throws {
        try saveAccount(
            OfflineAccountSnapshot(
                member: member,
                friends: friends,
                dDays: dDays,
                storedAt: now
            )
        )
    }

    /// A damaged or old-schema account is treated as a cache miss. This is
    /// intentional: stale local data must never prevent a fresh online login.
    func loadAccount(memberID: MemberID) -> OfflineAccountSnapshot? {
        guard memberID > 0 else { return nil }
        guard writeBarrier.isOpen(accountID: memberID) else { return nil }
        guard let snapshot: OfflineAccountSnapshot = read(
            from: accountURL(memberID: memberID)
        ) else { return nil }
        guard snapshot.memberID == memberID, snapshot.isCurrentSchema else {
            discardInvalidFile(at: accountURL(memberID: memberID))
            return nil
        }
        return snapshot
    }

    func saveMonth(_ snapshot: OfflineMonthSnapshot) throws {
        guard snapshot.accountID > 0 else {
            throw OfflineCacheStoreError.accountMismatch
        }
        guard snapshot.isCurrentSchema else {
            throw OfflineCacheStoreError.invalidMonthShape
        }
        try withOpenAccount(snapshot.accountID) {
            try write(
                snapshot,
                to: monthURL(accountID: snapshot.accountID, key: snapshot.key)
            )
            try pruneMonthsUnlocked(
                accountID: snapshot.accountID,
                around: OfflineMonthKey(date: now())
            )
        }
    }

    /// Corrupt, mismatched, and incompatible files are safely ignored.
    func loadMonth(
        accountID: MemberID,
        key: OfflineMonthKey
    ) -> OfflineMonthSnapshot? {
        guard accountID > 0 else { return nil }
        guard writeBarrier.isOpen(accountID: accountID) else { return nil }
        guard let snapshot: OfflineMonthSnapshot = read(
            from: monthURL(accountID: accountID, key: key)
        ) else { return nil }
        guard snapshot.accountID == accountID,
              snapshot.key == key,
              snapshot.isCurrentSchema
        else {
            discardInvalidFile(at: monthURL(accountID: accountID, key: key))
            return nil
        }
        return snapshot
    }

    func loadMonths(
        accountID: MemberID,
        keys: [OfflineMonthKey]
    ) -> [OfflineMonthSnapshot] {
        guard accountID > 0 else { return [] }
        guard writeBarrier.isOpen(accountID: accountID) else { return [] }
        return keys.compactMap { loadMonth(accountID: accountID, key: $0) }
            .sorted { $0.key < $1.key }
    }

    func loadCachedMonths(
        accountID: MemberID,
        around current: OfflineMonthKey
    ) -> [OfflineMonthSnapshot] {
        guard accountID > 0 else { return [] }
        return loadMonths(accountID: accountID, keys: rangePolicy.months(around: current))
    }

    /// Uses the injected clock for callers that want the store's current
    /// rolling window rather than supplying a month explicitly.
    func loadCachedMonths(accountID: MemberID) -> [OfflineMonthSnapshot] {
        loadCachedMonths(accountID: accountID, around: OfflineMonthKey(date: now()))
    }

    func saveTodoBoard(
        accountID: MemberID,
        board: TodoBoardDTO,
        now: Date = .now
    ) throws {
        guard accountID > 0 else { throw OfflineCacheStoreError.accountMismatch }
        let snapshot = OfflineTodoBoardSnapshot(
            accountID: accountID,
            board: board,
            storedAt: now
        )
        try withOpenAccount(accountID) {
            try write(snapshot, to: todoBoardURL(accountID: accountID))
        }
    }

    func loadTodoBoard(accountID: MemberID) -> TodoBoardDTO? {
        guard accountID > 0 else { return nil }
        guard writeBarrier.isOpen(accountID: accountID) else { return nil }
        guard let snapshot: OfflineTodoBoardSnapshot = read(
            from: todoBoardURL(accountID: accountID)
        ) else { return nil }
        guard snapshot.accountID == accountID, snapshot.isCurrentSchema else {
            discardInvalidFile(at: todoBoardURL(accountID: accountID))
            return nil
        }
        return snapshot.board
    }

    /// Deletes the account directory, including cached reads and queued writes.
    /// OutboxStore is separately purged by its owner; this method remains
    /// intentionally scoped to cache files only.
    func purge(accountID: MemberID) throws {
        guard accountID > 0 else { throw OfflineCacheStoreError.accountMismatch }
        writeBarrier.close(accountID: accountID)
        try fileSystem.removeItem(at: accountDirectory(memberID: accountID))
    }

    /// Removes month files outside the configured rolling range. This is
    /// explicit so callers can run maintenance after a prefetch batch and so
    /// tests can inject a deterministic current date.
    func pruneMonths(
        accountID: MemberID,
        around current: OfflineMonthKey
    ) async throws {
        guard accountID > 0 else { throw OfflineCacheStoreError.accountMismatch }
        try withOpenAccount(accountID) {
            try pruneMonthsUnlocked(accountID: accountID, around: current)
        }
    }

    /// Deletes all account caches under the offline root. The outbox store
    /// shares this root and exposes the same operation for its own seam.
    func purgeAll() async throws {
        writeBarrier.closeAll()
        try fileSystem.removeItem(at: rootURL)
    }

    /// Reopens an account after the authenticated session has been restored.
    /// Purge leaves a tombstone so stale in-flight writes cannot recreate the
    /// account directory until this explicit session boundary is crossed.
    func reopen(accountID: MemberID) async {
        writeBarrier.reopen(accountID: accountID)
    }

    func reopenAll() async {
        writeBarrier.reopenAll()
    }

    /// Searches all currently retained month files unless an explicit month
    /// set is supplied. The API search result shape is reused by the calendar
    /// UI, while the source schedules remain fully available in month snapshots.
    func searchSchedules(
        accountID: MemberID,
        query: String,
        keys: [OfflineMonthKey]? = nil
    ) -> [ScheduleSearchResultDTO] {
        guard accountID > 0 else { return [] }
        guard writeBarrier.isOpen(accountID: accountID) else { return [] }
        let selectedKeys = keys ?? rangePolicy.months(around: OfflineMonthKey(date: now()))
        var seenIDs = Set<ScheduleID>()
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return loadMonths(accountID: accountID, keys: selectedKeys)
            .flatMap(\.schedules)
            .flatMap { $0 }
            .filter { schedule in
                guard seenIDs.insert(schedule.id).inserted else { return false }
                guard !normalizedQuery.isEmpty else { return true }
                return schedule.content.localizedCaseInsensitiveContains(normalizedQuery)
                    || schedule.description.localizedCaseInsensitiveContains(normalizedQuery)
                    || schedule.owner.localizedCaseInsensitiveContains(normalizedQuery)
            }
            .sorted {
                if $0.startDateTime.rawValue == $1.startDateTime.rawValue {
                    return $0.content.localizedCaseInsensitiveCompare($1.content) == .orderedAscending
                }
                return $0.startDateTime.rawValue < $1.startDateTime.rawValue
            }
            .map { schedule in
                ScheduleSearchResultDTO(
                    content: schedule.content,
                    startDateTime: schedule.startDateTime,
                    endDateTime: schedule.endDateTime,
                    visibility: schedule.visibility ?? .privateAccess,
                    isTagged: schedule.isTagged,
                    author: schedule.owner
                )
            }
    }

    private func monthKey(from url: URL) -> OfflineMonthKey? {
        let stem = url.deletingPathExtension().lastPathComponent
        let components = stem.split(separator: "-", omittingEmptySubsequences: true)
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]),
              (1...12).contains(month)
        else { return nil }
        return OfflineMonthKey(year: year, month: month)
    }

    private func accountDirectory(memberID: MemberID) -> URL {
        rootURL.appending(path: "accounts/\(memberID)", directoryHint: .isDirectory)
    }

    private func accountURL(memberID: MemberID) -> URL {
        accountDirectory(memberID: memberID).appending(path: "account.json")
    }

    private func monthsDirectory(accountID: MemberID) -> URL {
        accountDirectory(memberID: accountID)
            .appending(path: "months", directoryHint: .isDirectory)
    }

    private func monthURL(accountID: MemberID, key: OfflineMonthKey) -> URL {
        monthsDirectory(accountID: accountID).appending(path: key.fileName)
    }

    private func todoBoardURL(accountID: MemberID) -> URL {
        accountDirectory(memberID: accountID).appending(path: "todo-board.json")
    }

    private func write<Value: Encodable>(_ value: Value, to url: URL) throws {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw OfflineCacheStoreError.encodingFailed
        }
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
            throw OfflineCacheStoreError.accountClosed
        }
    }

    private func pruneMonthsUnlocked(
        accountID: MemberID,
        around current: OfflineMonthKey
    ) throws {
        let allowed = Set(rangePolicy.months(around: current))
        for url in fileSystem.contentsOfDirectory(
            at: monthsDirectory(accountID: accountID)
        ) where url.pathExtension == "json" {
            guard let key = monthKey(from: url), !allowed.contains(key) else { continue }
            try fileSystem.removeItem(at: url)
        }
    }

    private func read<Value: Decodable>(from url: URL) -> Value? {
        guard fileSystem.fileExists(at: url) else { return nil }
        do {
            return try decoder.decode(Value.self, from: fileSystem.read(from: url))
        } catch {
            discardInvalidFile(at: url)
            return nil
        }
    }

    private func discardInvalidFile(at url: URL) {
        try? fileSystem.removeItem(at: url)
    }
}

extension OfflineCacheStore: OfflineCacheProviding {}
