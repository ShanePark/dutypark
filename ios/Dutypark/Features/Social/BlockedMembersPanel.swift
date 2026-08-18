import SwiftUI

/// The block list is small enough to render unpaged, and it always renders so a
/// member can find the unblock control even while nobody is blocked.
struct BlockedMembersPanel: View {
    let members: [BlockedMemberDTO]
    let isDisabled: Bool
    let unblock: (BlockedMemberDTO) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SocialPanelHeader(
                title: social("social.section.blocked"),
                count: members.count,
                systemImage: "hand.raised",
                colors: [DPColor.danger, DPColor.dangerHover]
            )

            LazyVStack(spacing: DPSpacing.small) {
                if members.isEmpty {
                    emptyState
                } else {
                    ForEach(members, id: \.id) { member in
                        blockedMemberRow(member)
                    }
                }
            }
            .padding(SocialFriendCardLayout.panelInset)
            .disabled(isDisabled)
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.extraLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.extraLarge, style: .continuous)
                .stroke(DPColor.borderPrimary, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        .accessibilityIdentifier("social.blocked.list")
    }

    private var emptyState: some View {
        VStack(spacing: DPSpacing.compact) {
            Image(systemName: "hand.raised")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(DPColor.textMuted)
            Text(social("social.empty.blocked"))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DPSpacing.small)
        .accessibilityIdentifier("social.blocked.empty")
    }

    private func blockedMemberRow(_ member: BlockedMemberDTO) -> some View {
        HStack(spacing: DPSpacing.compact) {
            SocialAvatar(member: member.memberPreview, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(DPFont.bold(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                Text(socialFormat("social.blocked.since", BlockedMemberPresentation.blockedDate(member.blockedAt)))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(social("social.action.unblock")) {
                unblock(member)
            }
            .font(DPFont.light(size: 14, relativeTo: .subheadline))
            .foregroundStyle(DPColor.textPrimary)
            .padding(.horizontal, DPSpacing.compact)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.standard, style: .continuous)
                    .stroke(DPColor.borderPrimary, lineWidth: 1)
            }
            .accessibilityIdentifier("social.blocked.\(member.id).unblock")
        }
        .padding(DPSpacing.compact)
        .background(DPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large, style: .continuous)
                .stroke(DPColor.borderPrimary, lineWidth: 1)
        }
        .accessibilityIdentifier("social.blocked.\(member.id)")
    }
}

private extension BlockedMemberDTO {
    /// Adapts a blocked member to the shared social avatar input; the block list
    /// carries no team information.
    var memberPreview: MemberPreviewDTO {
        MemberPreviewDTO(
            id: id,
            name: name,
            teamId: nil,
            team: nil,
            hasProfilePhoto: hasProfilePhoto,
            profilePhotoVersion: profilePhotoVersion
        )
    }
}

nonisolated enum BlockedMemberPresentation {
    /// The server sends a `LocalDateTime`, so the value is parsed without
    /// assuming a time zone and rendered as a plain calendar date.
    static func blockedDate(
        _ value: LocalDateTimeValue,
        locale: Locale = AppLocalization.locale
    ) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .current
        parser.dateFormat = value.rawValue.contains(".")
            ? "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            : "yyyy-MM-dd'T'HH:mm:ss"
        guard let date = parser.date(from: value.rawValue) else { return value.rawValue }

        let supportedLocale = AppLocalization.supportedLocale(
            languageCode: locale.identifier,
            preferredLanguages: []
        )
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = supportedLocale
        formatter.timeZone = .current
        formatter.dateFormat = supportedLocale.identifier == "ko" ? "yyyy.MM.dd" : "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
