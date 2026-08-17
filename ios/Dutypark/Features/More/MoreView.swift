import SwiftUI

nonisolated enum MoreMenuItem: String, CaseIterable, Hashable, Sendable {
    case friends
    case notifications
    case admin
    case guide
    case settings
    case logout

    // Grouped the way the web "more" menu separates global shortcuts, service
    // entries and the destructive action.
    static func visibleGroups(isAdmin: Bool) -> [[Self]] {
        [
            [.friends, .notifications],
            (isAdmin ? [.admin] : []) + [.guide, .settings],
            [.logout],
        ]
    }

    static func visibleItems(isAdmin: Bool) -> [Self] {
        visibleGroups(isAdmin: isAdmin).flatMap { $0 }
    }

    var accessibilityIdentifier: String {
        "more.\(rawValue)"
    }

    var systemImage: String {
        switch self {
        case .friends:
            "person.2"
        case .notifications:
            "bell"
        case .admin:
            "lock.shield"
        case .guide:
            "book"
        case .settings:
            "gearshape"
        case .logout:
            "rectangle.portrait.and.arrow.right"
        }
    }

    var isDestructive: Bool {
        self == .logout
    }

    var title: String {
        switch self {
        case .friends:
            RootChromeLocalization.home("home.friends")
        case .notifications:
            RootChromeLocalization.notifications("notifications.title")
        case .admin:
            AdminLocalization.string("admin.menu.title")
        case .guide:
            RootChromeLocalization.localizable("root.menu.guide")
        case .settings:
            RootChromeLocalization.localizable("root.menu.settings")
        case .logout:
            SettingsLocalization.string("settings.logout")
        }
    }
}

struct MoreView: View {
    let isAdmin: Bool
    let onSelect: (MoreMenuItem) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DPSpacing.medium) {
                ForEach(
                    Array(MoreMenuItem.visibleGroups(isAdmin: isAdmin).enumerated()),
                    id: \.offset
                ) { _, group in
                    section(group)
                }
            }
            .padding(DPSpacing.medium)
        }
        .background(DPColor.backgroundPrimary)
    }

    private func section(_ items: [MoreMenuItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                if index > 0 {
                    Divider().overlay(DPColor.borderPrimary)
                }
                MoreMenuRow(item: item) { onSelect(item) }
            }
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
        }
    }
}

private struct MoreMenuRow: View {
    let item: MoreMenuItem
    let action: () -> Void

    var body: some View {
        Button(role: item.isDestructive ? .destructive : nil, action: action) {
            HStack(spacing: DPSpacing.compact) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 32)
                Text(verbatim: item.title)
                    .font(DPTypography.body)
                Spacer()
                if !item.isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DPColor.textMuted)
                }
            }
            .foregroundStyle(item.isDestructive ? DPColor.danger : DPColor.textPrimary)
            .padding(.horizontal, DPSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.accessibilityIdentifier)
    }
}
