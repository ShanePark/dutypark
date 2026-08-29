#!/usr/bin/env swift

// Deterministically composes App Store screenshots from real, full-resolution
// captures. The capture is uniformly scaled into a manifest-declared rounded
// device frame; it is never non-uniformly scaled, cropped, or redrawn. Text
// and generated artwork may only be placed in a non-overlapping safe area.

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO

private let requiredWidth = 1320
private let requiredHeight = 2868

private struct OutputSpec: Decodable {
    let width: Int
    let height: Int
    let opaque: Bool
    let background: String?
}

private struct FontSpec: Decodable {
    let path: String
    let name: String
    let subheadlinePath: String?
    let subheadlineName: String?
    let headlineSize: Double
    let subheadlineSize: Double?
    let color: String
    let subheadlineColor: String?
}

private struct RectSpec: Decodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

private struct StickerSpec: Decodable {
    let path: String
    let frame: RectSpec
}

private struct DeviceFrameSpec: Decodable {
    // `frame` is the raw screenshot viewport, excluding the bezel.
    let frame: RectSpec
    let cornerRadius: Double
    let bezelWidth: Double
    let bezelColor: String
    let shadowColor: String?
    let shadowBlur: Double?
    let shadowOffsetY: Double?
}

private struct ScreenshotSpec: Decodable {
    let id: String
    let raw: String
    let output: String
    let safeArea: RectSpec
    let deviceFrame: DeviceFrameSpec
    let headline: String?
    let headlineFrame: RectSpec?
    let subheadline: String?
    let subheadlineFrame: RectSpec?
    let background: String?
    let stickers: [StickerSpec]?
}

private struct Manifest: Decodable {
    let version: Int
    let output: OutputSpec
    let font: FontSpec
    let screenshots: [ScreenshotSpec]
}

private enum ComposeError: LocalizedError {
    case usage
    case invalidManifest(String)
    case missingFile(String)
    case invalidImage(String)
    case invalidSafeArea(String)
    case invalidDeviceFrame(String)
    case invalidTextFrame(String)
    case unsupportedOutput(String)
    case encodingFailure(String)

    var errorDescription: String? {
        switch self {
        case .usage:
            return "Usage: compose_app_store_screenshots.swift <manifest.json>"
        case .invalidManifest(let message):
            return "Invalid manifest: \(message)"
        case .missingFile(let path):
            return "Missing generated asset or input file: \(path)"
        case .invalidImage(let message):
            return "Invalid image: \(message)"
        case .invalidSafeArea(let message):
            return "Invalid safe area: \(message)"
        case .invalidDeviceFrame(let message):
            return "Invalid device frame: \(message)"
        case .invalidTextFrame(let message):
            return "Invalid text frame: \(message)"
        case .unsupportedOutput(let message):
            return "Unsupported output: \(message)"
        case .encodingFailure(let message):
            return "PNG encoding failed: \(message)"
        }
    }
}

private func fail(_ error: ComposeError) -> Never {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
}

private func resolve(_ path: String, relativeTo directory: URL) -> URL {
    if path.hasPrefix("/") {
        return URL(fileURLWithPath: path).standardizedFileURL
    }
    return directory.appendingPathComponent(path).standardizedFileURL
}

private func requireFile(_ url: URL) throws {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
        throw ComposeError.missingFile(url.path)
    }
}

private func loadImage(_ url: URL) throws -> CGImage {
    try requireFile(url)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw ComposeError.invalidImage("could not decode \(url.path)")
    }
    return image
}

private func cgRect(_ spec: RectSpec) -> CGRect {
    CGRect(x: spec.x, y: spec.y, width: spec.width, height: spec.height)
}

/// Converts the manifest's top-left coordinate space into Core Graphics'
/// bottom-left drawing space without changing the declared size.
private func drawingRect(_ rect: CGRect, canvasHeight: CGFloat) -> CGRect {
    CGRect(
        x: rect.minX,
        y: canvasHeight - rect.maxY,
        width: rect.width,
        height: rect.height
    )
}

private func rectIsFinite(_ rect: CGRect) -> Bool {
    rect.origin.x.isFinite && rect.origin.y.isFinite && rect.width.isFinite && rect.height.isFinite
        && rect.width > 0 && rect.height > 0
}

private func rectContains(_ outer: CGRect, _ inner: CGRect) -> Bool {
    outer.contains(inner) || outer.insetBy(dx: -0.01, dy: -0.01).contains(inner)
}

