import SwiftUI

/// Explains how the friend list is ordered.
///
/// Reordering only exists for pinned friends, needs at least two of them, and starts
/// with a long press rather than an immediate drag — none of which the list itself can
/// show, so the screen offers this as help instead of a permanent hint.
struct SocialHelpModal: View {
    let maximumHeight: CGFloat
    let dismiss: () -> Void

    private let steps: [(icon: String, titleKey: String, bodyKey: String, tint: Color)] = [
        ("star.fill", "social.help.pin.title", "social.help.pin.body", DPColor.warning),
        (
            "hand.draw",
            "social.help.reorder.title",
            "social.help.reorder.body",
            DPColor.accent
        ),
        ("checkmark.circle", "social.help.save.title", "social.help.save.body", DPColor.success),
    ]

    var body: some View {
        DPModalPanel(maximumPanelHeight: min(maximumHeight * 0.9, 720)) {
            header
        } content: {
            helpBody
        }
    }

    private var header: some View {
        HStack {
            Text(social("social.help.title"))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(social("social.action.close"))
            .accessibilityIdentifier("social.help.close")
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.small)
        .background(DPColor.backgroundTertiary)
    }

    private var helpBody: some View {
        VStack(alignment: .leading, spacing: DPSpacing.large) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                helpStep(number: index + 1, step: step)
            }

            HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(DPColor.textMuted)
                Text(social("social.help.note"))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DPSpacing.compact)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DPColor.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard, style: .continuous))
        }
        .padding(DPSpacing.medium)
    }

    private func helpStep(
        number: Int,
        step: (icon: String, titleKey: String, bodyKey: String, tint: Color)
    ) -> some View {
        HStack(alignment: .top, spacing: DPSpacing.compact) {
            Text(verbatim: "\(number)")
                .font(DPFont.bold(size: 13, relativeTo: .footnote))
                .foregroundStyle(step.tint)
                .frame(width: 26, height: 26)
                .background(DPColor.backgroundTertiary, in: Circle())
                .overlay {
                    Circle().stroke(step.tint.opacity(0.5), lineWidth: DPChrome.borderWidth)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DPSpacing.small) {
                Label(social(step.titleKey), systemImage: step.icon)
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(step.tint)
                Text(social(step.bodyKey))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
