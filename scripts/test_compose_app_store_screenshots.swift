#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO

private let width = 1320
private let height = 2868

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

private func png(_ url: URL, width: Int, height: Int, color: CGColor) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(color)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = context.makeImage()!
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    check(CGImageDestinationFinalize(destination), "fixture PNG write")
}

private func write(_ value: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

private func sipsMetadata(for url: URL, in directory: URL) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = ["-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", url.path]
    process.currentDirectoryURL = directory
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()
    return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

private func image(_ url: URL) -> CGImage {
    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(source, 0, nil)!
}

final class RGBAImage {
    let image: CGImage
    private let data: CFData
    private let bytes: UnsafePointer<UInt8>
    private let bytesPerPixel: Int

    init(_ image: CGImage) {
        guard let provider = image.dataProvider, let data = provider.data, let bytes = CFDataGetBytePtr(data) else {
            fatalError("fixture output has no data provider")
        }
        self.image = image
        self.data = data
        self.bytes = bytes
        self.bytesPerPixel = image.bitsPerPixel / 8
    }

    func pixel(x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let bytes = bytes + (y * image.bytesPerRow) + (x * bytesPerPixel)
        if bytesPerPixel == 3 {
            return (bytes[0], bytes[1], bytes[2], 255)
        }
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }
}

private func pixel(_ image: RGBAImage, x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
    guard image.image.bitsPerPixel == 24 || image.image.bitsPerPixel == 32 else {
        fatalError("fixture output has no data provider")
    }
    return image.pixel(x: x, y: y)
}

// Manifest rectangles use a top-left origin; CGImage provider rows use a
// bottom-left origin for the CGContext-backed fixture.
private func topPixel(_ image: RGBAImage, x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
    pixel(image, x: x, y: height - 1 - y)
}

let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let root = FileManager.default.temporaryDirectory.appendingPathComponent("dutypark-app-store-compositor-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }

let raw = root.appendingPathComponent("raw.png")
let background = root.appendingPathComponent("background.png")
let output = root.appendingPathComponent("output.png")
let manifest = root.appendingPathComponent("manifest.json")
try png(raw, width: width, height: height, color: CGColor(red: 0.92, green: 0.94, blue: 0.97, alpha: 1))
try png(background, width: 400, height: 400, color: CGColor(red: 0.99, green: 0.55, blue: 0.45, alpha: 1))
try write([
    "version": 2,
    "output": ["width": width, "height": height, "opaque": true, "background": "#FFF9F3"],
    "font": [
        "path": repo.appendingPathComponent("ios/Dutypark/Resources/Fonts/Maplestory OTF Bold.otf").path,
        "name": "MaplestoryOTFBold",
        "headlineSize": 72,
        "subheadlineSize": 36,
        "color": "#1F2937"
    ],
    "screenshots": [[
        "id": "fixture",
        "raw": raw.path,
        "output": output.path,
        "safeArea": ["x": 100, "y": 70, "width": 1120, "height": 250],
        "deviceFrame": [
            "frame": ["x": 140, "y": 430, "width": 1040, "height": 2259.64],
            "cornerRadius": 40,
            "bezelWidth": 16,
            "bezelColor": "#111827",
            "shadowColor": "#40000000",
            "shadowBlur": 28,
            "shadowOffsetY": 14
        ],
        "background": background.path,
        "headline": "Fixture headline",
        "headlineFrame": ["x": 130, "y": 110, "width": 1060, "height": 120]
    ]]
], to: manifest)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/zsh")
process.arguments = ["-lc", "scripts/compose-app-store-screenshots.sh \"\(manifest.path)\""]
process.currentDirectoryURL = repo
let errors = Pipe()
process.standardError = errors
try process.run()
process.waitUntilExit()
check(process.terminationStatus == 0, String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "compose command failed")

let result = RGBAImage(image(output))
check(result.image.width == width && result.image.height == height, "output is not 1320x2868")
check(result.image.alphaInfo == .none || result.image.alphaInfo == .noneSkipFirst || result.image.alphaInfo == .noneSkipLast, "output retains an alpha channel")
let metadata = try sipsMetadata(for: output, in: repo)
check(metadata.contains("pixelWidth: 1320") && metadata.contains("pixelHeight: 2868"), "sips dimensions are not 1320x2868")
check(metadata.contains("hasAlpha: no"), "sips reports an alpha channel")
let source = RGBAImage(image(raw))
let untouched = topPixel(result, x: width / 2, y: height / 2)
check(topPixel(result, x: width / 2, y: 300) != topPixel(source, x: width / 2, y: 300), "marketing canvas was not placed above the device frame")
check(untouched == topPixel(source, x: width / 2, y: height / 2), "raw screenshot content was changed inside the device frame")
var headlineChanged = false
for y in 110..<230 {
    for x in 130..<1190 where topPixel(result, x: x, y: y) != topPixel(source, x: x, y: y) {
        headlineChanged = true
        break
    }
    if headlineChanged { break }
}
check(headlineChanged, "headline did not render inside its declared frame")

let missingManifest = root.appendingPathComponent("missing.json")
try write([
    "version": 2,
    "output": ["width": width, "height": height, "opaque": true],
    "font": [
        "path": repo.appendingPathComponent("ios/Dutypark/Resources/Fonts/Maplestory OTF Bold.otf").path,
        "name": "MaplestoryOTFBold",
        "headlineSize": 72,
        "color": "#1F2937"
    ],
    "screenshots": [[
        "id": "missing-generated",
        "raw": raw.path,
        "output": root.appendingPathComponent("missing-output.png").path,
        "safeArea": ["x": 100, "y": 70, "width": 1120, "height": 240],
        "deviceFrame": [
            "frame": ["x": 140, "y": 430, "width": 1040, "height": 2259.64],
            "cornerRadius": 40,
            "bezelWidth": 16,
            "bezelColor": "#111827"
        ],
        "background": root.appendingPathComponent("generated/missing-sticker.png").path,
        "stickers": []
    ]]
], to: missingManifest)

let missingProcess = Process()
missingProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
missingProcess.arguments = ["-lc", "scripts/compose-app-store-screenshots.sh \"\(missingManifest.path)\""]
missingProcess.currentDirectoryURL = repo
let missingErrors = Pipe()
missingProcess.standardError = missingErrors
try missingProcess.run()
missingProcess.waitUntilExit()
let missingMessage = String(data: missingErrors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
check(missingProcess.terminationStatus != 0 && missingMessage.contains("Missing generated asset or input file"), "missing generated asset was not rejected")

let ratioManifest = root.appendingPathComponent("ratio.json")
try write([
    "version": 2,
    "output": ["width": width, "height": height, "opaque": true],
    "font": [
        "path": repo.appendingPathComponent("ios/Dutypark/Resources/Fonts/Maplestory OTF Bold.otf").path,
        "name": "MaplestoryOTFBold",
        "headlineSize": 72,
        "color": "#1F2937"
    ],
    "screenshots": [[
        "id": "non-uniform",
        "raw": raw.path,
        "output": root.appendingPathComponent("ratio-output.png").path,
        "safeArea": ["x": 100, "y": 70, "width": 1120, "height": 240],
        "deviceFrame": [
            "frame": ["x": 140, "y": 430, "width": 1040, "height": 2000],
            "cornerRadius": 40,
            "bezelWidth": 16,
            "bezelColor": "#111827"
        ]
    ]]
], to: ratioManifest)
let ratioProcess = Process()
ratioProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
ratioProcess.arguments = ["-lc", "scripts/compose-app-store-screenshots.sh \"\(ratioManifest.path)\""]
ratioProcess.currentDirectoryURL = repo
let ratioErrors = Pipe()
ratioProcess.standardError = ratioErrors
try ratioProcess.run()
ratioProcess.waitUntilExit()
let ratioMessage = String(data: ratioErrors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
check(ratioProcess.terminationStatus != 0 && ratioMessage.contains("aspect ratio"), "non-uniform frame was not rejected")

print("PASS: App Store screenshot compositor dimensions, alpha, uniform frame, safe-area text, and asset validation")
