import SwiftUI
import UIKit

struct ProfilePhotoCropView: View {
    let image: UIImage
    let onConfirm: (Data) -> Void
    let onCancel: () -> Void

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    @State private var cropSize: CGFloat = 1

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
                        guard let jpeg = ProfilePhotoCropper.jpeg(
                            image: image,
                            viewport: cropSize,
                            zoom: zoom,
                            offset: offset
                        ) else { return }
                        onConfirm(jpeg)
                    }
                }
            }
        }
    }
}

enum ProfilePhotoCropper {
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
        guard viewport > 0, let normalized = normalizedCGImage(image) else { return nil }
        let width = CGFloat(normalized.width)
        let height = CGFloat(normalized.height)
        let scale = viewport / min(width, height) * zoom
        let side = min(width, height) / zoom
        let adjusted = clampedOffset(offset, imageSize: CGSize(width: width, height: height), viewport: viewport, zoom: zoom)
        let centerX = width / 2 - adjusted.width / scale
        let centerY = height / 2 - adjusted.height / scale
        let rect = CGRect(
            x: min(max(0, centerX - side / 2), width - side),
            y: min(max(0, centerY - side / 2), height - side),
            width: side,
            height: side
        ).integral
        guard let cropped = normalized.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped).jpegData(compressionQuality: 0.9)
    }

    private static func normalizedCGImage(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage { return cgImage }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }
}
