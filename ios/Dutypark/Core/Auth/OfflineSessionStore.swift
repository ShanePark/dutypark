import Foundation

/// The portion of local session data that is safe to retain after the access
/// and refresh cookies have expired.  This protocol intentionally knows
/// nothing about feature caches or pending writes; those can be connected by
/// the session boundary without making authentication depend on them.
nonisolated protocol SessionLocalDataPurging: Sendable {
    /// `nil` means all locally retained account data (used when the server
    /// explicitly says the device is a guest or no account can be trusted).
    func purgeLocalData(for memberID: MemberID?) async
    /// Reopens the account-scoped offline write barrier after a trusted
    /// authentication succeeds. Purge leaves a tombstone so stale in-flight
    /// work cannot recreate a logged-out account directory.
    func reopenLocalData(for memberID: MemberID?) async
}

extension SessionLocalDataPurging {
    func reopenLocalData(for memberID: MemberID?) async {}
}

nonisolated struct NoopSessionLocalDataPurger: SessionLocalDataPurging {
    nonisolated init() {}

    nonisolated func purgeLocalData(for memberID: MemberID?) async {}
}

nonisolated protocol OfflineSessionStoring: Sendable {
    func save(_ member: LoginMember, at date: Date?) async throws
    func load(at date: Date?) async -> LoginMember?
    func purge() async
}

/// Persists the last server-verified regular member so a previously opened
/// account can still reach its local, read-only feature caches while the
/// network or API is unavailable.
actor OfflineSessionStore: OfflineSessionStoring {
    nonisolated static let ttl: TimeInterval = 30 * 24 * 60 * 60

    private static let fileName = "offline-session.json"
    private static let currentVersion = 1

    private let fileURL: URL
    private let ttl: TimeInterval
    private let now: @Sendable () -> Date
    private let fileManager: FileManager

    init(
        directoryURL: URL? = nil,
        fileURL: URL? = nil,
        ttl: TimeInterval = OfflineSessionStore.ttl,
        now: @escaping @Sendable () -> Date = { .now },
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.ttl = ttl
        self.now = now

        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = directoryURL ?? Self.defaultDirectory(fileManager: fileManager)
            self.fileURL = directory.appendingPathComponent(Self.fileName)
        }
    }

    nonisolated static let shared = OfflineSessionStore()

    func save(_ member: LoginMember, at date: Date? = nil) async throws {
        // A managed/impersonated identity must never become the identity used
        // by an offline session.  Remove an older regular snapshot as well so
        // the next launch cannot silently use stale account data.
        guard !member.isImpersonating, member.originalMemberId == nil else {
            await purge()
            return
        }

        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
            ]
        )
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directory.path
        )

        let snapshot = PersistedSnapshot(
            version: Self.currentVersion,
            member: member,
            savedAt: date ?? now()
        )
        let data = try JSONEncoder().encode(snapshot)

        // `.atomic` writes a temporary sibling and replaces the destination;
        // the protection option applies to the resulting file as it is moved
        // into place.  This file contains identity metadata only, never a
        // bearer token or an OAuth provider identifier.
        try data.write(
            to: fileURL,
            options: [
                .atomic,
                .completeFileProtectionUntilFirstUserAuthentication,
            ]
        )
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path
        )
    }

    func load(at date: Date? = nil) async -> LoginMember? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(PersistedSnapshot.self, from: data),
              snapshot.version == Self.currentVersion,
              !snapshot.member.isImpersonating,
              snapshot.member.originalMemberId == nil
        else {
            await purge()
            return nil
        }

        let age = (date ?? now()).timeIntervalSince(snapshot.savedAt)
        guard age >= 0, age <= ttl else {
            await purge()
            return nil
        }
        return snapshot.member
    }

    func purge() async {
        try? fileManager.removeItem(at: fileURL)
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return applicationSupport.appendingPathComponent("Dutypark", isDirectory: true)
    }
}

private extension OfflineSessionStore {
    nonisolated struct PersistedSnapshot: Codable, Sendable {
        let version: Int
        let member: LoginMember
        let savedAt: Date
    }
}
