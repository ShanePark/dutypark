import Foundation
import Testing
import UIKit
@testable import Dutypark

@MainActor
@Suite(.serialized)
struct AttachmentTemporaryFileStoreTests {
    @Test
    func purgeRemovesDownloadedPrivateFiles() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AttachmentTemporaryFileStore(directoryURL: directory)
        let attachmentID = UUID()

        let url = try store.write(
            Data("private attachment".utf8),
            for: attachmentID,
            filename: "review.pdf"
        )
        #expect(FileManager.default.fileExists(atPath: url.path))

        await store.purge()

        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test
    func sessionPurgeAlsoRemovesDownloadedPrivateFiles() async throws {
        let offlineRoot = try temporaryDirectory()
        let attachmentRoot = try temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: offlineRoot)
            try? FileManager.default.removeItem(at: attachmentRoot)
        }

        let store = AttachmentTemporaryFileStore(directoryURL: attachmentRoot)
        let url = try store.write(
            Data("private attachment".utf8),
            for: UUID(),
            filename: "review.pdf"
        )
        let purger = OfflineLocalDataPurger(
            cache: OfflineCacheStore(rootURL: offlineRoot),
            outbox: OfflineOutboxStore(rootURL: offlineRoot),
            temporaryFileStore: store
        )

        await purger.purgeLocalData(for: 42)

        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(!FileManager.default.fileExists(atPath: attachmentRoot.path))
    }

    @Test
    func highResolutionHEICIsDownsampledBeforeJPEGEncoding() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-heic-\(UUID().uuidString)")
            .appendingPathExtension("heic")
        defer { try? FileManager.default.removeItem(at: url) }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 3_000, height: 2_500))
        let source = renderer.pngData { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3_000, height: 2_500))
        }
        try source.write(to: url, options: .atomic)

        let file = try AttachmentFileLoader.load(from: url)
        let image = try #require(UIImage(data: file.data))

        let width = try #require(image.cgImage?.width)
        let height = try #require(image.cgImage?.height)
        #expect(max(width, height) <= AttachmentUploadPolicy.maxImagePixelSize)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-attachment-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
