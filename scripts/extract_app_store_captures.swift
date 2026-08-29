#!/usr/bin/env swift

// Extracts named XCTAttachments exported by xcresulttool into the raw App Store
// screenshot directory. The whole export is validated before any existing raw
// capture is replaced.

import Foundation
import ImageIO

private let expectedScreens: [(suffix: String, fileName: String)] = [
    ("01-home-demo", "home.png"),
    ("02-calendar-demo", "calendar.png"),
    ("03-todo-demo", "todo.png"),
    ("04-team-demo", "team.png"),
    ("05-more-demo", "more.png"),
    ("06-social-demo", "social.png"),
    ("07-dday-demo", "dday.png")
]
private let requiredWidth = 1320
private let requiredHeight = 2868

private struct Attachment: Decodable {
    let exportedFileName: String
    let suggestedHumanReadableName: String
}

private struct AttachmentRecord: Decodable {
    let attachments: [Attachment]
}

private enum ExtractError: LocalizedError {
    case usage
    case invalidArgument(String)
    case missingManifest(String)
    case invalidManifest(String)
    case missingAttachment(String)
    case duplicateAttachment(String)
    case missingExportedFile(String)
    case ambiguousExportedFile(String)
    case invalidImage(String)
    case existingFile(String)
    case filesystem(String)

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: extract_app_store_captures.swift --manifest <manifest.json> --export-root <dir> --locale <ko|en> --output-root <dir> [--force]"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .missingManifest(let path):
            return "xcresult attachment manifest is missing: \(path)"
        case .invalidManifest(let message):
            return "Invalid xcresult attachment manifest: \(message)"
        case .missingAttachment(let name):
            return "Required attachment is missing: \(name)"
        case .duplicateAttachment(let name):
            return "Duplicate attachment name in xcresult export: \(name)"
        case .missingExportedFile(let name):
            return "Exported attachment file is missing: \(name)"
        case .ambiguousExportedFile(let name):
            return "Exported attachment file is ambiguous: \(name)"
        case .invalidImage(let message):
            return "Invalid screenshot attachment: \(message)"
        case .existingFile(let path):
            return "Raw capture already exists (use --force to overwrite): \(path)"
        case .filesystem(let message):
            return "Filesystem error: \(message)"
        }
    }
}

private func fail(_ error: ExtractError) -> Never {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
}

private struct Arguments {
    let manifest: URL
    let exportRoot: URL
    let outputRoot: URL
    let locale: String
    let force: Bool
}

private func absoluteURL(_ path: String) -> URL {
    let url = URL(fileURLWithPath: path)
    if url.path.hasPrefix("/") {
        return url.standardizedFileURL
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(path)
        .standardizedFileURL
}

private func parseArguments() throws -> Arguments {
    var manifest: String?
    var exportRoot: String?
    var outputRoot: String?
    var locale: String?
    var force = false
    var index = 1
    let arguments = CommandLine.arguments

    while index < arguments.count {
        switch arguments[index] {
        case "--manifest":
            index += 1
            guard index < arguments.count else { throw ExtractError.invalidArgument("--manifest needs a path") }
            manifest = arguments[index]
        case "--export-root":
            index += 1
            guard index < arguments.count else { throw ExtractError.invalidArgument("--export-root needs a directory") }
            exportRoot = arguments[index]
        case "--output-root":
            index += 1
            guard index < arguments.count else { throw ExtractError.invalidArgument("--output-root needs a directory") }
            outputRoot = arguments[index]
        case "--locale":
            index += 1
            guard index < arguments.count else { throw ExtractError.invalidArgument("--locale needs ko or en") }
            locale = arguments[index]
        case "--force":
            force = true
        case "--help", "-h":
            throw ExtractError.usage
        default:
            throw ExtractError.invalidArgument("unknown option \(arguments[index])")
        }
        index += 1
    }

    guard let manifest, let exportRoot, let outputRoot, let locale else {
        throw ExtractError.usage
    }
    guard locale == "ko" || locale == "en" else {
        throw ExtractError.invalidArgument("locale must be ko or en")
    }
    return Arguments(
        manifest: absoluteURL(manifest),
        exportRoot: absoluteURL(exportRoot),
        outputRoot: absoluteURL(outputRoot),
        locale: locale,
        force: force
    )
}

private func readManifest(at url: URL) throws -> [AttachmentRecord] {
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw ExtractError.missingManifest(url.path)
    }
    let data = try Data(contentsOf: url)
    do {
        if let records = try? JSONDecoder().decode([AttachmentRecord].self, from: data) {
            return records
        }
        // Keep the parser tolerant of a future xcresulttool wrapper object while
        // retaining the current documented top-level array format.
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any],
              let attachments = dictionary["attachments"] else {
            throw ExtractError.invalidManifest("expected an array of test attachment records")
        }
        let normalized = try JSONSerialization.data(withJSONObject: attachments)
        return try JSONDecoder().decode([AttachmentRecord].self, from: normalized)
    } catch let error as ExtractError {
        throw error
    } catch {
        throw ExtractError.invalidManifest(error.localizedDescription)
    }
}

