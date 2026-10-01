import XCTest
import UIKit
@testable import Dutypark

/// A calendar grid that pages sideways sits inside a page that scrolls down, and only
/// one of them can have any given drag. These are the rules that hand it over.
final class DPHorizontalPanPolicyTests: XCTestCase {
    func testADragHeadingSidewaysBelongsToThePager() {
        XCTAssertTrue(DPHorizontalPanPolicy.shouldBegin(
            velocity: CGPoint(x: 900, y: 30), translation: CGPoint(x: 60, y: 10)
        ))
        XCTAssertTrue(DPHorizontalPanPolicy.shouldBegin(
            velocity: CGPoint(x: -900, y: -30), translation: CGPoint(x: -60, y: -10)
        ))
    }

    func testASlightlyDiagonalDragHeadingSidewaysBelongsToThePager() {
        XCTAssertTrue(DPHorizontalPanPolicy.shouldBegin(
            velocity: CGPoint(x: 520, y: 900), translation: CGPoint(x: 52, y: 45)
        ))
        XCTAssertTrue(DPHorizontalPanPolicy.shouldBegin(
            velocity: CGPoint(x: -520, y: -900), translation: CGPoint(x: -52, y: -45)
        ))
    }

    func testADragHeadingDownThePageBelongsToTheScroll() {
        XCTAssertFalse(DPHorizontalPanPolicy.shouldBegin(
            velocity: CGPoint(x: 0, y: 900), translation: CGPoint(x: 0, y: 50)
        ))
        XCTAssertFalse(DPHorizontalPanPolicy.shouldBegin(
            velocity: CGPoint(x: 0, y: -900), translation: CGPoint(x: 0, y: -50)
        ))
    }

    // The regression this rule exists for: a thumb starting a scroll rolls sideways for
    // the first few points, and that was enough for the pager to swallow the scroll.
    func testAScrollThatDriftsSidewaysStillBelongsToTheScroll() {
        XCTAssertFalse(DPHorizontalPanPolicy.shouldBegin(
            velocity: CGPoint(x: 190, y: -940), translation: CGPoint(x: 12, y: -55)
        ))
        XCTAssertFalse(DPHorizontalPanPolicy.shouldBegin(
            velocity: CGPoint(x: -190, y: 940), translation: CGPoint(x: -12, y: 55)
        ))
    }

    func testADeadHeatBelongsToTheScroll() {
        XCTAssertFalse(DPHorizontalPanPolicy.shouldBegin(
            velocity: CGPoint(x: 500, y: 500), translation: CGPoint(x: 30, y: 30)
        ))
        XCTAssertTrue(DPHorizontalPanPolicy.shouldBegin(velocity: .zero, translation: .zero))
    }

    func testUnresolvedTravelKeepsTheTouchAliveRegardlessOfInitialVelocity() {
        XCTAssertTrue(DPHorizontalPanPolicy.shouldBegin(
            velocity: CGPoint(x: 60, y: 20), translation: CGPoint(x: 4, y: 2)
        ))
        XCTAssertTrue(DPHorizontalPanPolicy.shouldBegin(
            velocity: CGPoint(x: 20, y: 60), translation: CGPoint(x: 2, y: 4)
        ))
    }

    func testAnUnresolvedPanIsNotRejectedByNoisyInitialVelocity() {
        XCTAssertTrue(DPHorizontalPanPolicy.shouldBegin(
            velocity: CGPoint(x: 20, y: 60), translation: CGPoint(x: 4, y: 2)
        ), "UIKit must keep the touch alive until there is enough travel to lock its axis")
    }

