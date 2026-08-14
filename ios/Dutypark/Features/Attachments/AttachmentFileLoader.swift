import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum AttachmentFileLoader {
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

        try validateFileSize(at: url)

        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw AttachmentUploadError.unreadableFile
        }

        let type = UTType(filenameExtension: url.pathExtension)
        return try preparedFile(
            data: data,
            filename: url.lastPathComponent,
            type: type
        )
    }

    static func validateFileSize(at url: URL) throws {
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.fileSizeKey])
        } catch {
            throw AttachmentUploadError.unreadableFile
        }
        if let fileSize = values.fileSize,
           fileSize >= AttachmentUploadPolicy.safeMaximumBytes {
            throw AttachmentUploadError.tooLarge
        }
    }

    static func load(from item: PhotosPickerItem) async throws -> AttachmentUploadFile {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw AttachmentUploadError.unreadableFile
        }
        let type = item.supportedContentTypes.first
        let suffix = type?.preferredFilenameExtension ?? "jpg"
        return try preparedFile(
            data: data,
            filename: "photo-\(UUID().uuidString).\(suffix)",
            type: type
        )
    }

    static func preparedFile(
        data: Data,
        filename: String,
        type: UTType?
    ) throws -> AttachmentUploadFile {
        if isHEIC(data: data, type: type, filename: filename) {
            guard let image = UIImage(data: data),
                  let jpeg = image.jpegData(compressionQuality: 0.9)
            else {
                throw AttachmentUploadError.imageConversionFailed
            }
            return try AttachmentUploadFile(
                filename: replacingExtension(of: filename, with: "jpg"),
                contentType: "image/jpeg",
                data: jpeg
            )
        }

        return try AttachmentUploadFile(
            filename: filename,
            contentType: type?.preferredMIMEType ?? "application/octet-stream",
            data: data
        )
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
