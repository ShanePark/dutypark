import SwiftUI
import Testing
@testable import Dutypark

@MainActor
struct DPButtonFeedbackTests {
    @Test
    func destructiveButtonsFeelHeavierThanTheRoutineRoles() {
        let routine: [DPButtonRole] = [.primary, .success, .secondary, .outline]
        let destructive = DPButtonFeedback.feedback(for: .destructive)

        #expect(destructive == .impact(flexibility: .solid, intensity: 1))
        for role in routine {
            #expect(
                DPButtonFeedback.feedback(for: role) != destructive,
                "\(role) should not share the destructive haptic"
            )
        }
    }

    /// Pins the SDK behaviour the values above are shaped around: `impact(weight:)`
    /// collapses every weight to one light tap, so a `weight` based value could
    /// neither feel nor compare as heavier. Should this ever start failing, Apple
    /// has fixed the weight form and the two roles may use it again.
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
