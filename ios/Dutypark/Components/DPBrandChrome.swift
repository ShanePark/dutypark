import SwiftUI
import UIKit

struct DPBrandMark: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: DPSpacing.small) {
            brandIcon
            Text("Dutypark")
                .font(DPFont.bold(size: 18, relativeTo: .headline))
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)
        }
        .frame(minHeight: DPSize.minimumTouchTarget)
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityLabel("Dutypark")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
        .accessibilityIdentifier("header.brand")
    }

    @ViewBuilder
    private var brandIcon: some View {
        if let icon = Self.applicationIcon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFill()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image("DutyparkLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private static var applicationIcon: UIImage? {
        guard
            let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let iconName = iconFiles.last
        else { return nil }
        return UIImage(named: iconName)
    }
}
