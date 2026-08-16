import Foundation
import Testing
@testable import Dutypark

struct TodoDropSlotTests {
    private let dragged = UUID()
    private let target = UUID()

    /// A board sitting still offers no slot, so the tick has nothing to compare
    /// and a tap can never sound like a reorder.
    @Test func noSlotWhileNoCardIsHeld() {
        #expect(TodoDropSlot.resolved(
            draggedTodoID: nil,
            targetStatus: .todo,
            targetTodoID: target,
            insertAfter: false
        ) == nil)
    }

    /// The finger can leave every column mid-drag; there is no slot to announce
    /// until it comes back over one.
    @Test func noSlotWhileTheFingerIsOverNoTarget() {
        #expect(TodoDropSlot.resolved(
            draggedTodoID: dragged,
            targetStatus: nil,
            targetTodoID: target,
            insertAfter: true
        ) == nil)
    }

    @Test func aLiveTargetResolvesToItsSlot() {
        let slot = TodoDropSlot.resolved(
            draggedTodoID: dragged,
            targetStatus: .inProgress,
            targetTodoID: target,
            insertAfter: true
        )

        #expect(slot == TodoDropSlot(status: .inProgress, targetTodoID: target, insertAfter: true))
    }

    /// Dropping at the end of a column has no reference card, which is still a
    /// slot the finger can cross into.
    @Test func theEndOfAColumnIsItsOwnSlot() {
        let slot = TodoDropSlot.resolved(
            draggedTodoID: dragged,
            targetStatus: .done,
            targetTodoID: nil,
            insertAfter: false
        )

        #expect(slot == TodoDropSlot(status: .done, targetTodoID: nil, insertAfter: false))
    }

    /// Crossing a card's midpoint moves the insertion from above it to below it.
    /// The card is the same, so only `insertAfter` separates the two slots — and
    /// the finger has to feel that crossing.
    @Test func theSameCardAboveAndBelowAreDifferentSlots() {
        let above = TodoDropSlot.resolved(
            draggedTodoID: dragged,
            targetStatus: .todo,
            targetTodoID: target,
            insertAfter: false
        )
        let below = TodoDropSlot.resolved(
            draggedTodoID: dragged,
            targetStatus: .todo,
            targetTodoID: target,
            insertAfter: true
        )

        #expect(above != below)
        #expect(DPDragFeedback.firesOnRetarget(previous: above, next: below))
    }

    /// Carrying the same card between columns lands on a different slot even when
    /// both columns drop at the end.
    @Test func theSamePositionInAnotherColumnIsADifferentSlot() {
        let todoColumn = TodoDropSlot.resolved(
            draggedTodoID: dragged,
            targetStatus: .todo,
            targetTodoID: nil,
            insertAfter: false
        )
        let doneColumn = TodoDropSlot.resolved(
            draggedTodoID: dragged,
            targetStatus: .done,
            targetTodoID: nil,
            insertAfter: false
        )

        #expect(DPDragFeedback.firesOnRetarget(previous: todoColumn, next: doneColumn))
    }

    /// The resolver runs on every gesture sample, so a finger held still keeps
    /// producing the same slot; that must stay one silent value, not a buzz per
    /// sample.
    @Test func aStillFingerKeepsResolvingTheSameSlot() {
        let samples = (0..<5).map { _ in
            TodoDropSlot.resolved(
                draggedTodoID: dragged,
                targetStatus: .todo,
                targetTodoID: target,
                insertAfter: false
            )
        }

        for (previous, next) in zip(samples, samples.dropFirst()) {
            #expect(DPDragFeedback.firesOnRetarget(previous: previous, next: next) == false)
        }
    }

    /// A whole drag: pick up, cross two slots, drop. The lift and the drop have
    /// their own haptics, so only the two crossings tick.
    @Test func aDragTicksOncePerCrossingAndNotAtItsEdges() {
        let slots: [TodoDropSlot?] = [
            // Nothing held, then lifted before the finger has found a slot.
            TodoDropSlot.resolved(draggedTodoID: nil, targetStatus: nil, targetTodoID: nil, insertAfter: false),
            TodoDropSlot.resolved(draggedTodoID: dragged, targetStatus: nil, targetTodoID: nil, insertAfter: false),
            TodoDropSlot.resolved(
                draggedTodoID: dragged,
                targetStatus: .todo,
                targetTodoID: target,
                insertAfter: false
            ),
            TodoDropSlot.resolved(
                draggedTodoID: dragged,
                targetStatus: .todo,
                targetTodoID: target,
                insertAfter: true
            ),
            TodoDropSlot.resolved(draggedTodoID: dragged, targetStatus: .done, targetTodoID: nil, insertAfter: false),
            // Released.
            TodoDropSlot.resolved(draggedTodoID: nil, targetStatus: nil, targetTodoID: nil, insertAfter: false)
        ]

        var ticks = 0
        for (previous, next) in zip(slots, slots.dropFirst())
        where DPDragFeedback.firesOnRetarget(previous: previous, next: next) {
            ticks += 1
        }

        #expect(ticks == 2)
    }
}

struct TodoDragActivationWiringTests {
    /// The ring, the lift highlight and the vacated slot all have to reach the
    /// board; wiring them is the whole feature, and none of it is reachable from
    /// a unit test.
    @Test func theTodoBoardWiresEveryDragActivationAffordance() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Dutypark/Features/Todo/TodoView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("dpPressProgress(isPressing: isPressing, isDragging: isDragging, tint: status.color)"))
        #expect(source.contains("dpDragLift(tint: status.color, cornerRadius: TodoBoardLayout.cardRadius)"))
        #expect(source.contains("dpDragSourceSlot("))
        #expect(source.contains("dpDragRetargetFeedback(target: retargetDropSlot)"))
        #expect(source.contains("dpDragFeedback(dragID: draggedTodoID)"))
    }

    /// The ring adds no gesture of its own, so it only ever fills if the reorder
    /// recognizer reports the touch on both the iOS 18 and the iOS 17 path. A
    /// board that dropped either report would show a ring that never appears.
    @Test func theTodoBoardFeedsThePressRingFromTheReorderGesture() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Dutypark/Features/Todo/TodoView.swift"),
            encoding: .utf8
        )

        // The iOS 18 recognizer receives both reports.
        #expect(source.contains("onPressBegan: onPressBegan"))
        #expect(source.contains("onPressEnded: onPressEnded"))
        // The iOS 17 fallback reports the same two from its sequenced phases.
        #expect(source.contains("if case .first(true) = phase"))
        #expect(source.contains("isPressing: pressedTodoID == todo.uuid"))
    }
}
