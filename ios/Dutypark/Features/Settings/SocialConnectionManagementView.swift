import SwiftUI

nonisolated struct SettingsSocialManagementPresentation: Identifiable, Equatable, Sendable {
    let provider: OAuthProvider

    var id: String { provider.rawValue }
}

nonisolated struct SettingsSocialManagementState: Equatable, Sendable {
    let provider: OAuthProvider
    let isConnected: Bool
    let connectedProviderCount: Int
    let linkingProvider: OAuthProvider?
    let unlinkingProvider: OAuthProvider?

    var isConnecting: Bool { linkingProvider == provider }
    var isDisconnecting: Bool { unlinkingProvider == provider }
    var isWorking: Bool { linkingProvider != nil || unlinkingProvider != nil }
    var canConnect: Bool { !isConnected && !isWorking }
    var canRequestUnlink: Bool {
        isConnected
            && SettingsSocialUnlinkPolicy.canUnlink(connectedProviderCount: connectedProviderCount)
            && !isWorking
    }
    var showsLastProviderReason: Bool {
        isConnected
            && !SettingsSocialUnlinkPolicy.canUnlink(connectedProviderCount: connectedProviderCount)
    }
    var statusKey: String {
        isConnected ? "settings.social.connected" : "settings.social.disconnected"
    }
}

nonisolated enum SettingsSocialManagementPolicy {
    static func providerName(_ provider: OAuthProvider) -> String {
        switch provider {
        case .kakao: "Kakao"
        case .naver: "Naver"
        }
    }

    static func manageLabel(for provider: OAuthProvider) -> String {
        SettingsLocalization.string("settings.social.manage")
            .replacingOccurrences(of: "{provider}", with: providerName(provider))
    }

    static func description(for provider: OAuthProvider) -> String {
        SettingsSocialUnlinkPolicy.confirmationMessage(for: provider)
    }
}

struct SocialConnectionManagementView: View {
    let state: SettingsSocialManagementState
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    let connect: () async -> Void
    let unlink: () async -> Void

    @State private var confirmsUnlink = false

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            modalHeader
        } content: {
            VStack(alignment: .leading, spacing: DPSpacing.large) {
                providerStatus

                Label {
                    Text(SettingsSocialManagementPolicy.description(for: state.provider))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)

                providerAction
            }
            .padding(DPSpacing.large)
        } footer: {
            Button(action: dismiss) {
                SettingsLocalization.text("settings.visibility.close")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPSecondaryButtonStyle())
            .disabled(state.isWorking)
            .padding(DPSpacing.compact)
            .accessibilityIdentifier("settings.social.management.close")
        }
        .accessibilityIdentifier("settings.social.management.panel.\(providerID)")
        .alert(SettingsLocalization.string("settings.social.unlinkConfirmTitle"), isPresented: $confirmsUnlink) {
            Button(SettingsLocalization.string("settings.social.unlink"), role: .destructive) {
                Task { await unlink() }
            }
            Button(SettingsLocalization.string("settings.action.cancel"), role: .cancel) {}
        } message: {
            Text(SettingsSocialUnlinkPolicy.confirmationMessage(for: state.provider))
        }
    }

    private var modalHeader: some View {
        HStack(spacing: DPSpacing.small) {
            SettingsLocalization.text("settings.social.title")
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DPSpacing.small)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .background(DPColor.backgroundTertiary, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(state.isWorking)
            .accessibilityLabel(SettingsLocalization.string("settings.visibility.close"))
        }
        .padding(.horizontal, DPSpacing.large)
        .frame(minHeight: 64)
    }

    private var providerStatus: some View {
        HStack(spacing: DPSpacing.medium) {
            Text(state.provider == .kakao ? "K" : "N")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(state.provider == .kakao ? DPColor.textOnLight : DPColor.textOnDark)
                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                .background(
                    state.provider == .kakao
                        ? Color(red: 1, green: 0.9, blue: 0)
                        : Color(red: 0.01, green: 0.78, blue: 0.28)
                )
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                Text(SettingsSocialManagementPolicy.providerName(state.provider))
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(DPColor.textPrimary)
                Label(
                    SettingsLocalization.string(state.statusKey),
                    systemImage: state.isConnected ? "checkmark.circle.fill" : "circle.dashed"
                )
                .font(DPTypography.caption)
                .foregroundStyle(state.isConnected ? DPColor.success : DPColor.textMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(DPSpacing.medium)
        .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.social.management.status.\(providerID)")
    }

    @ViewBuilder
    private var providerAction: some View {
        if state.isConnected {
            VStack(alignment: .leading, spacing: DPSpacing.small) {
                Button {
                    guard state.canRequestUnlink else { return }
                    confirmsUnlink = true
                } label: {
                    HStack(spacing: DPSpacing.small) {
                        if state.isDisconnecting {
                            ProgressView()
                                .tint(DPColor.textOnDark)
                        } else {
                            Image(systemName: "link.badge.minus")
                        }
                        SettingsLocalization.text(
                            state.isDisconnecting ? "settings.social.unlinking" : "settings.social.unlink"
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPDestructiveButtonStyle())
                .disabled(!state.canRequestUnlink)
                .accessibilityHint(
                    state.showsLastProviderReason
                        ? SettingsLocalization.string("settings.social.unlinkLastAuthenticationMethod")
                        : SettingsSocialManagementPolicy.description(for: state.provider)
                )
                .accessibilityIdentifier("settings.social.management.unlink.\(providerID)")

                if state.showsLastProviderReason {
                    Label(
                        SettingsLocalization.string("settings.social.unlinkLastAuthenticationMethod"),
                        systemImage: "exclamationmark.circle"
                    )
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.social.management.unlink.reason.\(providerID)")
                }
            }
        } else {
            Button {
                guard state.canConnect else { return }
                Task { await connect() }
            } label: {
                HStack(spacing: DPSpacing.small) {
                    if state.isConnecting {
                        ProgressView()
                            .tint(DPColor.textOnDark)
                    } else {
                        Image(systemName: "link.badge.plus")
                    }
                    SettingsLocalization.text("settings.social.connect")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(!state.canConnect)
            .accessibilityIdentifier("settings.social.management.connect.\(providerID)")
        }
    }

    private var providerID: String {
        state.provider.rawValue.lowercased()
    }
}
