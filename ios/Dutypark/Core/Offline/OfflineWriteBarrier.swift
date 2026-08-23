import Foundation

nonisolated enum OfflineWriteBarrierError: Error, Equatable, Sendable {
    case accountClosed
}

/// A synchronous, process-local write barrier shared by cache and outbox
/// stores for the same root. The lock is held across the complete filesystem
/// mutation, so a purge cannot close an account between an operation's open
/// check and its atomic write.
nonisolated final class OfflineWriteBarrier: @unchecked Sendable {
    private let lock = NSLock()
    private var closedAccounts = Set<MemberID>()
    private var allAccountsClosed = false
    private var reopenedAccounts = Set<MemberID>()

    init() {}

    var isAllClosed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return allAccountsClosed
    }

    func isOpen(accountID: MemberID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if allAccountsClosed {
            return reopenedAccounts.contains(accountID)
        }
        return !closedAccounts.contains(accountID)
    }

    func withOpenAccount<Value>(
        _ accountID: MemberID,
        _ operation: () throws -> Value
    ) throws -> Value {
        lock.lock()
        defer { lock.unlock() }
        let isOpen = allAccountsClosed
            ? reopenedAccounts.contains(accountID)
            : !closedAccounts.contains(accountID)
        guard accountID > 0, isOpen else {
            throw OfflineWriteBarrierError.accountClosed
        }
        return try operation()
    }

    func close(accountID: MemberID) {
        guard accountID > 0 else { return }
        lock.lock()
        if allAccountsClosed {
            reopenedAccounts.remove(accountID)
        } else {
            closedAccounts.insert(accountID)
        }
        lock.unlock()
    }

    func closeAll() {
        lock.lock()
        allAccountsClosed = true
        closedAccounts.removeAll()
        reopenedAccounts.removeAll()
        lock.unlock()
    }

    func reopen(accountID: MemberID) {
        guard accountID > 0 else { return }
        lock.lock()
        if allAccountsClosed {
            reopenedAccounts.insert(accountID)
        } else {
            closedAccounts.remove(accountID)
        }
        lock.unlock()
    }

    func reopenAll() {
        lock.lock()
        allAccountsClosed = false
        closedAccounts.removeAll()
        reopenedAccounts.removeAll()
        lock.unlock()
    }
}

/// Default stores are constructed independently but must still share a
/// barrier when they point at the same account root. UUID-based test roots
/// naturally receive isolated barriers.
nonisolated final class OfflineWriteBarrierRegistry: @unchecked Sendable {
    static let shared = OfflineWriteBarrierRegistry()

    private let lock = NSLock()
    private var barriers: [String: OfflineWriteBarrier] = [:]

    init() {}

    func barrier(for rootURL: URL) -> OfflineWriteBarrier {
        let key = rootURL.standardizedFileURL.path
        lock.lock()
        defer { lock.unlock() }
        if let barrier = barriers[key] { return barrier }
        let barrier = OfflineWriteBarrier()
        barriers[key] = barrier
        return barrier
    }
}
