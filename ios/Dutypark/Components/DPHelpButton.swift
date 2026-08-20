import SwiftUI

/// Chrome shared by every "how does this screen work" affordance.
///
/// Screens used to draw their own help entry point, which left the friend list with a
/// bare glyph inside a grey chip next to the todo board's plain toolbar icon. Both now
/// use the same control, and both name it with the information glyph: a question mark
/// reads as "ask a question", while what the panels actually offer is an explanation.
enum DPHelpChrome {
    static let systemImage = "info.circle"
    static let iconSize = DPSize.icon

    /// Fraction of the space the overlay offers that a help panel may fill, and the
    /// hard cap it keeps on tall devices so the copy never stretches edge to edge.
    static let maximumPanelHeightRatio: CGFloat = 0.9
    static let maximumPanelHeight: CGFloat = 720

    /// The button is a bare glyph, so a press can only be acknowledged by dimming it.
    static let pressedOpacity: Double = 0.55
}

private struct DPHelpButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let enabled = isEnabled
        return configuration.label
            .font(.system(size: DPHelpChrome.iconSize, weight: .medium))
            .foregroundStyle(DPColor.accent)
            .frame(
                minWidth: DPSize.minimumTouchTarget,
                minHeight: DPSize.minimumTouchTarget
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? DPHelpChrome.pressedOpacity : 1)
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

/// The single entry point to a screen's `DPHelpModal`.
///
/// `label` names the panel it opens for VoiceOver, because the glyph alone cannot say
/// which screen the help is about.
struct DPHelpButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: DPHelpChrome.systemImage)
        }
        .buttonStyle(DPHelpButtonStyle())
        .accessibilityLabel(label)
    }
}
