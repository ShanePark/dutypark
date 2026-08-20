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
        DPHelpModal(
            title: social("social.help.title"),
            closeLabel: social("social.action.close"),
            maximumHeight: maximumHeight,
            closeAccessibilityIdentifier: "social.help.close",
            dismiss: dismiss
        ) {
            // The three blocks are one procedure, so they are numbered.
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                DPHelpSection(
                    systemImage: step.icon,
                    title: social(step.titleKey),
                    message: social(step.bodyKey),
                    tint: step.tint,
                    step: index + 1
                )
            }

            DPHelpNote(messages: [social("social.help.note")])
        }
    }
}
