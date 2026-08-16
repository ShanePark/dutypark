import SwiftUI

/// Compact, web-style confirmation content presented inside `DPModalOverlay`.
///
/// Pass `maximumContentWidth: DPConfirmationPanel.maximumWidth` to the overlay
/// so its background and shadow hug this panel on wider devices.
struct DPConfirmationPanel: View {
    static let minimumWidth: CGFloat = 280
    static let maximumWidth: CGFloat = 340

    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let isDestructive: Bool
    let isWorking: Bool
    let maximumHeight: CGFloat
    let cancel: () -> Void
    let confirm: () -> Void

    init(
        title: String,
        message: String,
        confirmTitle: String,
        cancelTitle: String,
        isDestructive: Bool = false,
        isWorking: Bool = false,
        maximumHeight: CGFloat,
        cancel: @escaping () -> Void,
        confirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
        self.isWorking = isWorking
        self.maximumHeight = maximumHeight
        self.cancel = cancel
        self.confirm = confirm
    }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            Text(verbatim: title)
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, DPSpacing.large)
                .background(DPColor.backgroundTertiary)
                .accessibilityAddTraits(.isHeader)
        } content: {
            Text(verbatim: message)
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(DPSpacing.large)
        } footer: {
            actionButtons
                .padding(.horizontal, DPSpacing.large)
                .padding(.vertical, DPSpacing.medium)
        }
        .frame(minWidth: Self.minimumWidth, maxWidth: Self.maximumWidth)
        .accessibilityElement(children: .contain)
    }

    private var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DPSpacing.compact) {
                cancelButton
                confirmButton
            }

            VStack(spacing: DPSpacing.small) {
                cancelButton
                confirmButton
            }
        }
    }

    private var cancelButton: some View {
        Button(role: .cancel, action: cancel) {
            Text(verbatim: cancelTitle)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(DPOutlineButtonStyle())
        .frame(maxWidth: .infinity)
        .disabled(isWorking)
        .accessibilityIdentifier("dp.confirmation.cancel")
    }

    @ViewBuilder
    private var confirmButton: some View {
        if isDestructive {
            Button(role: .destructive, action: confirm) {
                confirmLabel
            }
            .buttonStyle(DPDestructiveButtonStyle())
            .frame(maxWidth: .infinity)
            .disabled(isWorking)
            .accessibilityLabel(confirmTitle)
            .accessibilityIdentifier("dp.confirmation.confirm")
        } else {
            Button(action: confirm) {
                confirmLabel
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .frame(maxWidth: .infinity)
            .disabled(isWorking)
            .accessibilityLabel(confirmTitle)
            .accessibilityIdentifier("dp.confirmation.confirm")
        }
    }

    private var confirmLabel: some View {
        Group {
            if isWorking {
                ProgressView()
                    .tint(DPColor.textOnDark)
            } else {
                Text(verbatim: confirmTitle)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
