import SwiftUI

/// The panel a `DPHelpButton` opens, presented inside `DPModalOverlay`.
///
/// Screens supply their own blocks — `DPHelpSection` for the explanations and
/// `DPHelpNote` for the closing aside — and the panel owns everything around them, so
/// two help panels can never drift apart in header, spacing or scroll behaviour.
struct DPHelpModal<Content: View>: View {
    let title: String
    let closeLabel: String
    let maximumHeight: CGFloat
    var closeAccessibilityIdentifier: String?
    let dismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        DPModalPanel(
            maximumPanelHeight: min(
                maximumHeight * DPHelpChrome.maximumPanelHeightRatio,
                DPHelpChrome.maximumPanelHeight
            )
        ) {
            header
        } content: {
            VStack(alignment: .leading, spacing: DPSpacing.large) {
                content()
            }
            .padding(DPSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: DPHelpChrome.systemImage)
                .font(.system(size: DPHelpChrome.iconSize, weight: .semibold))
                .foregroundStyle(DPColor.accent)
                .accessibilityHidden(true)

            Text(verbatim: title)
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)

            Spacer(minLength: DPSpacing.small)

            closeButton
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.small)
        .background(DPColor.backgroundTertiary)
    }

    @ViewBuilder
    private var closeButton: some View {
        let button = Button(action: dismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(closeLabel)

        if let closeAccessibilityIdentifier {
            button.accessibilityIdentifier(closeAccessibilityIdentifier)
        } else {
            button
        }
    }
}

enum DPHelpSectionLayout {
    static let stepSize: CGFloat = 26
}

/// One explanation inside a `DPHelpModal`.
///
/// `step` numbers the block, and is only worth setting when the blocks describe an
/// ordered procedure; a screen whose blocks stand on their own leaves it out.
struct DPHelpSection: View {
    let systemImage: String
    let title: String
    let message: String
    var tint: Color = DPColor.accent
    var step: Int?

    var body: some View {
        HStack(alignment: .top, spacing: DPSpacing.compact) {
            if let step {
                Text(verbatim: "\(step)")
                    .font(DPFont.bold(size: 13, relativeTo: .footnote))
                    .foregroundStyle(tint)
                    .frame(
                        width: DPHelpSectionLayout.stepSize,
                        height: DPHelpSectionLayout.stepSize
                    )
                    .background(DPColor.backgroundTertiary, in: Circle())
                    .overlay {
                        Circle().stroke(tint.opacity(0.5), lineWidth: DPChrome.borderWidth)
                    }
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DPSpacing.small) {
                Label(title, systemImage: systemImage)
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(tint)
                Text(verbatim: message)
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The aside a help panel closes with: a tips list, or a single caveat the sections
/// above should not interrupt. A titled note bullets its lines; an untitled one is a
/// single remark and stays beside its icon.
struct DPHelpNote: View {
    var systemImage: String = DPHelpChrome.systemImage
    var title: String?
    var tint: Color = DPColor.textMuted
    let messages: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            if let title {
                Label(title, systemImage: systemImage)
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(tint)

                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                    HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
                        Text(verbatim: "•")
                        Text(verbatim: message)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                }
            } else {
                ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                    HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
                        Image(systemName: systemImage)
                            .font(.system(size: DPSize.iconSmall))
                            .foregroundStyle(tint)
                            .accessibilityHidden(true)
                        Text(verbatim: message)
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(DPSpacing.compact)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DPColor.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard, style: .continuous))
    }
}
