import Foundation
import CoreTransferable
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

nonisolated enum AttachmentFileLoader {
    static func load(from url: URL) throws -> AttachmentUploadFile {
        try load(
            from: url,
            startAccessing: { $0.startAccessingSecurityScopedResource() },
            stopAccessing: { $0.stopAccessingSecurityScopedResource() }
        )
    }

    static func load(
        from url: URL,
        startAccessing: (URL) -> Bool,
        stopAccessing: (URL) -> Void
    ) throws -> AttachmentUploadFile {
        let hasAccess = startAccessing(url)
        defer {
            if hasAccess {
                stopAccessing(url)
            }
        }

        return try loadFile(
            from: url,
            filename: url.lastPathComponent,
            type: UTType(filenameExtension: url.pathExtension)
        )
    }

    static func validateFileSize(at url: URL) throws {
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.fileSizeKey])
        } catch {
            throw AttachmentUploadError.unreadableFile
        }
        let fileSize = values.fileSize
            ?? ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber)
                .map(\.intValue)
        guard let fileSize else {
            throw AttachmentUploadError.unreadableFile
        }
        if fileSize >= AttachmentUploadPolicy.safeMaximumBytes {
            throw AttachmentUploadError.tooLarge
        }
    }

    static func load(from item: PhotosPickerItem) async throws -> AttachmentUploadFile {
        guard let imported = try await item.loadTransferable(
            type: ImportedAttachmentFile.self
        ) else {
            throw AttachmentUploadError.unreadableFile
        }
        let pathExtension = (imported.uploadFile.filename as NSString).pathExtension
        let suffix = pathExtension.isEmpty ? "jpg" : pathExtension
        return try AttachmentUploadFile(
            filename: "photo-\(UUID().uuidString).\(suffix)",
            contentType: imported.uploadFile.contentType,
            data: imported.uploadFile.data
        )
    }

    static func preparedFile(
        data: Data,
        filename: String,
        type: UTType?
    ) throws -> AttachmentUploadFile {
        if isHEIC(data: data, type: type, filename: filename) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                throw AttachmentUploadError.imageConversionFailed
            }
            return try preparedImageFile(
                source: source,
                filename: replacingExtension(of: filename, with: "jpg")
            )
        }

        return try AttachmentUploadFile(
            filename: filename,
            contentType: type?.preferredMIMEType ?? "application/octet-stream",
            data: data
        )
    }

    static func loadImportedFile(from url: URL) throws -> AttachmentUploadFile {
        try loadFile(
            from: url,
            filename: url.lastPathComponent,
            type: UTType(filenameExtension: url.pathExtension)
        )
    }

    private static func loadFile(
        from url: URL,
        filename: String,
        type: UTType?
    ) throws -> AttachmentUploadFile {
        // The resource metadata is checked while the selected provider file is
        // still file-backed. This rejects oversized files before materializing
        // their contents in memory.
        try validateFileSize(at: url)

        if isHEIC(
            at: url,
            type: type,
            filename: filename
        ) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                throw AttachmentUploadError.imageConversionFailed
            }
            return try preparedImageFile(
                source: source,
                filename: replacingExtension(of: filename, with: "jpg")
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw AttachmentUploadError.unreadableFile
        }

        return try preparedFile(
            data: data,
            filename: filename,
            type: type
        )
    }

    private static func preparedImageFile(
        source: CGImageSource,
        filename: String
    ) throws -> AttachmentUploadFile {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: AttachmentUploadPolicy.maxImagePixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ),
        let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.9)
        else {
            throw AttachmentUploadError.imageConversionFailed
        }
        return try AttachmentUploadFile(
            filename: filename,
            contentType: "image/jpeg",
            data: jpeg
        )
    }

    private static func isHEIC(
        at url: URL,
        type: UTType?,
        filename: String
    ) -> Bool {
        if isHEIC(data: Data(), type: type, filename: filename)
            || isHEIC(data: Data(), type: nil, filename: url.lastPathComponent) {
            return true
        }

        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            return false
        }
        defer { try? handle.close() }
        let header = (try? handle.read(upToCount: 12)) ?? Data()
        return isHEIC(data: header, type: nil, filename: url.lastPathComponent)
    }

    private static func isHEIC(data: Data, type: UTType?, filename: String) -> Bool {
        let extensionName = (filename as NSString).pathExtension.lowercased()
        return type?.conforms(to: .heic) == true
            || type?.identifier == "public.heif"
            || extensionName == "heic"
            || extensionName == "heif"
            || heifBrands.contains { data.dropFirst(4).starts(with: $0) }
    }

    private static let heifBrands = ["ftypheic", "ftypheix", "ftyphevc", "ftyphevx", "ftypmif1"]
        .map { Data($0.utf8) }

    private static func replacingExtension(of filename: String, with newExtension: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        return "\(base.isEmpty ? "photo" : base).\(newExtension)"
    }
}

nonisolated struct ImportedAttachmentFile: Transferable {
    let uploadFile: AttachmentUploadFile

    /// The provider owns `received.file` only for the duration of the
    /// importer closure. Materialize the upload value before returning so no
    /// later PhotosPicker work can observe a URL whose lifetime has ended.
    static func imported(from url: URL) throws -> Self {
        Self(uploadFile: try AttachmentFileLoader.loadImportedFile(from: url))
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(
            importedContentType: .item,
            shouldAttemptToOpenInPlace: false
        ) { received in
            try Self.imported(from: received.file)
        }
    }
}
