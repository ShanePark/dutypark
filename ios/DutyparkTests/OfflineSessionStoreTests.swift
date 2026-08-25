import Foundation
import XCTest
@testable import Dutypark

final class OfflineSessionStoreTests: XCTestCase {
    func testSnapshotRoundTripsAndDoesNotPersistCredentials() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let now = Date(timeIntervalSince1970: 1_000)
        let store = OfflineSessionStore(
            directoryURL: fixture.directory,
            now: { now }
        )

        try await store.save(Self.member, at: now)
        let restored = await store.load(at: now)

        XCTAssertEqual(restored, Self.member)
        let data = try Data(contentsOf: fixture.fileURL)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertNil(json["accessToken"])
        XCTAssertNil(json["refreshToken"])
        XCTAssertNil(json["provider"])
        XCTAssertNil(json["providerId"])
    }

    func testExpiredSnapshotIsRejectedAndPurged() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let savedAt = Date(timeIntervalSince1970: 1_000)
        let store = OfflineSessionStore(
            directoryURL: fixture.directory,
            now: { savedAt.addingTimeInterval(OfflineSessionStore.ttl + 1) }
        )

        try await store.save(Self.member, at: savedAt)
        let restored = await store.load()
        XCTAssertNil(restored)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileURL.path))
    }

    func testImpersonatingSnapshotIsNeverStoredOrLoaded() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let store = OfflineSessionStore(directoryURL: fixture.directory)
        let impersonating = LoginMember(
            id: 2,
            email: nil,
            name: "Managed",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: true,
            originalMemberId: 1
        )

        try await store.save(impersonating)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileURL.path))
    }

    func testPurgeRemovesSnapshot() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let store = OfflineSessionStore(directoryURL: fixture.directory)

        try await store.save(Self.member)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.fileURL.path))

        await store.purge()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.fileURL.path))
        let restored = await store.load()
        XCTAssertNil(restored)
    }

    func testSnapshotAndDirectoryUseFirstUnlockFileProtection() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let store = OfflineSessionStore(directoryURL: fixture.directory)

        try await store.save(Self.member)

        let fileAttributes = try FileManager.default.attributesOfItem(
            atPath: fixture.fileURL.path
        )
        let directoryAttributes = try FileManager.default.attributesOfItem(
            atPath: fixture.directory.path
        )

        guard let fileProtection = fileAttributes[.protectionKey] as? FileProtectionType,
              let directoryProtection = directoryAttributes[.protectionKey] as? FileProtectionType
        else {
            throw XCTSkip(
                "The simulator filesystem does not expose iOS file-protection attributes."
            )
        }
        XCTAssertEqual(
            fileProtection,
            .completeUntilFirstUserAuthentication
        )
        XCTAssertEqual(
            directoryProtection,
            .completeUntilFirstUserAuthentication
        )
    }

    private func makeFixture() throws -> (directory: URL, fileURL: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-offline-session-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return (directory, directory.appendingPathComponent("offline-session.json"))
    }

    private static let member = LoginMember(
        id: 1,
        email: "test@duty.park",
        name: "Test",
        teamId: 2,
        team: "Dutypark",
        isAdmin: false,
        isImpersonating: false,
        originalMemberId: nil
    )
}
