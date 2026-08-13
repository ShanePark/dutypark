import SwiftUI

struct DPLoadingState: View {
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: DPSpacing.small) {
            ProgressView()
                .tint(DPColor.accent)
            Text(label)
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DPSpacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("state.loading")
    }
}

struct DPErrorState: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey?
    let retryTitle: LocalizedStringKey?
    let retryAction: (() -> Void)?

    init(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        retryTitle: LocalizedStringKey? = nil,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: DPSpacing.medium) {
            VStack(spacing: DPSpacing.small) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(DPColor.danger)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let retryTitle, let retryAction {
                Button(retryTitle, action: retryAction)
                    .buttonStyle(DPPrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DPSpacing.large)
        .accessibilityIdentifier("state.error")
    }
}
