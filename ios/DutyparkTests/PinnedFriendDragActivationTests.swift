import Foundation
import Testing
@testable import Dutypark

/// Home and Social both feed `dpDragRetargetFeedback` the index the held card
/// occupies in the live reordered list. That only works as a "which slot am I
/// over?" identity if it stays put while the finger moves inside one slot and
/// changes exactly once per crossing — a trigger that churned on every drag
/// update would buzz continuously for the length of the drag.
@MainActor
struct PinnedFriendDragActivationTests {
    private static let order: [MemberID] = [31, 32, 33]
    private static let targets = [
        DPPinnedFriendDropTarget(memberID: 31, frame: CGRect(x: 0, y: 0, width: 300, height: 88)),
        DPPinnedFriendDropTarget(memberID: 32, frame: CGRect(x: 0, y: 96, width: 300, height: 88)),
        DPPinnedFriendDropTarget(memberID: 33, frame: CGRect(x: 0, y: 192, width: 300, height: 88))
    ]

    @Test func draggingPastEveryCardTicksOncePerCrossing() {
        let slots = sweep(from: 0, to: 200)

        #expect(slots.first == .some(0))
        #expect(slots.last == .some(2))
        #expect(ticks(in: slots) == 2)
    }

    @Test func movingInsideOneSlotIsSilent() {
        let slots = sweep(from: 0, to: 16)

        #expect(slots.allSatisfy { $0 == 0 })
        #expect(ticks(in: slots) == 0)
    }

    @Test func draggingBackUpTicksAgain() {
        let slots = sweep(from: 200, to: 0, by: -4)

        #expect(slots.first == .some(2))
        #expect(slots.last == .some(0))
        #expect(ticks(in: slots) == 2)
    }

    /// The first and last samples of a drag are the lift and the drop, and both
    /// already have a haptic of their own.
    @Test func theEdgesOfADragDoNotTick() {
        let drag: [Int?] = [nil] + sweep(from: 0, to: 200) + [nil]

        #expect(ticks(in: drag) == 2)
    }

    private func sweep(from start: CGFloat, to end: CGFloat, by step: CGFloat = 4) -> [Int?] {
        stride(from: start, through: end, by: step).map { previewTop in
            DPPinnedFriendLiveOrder.reordered(
                Self.order,
                draggedID: 31,
                previewFrame: CGRect(x: 0, y: previewTop, width: 300, height: 88),
                targets: Self.targets
            )
            .firstIndex(of: 31)
        }
    }

    private func ticks(in slots: [Int?]) -> Int {
        var ticks = 0
        for (previous, next) in zip(slots, slots.dropFirst())
        where DPDragFeedback.firesOnRetarget(previous: previous, next: next) {
            ticks += 1
        }
        return ticks
    }
}
