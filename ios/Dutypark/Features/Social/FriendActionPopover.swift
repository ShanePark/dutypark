import SwiftUI

struct FriendActionPopover: View {
    let friend: DashboardFriendDetailDTO
    let close: () -> Void
    let addFamily: () -> Void
    let removeFamily: () -> Void
    let removeFriend: () -> Void
    let onBlock: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DPSpacing.small) {
                Text(friend.member.name)
                    .font(DPFont.bold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                Button {
                    DPHapticCenter.shared.emit(.routine)
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DPColor.textMuted)
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, DPSpacing.medium)
            .padding(.trailing, 6)
            .background(DPColor.backgroundTertiary)

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
                    action: {
                        DPHapticCenter.shared.emit(.selection)
                        addFamily()
                    }
                )
            }

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
        .frame(minWidth: 200, maxWidth: 240)
        .background(DPColor.backgroundCard)
    }

    private func actionButton(
        _ title: String,
        image: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: image).frame(width: 16)
                Text(title)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .font(DPFont.light(size: 14, relativeTo: .subheadline))
            .foregroundStyle(color)
            .padding(.horizontal, DPSpacing.medium)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
