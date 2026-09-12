import Foundation

/// The widget and the containing app exchange only this small, versioned value.
/// Keep this file Foundation-only so both targets can compile it without sharing
/// the app's feature models or authentication code.
nonisolated struct DutyparkWidgetDay: Codable, Equatable, Sendable, Identifiable {
    /// A local calendar date in `yyyy-MM-dd` form.
    let date: String
    /// Gregorian weekday using the same Sunday-first convention as the app calendar:
    /// Sunday is 1 and Saturday is 7.
    let weekday: Int
    let isCurrentMonth: Bool
    /// The already resolved display label, including explicit server abbreviations.
    let abbreviation: String?
    let colorHex: String?
    let isOff: Bool
    /// The first schedule returned for this date, shortened for the compact
    /// monthly surface. `nil` means that this date has no schedules.
    let scheduleContent: String?
    /// Total schedules returned for this date, including the representative
    /// schedule above.
    let scheduleCount: Int

    var id: String { date }

    init(
        date: String,
        weekday: Int,
        isCurrentMonth: Bool,
        abbreviation: String?,
        colorHex: String?,
        isOff: Bool,
        scheduleContent: String? = nil,
        scheduleCount: Int = 0
    ) {
        self.date = date
        self.weekday = weekday
        self.isCurrentMonth = isCurrentMonth
        self.abbreviation = abbreviation
        self.colorHex = colorHex
        self.isOff = isOff
        self.scheduleContent = scheduleContent
        self.scheduleCount = scheduleCount
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case weekday
        case isCurrentMonth
        case abbreviation
        case colorHex
        case isOff
        case scheduleContent
        case scheduleCount
    }

    /// New schedule fields are optional on decode so snapshots written by the
    /// previous monthly widget remain readable after an app update.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        weekday = try container.decode(Int.self, forKey: .weekday)
        isCurrentMonth = try container.decode(Bool.self, forKey: .isCurrentMonth)
        abbreviation = try container.decodeIfPresent(String.self, forKey: .abbreviation)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        isOff = try container.decode(Bool.self, forKey: .isOff)
        scheduleContent = try container.decodeIfPresent(String.self, forKey: .scheduleContent)
        scheduleCount = try container.decodeIfPresent(Int.self, forKey: .scheduleCount) ?? 0
    }
}

nonisolated enum DutyparkWidgetTodoStatus: String, Codable, Equatable, Sendable {
    case todo = "TODO"
    case inProgress = "IN_PROGRESS"
}

/// Keeps the widget's compact schedule label consistent with Swift's user-
/// visible character boundaries while leaving the persisted schedule content
/// untouched for accessibility and future presentation changes.
nonisolated enum DutyparkWidgetScheduleText {
    static func shortened(_ content: String) -> String {
        content.count > 5 ? String(content.prefix(5)) + "..." : content
    }
}

/// Presentation-only Todo data shared with the extension. Completed cards are
/// deliberately not representable in this contract.
nonisolated struct DutyparkWidgetTodoItem: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let status: DutyparkWidgetTodoStatus

    init(id: String, title: String, status: DutyparkWidgetTodoStatus) {
        self.id = id
        self.title = title
        self.status = status
    }

    var isInProgress: Bool { status == .inProgress }
}

/// Short alias for callers that prefer the singular Todo model name.
typealias DutyparkWidgetTodo = DutyparkWidgetTodoItem

nonisolated struct DutyparkWidgetTodoSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let accountID: Int64
    let todos: [DutyparkWidgetTodoItem]
    let updatedAt: Date

    init(
        accountID: Int64,
        todos: [DutyparkWidgetTodoItem],
        updatedAt: Date = .now,
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.accountID = accountID
        self.todos = todos
        self.updatedAt = updatedAt
    }

    var isCurrentSchema: Bool {
        schemaVersion == Self.currentSchemaVersion
            && accountID > 0
            && todos.allSatisfy { todo in
                !todo.id.isEmpty
                    && !todo.title.isEmpty
            }
    }
}

