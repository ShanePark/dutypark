import SwiftUI

/// Roles shared by every `DP*ButtonStyle`, used to pick their press haptic.
nonisolated enum DPButtonRole {
    case primary
    case success
    case destructive
    case secondary
    case outline
}

/// Press-feedback rules factored out of the button styles so they stay testable.
///
/// Every value here is built with `impact(flexibility:intensity:)` rather than
/// `impact(weight:)`: the `weight` form collapses `.light`, `.medium` and
/// `.heavy` to one and the same light tap on the current SDK, so a `weight`
/// based value can neither *feel* nor *compare* as heavier. The
/// `flexibility`/`intensity` form carries both of its fields faithfully.
nonisolated enum DPButtonFeedback {
    /// Destructive taps are irreversible, so they get a firm, full-intensity
    /// thud instead of the routine roles' soft tick.
    static let destructiveImpact = SensoryFeedback.impact(flexibility: .solid, intensity: 1)

    /// One shared tick for every reversible tap, so routine buttons stay
    /// consistent with each other.
    static let routineImpact = SensoryFeedback.impact(flexibility: .soft, intensity: 0.6)

    static func feedback(for role: DPButtonRole) -> SensoryFeedback {
        switch role {
        case .destructive:
            return destructiveImpact
        case .primary, .success, .secondary, .outline:
            return routineImpact
        }
    }

    /// Haptics belong on the press-down edge only: firing on release would land
    /// after the action already ran, and a disabled button must stay silent.
    static func firesOnPress(isEnabled: Bool, wasPressed: Bool, isPressed: Bool) -> Bool {
        isEnabled && !wasPressed && isPressed
    }
}

/// Feedback for friend-tag selection mutations. The selector owns this at the
/// binding boundary so cards, chips, and clear-all cannot drift apart.
nonisolated enum DPFriendTagFeedback {
    static func feedback(
        isEnabled: Bool,
        previous: Set<MemberID>,
        current: Set<MemberID>
    ) -> SensoryFeedback? {
        guard isEnabled, previous != current else { return nil }
        return current.count > previous.count ? .selection : DPButtonFeedback.routineImpact
    }
}

private struct DPSolidButtonStyle: ButtonStyle {
    let role: DPButtonRole
    let background: Color
    let pressedBackground: Color
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let enabled = isEnabled
        return configuration.label
            .font(DPTypography.bodyMedium)
            .foregroundStyle(DPColor.textOnDark)
            .padding(.horizontal, DPChrome.controlHorizontalPadding)
            .frame(
                minWidth: DPSize.minimumTouchTarget,
                minHeight: DPSize.minimumTouchTarget
            )
            .background(
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .fill(configuration.isPressed ? pressedBackground : background)
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : DPChrome.disabledOpacity)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .sensoryFeedback(
                DPButtonFeedback.feedback(for: role),
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

struct DPPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        DPSolidButtonStyle(
            role: .primary,
            background: DPColor.accent,
            pressedBackground: DPColor.accentHover,
            isEnabled: isEnabled
        )
            .makeBody(configuration: configuration)
    }
}

struct DPSuccessButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        DPSolidButtonStyle(
            role: .success,
            background: DPColor.success,
            pressedBackground: DPColor.successHover,
            isEnabled: isEnabled
        )
            .makeBody(configuration: configuration)
    }
}

struct DPDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        DPSolidButtonStyle(
            role: .destructive,
            background: DPColor.danger,
            pressedBackground: DPColor.dangerHover,
            isEnabled: isEnabled
        )
            .makeBody(configuration: configuration)
    }
}

struct DPSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let enabled = isEnabled
        return configuration.label
            .font(DPTypography.bodyMedium)
            .foregroundStyle(DPColor.textPrimary)
            .padding(.horizontal, DPChrome.controlHorizontalPadding)
            .frame(
                minWidth: DPSize.minimumTouchTarget,
                minHeight: DPSize.minimumTouchTarget
            )
            .background(
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .fill(configuration.isPressed ? DPColor.backgroundHover : DPColor.backgroundTertiary)
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : DPChrome.disabledOpacity)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .sensoryFeedback(
                DPButtonFeedback.feedback(for: .secondary),
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

struct DPOutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let enabled = isEnabled
        return configuration.label
            .font(DPTypography.bodyMedium)
            .foregroundStyle(DPColor.textSecondary)
            .padding(.horizontal, DPChrome.controlHorizontalPadding)
            .frame(
                minWidth: DPSize.minimumTouchTarget,
                minHeight: DPSize.minimumTouchTarget
            )
            .background(
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .fill(configuration.isPressed ? DPColor.backgroundHover : DPColor.backgroundPrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : DPChrome.disabledOpacity)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .sensoryFeedback(
                DPButtonFeedback.feedback(for: .outline),
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

struct DPCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay(
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
            )
            .shadow(
                color: .black.opacity(DPChrome.shadowOpacity(for: colorScheme)),
                radius: 1,
                x: 0,
                y: 1
            )
    }
}

struct DPInputChromeModifier: ViewModifier {
    let isFocused: Bool
    let isInvalid: Bool
    let isDisabled: Bool

    private var borderColor: Color {
        if isInvalid { return DPColor.warning }
        if isFocused { return DPColor.accent }
        return DPColor.borderInput
    }

    func body(content: Content) -> some View {
        content
            .font(DPTypography.body)
            .foregroundStyle(DPColor.textPrimary)
            .padding(.horizontal, DPChrome.inputHorizontalPadding)
            .padding(.vertical, DPChrome.inputVerticalPadding)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(isDisabled ? DPColor.backgroundTertiary : DPColor.backgroundInput)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(borderColor, lineWidth: isFocused ? DPChrome.focusRingWidth : DPChrome.borderWidth)
            }
            .opacity(isDisabled ? DPChrome.disabledOpacity : 1)
    }
}

extension View {
    func dpCard(padding: CGFloat = DPSpacing.medium) -> some View {
        modifier(DPCardModifier(padding: padding))
    }

    func dpInputChrome(
        isFocused: Bool = false,
        isInvalid: Bool = false,
        isDisabled: Bool = false
    ) -> some View {
        modifier(
            DPInputChromeModifier(
                isFocused: isFocused,
                isInvalid: isInvalid,
                isDisabled: isDisabled
            )
        )
    }
}
