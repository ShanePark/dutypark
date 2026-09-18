import SwiftUI

/// The friend management surface used by both compact and regular iPhone layouts.
///
/// The web presents this content as a mobile bottom sheet. Keeping the same order and
/// grouping here makes the trailing management area predictable: identity first, the
/// family relationship second, and destructive actions in their own group.
struct FriendActionSheet: View {
    let friend: DashboardFriendDetailDTO
    let close: () -> Void
    let addFamily: () -> Void
    let removeFamily: () -> Void
    let removeFriend: () -> Void
    let onBlock: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DPColor.borderSecondary)
                .frame(width: 40, height: 4)
                .padding(.top, DPSpacing.small)
                .padding(.bottom, DPSpacing.extraSmall)
                .accessibilityHidden(true)
                .accessibilityIdentifier("friendActionSheetGrabber")

            header

            Divider().overlay(DPColor.borderPrimary)

            if friend.isFamily {
                actionButton(
                    social("social.action.removeFamily"),
                    image: "person.badge.minus",
                    color: DPColor.warning,
                    action: removeFamily
                )
            } else {
                actionButton(
                    social("social.action.addFamily"),
                    image: "house",
                    color: DPColor.accent,
                    action: addFamily
                )
            }

            Divider()
                .overlay(DPColor.borderPrimary)
                .padding(.top, DPSpacing.extraSmall)

            actionButton(
                social("social.action.removeFriend"),
                image: "trash",
                color: DPColor.danger,
                action: removeFriend
            )

            actionButton(
                social("social.action.block"),
                image: "hand.raised",
                color: DPColor.danger,
                action: onBlock
            )
        }
        .background(DPColor.backgroundCard)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: DPSpacing.small)
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: DPSpacing.small) {
            DPProfileAvatar(
                memberID: friend.member.id,
                hasProfilePhoto: friend.member.hasProfilePhoto,
                profilePhotoVersion: friend.member.profilePhotoVersion,
                size: 48
            )
            .overlay { Circle().stroke(DPColor.borderPrimary, lineWidth: 2) }

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.member.name)
                    .font(DPFont.bold(size: 16, relativeTo: .body))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)

                if friend.isFamily {
                    Label(
                        social("social.label.family"),
                        systemImage: "house.fill"
                    )
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.warning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(social("social.action.close"))
            .accessibilityIdentifier("social.friend.sheet.close")
        }
        .padding(.horizontal, DPSpacing.large)
        .padding(.vertical, DPSpacing.medium)
        .background(DPColor.backgroundTertiary)
    }

    private func actionButton(
        _ title: String,
        image: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DPSpacing.small) {
                Image(systemName: image)
                    .frame(width: 20)
                Text(title)
                    .font(DPFont.light(size: 15, relativeTo: .subheadline))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .foregroundStyle(color)
            .padding(.horizontal, DPSpacing.large)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("social.friend.sheet.action.\(image)")
    }
}

enum FriendActionSheetLayout {
    /// Grabber, identity header, three action rows, separators, and a small safe-area
    /// cushion. The detent is deliberately stable between family and regular friends.
    static let defaultHeight: CGFloat = 300
}
