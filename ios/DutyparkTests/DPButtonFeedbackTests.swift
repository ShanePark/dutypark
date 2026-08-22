import SwiftUI
import Testing
@testable import Dutypark

@MainActor
struct DPButtonFeedbackTests {
    @Test
    func destructiveButtonsUseWarningFeedbackInsteadOfRoutineFeedback() {
        let routine: [DPButtonRole] = [.primary, .success, .secondary, .outline]
        let destructive = DPButtonFeedback.feedback(for: .destructive)

        #expect(destructive == .warning)
        for role in routine {
            #expect(
                DPButtonFeedback.feedback(for: role) != destructive,
                "\(role) should not share the destructive warning"
            )
        }
    }

    /// Keep the impact comparison covered because routine button taps and drag
    /// feedback still rely on the flexibility/intensity form.
    @Test
    func weightBasedImpactCannotExpressAHeavierTap() {
        #expect(SensoryFeedback.impact(weight: .heavy) == .impact(weight: .light))
        #expect(SensoryFeedback.impact(weight: .medium) == .impact(weight: .light))
        #expect(
            SensoryFeedback.impact(flexibility: .solid, intensity: 1)
                != .impact(flexibility: .soft, intensity: 0.6),
            "the flexibility form must stay discriminating, or these haptics are untestable"
        )
    }

    @Test
    func routineRolesShareOneLightTapSoTheyStayConsistent() {
        let expected = SensoryFeedback.impact(flexibility: .soft, intensity: 0.6)

        #expect(DPButtonFeedback.feedback(for: .primary) == expected)
        #expect(DPButtonFeedback.feedback(for: .success) == expected)
        #expect(DPButtonFeedback.feedback(for: .secondary) == expected)
        #expect(DPButtonFeedback.feedback(for: .outline) == expected)
    }

    @Test
    func feedbackFiresOnlyOnThePressDownEdge() {
        #expect(DPButtonFeedback.firesOnPress(isEnabled: true, wasPressed: false, isPressed: true))
        #expect(!DPButtonFeedback.firesOnPress(isEnabled: true, wasPressed: true, isPressed: false))
        #expect(!DPButtonFeedback.firesOnPress(isEnabled: true, wasPressed: false, isPressed: false))
        #expect(!DPButtonFeedback.firesOnPress(isEnabled: true, wasPressed: true, isPressed: true))
    }

    @Test
    func disabledButtonsStaySilent() {
        #expect(!DPButtonFeedback.firesOnPress(isEnabled: false, wasPressed: false, isPressed: true))
        #expect(!DPButtonFeedback.firesOnPress(isEnabled: false, wasPressed: true, isPressed: false))
    }
}