/// A single account's refreshed month for the monthly widget.
/// The app replaces this month atomically after a successful authenticated
/// refresh; the widget never needs to hold credentials or call the API.
nonisolated struct DutyparkWidgetSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let accountID: Int64
    let year: Int
    let month: Int
    let days: [DutyparkWidgetDay]
    let updatedAt: Date

    init(
        accountID: Int64,
        year: Int,
        month: Int,
        days: [DutyparkWidgetDay],
        updatedAt: Date = .now,
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.accountID = accountID
        self.year = year
        self.month = month
        self.days = days
        self.updatedAt = updatedAt
    }

    var isCurrentSchema: Bool {
        schemaVersion == Self.currentSchemaVersion
            && accountID > 0
            && year > 0
            && (1...12).contains(month)
            && days.count == 42
            && days.allSatisfy { day in
                (1...7).contains(day.weekday)
                    && !day.date.isEmpty
                    && day.scheduleCount >= 0
            }
    }
}

/// Shared identifiers are kept beside the wire format so the app and extension
/// cannot silently drift apart when one target is renamed.
nonisolated enum DutyparkWidgetKind {
    static let monthly = "DutyparkMonthlyWidget"
    static let todo = "DutyparkTodoWidget"
}

/// Synchronous, process-safe persistence for the app group snapshot.
///
/// The containing app calls `activate` when a verified session is published and
/// passes that session generation to every save. `clear` invalidates the current
/// generation before removing the file, so a late calendar request from a prior
/// account/session cannot recreate widget data after logout.
nonisolated final class DutyparkWidgetSnapshotStore: @unchecked Sendable {
    static let appGroupIdentifier = "group.io.github.shanepark.dutypark"
    private static let accountsDirectoryName = "accounts"
    private static let activeAccountFileName = "active-account.json"

    static let shared = DutyparkWidgetSnapshotStore()

    private let rootURL: URL?
    private let fileManager: FileManager
    private static let todoFileName = "todo.json"
    private let lock = NSLock()
    private var activeAccountID: Int64?
    private var activeSessionGeneration: UInt64?

    init(
        rootURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL ?? Self.defaultRootURL(fileManager: fileManager)
        self.fileManager = fileManager
    }

    nonisolated static func defaultRootURL(
        fileManager: FileManager = .default
    ) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// Binds future writes to the authenticated account/session. Existing data for
    /// another account is removed before the new session becomes active.
    func activate(accountID: Int64, sessionGeneration: UInt64) {
        guard accountID > 0 else { return }
        lock.lock()
        defer { lock.unlock() }

        if let existingAccountID = readActiveAccountIDUnlocked(), existingAccountID != accountID {
            removeAccountUnlocked(existingAccountID)
        }
        activeAccountID = accountID
        activeSessionGeneration = sessionGeneration
        writeActiveAccountIDUnlocked(accountID)
    }

    /// Invalidates writes from the previous authentication generation while
    /// retaining the last snapshot until session cleanup decides whether it
    /// belongs to the next authenticated account.
    func invalidateSession() {
        lock.lock()
        activeSessionGeneration = nil
        lock.unlock()
    }

    /// Reports whether a caller still owns the active authenticated binding.
    /// This closes the await boundary before a network request; `save` repeats
    /// the same guard when the response returns.
    func isActive(accountID: Int64, sessionGeneration: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeAccountID == accountID
            && activeSessionGeneration == sessionGeneration
    }

    /// Saves only when the account and authentication generation still match the
    /// active session. The result is false for a closed/missing app-group store or
    /// an obsolete async caller.
    @discardableResult
    func save(
        _ snapshot: DutyparkWidgetSnapshot,
        sessionGeneration: UInt64
    ) -> Bool {
        save(
            snapshot,
            sessionGeneration: sessionGeneration,
            onlyIfMissing: false
        )
    }

    /// Saves a cache migration only when this month has no valid widget
    /// snapshot. Network refreshes should use `save` so they can replace it.
    @discardableResult
    func saveIfMissing(
        _ snapshot: DutyparkWidgetSnapshot,
        sessionGeneration: UInt64
    ) -> Bool {
        save(
            snapshot,
            sessionGeneration: sessionGeneration,
            onlyIfMissing: true
        )
    }

    /// Saves the active Todo and in-progress cards for the current account.
    /// Completed cards are filtered by the builder before they reach this store,
    /// while the schema validator also rejects an unsupported status on decode.
    @discardableResult
    func saveTodo(
        _ snapshot: DutyparkWidgetTodoSnapshot,
        sessionGeneration: UInt64
    ) -> Bool {
        saveTodo(
            snapshot,
            sessionGeneration: sessionGeneration,
            onlyIfMissing: false
        )
    }

    /// Saves a cache migration only when no valid Todo snapshot exists for the
    /// active account. A cached board must not replace a newer online publish.
    @discardableResult
    func saveTodoIfMissing(
        _ snapshot: DutyparkWidgetTodoSnapshot,
        sessionGeneration: UInt64
    ) -> Bool {
        saveTodo(
            snapshot,
            sessionGeneration: sessionGeneration,
            onlyIfMissing: true
        )
    }

    @discardableResult
    private func saveTodo(
        _ snapshot: DutyparkWidgetTodoSnapshot,
        sessionGeneration: UInt64,
        onlyIfMissing: Bool
    ) -> Bool {
        guard snapshot.isCurrentSchema else { return false }
        lock.lock()
        defer { lock.unlock() }
        guard let activeAccountID,
              activeAccountID == snapshot.accountID,
              let activeSessionGeneration,
              activeSessionGeneration == sessionGeneration,
              let snapshotURL = todoURLUnlocked(accountID: snapshot.accountID)
        else { return false }

        do {
            if let existingSnapshot = readTodoUnlocked(from: snapshotURL) {
                let matchesSnapshot = existingSnapshot.isCurrentSchema
                    && existingSnapshot.accountID == snapshot.accountID
                if onlyIfMissing, matchesSnapshot {
                    return false
                }
                if matchesSnapshot,
                   existingSnapshot.updatedAt > snapshot.updatedAt {
                    return false
                }
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(snapshot)
            try fileManager.createDirectory(
                at: snapshotURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(
                to: snapshotURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    private func save(
        _ snapshot: DutyparkWidgetSnapshot,
        sessionGeneration: UInt64,
        onlyIfMissing: Bool
    ) -> Bool {
        guard snapshot.isCurrentSchema else { return false }
        lock.lock()
        defer { lock.unlock() }
        guard let activeAccountID,
              activeAccountID == snapshot.accountID,
              let activeSessionGeneration,
              activeSessionGeneration == sessionGeneration,
              let snapshotURL = monthURLUnlocked(
                  accountID: snapshot.accountID,
                  year: snapshot.year,
                  month: snapshot.month
              )
        else { return false }

        do {
            if let existing = readStoredSnapshotUnlocked(from: snapshotURL) {
                let existingSnapshot = existing.snapshot
                let matchesSnapshot = existingSnapshot.isCurrentSchema
                    && existingSnapshot.accountID == snapshot.accountID
                    && existingSnapshot.year == snapshot.year
                    && existingSnapshot.month == snapshot.month
                if onlyIfMissing, matchesSnapshot, existing.hasScheduleFields {
                    return false
                }
                if matchesSnapshot,
                   existingSnapshot.updatedAt > snapshot.updatedAt {
                    return false
                }
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(snapshot)
            try fileManager.createDirectory(
                at: snapshotURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: snapshotURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }

    /// Reads a valid snapshot synchronously for WidgetKit's non-async timeline API.
    func load() -> DutyparkWidgetSnapshot? {
        let components = Calendar.current.dateComponents([.year, .month], from: .now)
        return load(
            year: components.year ?? 1970,
            month: components.month ?? 1
        )
    }

    /// Reads a particular month for timeline entries that cross a calendar boundary.
    func load(year: Int, month: Int) -> DutyparkWidgetSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard let activeAccountID = readActiveAccountIDUnlocked(),
              let snapshotURL = monthURLUnlocked(
                  accountID: activeAccountID,
                  year: year,
                  month: month
              ),
              let snapshot = readUnlocked(from: snapshotURL),
              snapshot.accountID == activeAccountID,
              snapshot.year == year,
              snapshot.month == month,
              snapshot.isCurrentSchema
        else {
            return nil
        }
        return snapshot
    }

    /// WidgetKit calls the static form directly from the extension process,
    /// which has no authenticated app session to activate first.
    static func load() -> DutyparkWidgetSnapshot? {
        shared.load()
    }

    static func load(year: Int, month: Int) -> DutyparkWidgetSnapshot? {
        shared.load(year: year, month: month)
    }

    /// Reads the currently active account's Todo snapshot from the App Group.
    func loadTodo() -> DutyparkWidgetTodoSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard let activeAccountID = readActiveAccountIDUnlocked(),
              let snapshotURL = todoURLUnlocked(accountID: activeAccountID),
              let snapshot = readTodoUnlocked(from: snapshotURL),
              snapshot.accountID == activeAccountID,
              snapshot.isCurrentSchema
        else {
            return nil
        }
        return snapshot
    }

    static func loadTodo() -> DutyparkWidgetTodoSnapshot? {
        shared.loadTodo()
    }

    /// Invalidates the active session before deleting its snapshot. An account ID
    /// mismatch is ignored so an old cleanup callback cannot erase a new account.
    func clear(accountID: Int64? = nil) {
        lock.lock()
        defer { lock.unlock() }

        let persistedAccountID = readActiveAccountIDUnlocked()
        if let accountID {
            if let activeAccountID, activeAccountID != accountID {
                return
            }
            if activeAccountID == nil, persistedAccountID != accountID {
                return
            }
            removeAccountUnlocked(accountID)
        } else {
            removeAllAccountsUnlocked()
        }
        activeAccountID = nil
        activeSessionGeneration = nil
        removeActiveAccountFileUnlocked()
    }

    private func readUnlocked(from snapshotURL: URL) -> DutyparkWidgetSnapshot? {
        readStoredSnapshotUnlocked(from: snapshotURL)?.snapshot
    }

    private func readStoredSnapshotUnlocked(
        from snapshotURL: URL
    ) -> (snapshot: DutyparkWidgetSnapshot, hasScheduleFields: Bool)? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        guard let snapshot = try? decoder.decode(DutyparkWidgetSnapshot.self, from: data) else {
            return nil
        }
        return (
            snapshot: snapshot,
            hasScheduleFields: Self.hasScheduleFields(in: data)
        )
    }

    private static func hasScheduleFields(in data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let payload = object as? [String: Any],
              let days = payload["days"] as? [[String: Any]]
        else { return false }
        return days.contains { day in
            day["scheduleContent"] != nil || day["scheduleCount"] != nil
        }
    }

    private func readTodoUnlocked(from snapshotURL: URL) -> DutyparkWidgetTodoSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try? decoder.decode(DutyparkWidgetTodoSnapshot.self, from: data)
    }

    private func activeAccountURLUnlocked() -> URL? {
        rootURL?.appendingPathComponent(Self.activeAccountFileName, isDirectory: false)
    }

    private func accountsURLUnlocked() -> URL? {
        rootURL?.appendingPathComponent(Self.accountsDirectoryName, isDirectory: true)
    }

    private func accountURLUnlocked(_ accountID: Int64) -> URL? {
        accountsURLUnlocked()?.appendingPathComponent(String(accountID), isDirectory: true)
    }

    private func monthURLUnlocked(accountID: Int64, year: Int, month: Int) -> URL? {
        guard accountID > 0, year > 0, (1...12).contains(month) else { return nil }
        return accountURLUnlocked(accountID)?
            .appendingPathComponent("months", isDirectory: true)
            .appendingPathComponent(
                String(format: "%04d-%02d.json", year, month),
                isDirectory: false
            )
    }

    private func todoURLUnlocked(accountID: Int64) -> URL? {
        accountURLUnlocked(accountID)?.appendingPathComponent(
            Self.todoFileName,
            isDirectory: false
        )
    }

    private func readActiveAccountIDUnlocked() -> Int64? {
        if let activeAccountID { return activeAccountID }
        guard let activeAccountURL = activeAccountURLUnlocked(),
              let data = try? Data(contentsOf: activeAccountURL),
              let value = try? JSONDecoder().decode(ActiveAccount.self, from: data),
              value.accountID > 0
        else { return nil }
        return value.accountID
    }

    private func writeActiveAccountIDUnlocked(_ accountID: Int64) {
        guard let activeAccountURL = activeAccountURLUnlocked() else { return }
        do {
            let data = try JSONEncoder().encode(ActiveAccount(accountID: accountID))
            try fileManager.createDirectory(
                at: activeAccountURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(
                to: activeAccountURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        } catch {
            // Snapshot writes remain guarded by the in-memory account binding. A
            // malformed pointer is treated as a widget cache miss next process.
        }
    }

    private func removeAccountUnlocked(_ accountID: Int64) {
        guard let accountURL = accountURLUnlocked(accountID) else { return }
        try? fileManager.removeItem(at: accountURL)
    }

    private func removeAllAccountsUnlocked() {
        guard let accountsURL = accountsURLUnlocked() else { return }
        try? fileManager.removeItem(at: accountsURL)
    }

    private func removeActiveAccountFileUnlocked() {
        guard let activeAccountURL = activeAccountURLUnlocked() else { return }
        try? fileManager.removeItem(at: activeAccountURL)
    }

    private struct ActiveAccount: Codable, Sendable {
        let accountID: Int64
    }
}
