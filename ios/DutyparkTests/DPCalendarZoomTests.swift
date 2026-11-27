import CoreGraphics
import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass
import XCTest
@testable import Dutypark

final class DPCalendarZoomTests: XCTestCase {
    func testScaleStaysBetweenActualSizeAndThreeTimes() {
        XCTAssertEqual(DPCalendarZoomPolicy.scale(0.5), 1)
        XCTAssertEqual(DPCalendarZoomPolicy.scale(2), 2)
        XCTAssertEqual(DPCalendarZoomPolicy.scale(4), 3)
    }

    func testPinchKeepsTheContentUnderTheFingers() {
        let offset = DPCalendarZoomPolicy.pinchOffset(
            startScale: 1, startOffset: .zero, startLocation: CGPoint(x: 100, y: 150),
            location: CGPoint(x: 110, y: 160), scale: 2,
            size: CGSize(width: 350, height: 500), visibleRect: CGRect(x: 0, y: 0, width: 350, height: 500)
        )
        XCTAssertEqual(offset, CGSize(width: -90, height: -140))
        XCTAssertEqual(100 * 2 + offset.width, 110)
        XCTAssertEqual(150 * 2 + offset.height, 160)
    }

    func testPanStaysWithinTheVisibleEdges() {
        let size = CGSize(width: 350, height: 500)
        let viewport = CGRect(origin: .zero, size: size)
        XCTAssertEqual(
            DPCalendarZoomPolicy.offset(CGSize(width: 100, height: -2000), scale: 2, size: size, visibleRect: viewport),
            CGSize(width: 0, height: -500)
        )
        XCTAssertEqual(
            DPCalendarZoomPolicy.offset(CGSize(width: -400, height: 20), scale: 1, size: size, visibleRect: viewport),
            .zero
        )
    }

    func testTallMonthCanBringItsLastWeekIntoTheVisibleViewport() {
        let offset = DPCalendarZoomPolicy.offset(
            CGSize(width: 0, height: -3000), scale: 2,
            size: CGSize(width: 350, height: 1000),
            visibleRect: CGRect(x: 0, y: 200, width: 350, height: 500)
        )
        XCTAssertEqual(offset.height, -1300)
        XCTAssertEqual(1000 * 2 + offset.height, 700)
    }

    func testEmptyOrStaleViewportUsesValidCalendarBounds() {
        let size = CGSize(width: 350, height: 500)
        let bounds = CGRect(origin: .zero, size: size)
        XCTAssertEqual(DPCalendarZoomPolicy.viewport(.zero, size: size), bounds)
        XCTAssertEqual(DPCalendarZoomPolicy.viewport(.null, size: size), bounds)
        XCTAssertEqual(
            DPCalendarZoomPolicy.viewport(CGRect(x: 0, y: 450, width: 350, height: 300), size: size),
            CGRect(x: 0, y: 450, width: 350, height: 50)
        )
        XCTAssertEqual(
            DPCalendarZoomPolicy.offset(CGSize(width: -2000, height: -2000), scale: 2, size: size, visibleRect: .zero),
            CGSize(width: -350, height: -500)
        )
    }

