import SwiftUI
import UIKit

/// Shared application chrome aligned with the authenticated web header and footer.
enum DPBrandChrome {
    static func configureAppearance() {
        configureNavigationBar()
        configureTabBar()
    }

    private static func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(DPColor.backgroundCard)
        appearance.shadowColor = UIColor(DPColor.borderPrimary)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(DPColor.textPrimary),
            .font: UIFont(name: DPFont.boldPostScriptName, size: 18)
                ?? UIFont.systemFont(ofSize: 18, weight: .bold)
        ]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = UIColor(DPColor.textMuted)
    }

    private static func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(DPColor.backgroundFooter)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.30)
        appearance.selectionIndicatorImage = selectionIndicatorImage()

        configure(appearance.stackedLayoutAppearance)
        configure(appearance.inlineLayoutAppearance)
        configure(appearance.compactInlineLayoutAppearance)

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.55)
        tabBar.tintColor = .white
    }

    private static func configure(_ itemAppearance: UITabBarItemAppearance) {
        let lightFont = UIFont(name: DPFont.lightPostScriptName, size: 10)
            ?? UIFont.systemFont(ofSize: 10)
        let boldFont = UIFont(name: DPFont.boldPostScriptName, size: 10)
            ?? UIFont.systemFont(ofSize: 10, weight: .semibold)

        itemAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.55)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.55),
            .font: lightFont
        ]
        itemAppearance.selected.iconColor = .white
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: boldFont
        ]
    }

    private static func selectionIndicatorImage() -> UIImage {
        let size = CGSize(width: 72, height: 48)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
            let path = UIBezierPath(roundedRect: bounds, cornerRadius: DPRadius.large)
            UIColor.white.withAlphaComponent(0.25).setFill()
            path.fill()
            UIColor.white.withAlphaComponent(0.30).setStroke()
            context.cgContext.setLineWidth(1)
            path.stroke()
        }
    }
}

struct DPBrandMark: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DPSpacing.small) {
                brandIcon
                Text("Dutypark")
                    .font(DPFont.bold(size: 18, relativeTo: .headline))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
            }
            .frame(minHeight: DPSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dutypark")
        .accessibilityIdentifier("header.brand")
    }

    @ViewBuilder
    private var brandIcon: some View {
        if let icon = Self.applicationIcon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(DPColor.accent)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textOnDark)
            }
            .frame(width: 32, height: 32)
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
