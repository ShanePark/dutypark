import Foundation
import CoreGraphics
import Testing
@testable import Dutypark

@MainActor
struct TodoDragAutoScrollTests {
    private let viewport = CGRect(x: 0, y: 0, width: 375, height: 700)

    @Test
    func trailingEdgeChoosesTheNextColumnAndDoesNotRepeatWhileScrollIsInFlight() {
        let target = TodoDragAutoScrollPolicy.nextStatus(
            location: CGPoint(x: 370, y: 300),
            viewport: viewport,
            visibleStatus: .todo,
            lastAutoScrolledStatus: nil
        )

        #expect(target == .inProgress)
        #expect(TodoDragAutoScrollPolicy.nextStatus(
            location: CGPoint(x: 370, y: 300),
            viewport: viewport,
            visibleStatus: .todo,
            lastAutoScrolledStatus: target
        ) == nil)
    }

    @Test
    func leadingAndTrailingEdgesRespectBoardBoundaries() {
        #expect(TodoDragAutoScrollPolicy.nextStatus(
            location: CGPoint(x: 5, y: 300),
            viewport: viewport,
            visibleStatus: .todo,
            lastAutoScrolledStatus: nil
        ) == nil)
        #expect(TodoDragAutoScrollPolicy.nextStatus(
            location: CGPoint(x: 370, y: 300),
            viewport: viewport,
            visibleStatus: .done,
            lastAutoScrolledStatus: nil
        ) == nil)
        #expect(TodoDragAutoScrollPolicy.nextStatus(
            location: CGPoint(x: 5, y: 300),
            viewport: viewport,
            visibleStatus: .done,
            lastAutoScrolledStatus: nil
        ) == .inProgress)
    }

    @Test
    func leavingTheEdgeAllowsACompletedScrollToBeRequestedAgain() {
        #expect(TodoDragAutoScrollPolicy.isInsideActivationEdge(
            location: CGPoint(x: 370, y: 300),
            viewport: viewport
        ))
        #expect(!TodoDragAutoScrollPolicy.isInsideActivationEdge(
            location: CGPoint(x: 180, y: 300),
            viewport: viewport
        ))

        #expect(TodoDragAutoScrollPolicy.nextStatus(
            location: CGPoint(x: 370, y: 300),
            viewport: viewport,
            visibleStatus: .inProgress,
            lastAutoScrolledStatus: nil
        ) == .done)
    }

    @Test
    func boardUsesLiveDropFramesAndSynchronizesBothStatusBindings() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Dutypark/Features/Todo/TodoView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("cards: cardDropTargets"))
        #expect(source.contains("columns: columnDropTargets"))
        #expect(!source.contains("dragReferenceCardTargets"))
        #expect(!source.contains("dragReferenceColumnTargets"))
        #expect(source.contains("model.selectedStatus = status"))
        #expect(source.contains("visibleStatus = status"))
    }

    @Test
    func dragTransitionUsesOneSmoothScrollPath() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Dutypark/Features/Todo/TodoView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("static let dragAutoScrollDuration: TimeInterval = 0.3"))
        #expect(source.contains("withAnimation(.smooth("))
        #expect(source.contains("duration: TodoBoardLayout.dragAutoScrollDuration"))
        #expect(source.contains("extraBounce: 0"))
        #expect(source.contains("guard draggedTodoID == nil else { return }"))
    }
}
