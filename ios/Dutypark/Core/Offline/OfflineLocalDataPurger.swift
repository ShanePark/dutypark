import Foundation

/// Connects the session boundary to both durable offline stores. Account
/// logout only removes that account's directory; a nil member ID is reserved
/// for a full local-data reset and removes the entire Offline root.
nonisolated struct OfflineLocalDataPurger: SessionLocalDataPurging, Sendable {
    static let shared = OfflineLocalDataPurger()

    private let cache: any OfflineCacheProviding
    private let outbox: any OfflineOutboxProviding
    private let temporaryFileStore: any AttachmentTemporaryFilePurging

    nonisolated init(
        cache: any OfflineCacheProviding = OfflineCacheStore.shared,
        outbox: any OfflineOutboxProviding = OfflineOutboxStore.shared,
        temporaryFileStore: any AttachmentTemporaryFilePurging = AttachmentTemporaryFileStore.shared
    ) {
        self.cache = cache
        self.outbox = outbox
        self.temporaryFileStore = temporaryFileStore
    }

    nonisolated func purgeLocalData(for memberID: Int64?) async {
        // Private attachment downloads live outside the durable offline stores.
        // Purge them for every session boundary, including a full reset.
        await temporaryFileStore.purge()

        if let memberID {
            guard memberID > 0 else { return }
            do {
                try await outbox.purge(accountID: memberID)
            } catch {
                // Best effort; still clear the independent cache below.
            }
            do {
                try await cache.purge(accountID: memberID)
            } catch {
                // Session teardown must remain best-effort.
            }
        } else {
            do {
                try await outbox.purgeAll()
            } catch {
                // Still attempt the cache root below.
            }
            do {
                try await cache.purgeAll()
            } catch {
                // Session teardown must remain best-effort.
            }
        }
    }

    /// Reopens the write barrier after authentication succeeds. This must be
    /// called by the session boundary for the newly active account; purge is
    /// deliberately a persistent tombstone against stale in-flight work.
    nonisolated func reopenLocalData(for memberID: Int64?) async {
        if let memberID {
            guard memberID > 0 else { return }
            await outbox.reopen(accountID: memberID)
            await cache.reopen(accountID: memberID)
        } else {
            await outbox.reopenAll()
            await cache.reopenAll()
        }
    }
}
