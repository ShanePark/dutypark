import SwiftUI

private struct DPSolidButtonStyle: ButtonStyle {
    let background: Color
    let pressedBackground: Color
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
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
    }
}

struct DPPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        DPSolidButtonStyle(
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
        configuration.label
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
    }
}

struct DPOutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
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