private func color(_ hex: String, alpha: CGFloat = 1) throws -> CGColor {
    var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("#") {
        value.removeFirst()
    }
    guard value.count == 6 || value.count == 8,
          let integer = UInt64(value, radix: 16) else {
        throw ComposeError.invalidManifest("color must be #RRGGBB or #RRGGBBAA: \(hex)")
    }
    let divisor: CGFloat = 255
    let red = CGFloat((integer >> (value.count == 8 ? 24 : 16)) & 0xff) / divisor
    let green = CGFloat((integer >> (value.count == 8 ? 16 : 8)) & 0xff) / divisor
    let blue = CGFloat((integer >> (value.count == 8 ? 8 : 0)) & 0xff) / divisor
    let embeddedAlpha = value.count == 8 ? CGFloat(integer & 0xff) / divisor : 1
    return NSColor(calibratedRed: red, green: green, blue: blue, alpha: embeddedAlpha * alpha).cgColor
}

private func registerFont(path: String, name: String, size: CGFloat, manifestDirectory: URL) throws {
    let fontURL = resolve(path, relativeTo: manifestDirectory)
    try requireFile(fontURL)
    if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil) {
        // A previously registered process font returns false. It is still safe
        // to continue if the requested family can be resolved below.
        guard NSFont(name: name, size: size) != nil else {
            throw ComposeError.invalidManifest("could not register font \(fontURL.path)")
        }
    }
    guard NSFont(name: name, size: size) != nil else {
        throw ComposeError.invalidManifest("font \(name) is not available after registering \(fontURL.path)")
    }
}

private func drawImage(
    _ image: CGImage,
    in rect: CGRect,
    interpolation: CGInterpolationQuality = .high,
    on context: CGContext
) {
    context.saveGState()
    context.interpolationQuality = interpolation
    context.draw(image, in: rect)
    context.restoreGState()
}

