import Foundation

/// The temporary files used to preview or share private attachments.  This is
/// deliberately separate from the offline cache: attachment downloads are
/// not durable app data and must be removed at every session boundary.
nonisolated protocol AttachmentTemporaryFilePurging: Sendable {
    func purge() async
}

nonisolated struct AttachmentTemporaryFileStore: AttachmentTemporaryFilePurging, Sendable {
    static let shared = Self()

    let directoryURL: URL

    init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL
            ?? FileManager.default.temporaryDirectory
                .appending(path: "DutyparkAttachments", directoryHint: .isDirectory)
    }

    func write(_ data: Data, for attachmentID: AttachmentID, filename: String) throws -> URL {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directoryURL.path
        )

        let url = directoryURL.appending(
            path: "\(attachmentID.uuidString)-\(safeFilename(filename))",
            directoryHint: .notDirectory
        )
        try data.write(
            to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
        return url
    }

    func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func purge() async {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    private func safeFilename(_ filename: String) -> String {
        let value = filename
            .components(separatedBy: .controlCharacters)
            .joined()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return value.isEmpty ? "attachment" : value
    }
}
