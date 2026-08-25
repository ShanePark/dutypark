import SwiftUI

/// Inline login-session list for the admin member rows.
///
/// Mirrors the web `SessionTokenList` in its compact, collapsible mobile form: the member row shows
/// the most recent session and expands to the rest, so the admin sees last-used time, first login,
/// IP, device and client without opening the member detail screen.
struct AdminMemberSessionList: View {
    let memberID: MemberID
    let tokens: [SettingsRefreshToken]
    let onRevoke: (SettingsRefreshToken) -> Void
    @State private var isExpanded = false

    private var presentation: AdminMemberSessionListPresentation {
        AdminMemberSessionListPresentation(tokens: tokens, isExpanded: isExpanded)
    }

    var body: some View {
        let list = presentation
        VStack(spacing: DPSpacing.small) {
            ForEach(
                Array(list.visibleTokens.enumerated()),
                id: \.element.id
            ) { index, token in
                card(token, showsToggle: list.showsToggle(at: index), presentation: list)
            }
        }
    }

    private func card(
        _ token: SettingsRefreshToken,
        showsToggle: Bool,
        presentation: AdminMemberSessionListPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack(alignment: .top, spacing: DPSpacing.small) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: DPSpacing.extraSmall) {
                        Image(systemName: "clock")
                            .font(.system(size: DPSize.iconSmall))
                            .foregroundStyle(DPColor.textMuted)
                        Text(SettingsSessionFormatter.relativeTime(token.lastUsed))
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.textSecondary)
                    }
                    Text(
                        "\(SettingsLocalization.string("settings.sessions.created")): "
                            + SettingsSessionFormatter.dateText(token.createdDate)
                    )
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .padding(.leading, 20)
                }

                Spacer(minLength: DPSpacing.small)

                HStack(spacing: DPSpacing.small) {
                    if token.isCurrentLogin == true {
                        SettingsLocalization.text("settings.sessions.current")
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.success)
                            .padding(.horizontal, DPSpacing.small)
                            .padding(.vertical, 2)
                            .background(DPColor.successSoft, in: Capsule())
                            .fixedSize()
                    } else {
                        Button {
                            onRevoke(token)
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DPColor.danger)
                                .frame(width: 24, height: 24)
                                .background(DPColor.dangerSoft, in: Circle())
                                .contentShape(Rectangle().inset(by: -10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            AdminLocalization.string("admin.members.revokeSession.action")
                        )
                        .accessibilityIdentifier("admin.member.session.revoke.\(token.id)")
                    }

                    if showsToggle {
                        Button {
                            DPHapticCenter.shared.emit(.selection)
                            isExpanded.toggle()
                        } label: {
                            Text(presentation.toggleTitle)
                                .font(DPFont.bold(size: 12, relativeTo: .caption2))
                                .foregroundStyle(
                                    presentation.isExpanded
                                        ? DPColor.textOnDark
                                        : DPColor.textSecondary
                                )
                                .frame(width: 24, height: 24)
                                .background(
                                    presentation.isExpanded
                                        ? DPColor.surfaceStrong
                                        : DPColor.backgroundTertiary,
                                    in: Circle()
                                )
                                .contentShape(Rectangle().inset(by: -10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("admin.member.sessions.toggle.\(memberID)")
                    }
                }
            }

            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                HStack(spacing: DPSpacing.small) {
                    Image(systemName: "globe")
                        .font(.system(size: DPSize.iconSmall))
                        .foregroundStyle(DPColor.textMuted)
                    Text(AdminMemberSessionListPresentation.ipText(token))
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                }
                HStack(spacing: DPSpacing.small) {
                    Image(systemName: AdminMemberSessionListPresentation.deviceIcon(token))
                        .font(.system(size: DPSize.iconSmall))
                        .foregroundStyle(DPColor.textMuted)
                    Text(AdminMemberSessionListPresentation.deviceText(token))
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                        .lineLimit(1)
                    if AdminMemberSessionListPresentation.isAppSession(token) {
                        HStack(spacing: DPSpacing.extraSmall) {
                            Image(systemName: "apps.iphone")
                                .font(.system(size: DPSize.iconSmall))
                            Text(AdminMemberSessionListPresentation.clientText(token))
                        }
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textMuted)
                    } else {
                        Text(AdminMemberSessionListPresentation.clientText(token))
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.textMuted)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DPSpacing.compact)
        .background(DPColor.backgroundTertiary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
    }
}

nonisolated struct AdminMemberSessionListPresentation: Equatable, Sendable {
    let tokens: [SettingsRefreshToken]
    let isExpanded: Bool

    init(tokens: [SettingsRefreshToken], isExpanded: Bool) {
        self.tokens = SettingsSessionFormatter.sorted(tokens)
        self.isExpanded = isExpanded
    }

    var visibleTokens: [SettingsRefreshToken] {
        isExpanded ? tokens : Array(tokens.prefix(1))
    }

    var hiddenCount: Int { max(0, tokens.count - 1) }

    var toggleTitle: String { isExpanded ? "-" : "+\(hiddenCount)" }

    /// The web renders the expand chip on the first row only, so collapsing stays reachable from
    /// the row that is always visible.
    func showsToggle(at index: Int) -> Bool {
        index == 0 && hiddenCount > 0
    }

    static func ipText(_ token: SettingsRefreshToken) -> String {
        SettingsSessionClientPresentation.nonempty(token.remoteAddr)
    }

    static func deviceText(_ token: SettingsRefreshToken) -> String {
        SettingsSessionClientPresentation.nonempty(token.userAgent?.device)
    }

    static func deviceIcon(_ token: SettingsRefreshToken) -> String {
        SettingsSessionClientPresentation(token: token).deviceIcon
    }

    static func clientText(_ token: SettingsRefreshToken) -> String {
        SettingsSessionClientPresentation(token: token).clientValue
    }

    static func isAppSession(_ token: SettingsRefreshToken) -> Bool {
        token.resolvedClientType == .iosApp
    }
}

nonisolated struct AdminMemberPaginationPresentation: Equatable, Sendable {
    let start: Int
    let end: Int
    let total: Int

    init(page: Int, pageSize: Int, totalElements: Int64) {
        total = Int(totalElements)
        start = total == 0 ? 0 : page * pageSize + 1
        end = min((page + 1) * pageSize, total)
    }

    var text: String {
        AdminLocalization.format("admin.dashboard.pagination", start, end, total)
    }
}
