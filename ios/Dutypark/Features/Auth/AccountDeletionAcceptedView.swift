import SwiftUI

struct AccountDeletionAcceptedView: View {
    let onConfirm: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DPSpacing.large) {
                    Spacer(minLength: DPSpacing.large)

                    VStack(spacing: DPSpacing.medium) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(DPColor.success)
                            .accessibilityHidden(true)

                        Text(SettingsLocalization.string("settings.accountDeletion.accepted.title"))
                            .font(DPTypography.pageTitle)
                            .foregroundStyle(DPColor.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(SettingsLocalization.string("settings.accountDeletion.accepted.loggedOut"))
                            .font(DPTypography.body)
                            .foregroundStyle(DPColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)

                    VStack(alignment: .leading, spacing: DPSpacing.medium) {
                        informationRow(
                            systemImage: "clock.arrow.circlepath",
                            text: SettingsLocalization.string("settings.accountDeletion.accepted.processing")
                        )
                        Divider().overlay(DPColor.borderPrimary)
                        informationRow(
                            systemImage: "checkmark.circle",
                            text: SettingsLocalization.string("settings.accountDeletion.accepted.noAction")
                        )
                    }
                    .dpCard(padding: DPSpacing.medium)
                }
                .frame(maxWidth: 560)
                .frame(minHeight: max(0, geometry.size.height - 96))
                .padding(.horizontal, DPSpacing.large)
                .padding(.bottom, DPSpacing.large)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: onConfirm) {
                    Text(SettingsLocalization.string("settings.accountDeletion.accepted.confirm"))
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(DPPrimaryButtonStyle())
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DPSpacing.large)
                    .padding(.vertical, DPSpacing.medium)
                    .background(DPColor.backgroundPrimary)
                    .accessibilityIdentifier("accountDeletion.accepted.confirm")
            }
        }
        .background(DPColor.backgroundPrimary.ignoresSafeArea())
        .accessibilityIdentifier("screen.accountDeletionAccepted")
    }

    private func informationRow(
        systemImage: String,
        text: String
    ) -> some View {
        HStack(alignment: .top, spacing: DPSpacing.compact) {
            Image(systemName: systemImage)
                .font(.system(size: DPSize.icon))
                .foregroundStyle(DPColor.accent)
                .frame(width: DPSize.iconLarge)
                .accessibilityHidden(true)

            Text(text)
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