private func regularFileURLs(in root: URL) -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }
    return enumerator.compactMap { item in
        guard let url = item as? URL,
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            return nil
        }
        return url
    }
}

private func findExportedFile(named name: String, in root: URL) throws -> URL {
    let normalizedRoot = root.standardizedFileURL
    let direct = normalizedRoot.appendingPathComponent(name).standardizedFileURL
    let rootPrefix = normalizedRoot.path.hasSuffix("/") ? normalizedRoot.path : normalizedRoot.path + "/"
    if direct.path.hasPrefix(rootPrefix), FileManager.default.fileExists(atPath: direct.path) {
        return direct
    }
    let matches = regularFileURLs(in: normalizedRoot).filter { $0.lastPathComponent == URL(fileURLWithPath: name).lastPathComponent }
    if matches.isEmpty {
        throw ExtractError.missingExportedFile(name)
    }
    guard matches.count == 1 else {
        throw ExtractError.ambiguousExportedFile(name)
    }
    return matches[0]
}

private func normalizedAttachmentName(_ name: String, locale: String) -> String? {
    let prefix = "appstore-\(locale)-"
    guard name.hasPrefix(prefix) else { return nil }

    let knownBases = expectedScreens.map { prefix + $0.suffix }
    if knownBases.contains(name) || knownBases.contains(String(name.dropLast(4))) && name.hasSuffix(".png") {
        return name.hasSuffix(".png") ? String(name.dropLast(4)) : name
    }

    guard name.hasSuffix(".png") else { return nil }
    let stem = String(name.dropLast(4))
    let components = stem.split(separator: "_", omittingEmptySubsequences: false)
    guard components.count >= 3,
          let repetition = Int(components[components.count - 2]),
          repetition >= 0,
          UUID(uuidString: String(components[components.count - 1])) != nil else {
        return nil
    }
    let base = components.dropLast(2).joined(separator: "_")
    return knownBases.contains(base) ? base : nil
}

private func validateImage(at url: URL) throws {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          CGImageSourceGetCount(source) == 1,
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw ExtractError.invalidImage("could not decode \(url.path)")
    }
    guard image.width == requiredWidth, image.height == requiredHeight else {
        throw ExtractError.invalidImage(
            "\(url.lastPathComponent) must be \(requiredWidth)x\(requiredHeight), got \(image.width)x\(image.height)"
        )
    }
    switch image.alphaInfo {
    case .none, .noneSkipFirst, .noneSkipLast:
        break
    default:
        throw ExtractError.invalidImage("\(url.lastPathComponent) has an alpha channel")
    }
}

private func replaceAtomically(source: URL, destination: URL) throws {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: destination.path) {
        _ = try fileManager.replaceItemAt(destination, withItemAt: source, backupItemName: nil, options: [])
    } else {
        try fileManager.moveItem(at: source, to: destination)
    }
}

do {
    let arguments = try parseArguments()
    let fileManager = FileManager.default
    let records = try readManifest(at: arguments.manifest)
    let prefix = "appstore-\(arguments.locale)-"
    var attachmentsByName: [String: Attachment] = [:]

    for record in records {
        for attachment in record.attachments {
            let name = attachment.suggestedHumanReadableName
            guard let normalizedName = normalizedAttachmentName(name, locale: arguments.locale) else {
                continue
            }
            guard attachmentsByName[normalizedName] == nil else {
                throw ExtractError.duplicateAttachment(normalizedName)
            }
            attachmentsByName[normalizedName] = attachment
        }
    }

    var pending: [(source: URL, destination: URL)] = []
    let localeRoot = arguments.outputRoot.appendingPathComponent(arguments.locale)
    try fileManager.createDirectory(at: localeRoot, withIntermediateDirectories: true)

    for screen in expectedScreens {
        let attachmentName = prefix + screen.suffix
        guard let attachment = attachmentsByName[attachmentName] else {
            throw ExtractError.missingAttachment(attachmentName)
        }
        let source = try findExportedFile(named: attachment.exportedFileName, in: arguments.exportRoot)
        try validateImage(at: source)
        let destination = localeRoot.appendingPathComponent(screen.fileName)
        if fileManager.fileExists(atPath: destination.path), !arguments.force {
            throw ExtractError.existingFile(destination.path)
        }
        pending.append((source, destination))
    }

    let staging = localeRoot.appendingPathComponent(".extract-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: staging) }

    for item in pending {
        let staged = staging.appendingPathComponent(item.destination.lastPathComponent)
        try fileManager.copyItem(at: item.source, to: staged)
        try validateImage(at: staged)
    }
    for item in pending {
        let staged = staging.appendingPathComponent(item.destination.lastPathComponent)
        try replaceAtomically(source: staged, destination: item.destination)
    }

    print("Extracted \(pending.count) \(arguments.locale) App Store captures to \(localeRoot.path)")
} catch let error as ExtractError {
    fail(error)
} catch {
    fail(.filesystem(error.localizedDescription))
}
