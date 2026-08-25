import Foundation

/// Narrow filesystem seam used by the offline stores. Keeping this protocol
/// small lets tests use a temporary root (or an in-memory implementation)
/// without weakening the production file protection and atomic-write policy.
nonisolated protocol OfflineFileSystem: Sendable {
    func createDirectory(at url: URL) throws
    func read(from url: URL) throws -> Data
    func write(_ data: Data, to url: URL) throws
    func removeItem(at url: URL) throws
    func fileExists(at url: URL) -> Bool
    func contentsOfDirectory(at url: URL) -> [URL]
}

nonisolated struct LocalOfflineFileSystem: OfflineFileSystem, Sendable {
    static let shared = Self()

    init() {}

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
    }

    func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func write(_ data: Data, to url: URL) throws {
        // Data.write(.atomic) writes a sibling temporary file and replaces the
        // destination, so a killed process cannot leave a partially encoded
        // JSON document behind.
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }

    func removeItem(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func contentsOfDirectory(at url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
    }
}