    @MainActor
    func testPanYieldsAtActualSizeAndOnlyStartsInsideAnEnlargedCalendar() {
        let coordinator = DPCalendarZoomCoordinator()
        let anchor = UIView(frame: CGRect(x: 0, y: 0, width: 350, height: 500))
        coordinator.anchor = anchor
        XCTAssertFalse(coordinator.gestureRecognizerShouldBegin(coordinator.pan))
        coordinator.isZoomed = { true }
        XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(coordinator.pan))
        XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(coordinator.pinch))
        XCTAssertEqual(coordinator.pan.maximumNumberOfTouches, 1)
    }

    @MainActor
    func testCancelledPinchRestoresOuterScrolling() {
        let coordinator = DPCalendarZoomCoordinator()
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 350, height: 500))
        let anchor = UIView(frame: scrollView.bounds)
        scrollView.addSubview(anchor)
        coordinator.anchor = anchor
        coordinator.attach(to: scrollView)
        coordinator.handlePinch(state: .began, scale: 1, location: CGPoint(x: 100, y: 100))
        XCTAssertFalse(scrollView.panGestureRecognizer.isEnabled)
        coordinator.handlePinch(state: .cancelled, scale: 1, location: CGPoint(x: 100, y: 100))
        XCTAssertTrue(scrollView.panGestureRecognizer.isEnabled)
        coordinator.detach()
    }

    @MainActor
    func testMonthResetAndDetachRestoreOuterScrolling() {
        let coordinator = DPCalendarZoomCoordinator()
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 350, height: 500))
        coordinator.attach(to: scrollView)
        coordinator.resetIfNeeded(for: AnyHashable("first"))
        coordinator.handlePan(state: .began, translation: .zero)
        XCTAssertFalse(scrollView.panGestureRecognizer.isEnabled)
        coordinator.resetIfNeeded(for: AnyHashable("next"))
        XCTAssertTrue(scrollView.panGestureRecognizer.isEnabled)
        coordinator.handlePinch(state: .began, scale: 1, location: .zero)
        XCTAssertFalse(scrollView.panGestureRecognizer.isEnabled)
        coordinator.detach()
        XCTAssertTrue(scrollView.panGestureRecognizer.isEnabled)
    }

    @MainActor
    func testDisablingTheMonthPagerCancelsItsCurrentPanOnce() {
        let coordinator = DPHorizontalPanCoordinator()
        var changes = 0
        var cancellations = 0
        var completions = 0
        coordinator.onChanged = { _ in changes += 1 }
        coordinator.onCancelled = { _ in cancellations += 1 }
        coordinator.onEnded = { _, _ in completions += 1 }
        coordinator.handlePan(state: .began, translation: CGPoint(x: 40, y: 0), velocity: .zero)
        coordinator.setEnabled(false)
        coordinator.handlePan(state: .cancelled, translation: CGPoint(x: 40, y: 0), velocity: .zero)
        coordinator.handlePan(state: .ended, translation: CGPoint(x: 200, y: 0), velocity: .zero)
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(cancellations, 1)
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(coordinator.gesture.maximumNumberOfTouches, 1)
        coordinator.setEnabled(true)
        coordinator.handlePan(state: .began, translation: CGPoint(x: 40, y: 0), velocity: .zero)
        XCTAssertEqual(changes, 2)
    }

    @MainActor
    func testHostedZoomKeepsTheMonthPagerAndRestoresItAfterAMonthReset() throws {
        let state = CalendarZoomHostState()
        let host = UIHostingController(rootView: CalendarZoomHostFixture(state: state))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        func render() {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            host.view.layoutIfNeeded()
        }

        func recognizers(in view: UIView) -> [UIGestureRecognizer] {
            (view.gestureRecognizers ?? []) + view.subviews.flatMap { recognizers(in: $0) }
        }

        render()
        let gestures = recognizers(in: host.view)
        let pinch = try XCTUnwrap(gestures.first { $0.delegate is DPCalendarZoomCoordinator && $0 is UIPinchGestureRecognizer })
        let zoom = try XCTUnwrap(pinch.delegate as? DPCalendarZoomCoordinator)
        let monthPan = try XCTUnwrap(gestures.first { $0.delegate is DPHorizontalPanCoordinator })
        let outerScroll = try XCTUnwrap(pinch.view as? UIScrollView)
        XCTAssertTrue(monthPan.view === outerScroll)
        XCTAssertTrue(monthPan.isEnabled)
        XCTAssertFalse(zoom.gestureRecognizerShouldBegin(zoom.pan))

        zoom.handlePinch(state: .began, scale: 1, location: CGPoint(x: 100, y: 100))
        zoom.handlePinch(state: .changed, scale: 2, location: CGPoint(x: 100, y: 100))
        render()
        XCTAssertTrue(zoom.isZoomed())
        XCTAssertFalse(monthPan.isEnabled)
        XCTAssertFalse(outerScroll.panGestureRecognizer.isEnabled)
        zoom.handlePinch(state: .ended, scale: 2, location: CGPoint(x: 100, y: 100))
        XCTAssertTrue(outerScroll.panGestureRecognizer.isEnabled)

        state.resetID += 1
        render()
        XCTAssertFalse(zoom.isZoomed())
        XCTAssertTrue(monthPan.isEnabled)
        XCTAssertTrue(outerScroll.panGestureRecognizer.isEnabled)
        XCTAssertTrue(recognizers(in: host.view).contains { $0 === monthPan })
    }

    @MainActor
    func testHostedZoomKeepsOuterScrollingOffWhenSwiftUIReappliesScrollSettings() throws {
        let state = CalendarZoomHostState()
        let host = UIHostingController(rootView: CalendarZoomHostFixture(state: state))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        func render() {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            host.view.layoutIfNeeded()
        }

        func recognizers(in view: UIView) -> [UIGestureRecognizer] {
            (view.gestureRecognizers ?? []) + view.subviews.flatMap { recognizers(in: $0) }
        }

        render()
        let pinch = try XCTUnwrap(recognizers(in: host.view).first { $0.delegate is DPCalendarZoomCoordinator && $0 is UIPinchGestureRecognizer })
        let zoom = try XCTUnwrap(pinch.delegate as? DPCalendarZoomCoordinator)
        let outerScroll = try XCTUnwrap(pinch.view as? UIScrollView)

        // SwiftUI may re-apply its scroll settings in any update, which re-enables
        // UIScrollView's own pan unless SwiftUI itself knows scrolling is off.
        zoom.handlePinch(state: .began, scale: 1, location: CGPoint(x: 100, y: 100))
        zoom.handlePinch(state: .changed, scale: 2, location: CGPoint(x: 100, y: 100))
        outerScroll.isScrollEnabled = true
        render()
        XCTAssertFalse(outerScroll.panGestureRecognizer.isEnabled, "A pinch must keep the outer scroll still")
        zoom.handlePinch(state: .ended, scale: 2, location: CGPoint(x: 100, y: 100))
        render()
        XCTAssertTrue(zoom.isZoomed())
        XCTAssertTrue(outerScroll.panGestureRecognizer.isEnabled)

        zoom.handlePan(state: .began, translation: .zero)
        outerScroll.isScrollEnabled = true
        render()
        XCTAssertFalse(outerScroll.panGestureRecognizer.isEnabled, "A zoom pan must keep the outer scroll still")
        zoom.handlePan(state: .ended, translation: .zero)
        render()
        XCTAssertTrue(outerScroll.panGestureRecognizer.isEnabled)
    }

    @MainActor
    func testHostedPinchIgnoresTapsUntilTheNextTouchSequence() throws {
        let state = CalendarZoomHostState()
        let host = UIHostingController(rootView: CalendarZoomHostFixture(state: state))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        func render() {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            host.view.layoutIfNeeded()
        }

        func recognizers(in view: UIView) -> [UIGestureRecognizer] {
            (view.gestureRecognizers ?? []) + view.subviews.flatMap { recognizers(in: $0) }
        }

        render()
        let pinch = try XCTUnwrap(recognizers(in: host.view).first { $0.delegate is DPCalendarZoomCoordinator && $0 is UIPinchGestureRecognizer })
        let zoom = try XCTUnwrap(pinch.delegate as? DPCalendarZoomCoordinator)
        let outerScroll = try XCTUnwrap(pinch.view as? UIScrollView)
        // The watcher sees every touch on the page without claiming or delaying one.
        XCTAssertTrue(zoom.touchSequence.view === outerScroll)
        XCTAssertFalse(zoom.touchSequence.cancelsTouchesInView)
        XCTAssertFalse(zoom.touchSequence.delaysTouchesEnded)
        XCTAssertFalse(zoom.touchSequence.canPrevent(outerScroll.panGestureRecognizer))
        XCTAssertFalse(zoom.touchSequence.canBePrevented(by: zoom.pan))
        XCTAssertFalse(state.ignoresTaps)

        // Pinching back to actual size leaves a finger down after the pinch ends;
        // its lift must not count as a tap on the day under it.
        zoom.handlePinch(state: .began, scale: 1, location: CGPoint(x: 100, y: 100))
        zoom.handlePinch(state: .changed, scale: 0.5, location: CGPoint(x: 100, y: 100))
        zoom.handlePinch(state: .ended, scale: 0.5, location: CGPoint(x: 100, y: 100))
        render()
        XCTAssertFalse(zoom.isZoomed())
        XCTAssertTrue(state.ignoresTaps)

        zoom.touchSequenceBegan()
        render()
        XCTAssertFalse(state.ignoresTaps, "A fresh touch after the pinch is an ordinary tap")

        zoom.handlePinch(state: .began, scale: 1, location: CGPoint(x: 100, y: 100))
        zoom.handlePinch(state: .changed, scale: 2, location: CGPoint(x: 100, y: 100))
        zoom.handlePinch(state: .ended, scale: 2, location: CGPoint(x: 100, y: 100))
        render()
        XCTAssertTrue(zoom.isZoomed())
        XCTAssertTrue(state.ignoresTaps)
        zoom.touchSequenceBegan()
        render()
        XCTAssertFalse(state.ignoresTaps, "Taps work again while zoomed in")
    }

    func testEveryZoomHostIgnoresDayTapsAfterAPinch() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        func source(_ path: String) throws -> String {
            try String(contentsOf: root.appending(path: path), encoding: .utf8)
        }
        let calendar = try source("Dutypark/Features/Calendar/CalendarView.swift")
        XCTAssertTrue(calendar.contains("ignoresTaps: $isCalendarTapIgnored"))
        XCTAssertTrue(calendar.contains("guard !isSwipingMonth, !isSlidingMonth else { return }\n                        // The finger lifted last after a pinch was zooming, not tapping.\n                        guard !isCalendarTapIgnored else { return }"))
        XCTAssertTrue(calendar.contains("openTodo: { todo in if !isCalendarTapIgnored { openTodo(todo) } }"))

        let team = try source("Dutypark/Features/Team/TeamView.swift")
        XCTAssertTrue(team.contains("ignoresTaps: $isCalendarTapIgnored"))
        XCTAssertTrue(team.contains("guard !isCalendarTapIgnored, !isSwipingMonth, !isSlidingMonth, !viewModel.isLoading else { return }"))
    }

    @MainActor
    func testHostedZoomPreservesMagnificationDuringEdgePansAndGeometryChanges() throws {
        let state = CalendarZoomHostState()
        let host = UIHostingController(rootView: CalendarZoomHostFixture(state: state))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 600))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        func render() {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            host.view.layoutIfNeeded()
        }

        func zoomCoordinator(in view: UIView) -> DPCalendarZoomCoordinator? {
            if let coordinator = (view.gestureRecognizers ?? []).first(where: { $0.delegate is DPCalendarZoomCoordinator })?.delegate as? DPCalendarZoomCoordinator {
                return coordinator
            }
            return view.subviews.compactMap { zoomCoordinator(in: $0) }.first
        }

        render()
        let zoom = try XCTUnwrap(zoomCoordinator(in: host.view))
        zoom.handlePinch(state: .began, scale: 1, location: CGPoint(x: 100, y: 100))
        zoom.handlePinch(state: .changed, scale: 2, location: CGPoint(x: 100, y: 100))
        zoom.handlePinch(state: .ended, scale: 2, location: CGPoint(x: 100, y: 100))
        render()
        XCTAssertTrue(zoom.isZoomed())

        for height: CGFloat in [300.5, 299.5, 0, 340, 300] {
            zoom.handlePan(state: .began, translation: .zero)
            zoom.handlePan(state: .changed, translation: CGPoint(x: -2000, y: -2000))
            state.height = height
            render()
            XCTAssertTrue(zoom.isZoomed(), "A geometry update during an edge pan must keep the magnification")
            zoom.handlePan(state: .cancelled, translation: CGPoint(x: -2000, y: -2000))
            render()
            XCTAssertTrue(zoom.isZoomed(), "Cancelling an edge pan must keep the magnification")
        }
    }
}

@MainActor
private final class CalendarZoomHostState: ObservableObject {
    @Published var resetID = 0
    @Published var height: CGFloat = 300
    @Published var ignoresTaps = false
}

private struct CalendarZoomHostFixture: View {
    @ObservedObject var state: CalendarZoomHostState
    @State private var isActive = false
    @State private var isScrollLocked = false

    var body: some View {
        ScrollView {
            DPCalendarZoom(resetID: AnyHashable(state.resetID), isActive: $isActive, isScrollLocked: $isScrollLocked, ignoresTaps: $state.ignoresTaps) {
                Color.red
                    .frame(height: state.height)
                    .dpHorizontalPan(
                        isEnabled: !isActive,
                        onChanged: { _ in }, onEnded: { _, _ in }, onCancelled: { _ in }
                    )
            }
        }
        .scrollDisabled(isScrollLocked)
    }
}
