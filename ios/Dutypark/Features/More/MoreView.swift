import SwiftUI

nonisolated enum MoreMenuItem: String, CaseIterable, Hashable, Sendable {
    case friends
    case notifications
    case guide
    case support
    case settings
    case logout

    // Grouped the way the web "more" menu separates global shortcuts, service
    // entries and the destructive action.
    static func visibleGroups() -> [[Self]] {
        [
            [.friends, .notifications],
            [.guide, .support, .settings],
            [.logout],
        ]
    }

    static func visibleItems() -> [Self] {
        visibleGroups().flatMap { $0 }
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
        case .guide:
            "book"
        case .support:
            "questionmark.circle"
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
        // The menu entry names the screen it opens, which is friend management; the home
        // dashboard's own panel keeps the shorter "friends" wording.
        case .friends:
            RootChromeLocalization.social("social.title")
        case .notifications:
            RootChromeLocalization.notifications("notifications.title")
        case .guide:
            RootChromeLocalization.localizable("root.menu.guide")
        case .support:
            RootChromeLocalization.localizable("root.menu.support")
        case .settings:
            RootChromeLocalization.localizable("root.menu.settings")
        case .logout:
            SettingsLocalization.string("settings.logout")
        }
    }
}

/// Identity shown by the "more" profile card. It reuses the authenticated session's
/// member so opening the tab never triggers another member request.
nonisolated struct MoreProfileSummary: Equatable, Sendable {
    let memberID: MemberID
    let name: String
    let supportingText: String?
    let hasProfilePhoto: Bool?
    let profilePhotoVersion: Int64

    init(member: LoginMember, hasProfilePhoto: Bool? = nil, profilePhotoVersion: Int64) {
        memberID = member.id
        name = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
        supportingText = Self.nonempty(member.team) ?? Self.nonempty(member.email)
        self.hasProfilePhoto = hasProfilePhoto
        self.profilePhotoVersion = profilePhotoVersion
    }

    /// Members are always named on the server, but an empty name must still leave the
    /// card with a readable label.
    var displayName: String {
        name.isEmpty ? RootChromeLocalization.localizable("root.menu.myInfo") : name
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

struct MoreView: View {
    let profile: MoreProfileSummary?
    let onOpenMyInfo: () -> Void
    let onSelect: (MoreMenuItem) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: DPSpacing.medium) {
                if let profile {
                    card {
                        MoreProfileRow(profile: profile, action: onOpenMyInfo)
                    }
                }
                ForEach(
                    Array(MoreMenuItem.visibleGroups().enumerated()),
                    id: \.offset
                ) { _, group in
                    section(group)
                }
                if let versionText = MoreAppVersion.displayText {
                    Text(verbatim: versionText)
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, DPSpacing.small)
                        .accessibilityIdentifier("more.appVersion")
                }
            }
            .padding(DPSpacing.medium)
        }
        .background(DPColor.backgroundSecondary)
    }

    private func section(_ items: [MoreMenuItem]) -> some View {
        card {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                if index > 0 {
                    Divider().overlay(DPColor.borderPrimary)
                }
                MoreMenuRow(item: item) { onSelect(item) }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.large)
                    .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
            }
    }
}

private struct MoreProfileRow: View {
    let profile: MoreProfileSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DPSpacing.compact) {
                MoreProfilePhoto(profile: profile)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: profile.displayName)
                        .font(DPTypography.bodyMedium)
                        .foregroundStyle(DPColor.textPrimary)
                        .lineLimit(1)
                    if let supportingText = profile.supportingText {
                        Text(verbatim: supportingText)
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: DPSpacing.small)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
            }
            .padding(.horizontal, DPSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("more.myInfo")
    }
}

private struct MoreProfilePhoto: View {
    let profile: MoreProfileSummary

    var body: some View {
        DPProfileAvatar(
            memberID: profile.memberID,
            hasProfilePhoto: profile.hasProfilePhoto,
            profilePhotoVersion: profile.profilePhotoVersion,
            size: 48
        )
        .accessibilityHidden(true)
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