    @MainActor
    func testNoisyBeginCanBecomeAHorizontalSwipeInTheSameTouch() {
        let coordinator = DPHorizontalPanCoordinator()
        var changes: [CGSize] = []
        var ends: [CGSize] = []
        coordinator.onChanged = { changes.append($0) }
        coordinator.onEnded = { translation, _ in ends.append(translation) }

        coordinator.handlePan(state: .began, translation: CGPoint(x: 4, y: 2), velocity: CGPoint(x: 20, y: 60))
        XCTAssertTrue(changes.isEmpty)
        coordinator.handlePan(state: .changed, translation: CGPoint(x: 40, y: 12), velocity: .zero)
        coordinator.handlePan(state: .ended, translation: CGPoint(x: 120, y: 20), velocity: .zero)

        XCTAssertEqual(changes.last, CGSize(width: 120, height: 20))
        XCTAssertEqual(ends, [CGSize(width: 120, height: 20)])
    }

    @MainActor
    func testFastFlickPreparesTheTrackBeforeEndingWithoutAnIntermediateChange() {
        let coordinator = DPHorizontalPanCoordinator()
        var events: [String] = []
        coordinator.onChanged = { _ in events.append("change") }
        coordinator.onEnded = { _, _ in events.append("end") }
        coordinator.handlePan(state: .began, translation: CGPoint(x: -4, y: 2), velocity: .zero)
        coordinator.handlePan(state: .ended, translation: CGPoint(x: -36, y: 10), velocity: CGPoint(x: -700, y: 40))
        XCTAssertEqual(events, ["change", "end"])
    }

    @MainActor
    func testVerticalTouchNeverChangesTheMonthAndTheNextTouchCanSwipe() {
        let coordinator = DPHorizontalPanCoordinator()
        var events: [String] = []
        coordinator.onChanged = { _ in events.append("change") }
        coordinator.onEnded = { _, _ in events.append("end") }
        coordinator.onCancelled = { _ in events.append("cancel") }
        coordinator.handlePan(state: .began, translation: CGPoint(x: 2, y: 4), velocity: .zero)
        coordinator.handlePan(state: .changed, translation: CGPoint(x: 8, y: 30), velocity: .zero)
        coordinator.handlePan(state: .ended, translation: CGPoint(x: 120, y: 60), velocity: .zero)
        XCTAssertTrue(events.isEmpty)
        XCTAssertFalse(coordinator.gesture.cancelsTouchesInView)
        XCTAssertTrue(coordinator.gestureRecognizer(coordinator.gesture, shouldRecognizeSimultaneouslyWith: UIPanGestureRecognizer()))

        coordinator.handlePan(state: .began, translation: CGPoint(x: 40, y: 12), velocity: .zero)
        coordinator.handlePan(state: .cancelled, translation: CGPoint(x: 80, y: 20), velocity: .zero)
        XCTAssertEqual(events, ["change", "cancel"])
        events.removeAll()
        coordinator.handlePan(state: .began, translation: CGPoint(x: 2, y: 4), velocity: .zero)
        coordinator.handlePan(state: .changed, translation: CGPoint(x: 8, y: 30), velocity: .zero)
        coordinator.handlePan(state: .failed, translation: CGPoint(x: 120, y: 60), velocity: .zero)
        XCTAssertTrue(events.isEmpty)
    }

    func testThePagerPreparesItsTrackWhenThePanBegins() {
        XCTAssertTrue(DPHorizontalPanPolicy.shouldSendChange(for: .began))
        XCTAssertTrue(DPHorizontalPanPolicy.shouldSendChange(for: .changed))
        XCTAssertFalse(DPHorizontalPanPolicy.shouldSendChange(for: .ended))
    }

    func testOnlyAnEndedPanCanCommitAndCancellationIsSeparate() {
        XCTAssertTrue(DPHorizontalPanPolicy.shouldSendEnd(for: .ended))
        XCTAssertFalse(DPHorizontalPanPolicy.shouldSendEnd(for: .cancelled))
        XCTAssertFalse(DPHorizontalPanPolicy.shouldSendEnd(for: .failed))
        XCTAssertTrue(DPHorizontalPanPolicy.shouldSendCancel(for: .cancelled))
        XCTAssertTrue(DPHorizontalPanPolicy.shouldSendCancel(for: .failed))
        XCTAssertFalse(DPHorizontalPanPolicy.shouldSendCancel(for: .ended))
    }
}
