import CoreTransferable
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

nonisolated enum ProfilePhotoProcessingPolicy {
    /// A profile photo does not need camera-original dimensions. Keeping the image
    /// at this size bounds the decoded bitmap before it reaches the crop screen.
    static let maxInputPixelDimension = 2_048
    static let maxInputFileBytes = 50 * 1_024 * 1_024
    static let maxOutputPixelDimension = 1_024
    static let maxUploadBytes = 1 * 1_024 * 1_024

    static func tooLargeMessage(maxBytes: Int) -> String {
        let size = "\(maxBytes / (1_024 * 1_024)) MB"
        if AppLocalization.locale.identifier.lowercased().hasPrefix("ko") {
            return "사진이 너무 큽니다. \(size) 이하의 사진을 선택해 주세요."
        }
        return "This photo is too large. Choose a photo no larger than \(size)."
    }

    static var inputSizeUnavailableMessage: String {
        if AppLocalization.locale.identifier.lowercased().hasPrefix("ko") {
            return "사진 크기를 확인하지 못했습니다. 다른 사진을 선택해 주세요."
        }
        return "The photo size could not be verified. Choose another photo."
    }
}

nonisolated enum ProfilePhotoProcessingError: Error, Equatable, Sendable, LocalizedError {
    case invalidImage
    case inputSizeUnavailable
    case inputTooLarge(maxBytes: Int)
    case outputTooLarge(maxBytes: Int)

    var userMessage: String {
        switch self {
        case .invalidImage:
            SettingsLocalization.string("settings.photo.invalid")
        case .inputSizeUnavailable:
            ProfilePhotoProcessingPolicy.inputSizeUnavailableMessage
        case .inputTooLarge(let maxBytes), .outputTooLarge(let maxBytes):
            ProfilePhotoProcessingPolicy.tooLargeMessage(maxBytes: maxBytes)
        }
    }

    var errorDescription: String? { userMessage }
}

nonisolated enum ProfilePhotoUploadError: Error, Equatable, Sendable, LocalizedError {
    case tooLarge(maxBytes: Int)

    var errorDescription: String? {
        switch self {
        case .tooLarge(let maxBytes):
            ProfilePhotoProcessingPolicy.tooLargeMessage(maxBytes: maxBytes)
        }
    }
}

/// The Photos picker imports a file representation so ImageIO can downsample it
/// directly from disk. Loading `Data` first would materialize a camera-original
/// image before the size limit can be applied.
struct ProfilePhotoPickerImage: Transferable, @unchecked Sendable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(
            importedContentType: .image,
            shouldAttemptToOpenInPlace: false
        ) { received in
            let image = try ProfilePhotoCropper.loadDownsampledImage(at: received.file)
            return Self(image: image)
        }
    }
}

struct ProfilePhotoCropView: View {
    let image: UIImage
    let onConfirm: (Data) -> Void
    let onCancel: () -> Void
    let onError: (ProfilePhotoProcessingError) -> Void

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    @State private var cropSize: CGFloat = 1

    init(
        image: UIImage,
        onConfirm: @escaping (Data) -> Void,
        onCancel: @escaping () -> Void,
        onError: @escaping (ProfilePhotoProcessingError) -> Void = { _ in }
    ) {
        self.image = image
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.onError = onError
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                GeometryReader { proxy in
                    let size = min(proxy.size.width, proxy.size.height)
                    ZStack {
                        Color.black
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .scaleEffect(zoom)
                            .offset(offset)
                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .shadow(radius: 2)
                            .padding(2)
                    }
                    .frame(width: size, height: size)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = ProfilePhotoCropper.clampedOffset(
                                    CGSize(
                                        width: dragStart.width + value.translation.width,
                                        height: dragStart.height + value.translation.height
                                    ),
                                    imageSize: image.size,
                                    viewport: size,
                                    zoom: zoom
                                )
                            }
                            .onEnded { _ in dragStart = offset }
                    )
                    .onAppear { cropSize = size }
                    .onChange(of: size) { _, value in cropSize = value }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .aspectRatio(1, contentMode: .fit)

                HStack {
                    Image(systemName: "minus.magnifyingglass")
                    Slider(value: $zoom, in: 1...3, step: 0.1)
                        .onChange(of: zoom) { _, value in
                            offset = ProfilePhotoCropper.clampedOffset(
                                offset,
                                imageSize: image.size,
                                viewport: cropSize,
                                zoom: value
                            )
                            dragStart = offset
                        }
                    Image(systemName: "plus.magnifyingglass")
                }
                .padding(.horizontal)
                SettingsLocalization.text("settings.crop.hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle(SettingsLocalization.string("settings.crop.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SettingsLocalization.string("settings.action.cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(SettingsLocalization.string("settings.action.save")) {
                        let result = ProfilePhotoCropper.jpegResult(
                            image: image,
                            viewport: cropSize,
                            zoom: zoom,
                            offset: offset
                        )
                        switch result {
                        case .success(let jpeg): onConfirm(jpeg)
                        case .failure(let error): onError(error)
                        }
                    }
                }
            }
        }
    }
}

