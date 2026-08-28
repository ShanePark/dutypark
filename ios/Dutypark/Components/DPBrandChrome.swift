import SwiftUI
import UIKit

enum DPDashboardHeaderChrome {
    static let sharedBackgroundVisibility: SwiftUI.Visibility = .hidden
}

struct DPDashboardHeaderToolbarItem<Content: View>: ToolbarContent {
    private let placement: ToolbarItemPlacement
    private let content: Content

    init(
        placement: ToolbarItemPlacement,
        @ViewBuilder content: () -> Content
    ) {
        self.placement = placement
        self.content = content()
    }

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: placement) {
                content
            }
            .sharedBackgroundVisibility(DPDashboardHeaderChrome.sharedBackgroundVisibility)
        } else {
            ToolbarItem(placement: placement) {
                content
            }
        }
    }
}

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
        .accessibilityElement(children: .ignore)
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
