import Foundation
import XCTest
@testable import Dutypark

final class DragFeedbackTests: XCTestCase {
    func testLiftFiresOnceWhenACardIsPickedUp() {
        let none: MemberID? = nil
        let held: MemberID? = 31

        XCTAssertTrue(DPDragFeedback.firesOnLift(previous: none, next: held))
    }

    func testLiftDoesNotFireWhileTheDragContinues() {
        let held: MemberID? = 31

        XCTAssertFalse(DPDragFeedback.firesOnLift(previous: held, next: held))
    }

    /// A plain tap never assigns the held card, so the trigger stays `nil` and the
    /// pick-up haptic must stay silent.
    func testLiftDoesNotFireForATapThatNeverHoldsACard() {
        let none: MemberID? = nil

        XCTAssertFalse(DPDragFeedback.firesOnLift(previous: none, next: none))
        XCTAssertFalse(DPDragFeedback.firesOnDrop(previous: none, next: none))
    }

    func testDropFiresWhenTheCardIsReleased() {
        let held: MemberID? = 31
        let none: MemberID? = nil

        XCTAssertTrue(DPDragFeedback.firesOnDrop(previous: held, next: none))
        XCTAssertFalse(DPDragFeedback.firesOnLift(previous: held, next: none))
    }

    func testEachDragInASequenceFiresExactlyOneLiftAndOneDrop() {
        let states: [MemberID?] = [nil, 31, 31, 31, nil, 32, nil]

        var lifts = 0
        var drops = 0
        for (previous, next) in zip(states, states.dropFirst()) {
            if DPDragFeedback.firesOnLift(previous: previous, next: next) { lifts += 1 }
            if DPDragFeedback.firesOnDrop(previous: previous, next: next) { drops += 1 }
        }

        XCTAssertEqual(lifts, 2)
        XCTAssertEqual(drops, 2)
    }

    /// A board card is keyed by UUID rather than by member, so the same edge rule
    /// has to hold for the todo board.
    func testTheSameEdgeRuleAppliesToTheTodoBoard() {
        let todoID: TodoID? = UUID()

        XCTAssertTrue(DPDragFeedback.firesOnLift(previous: nil as TodoID?, next: todoID))
        XCTAssertTrue(DPDragFeedback.firesOnDrop(previous: todoID, next: nil as TodoID?))
        XCTAssertFalse(DPDragFeedback.firesOnLift(previous: todoID, next: todoID))
    }

    /// The lift and the drop have to be two different haptics. Asserting that
    /// directly matters more than the exact values: the previous `impact(weight:)`
    /// pair looked different in source but collapsed to the same light tap at
    /// runtime, so the drag had one indistinguishable buzz for both edges.
    func testDragLiftIsFirmerThanTheDropSettle() {
        XCTAssertNotEqual(DPDragFeedback.lift, DPDragFeedback.drop)
        XCTAssertEqual(DPDragFeedback.lift, .impact(flexibility: .solid, intensity: 0.8))
        XCTAssertEqual(DPDragFeedback.drop, .impact(flexibility: .soft, intensity: 0.5))
    }

    /// The pick-up is meant to read as firmer than a routine button press, which
    /// only holds if the two are actually distinct values.
    func testDragLiftIsDistinctFromTheRoutineButtonTick() {
        XCTAssertNotEqual(DPDragFeedback.lift, DPButtonFeedback.feedback(for: .primary))
    }

    /// All three drag surfaces route their held-card state through the shared
    /// feedback modifier instead of firing haptics from inside a gesture callback,
    /// which is what keeps a lift to one haptic instead of one per drag update.
    func testEveryDragSurfaceUsesTheSharedFeedbackModifier() throws {
        let expectations = [
            "Dutypark/Features/Home/HomeView.swift": "dpDragFeedback(dragID: draggedPinnedFriendID)",
            "Dutypark/Features/Social/SocialView.swift": "dpDragFeedback(dragID: draggedPinnedFriendID)",
            "Dutypark/Features/Todo/TodoView.swift": "dpDragFeedback(dragID: draggedTodoID)"
        ]

        for (path, expected) in expectations {
            let source = try Self.projectSource(at: path)
            XCTAssertTrue(source.contains(expected), "\(path) should apply \(expected)")
        }
    }

    /// The pinned friend drag keeps the pressed control alive under the finger, so
    /// the rationale for swallowing the lift that ends a drag has to stay next to
    /// the code that does it.
    func testTapSuppressionRationaleStaysDocumented() throws {
        let home = try Self.projectSource(at: "Dutypark/Features/Home/HomeView.swift")
        let social = try Self.projectSource(at: "Dutypark/Features/Social/SocialView.swift")

        XCTAssertTrue(home.contains("A reorder drag keeps the pressed control alive underneath the finger"))
        XCTAssertTrue(home.contains("private func consumeDragSuppression() -> Bool"))
        XCTAssertTrue(social.contains("A reorder drag keeps the pressed control alive underneath the finger"))
        XCTAssertTrue(social.contains("private func consumeDragSuppression(for memberID: MemberID?) -> Bool"))
    }

    private static func projectSource(at path: String) throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: path)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
