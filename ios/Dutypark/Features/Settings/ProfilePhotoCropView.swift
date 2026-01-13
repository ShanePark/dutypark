import SwiftUI
import UIKit

struct ProfilePhotoCropView: View {
    let image: UIImage
    let onSave: (UIImage) -> Void
    let onDelete: (() -> Void)?
    let onSelectAnother: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let maxScale: CGFloat = 3.0

    var body: some View {
        let cropSize = min(UIScreen.main.bounds.width - 64, 280)
        let normalized = normalizedImage(image)
        let baseScale = max(cropSize / normalized.size.width, cropSize / normalized.size.height)

        VStack(spacing: DesignSystem.Spacing.lg) {
            header

            cropArea(image: normalized, baseScale: baseScale, cropSize: cropSize)

            zoomSection

            actionSection
        }
        .padding(DesignSystem.Spacing.lg)
        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgPrimary : DesignSystem.Colors.Light.bgSecondary)
        .onAppear {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }

    private var header: some View {
        HStack {
            Text("프로필 사진 편집")
                .font(.headline)
                .foregroundColor(textPrimary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(textMuted)
                    .padding(8)
                    .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                    .cornerRadius(8)
            }
        }
    }

    private func cropArea(image: UIImage, baseScale: CGFloat, cropSize: CGFloat) -> some View {
        let displayScale = baseScale * scale
        let displayWidth = image.size.width * displayScale
        let displayHeight = image.size.height * displayScale

        return ZStack {
            Image(uiImage: image)
                .resizable()
                .frame(width: displayWidth, height: displayHeight)
                .offset(offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let proposed = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                            offset = clampedOffset(proposed, image: image, baseScale: baseScale, cropSize: cropSize)
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let nextScale = min(max(lastScale * value, 1.0), maxScale)
                            scale = nextScale
                            offset = clampedOffset(offset, image: image, baseScale: baseScale, cropSize: cropSize)
                        }
                        .onEnded { _ in
                            scale = min(max(scale, 1.0), maxScale)
                            lastScale = scale
                            offset = clampedOffset(offset, image: image, baseScale: baseScale, cropSize: cropSize)
                            lastOffset = offset
                        }
                )

            Color.black.opacity(0.45)
                .overlay(
                    Circle()
                        .frame(width: cropSize, height: cropSize)
                        .blendMode(.destinationOut)
                )
                .compositingGroup()

            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: cropSize, height: cropSize)
        }
        .frame(width: cropSize, height: cropSize)
        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .clipped()
    }

    private var zoomSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.caption)
                    .foregroundColor(textMuted)

                Slider(value: Binding(
                    get: { scale },
                    set: { newValue in
                        scale = min(max(newValue, 1.0), maxScale)
                        lastScale = scale
                        offset = clampedOffset(offset, image: normalizedImage(image), baseScale: baseScaleValue, cropSize: cropSizeValue)
                        lastOffset = offset
                    }
                ), in: 1.0...maxScale)
                .tint(DesignSystem.Colors.accent)

                Image(systemName: "plus.magnifyingglass")
                    .font(.caption)
                    .foregroundColor(textMuted)

                Text("\(Int(scale * 100))%")
                    .font(.caption)
                    .foregroundColor(textSecondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if let onSelectAnother {
                Button {
                    dismiss()
                    onSelectAnother()
                } label: {
                    Text("다른 이미지 선택")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    dismiss()
                } label: {
                    Text("취소")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }

                if let onDelete {
                    Button {
                        dismiss()
                        onDelete()
                    } label: {
                        Text("삭제")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.danger)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                }

                Button {
                    if let cropped = cropImage(source: image, cropSize: cropSizeValue, baseScale: baseScaleValue) {
                        dismiss()
                        onSave(cropped)
                    }
                } label: {
                    Text("저장")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.accent)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
        }
    }

    private var cropSizeValue: CGFloat {
        min(UIScreen.main.bounds.width - 64, 280)
    }

    private var baseScaleValue: CGFloat {
        let normalized = normalizedImage(image)
        return max(cropSizeValue / normalized.size.width, cropSizeValue / normalized.size.height)
    }

    private var textPrimary: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary
    }

    private var textSecondary: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary
    }

    private var textMuted: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted
    }

    private func clampedOffset(_ proposed: CGSize, image: UIImage, baseScale: CGFloat, cropSize: CGFloat) -> CGSize {
        let scaledWidth = image.size.width * baseScale * scale
        let scaledHeight = image.size.height * baseScale * scale
        let maxX = max(0, (scaledWidth - cropSize) / 2)
        let maxY = max(0, (scaledHeight - cropSize) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func cropImage(source: UIImage, cropSize: CGFloat, baseScale: CGFloat) -> UIImage? {
        let normalized = normalizedImage(source)
        let scaleFactor = baseScale * scale
        let imageOriginX = (cropSize - normalized.size.width * scaleFactor) / 2 + offset.width
        let imageOriginY = (cropSize - normalized.size.height * scaleFactor) / 2 + offset.height

        let cropX = (0 - imageOriginX) / scaleFactor
        let cropY = (0 - imageOriginY) / scaleFactor
        let cropRect = CGRect(x: cropX, y: cropY, width: cropSize / scaleFactor, height: cropSize / scaleFactor)
            .intersection(CGRect(origin: .zero, size: normalized.size))

        guard let cgImage = normalized.cgImage?.cropping(to: cropRect) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: normalized.scale, orientation: .up)
    }

    private func normalizedImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

#Preview {
    ProfilePhotoCropView(image: UIImage(systemName: "person.circle")!, onSave: { _ in }, onDelete: {}, onSelectAnother: {})
}
