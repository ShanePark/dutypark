import SwiftUI

/// Tone of a row-level action control. Each case maps onto the soft-surface and
/// border token pair the rest of the app already uses for that status, so an edit,
/// a delete and an untag stay recognisable apart without inventing new colors.
nonisolated enum DPIconActionTone {
    case accent
    case warning
    case danger
    case neutral

    var foreground: Color {
        switch self {
        case .accent: DPColor.accent
        case .warning: DPColor.warningHover
        case .danger: DPColor.danger
        case .neutral: DPColor.textSecondary
        }
    }

    var background: Color {
        switch self {
        case .accent: DPColor.accentSoft
        case .warning: DPColor.warningSoft
        case .danger: DPColor.dangerSoft
        case .neutral: DPColor.backgroundTertiary
        }
    }

    var pressedBackground: Color {
        switch self {
        case .accent: DPColor.accentSoftHover
        case .warning: DPColor.warningSoftHover
        case .danger: DPColor.dangerSoftHover
        case .neutral: DPColor.backgroundHover
        }
    }

    var border: Color {
        switch self {
        case .accent: DPColor.accentBorder
        case .warning: DPColor.warningBorder
        case .danger: DPColor.dangerBorder
        case .neutral: DPColor.borderSecondary
        }
    }

    var buttonRole: DPButtonRole {
        switch self {
        case .accent: .primary
        case .warning, .neutral: .secondary
        case .danger: .destructive
        }
    }
}

enum DPIconActionMetrics {
    /// Painted size of the chip. Smaller than a touch target on purpose: three of
    /// these sit side by side in a card row, and a 44pt block each would crowd out
    /// the content they act on.
    static let controlSize: CGFloat = 32

    /// Transparent reach added around the chip so the control still answers to the
    /// full `DPSize.minimumTouchTarget`.
    static let touchPadding: CGFloat = (DPSize.minimumTouchTarget - controlSize) / 2

    static let iconSize: CGFloat = 14
}

/// Chrome for compact row actions such as edit, delete, untag or report.
///
/// These used to be drawn as a bare glyph on the card background, which read as
/// decoration rather than as something tappable. The style gives each of them a
/// filled, bordered surface in its own tone while keeping the full touch target.
struct DPIconActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    let tone: DPIconActionTone

    init(_ tone: DPIconActionTone = .neutral) {
        self.tone = tone
    }

    func makeBody(configuration: Configuration) -> some View {
        let enabled = isEnabled
        return configuration.label
            .foregroundStyle(tone.foreground)
            .frame(minHeight: DPIconActionMetrics.controlSize)
            .background(
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .fill(configuration.isPressed ? tone.pressedBackground : tone.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(tone.border, lineWidth: DPChrome.borderWidth)
            )
            .padding(DPIconActionMetrics.touchPadding)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : DPChrome.disabledOpacity)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .sensoryFeedback(
                DPButtonFeedback.feedback(for: tone.buttonRole),
                trigger: configuration.isPressed
            ) { wasPressed, isPressed in
                DPButtonFeedback.firesOnPress(
                    isEnabled: enabled,
                    wasPressed: wasPressed,
                    isPressed: isPressed
                )
            }
    }
}

/// A row action drawn as a bordered chip.
///
/// `label` always names the action for VoiceOver; `showsLabel` decides whether it is
/// spelled out next to the icon as well, which is worth the width for an action the
/// icon alone cannot explain.
struct DPIconActionButton: View {
    let systemImage: String
    let label: String
    var showsLabel: Bool = false
    var tone: DPIconActionTone = .neutral
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DPSpacing.extraSmall) {
                Image(systemName: systemImage)
                    .font(.system(size: DPIconActionMetrics.iconSize, weight: .semibold))
                if showsLabel {
                    Text(verbatim: label)
                        .font(DPTypography.caption)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: DPIconActionMetrics.controlSize)
            .padding(.horizontal, showsLabel ? DPSpacing.small : 0)
        }
        .buttonStyle(DPIconActionButtonStyle(tone))
        .accessibilityLabel(label)
    }
}