nonisolated enum ProfilePhotoCropper {
    static func clampedOffset(
        _ offset: CGSize,
        imageSize: CGSize,
        viewport: CGFloat,
        zoom: CGFloat
    ) -> CGSize {
        guard viewport > 0, imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let baseScale = viewport / min(imageSize.width, imageSize.height)
        let width = imageSize.width * baseScale * zoom
        let height = imageSize.height * baseScale * zoom
        return CGSize(
            width: min(max(offset.width, -(width - viewport) / 2), (width - viewport) / 2),
            height: min(max(offset.height, -(height - viewport) / 2), (height - viewport) / 2)
        )
    }

    static func jpeg(
        image: UIImage,
        viewport: CGFloat,
        zoom: CGFloat,
        offset: CGSize
    ) -> Data? {
        guard case .success(let data) = jpegResult(
            image: image,
            viewport: viewport,
            zoom: zoom,
            offset: offset
        ) else {
            return nil
        }
        return data
    }

    static func jpegResult(
        image: UIImage,
        viewport: CGFloat,
        zoom: CGFloat,
        offset: CGSize
    ) -> Result<Data, ProfilePhotoProcessingError> {
        let boundedImage = downsampledImage(image) ?? image
        guard viewport > 0, let normalized = normalizedCGImage(boundedImage) else {
            return .failure(.invalidImage)
        }
        let width = CGFloat(normalized.width)
        let height = CGFloat(normalized.height)
        let scale = viewport / min(width, height) * zoom
        let side = min(width, height) / zoom
        guard scale > 0, side >= 1 else {
            return .failure(.invalidImage)
        }
        let adjusted = clampedOffset(offset, imageSize: CGSize(width: width, height: height), viewport: viewport, zoom: zoom)
        let centerX = width / 2 - adjusted.width / scale
        let centerY = height / 2 - adjusted.height / scale
        let rect = CGRect(
            x: min(max(0, centerX - side / 2), width - side),
            y: min(max(0, centerY - side / 2), height - side),
            width: side,
            height: side
        ).integral
        guard rect.width >= 1,
              rect.height >= 1,
              let cropped = normalized.cropping(to: rect)
        else {
            return .failure(.invalidImage)
        }

        let croppedImage = UIImage(cgImage: cropped, scale: 1, orientation: .up)
        guard let data = boundedJPEGData(croppedImage) else {
            return .failure(.outputTooLarge(maxBytes: ProfilePhotoProcessingPolicy.maxUploadBytes))
        }
        return .success(data)
    }

    static func downsampledImage(at url: URL) -> UIImage? {
        try? loadDownsampledImage(at: url)
    }

    static func loadDownsampledImage(at url: URL) throws -> UIImage {
        let resourceValues: URLResourceValues
        do {
            resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        } catch {
            throw ProfilePhotoProcessingError.inputSizeUnavailable
        }
        try validateInputFileSize(resourceValues.fileSize)

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0
        else {
            throw ProfilePhotoProcessingError.invalidImage
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: ProfilePhotoProcessingPolicy.maxInputPixelDimension,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ProfilePhotoProcessingError.invalidImage
        }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    static func validateInputFileSize(_ fileSize: Int?) throws {
        guard let fileSize else {
            throw ProfilePhotoProcessingError.inputSizeUnavailable
        }
        guard fileSize >= 0,
              fileSize <= ProfilePhotoProcessingPolicy.maxInputFileBytes
        else {
            if fileSize < 0 {
                throw ProfilePhotoProcessingError.inputSizeUnavailable
            }
            throw ProfilePhotoProcessingError.inputTooLarge(
                maxBytes: ProfilePhotoProcessingPolicy.maxInputFileBytes
            )
        }
    }

    static func downsampledImage(
        _ image: UIImage,
        maxPixelDimension: Int = ProfilePhotoProcessingPolicy.maxInputPixelDimension
    ) -> UIImage? {
        guard let cgImage = image.cgImage,
              maxPixelDimension > 0
        else { return nil }
        let largestDimension = max(cgImage.width, cgImage.height)
        guard largestDimension > maxPixelDimension else { return image }

        let scale = CGFloat(maxPixelDimension) / CGFloat(largestDimension)
        let size = CGSize(
            width: max(1, floor(CGFloat(cgImage.width) * scale)),
            height: max(1, floor(CGFloat(cgImage.height) * scale))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func boundedJPEGData(_ image: UIImage) -> Data? {
        var currentImage = downsampledImage(
            image,
            maxPixelDimension: ProfilePhotoProcessingPolicy.maxOutputPixelDimension
        ) ?? image
        var currentDimension = max(
            currentImage.cgImage?.width ?? 0,
            currentImage.cgImage?.height ?? 0
        )
        guard currentDimension > 0 else { return nil }

        while currentDimension > 0 {
            var quality: CGFloat = 0.85
            while quality >= 0.25 {
                if let data = currentImage.jpegData(compressionQuality: quality),
                   data.count <= ProfilePhotoProcessingPolicy.maxUploadBytes
                {
                    return data
                }
                quality -= 0.1
            }

            guard currentDimension > 64 else { break }
            let nextDimension = max(64, Int(floor(Double(currentDimension) * 0.75)))
            guard nextDimension < currentDimension,
                  let resized = downsampledImage(currentImage, maxPixelDimension: nextDimension)
            else { break }
            currentImage = resized
            currentDimension = nextDimension
        }
        return nil
    }

    private static func normalizedCGImage(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage { return cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }
}