private func drawAspectFill(_ image: CGImage, in rect: CGRect, on context: CGContext) {
    let scale = max(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
    let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
    let destination = CGRect(
        x: rect.midX - size.width / 2,
        y: rect.midY - size.height / 2,
        width: size.width,
        height: size.height
    )
    context.saveGState()
    context.addRect(rect)
    context.clip()
    drawImage(image, in: destination, interpolation: .high, on: context)
    context.restoreGState()
}

private func drawDeviceFrame(
    _ image: CGImage,
    spec: DeviceFrameSpec,
    bezelColor: CGColor,
    shadowColor: CGColor?,
    canvasHeight: CGFloat,
    on context: CGContext
) {
    let contentRect = drawingRect(cgRect(spec.frame), canvasHeight: canvasHeight)
    let bezel = CGFloat(spec.bezelWidth)
    let outerRect = contentRect.insetBy(dx: -bezel, dy: -bezel)
    let contentRadius = CGFloat(spec.cornerRadius)
    let outerRadius = contentRadius + bezel
    let outerPath = CGPath(
        roundedRect: outerRect,
        cornerWidth: outerRadius,
        cornerHeight: outerRadius,
        transform: nil
    )
    let contentPath = CGPath(
        roundedRect: contentRect,
        cornerWidth: contentRadius,
        cornerHeight: contentRadius,
        transform: nil
    )

    context.saveGState()
    if let shadowColor {
        context.setShadow(
            offset: CGSize(width: 0, height: -CGFloat(spec.shadowOffsetY ?? 14)),
            blur: CGFloat(spec.shadowBlur ?? 30),
            color: shadowColor
        )
    }
    context.addPath(outerPath)
    context.setFillColor(bezelColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(contentPath)
    context.clip()
    drawImage(image, in: contentRect, interpolation: .high, on: context)
    context.restoreGState()
}

private func drawText(
    _ text: String,
    in rect: CGRect,
    fontName: String,
    size: CGFloat,
    color: CGColor,
    canvasHeight: CGFloat,
    on context: CGContext
) throws {
    guard rectIsFinite(rect) else {
        throw ComposeError.invalidTextFrame("text frame must have finite positive dimensions")
    }
    guard let font = NSFont(name: fontName, size: size) else {
        throw ComposeError.invalidManifest("font \(fontName) is not available")
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = 2
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: color) ?? NSColor.black,
        .paragraphStyle: paragraph
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)

    context.saveGState()
    let previous = NSGraphicsContext.current
    // Manifest rectangles use the same top-left origin as App Store artwork.
    // AppKit's CGContext-backed drawing uses a bottom-left origin, so convert
    // only the text rectangle; the raw image remains untouched.
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    attributed.draw(in: NSRect(x: rect.minX, y: canvasHeight - rect.maxY, width: rect.width, height: rect.height))
    NSGraphicsContext.current = previous
    context.restoreGState()
}

private func validateFrame(
    _ frame: RectSpec?,
    named name: String,
    safeArea: CGRect,
    canvas: CGRect
) throws -> CGRect? {
    guard let frame else { return nil }
    let rect = cgRect(frame)
    guard rectIsFinite(rect), canvas.contains(rect) else {
        throw ComposeError.invalidTextFrame("\(name) must be inside the output canvas")
    }
    guard rectContains(safeArea, rect) else {
        throw ComposeError.invalidTextFrame("\(name) must be entirely inside safeArea")
    }
    return rect
}

private func compose(
    manifest: Manifest,
    manifestURL: URL
) throws {
    guard manifest.version == 2 else {
        throw ComposeError.invalidManifest("unsupported version \(manifest.version); expected 2")
    }
    guard manifest.output.width == requiredWidth, manifest.output.height == requiredHeight else {
        throw ComposeError.unsupportedOutput("App Store output must be \(requiredWidth)x\(requiredHeight)")
    }
    guard manifest.output.opaque else {
        throw ComposeError.unsupportedOutput("output.opaque must be true")
    }
    guard !manifest.screenshots.isEmpty else {
        throw ComposeError.invalidManifest("screenshots must not be empty")
    }

    let manifestDirectory = manifestURL.deletingLastPathComponent()
    try registerFont(
        path: manifest.font.path,
        name: manifest.font.name,
        size: manifest.font.headlineSize,
        manifestDirectory: manifestDirectory
    )
    guard (manifest.font.subheadlinePath == nil) == (manifest.font.subheadlineName == nil) else {
        throw ComposeError.invalidManifest("subheadlinePath and subheadlineName must be provided together")
    }
    if let path = manifest.font.subheadlinePath, let name = manifest.font.subheadlineName {
        try registerFont(
            path: path,
            name: name,
            size: manifest.font.subheadlineSize ?? 36,
            manifestDirectory: manifestDirectory
        )
    }
    let subheadlineFontName = manifest.font.subheadlineName ?? manifest.font.name
    let canvasRect = CGRect(x: 0, y: 0, width: requiredWidth, height: requiredHeight)
    let baseColor = try color(manifest.output.background ?? "#FFF9F3")
    let headlineColor = try color(manifest.font.color)
    let subheadlineColor = try color(manifest.font.subheadlineColor ?? manifest.font.color)

    for screenshot in manifest.screenshots {
        let rawURL = resolve(screenshot.raw, relativeTo: manifestDirectory)
        let outputURL = resolve(screenshot.output, relativeTo: manifestDirectory)
        let raw = try loadImage(rawURL)
        guard raw.width == requiredWidth, raw.height == requiredHeight else {
            throw ComposeError.invalidImage("\(rawURL.path) is \(raw.width)x\(raw.height); expected \(requiredWidth)x\(requiredHeight)")
        }

        let safeArea = cgRect(screenshot.safeArea)
        guard rectIsFinite(safeArea), canvasRect.contains(safeArea) else {
            throw ComposeError.invalidSafeArea("\(screenshot.id) must declare a finite safeArea inside the canvas")
        }
        let contentRect = cgRect(screenshot.deviceFrame.frame)
        let bezel = CGFloat(screenshot.deviceFrame.bezelWidth)
        guard rectIsFinite(contentRect), bezel.isFinite, bezel >= 0 else {
            throw ComposeError.invalidDeviceFrame("\(screenshot.id) frame and bezel must be finite and positive")
        }
        let outerRect = contentRect.insetBy(dx: -bezel, dy: -bezel)
        guard canvasRect.contains(outerRect) else {
            throw ComposeError.invalidDeviceFrame("\(screenshot.id) outer frame must be inside the output canvas")
        }
        let rawAspect = CGFloat(raw.width) / CGFloat(raw.height)
        let frameAspect = contentRect.width / contentRect.height
        guard abs(rawAspect - frameAspect) <= 0.00001 else {
            throw ComposeError.invalidDeviceFrame("\(screenshot.id) frame aspect ratio \(frameAspect) does not match raw capture \(rawAspect); use uniform scaling")
        }
        guard screenshot.deviceFrame.cornerRadius.isFinite,
              screenshot.deviceFrame.cornerRadius >= 0,
              screenshot.deviceFrame.cornerRadius <= min(contentRect.width, contentRect.height) / 2 else {
            throw ComposeError.invalidDeviceFrame("\(screenshot.id) cornerRadius is out of bounds")
        }
        guard !safeArea.intersects(outerRect) else {
            throw ComposeError.invalidSafeArea("\(screenshot.id) safeArea must not overlap the device frame")
        }
        let headlineFrame = try validateFrame(screenshot.headlineFrame, named: "headlineFrame", safeArea: safeArea, canvas: canvasRect)
        let subheadlineFrame = try validateFrame(screenshot.subheadlineFrame, named: "subheadlineFrame", safeArea: safeArea, canvas: canvasRect)
        if screenshot.headline != nil && headlineFrame == nil {
            throw ComposeError.invalidTextFrame("\(screenshot.id) has headline text but no headlineFrame")
        }
        if screenshot.subheadline != nil && subheadlineFrame == nil {
            throw ComposeError.invalidTextFrame("\(screenshot.id) has subheadline text but no subheadlineFrame")
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw ComposeError.encodingFailure("could not create sRGB color space")
        }
        guard let context = CGContext(
            data: nil,
            width: requiredWidth,
            height: requiredHeight,
            bitsPerComponent: 8,
            bytesPerRow: requiredWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw ComposeError.encodingFailure("could not create bitmap context")
        }
        context.setFillColor(baseColor)
        context.fill(canvasRect)
        if let background = screenshot.background {
            let backgroundURL = resolve(background, relativeTo: manifestDirectory)
            let image = try loadImage(backgroundURL)
            drawAspectFill(image, in: canvasRect, on: context)
        }
        for sticker in screenshot.stickers ?? [] {
            let frame = cgRect(sticker.frame)
            guard rectIsFinite(frame), canvasRect.contains(frame), rectContains(safeArea, frame) else {
                throw ComposeError.invalidSafeArea("sticker \(sticker.path) must be entirely inside safeArea")
            }
            let stickerURL = resolve(sticker.path, relativeTo: manifestDirectory)
            drawImage(
                try loadImage(stickerURL),
                in: drawingRect(frame, canvasHeight: CGFloat(requiredHeight)),
                interpolation: .high,
                on: context
            )
        }
        if let headline = screenshot.headline, let frame = headlineFrame {
            try drawText(headline, in: frame, fontName: manifest.font.name, size: manifest.font.headlineSize, color: headlineColor, canvasHeight: CGFloat(requiredHeight), on: context)
        }
        if let subheadline = screenshot.subheadline, let frame = subheadlineFrame {
            try drawText(subheadline, in: frame, fontName: subheadlineFontName, size: CGFloat(manifest.font.subheadlineSize ?? 36), color: subheadlineColor, canvasHeight: CGFloat(requiredHeight), on: context)
        }
        let shadowColor: CGColor?
        if let shadowHex = screenshot.deviceFrame.shadowColor {
            shadowColor = try color(shadowHex)
        } else {
            shadowColor = nil
        }
        drawDeviceFrame(
            raw,
            spec: screenshot.deviceFrame,
            bezelColor: try color(screenshot.deviceFrame.bezelColor),
            shadowColor: shadowColor,
            canvasHeight: CGFloat(requiredHeight),
            on: context
        )

        guard let image = context.makeImage() else {
            throw ComposeError.encodingFailure("could not create output image")
        }
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, "public.png" as CFString, 1, nil) else {
            throw ComposeError.encodingFailure("could not create destination \(outputURL.path)")
        }
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyPNGInterlaceType: false] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ComposeError.encodingFailure("could not write \(outputURL.path)")
        }
        print("wrote \(outputURL.path)")
    }
}

private func loadManifest(_ url: URL) throws -> Manifest {
    try requireFile(url)
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Manifest.self, from: data)
    } catch let error as ComposeError {
        throw error
    } catch {
        throw ComposeError.invalidManifest(error.localizedDescription)
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 1 else { fail(.usage) }
let manifestURL = URL(fileURLWithPath: arguments[0]).standardizedFileURL
do {
    try compose(manifest: loadManifest(manifestURL), manifestURL: manifestURL)
} catch let error as ComposeError {
    fail(error)
} catch {
    fail(.invalidManifest(error.localizedDescription))
}
