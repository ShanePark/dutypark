import Foundation
import Testing
@testable import Dutypark

/// `@MainActor` because the layout constants it compares against live in the app
/// target, which defaults every declaration to main actor isolation.
@MainActor
struct DPDragActivationTests {
    /// The ring exists to answer "how much longer?", which it only does if it fills
    /// on the same clock as the press it is counting down.
    @Test func ringFillsForExactlyAsLongAsTheReorderPress() {
        #expect(DPDragActivation.pressDuration == DPPinnedFriendDragLayout.minimumPressDuration)
        #expect(DPDragActivation.pressDuration == TodoBoardLayout.dragLongPressDuration)
    }

    /// Same for the drift tolerance: a ring that kept filling past the recognizer's
    /// `allowableMovement` would promise a lift that can no longer happen.
    @Test func ringGivesUpOnTheSameDriftAsTheRecognizer() {
        #expect(DPDragActivation.maximumPressMovement == DPPinnedFriendDragLayout.maximumPressDistance)
        #expect(DPDragActivation.maximumPressMovement == TodoBoardLayout.dragLongPressMaximumDistance)
    }

    /// The ring is driven by the reorder recognizer's own touch reports rather than
    /// by a gesture of its own: an extra `DragGesture` on the card competes with the
    /// enclosing scroll view, which broke both scrolling from a card and the reorder
    /// drag itself.
    @Test func theRingBorrowsTheReorderRecognizerInsteadOfAddingAGesture() throws {
        let component = try Self.projectSource(at: "Dutypark/Components/DPDragActivation.swift")
        let recognizer = try Self.projectSource(at: "Dutypark/Components/DPTapLongPressGestureSurface.swift")

        // Constructions, not mentions: the rationale for not adding one names the
        // gesture it rules out.
        #expect(component.contains("DragGesture(") == false)
        #expect(component.contains("simultaneousGesture(") == false)
        #expect(component.contains(".gesture(") == false)
        #expect(recognizer.contains("func touchesBegan("))
        #expect(recognizer.contains("override func reset()"))
    }

    /// The delay is there to keep taps and scroll starts from flashing the ring, so
    /// it has to stay a small slice of the press rather than most of it.
    @Test func theRingAppearsEarlyEnoughToBeWorthShowing() {
        #expect(DPDragActivation.ringAppearDelay < DPDragActivation.pressDuration)
        #expect(DPDragActivation.progressWhenRingAppears < 0.5)
    }

    /// A lifted card has to read as lifted: bigger than its resting self, and on a
    /// shadow deeper than the resting card's.
    @Test func theLiftedCardIsRaisedAboveItsRestingState() {
        #expect(DPDragActivation.liftScale > 1)
        #expect(DPDragActivation.liftRingWidth > DPChrome.borderWidth)
        #expect(DPDragActivation.liftShadowOpacity > DPChrome.shadowOpacity(for: .light))
    }

    private static func projectSource(at path: String) throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: path)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

struct DPDragRetargetFeedbackTests {
    /// The lift already covers acquiring the first slot and the drop covers losing
    /// the last one, so a tick at either edge would double up on a haptic the finger
    /// has just felt.
    @Test func onlyAMoveBetweenTwoLiveSlotsTicks() {
        #expect(DPDragFeedback.firesOnRetarget(previous: 1, next: 2))
        #expect(DPDragFeedback.firesOnRetarget(previous: 1, next: 1) == false)
        #expect(DPDragFeedback.firesOnRetarget(previous: nil, next: 1) == false)
        #expect(DPDragFeedback.firesOnRetarget(previous: 1, next: nil as Int?) == false)
        #expect(DPDragFeedback.firesOnRetarget(previous: nil, next: nil as Int?) == false)
    }

    /// Crossing slots is a lighter event than picking the card up or putting it
    /// down, and it fires far more often, so it must not be either of those.
    @Test func theRetargetTickIsItsOwnHaptic() {
        #expect(DPDragFeedback.retarget != DPDragFeedback.lift)
        #expect(DPDragFeedback.retarget != DPDragFeedback.drop)
        #expect(DPDragFeedback.retarget == .selection)
    }

    /// A drag that crosses three slots ticks three times, once per crossing.
    @Test func eachCrossingTicksExactlyOnce() {
        let slots: [Int?] = [nil, 1, 1, 2, 2, 3, 1, nil]

        var ticks = 0
        for (previous, next) in zip(slots, slots.dropFirst())
        where DPDragFeedback.firesOnRetarget(previous: previous, next: next) {
            ticks += 1
        }

        #expect(ticks == 3)
    }
}
