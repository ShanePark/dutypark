import CoreGraphics
import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import Dutypark

final class CalendarMonthSwipeTests: XCTestCase {
    @MainActor
    func testFirstPanKeepsItsRecognizerWhenTheMonthTrackAppears() throws {
        let events = CalendarPanLifecycleEvents()
        let host = UIHostingController(rootView: CalendarPanLifecycleFixture(events: events))
        host.view.frame = CGRect(x: 0, y: 0, width: 375, height: 600)
        let window = UIWindow(frame: host.view.frame)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        func render() {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            host.view.layoutIfNeeded()
        }

        func pagerRecognizers(in view: UIView) -> [UIPanGestureRecognizer] {
            let own = (view.gestureRecognizers ?? []).compactMap { gesture -> UIPanGestureRecognizer? in
                guard gesture.delegate is DPHorizontalPanCoordinator else { return nil }
                return gesture as? UIPanGestureRecognizer
            }
            return own + view.subviews.flatMap { pagerRecognizers(in: $0) }
        }

        render()
        let initialRecognizers = pagerRecognizers(in: host.view)
        XCTAssertEqual(initialRecognizers.count, 1, "The first visible calendar must already receive pans")
        let pan = try XCTUnwrap(initialRecognizers.first)
        let coordinator = try XCTUnwrap(pan.delegate as? DPHorizontalPanCoordinator)
        let anchor = try XCTUnwrap(coordinator.anchor)
        XCTAssertNotNil(anchor.window)

        // UIKit has begun one touch. Its first change replaces the single-month
        // branch with the actual three-page track, as CalendarView does.
        coordinator.handlePan(state: .began, translation: CGPoint(x: -40, y: 4), velocity: .zero)
        render()
        XCTAssertTrue(events.hasTrack, "The pan must have prepared the adjacent months")
        let activeRecognizers = pagerRecognizers(in: host.view)
        XCTAssertEqual(activeRecognizers.count, 1)
        XCTAssertTrue(activeRecognizers.first === pan, "Replacing month content must not remove an in-flight recognizer")
        XCTAssertTrue(coordinator.anchor === anchor, "The first pan's coordinate anchor must survive content replacement")
        XCTAssertNotNil(anchor.window)

        coordinator.handlePan(state: .ended, translation: CGPoint(x: -150, y: 4), velocity: .zero)
        XCTAssertEqual(events.completedPans, 1)
    }

    func testASidewaysDragPastTheThresholdPicksTheNeighbouringMonth() {
        let width: CGFloat = 360
        let travel = width * CalendarMonthSwipe.releaseDistanceFraction

        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(
                translation: CGSize(width: travel, height: 0),
                velocity: .zero,
                viewportWidth: width
            ),
            -1,
            "Dragging left to right pulls the previous month in"
        )
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(
                translation: CGSize(width: -travel, height: 0),
                velocity: .zero,
                viewportWidth: width
            ),
            1,
            "Dragging right to left pulls the next month in"
        )
    }

    func testAShortDragKeepsTheMonth() {
        let width: CGFloat = 360
        let travel = width * CalendarMonthSwipe.releaseDistanceFraction - 1

        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(
                translation: CGSize(width: travel, height: 0), velocity: .zero, viewportWidth: width
            ),
            0
        )
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(
                translation: CGSize(width: -travel, height: 0), velocity: .zero, viewportWidth: width
            ),
            0
        )
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(translation: .zero, velocity: .zero, viewportWidth: width),
            0
        )
    }

    func testAPartialPageDragDoesNotCommitTheMonth() {
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(
                translation: CGSize(width: 90, height: 0), velocity: .zero, viewportWidth: 360
            ),
            0,
            "A short pull should settle back to the current month"
        )
    }

    func testAHorizontalDragWithVerticalDriftStillSelectsTheNeighbour() {
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(
                translation: CGSize(width: 120, height: 95), velocity: .zero, viewportWidth: 360
            ),
            -1,
            "Once the horizontal pan is recognized, small vertical drift should not veto it"
        )
    }

    func testAFastOutwardFlickCommitsBeforeTheDistanceThreshold() {
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(
                translation: CGSize(width: 36, height: 20),
                velocity: CGSize(width: 700, height: 40),
                viewportWidth: 360
            ),
            -1
        )
    }

    func testAReversedOrInwardReleaseKeepsTheCurrentMonth() {
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(
                translation: CGSize(width: 80, height: 10),
                velocity: CGSize(width: -240, height: 0),
                viewportWidth: 360
            ),
            0,
            "Returning toward the starting month before release should cancel the page change"
        )
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(
                translation: CGSize(width: 140, height: 10),
                velocity: CGSize(width: -240, height: 0),
                viewportWidth: 360
            ),
            0,
            "An inward release should not commit even after crossing the distance threshold"
        )
    }

    func testSmallOpposingVelocityNoiseDoesNotCancelACompletePageDrag() {
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(
                translation: CGSize(width: 140, height: 10),
                velocity: CGSize(width: -40, height: 0),
                viewportWidth: 360
            ),
            -1
        )
    }

    func testTheGridFollowsTheFingerInsteadOfRubberBanding() {
        let viewportWidth: CGFloat = 360

        XCTAssertEqual(
            CalendarMonthSwipe.followOffset(translation: .zero, viewportWidth: viewportWidth),
            0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            CalendarMonthSwipe.followOffset(
                translation: CGSize(width: 10, height: 0),
                viewportWidth: viewportWidth
            ),
            10,
            accuracy: 0.001,
            "The page should move by the same distance as the finger"
        )
        XCTAssertEqual(
            CalendarMonthSwipe.followOffset(
                translation: CGSize(width: -180, height: 0),
                viewportWidth: viewportWidth
            ),
            -180,
            accuracy: 0.001,
            "The next page should remain attached throughout the swipe"
        )
        XCTAssertEqual(
            CalendarMonthSwipe.followOffset(
                translation: CGSize(width: viewportWidth * 2, height: 0),
                viewportWidth: viewportWidth
            ),
            viewportWidth,
            accuracy: 0.001,
            "The previous page stops at the viewport edge"
        )
        XCTAssertEqual(
            CalendarMonthSwipe.followOffset(
                translation: CGSize(width: -viewportWidth * 2, height: 0),
                viewportWidth: viewportWidth
            ),
            -viewportWidth,
            accuracy: 0.001,
            "The next page stops at the viewport edge"
        )
    }

    func testTheGridKeepsFollowingItsHorizontalAxisAfterThePanBegins() {
        XCTAssertEqual(
            CalendarMonthSwipe.followOffset(
                translation: CGSize(width: 80, height: 100),
                viewportWidth: 360
            ),
            80,
            accuracy: 0.001,
            "A recognized horizontal pan should not jump back when the finger wobbles vertically"
        )
    }

    func testThreeMonthTrackKeepsTheNeighbourAttachedInBothDirections() {
        let width: CGFloat = 360

        XCTAssertEqual(
            CalendarMonthSwipe.trackOffset(width: width, drag: 0),
            -width,
            accuracy: 0.001,
            "The current month starts in the middle slot"
        )
        XCTAssertEqual(
            CalendarMonthSwipe.trackOffset(width: width, drag: -width),
            CalendarMonthSwipe.settledTrackOffset(width: width, monthOffset: 1),
            accuracy: 0.001,
            "Dragging left keeps the next month attached to the current page"
        )
        XCTAssertEqual(
            CalendarMonthSwipe.trackOffset(width: width, drag: width),
            CalendarMonthSwipe.settledTrackOffset(width: width, monthOffset: -1),
            accuracy: 0.001,
            "Dragging right keeps the previous month attached to the current page"
        )
        XCTAssertEqual(
            CalendarMonthSwipe.settledTrackOffset(width: width, monthOffset: 1),
            -2 * width,
            accuracy: 0.001
        )
        XCTAssertEqual(
            CalendarMonthSwipe.settledTrackOffset(width: width, monthOffset: -1),
            0,
            accuracy: 0.001
        )
    }

    @MainActor
    func testDDayPositionStaysFixedWhileDraggingAndLoadingAdjacentMonth() throws {
        for (sourceRows, targetRows) in [(5, 6), (6, 5)] {
            let state = CalendarMonthHeightFixtureState()
            let host = UIHostingController(rootView: CalendarMonthHeightFixture(
                state: state, sourceRows: sourceRows, targetRows: targetRows
            ))
            host.view.frame = CGRect(x: 0, y: 0, width: 375, height: 800)
            let window = UIWindow(frame: host.view.frame)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true }

            func render() {
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
                host.view.layoutIfNeeded()
            }

            render()
            let restingY = try XCTUnwrap(state.frames["dday"]).minY
            let sourceHeight = try XCTUnwrap(state.frames["page-1"]).height
            XCTAssertTrue(restingY.isFinite)
            XCTAssertGreaterThan(restingY, sourceHeight)
            XCTAssertEqual(sourceHeight, CGFloat(sourceRows) * 60, accuracy: 0.5)

            // Reverse the finger and let the neighbour's taller schedules arrive
            // before cancellation. Neither event should move the D-Day cards.
            for (progress, rowHeight): (CGFloat, CGFloat) in [(0.2, 60), (0.7, 60), (0.35, 60), (0.35, 74), (0, 74)] {
                state.progress = progress
                state.targetRowHeight = rowHeight
                render()
                XCTAssertEqual(try XCTUnwrap(state.frames["page-2"]).height, rowHeight * CGFloat(targetRows), accuracy: 0.5)
                XCTAssertEqual(
                    try XCTUnwrap(state.frames["dday"]).minY,
                    restingY,
                    accuracy: 0.5,
                    "The D-Day cards must hold their position until the month change completes"
                )
            }

            state.didCancel = true
            render()
            XCTAssertEqual(try XCTUnwrap(state.frames["dday"]).minY, restingY, accuracy: 0.5)
            state.didCancel = false
            state.progress = 1
            render()
            XCTAssertEqual(try XCTUnwrap(state.frames["dday"]).minY, restingY, accuracy: 0.5)

            state.didCommit = true
            render()
            let finalHeight = CGFloat(targetRows) * 74
            XCTAssertEqual(try XCTUnwrap(state.frames["dday"]).minY, restingY + finalHeight - sourceHeight, accuracy: 0.5)
        }
    }

    /// The swipe has to ride along with the enclosing scroll view and the day cells'
    /// own tap. `simultaneousGesture(DragGesture())` was not enough: it claimed every
    /// drag that passed its minimum distance whichever way it went, so a scroll that
    /// set off with the slightest sideways lean never moved the page. The pager reads
    /// the drag's direction first now and leaves the vertical ones alone.
    func testTheCalendarGridCarriesTheSwipeAlongsideItsOtherGestures() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Dutypark/Features/Calendar/CalendarView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains(".dpHorizontalPan("))
        XCTAssertTrue(source.contains("onCancelled: cancelMonthSwipe"))
        XCTAssertFalse(
            source.contains("simultaneousGesture(monthSwipeGesture)"),
            "A plain DragGesture over the grid takes drags that belong to the scroll"
        )
        XCTAssertTrue(
            source.contains("guard !isSwipingMonth, !isSlidingMonth else { return }"),
            "A day that was dragged sideways must not open its detail modal"
        )
        XCTAssertTrue(source.contains("CalendarMonthSwipe.monthOffset("))
        XCTAssertTrue(source.contains("velocity: velocity"))
        XCTAssertTrue(source.contains("CalendarMonthSwipe.followOffset("))
        XCTAssertTrue(source.contains("viewportWidth: calendarGridWidth"))
    }

    func testWeekdayHeaderStaysOutsideTheMovingMonthBody() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Dutypark/Features/Calendar/CalendarView.swift"),
            encoding: .utf8
        )

        let gridStart = try XCTUnwrap(source.range(of: "private var calendarGrid: some View"))
        let headerStart = try XCTUnwrap(source.range(of: "private var calendarWeekdayHeader"))
        let pagerStart = try XCTUnwrap(source.range(of: "private var monthBodyPager"))
        let pagerEnd = try XCTUnwrap(source.range(of: "private func followMonthSwipe"))
        let trackStart = try XCTUnwrap(source.range(of: "struct CalendarMonthPageTrack"))
        let stripStart = try XCTUnwrap(source.range(of: "struct CalendarWeekdayStrip"))
        let layoutStart = try XCTUnwrap(source.range(of: "nonisolated enum CalendarMainLayout"))
        guard gridStart.lowerBound <= pagerStart.lowerBound,
              headerStart.lowerBound <= pagerStart.lowerBound,
              pagerStart.lowerBound <= pagerEnd.lowerBound,
              trackStart.lowerBound <= stripStart.lowerBound,
              stripStart.lowerBound <= layoutStart.lowerBound
        else {
            XCTFail("Calendar header, track, and strip declarations are out of order")
            return
        }
        let gridDeclaration = source[gridStart.lowerBound..<pagerStart.lowerBound]
        let headerDeclaration = source[headerStart.lowerBound..<pagerStart.lowerBound]
        let pagerDeclaration = source[pagerStart.lowerBound..<pagerEnd.lowerBound]
        let trackDeclaration = source[trackStart.lowerBound..<stripStart.lowerBound]
        let stripDeclaration = source[stripStart.lowerBound..<layoutStart.lowerBound]

        XCTAssertTrue(gridDeclaration.contains("calendarWeekdayHeader\n            monthBodyPager"))
        XCTAssertTrue(headerDeclaration.contains("CalendarWeekdayStrip()"))
        XCTAssertFalse(pagerDeclaration.contains("CalendarWeekdayStrip()"))
        XCTAssertTrue(stripDeclaration.contains("DPCalendarWeekdayHeaderCell"))
        XCTAssertTrue(trackDeclaration.contains("HStack(spacing: 0)"))
        XCTAssertTrue(trackDeclaration.contains(".frame(width: width, height: height, alignment: .topLeading)"))
        XCTAssertTrue(trackDeclaration.contains(".clipped()"))
        XCTAssertTrue(pagerDeclaration.contains(".clipped()"))
        XCTAssertTrue(pagerDeclaration.contains("CalendarMonthBodyHeightsPreferenceKey"))
        XCTAssertTrue(pagerDeclaration.contains("monthTransition?.viewport.height"))
        XCTAssertTrue(pagerDeclaration.contains("viewport: CalendarMonthBodyViewport(sourceHeight: max("))
        XCTAssertTrue(source.contains(".accessibilityHidden(!isInteractive)"))
        XCTAssertTrue(source.contains("monthTransition = nil\n                monthTrackOffset = 0\n                isSlidingMonth = false\n                isSwipingMonth = false"))
    }

    @MainActor
    func testRenderedMonthGridKeepsSevenColumnsInsideTheWeekdayStrip() throws {
        for screenWidth: CGFloat in [375, 390] {
            var frames: [String: CGRect] = [:]
            let root = CalendarMonthLayoutFixture(screenWidth: screenWidth) { frames = $0 }
                .preferredColorScheme(.dark)
            let host = UIHostingController(rootView: root)
            host.view.frame = CGRect(x: 0, y: 0, width: screenWidth, height: 500)
            let window = UIWindow(frame: host.view.frame)
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            host.view.layoutIfNeeded()

            let gridWidth = screenWidth - 24
            let viewport = try XCTUnwrap(frames["viewport-\(Int(screenWidth))"])
            let header = try XCTUnwrap(frames["header-\(Int(screenWidth))"])
            let currentPage = try XCTUnwrap(frames["page-1-\(Int(screenWidth))"])
            XCTAssertEqual(viewport.width, gridWidth, accuracy: 0.5)
            XCTAssertEqual(header.width, gridWidth, accuracy: 0.5)
            XCTAssertEqual(currentPage.width, gridWidth, accuracy: 0.5)
            XCTAssertEqual(currentPage.minX, header.minX, accuracy: 0.5)

            let firstCell = try XCTUnwrap(frames["cell-1-0-\(Int(screenWidth))"])
            let columnWidth = gridWidth / 7
            for column in 0..<7 {
                let cell = try XCTUnwrap(frames["cell-1-\(column)-\(Int(screenWidth))"])
                XCTAssertEqual(cell.width, columnWidth, accuracy: 0.5)
                XCTAssertEqual(cell.minX, firstCell.minX + CGFloat(column) * columnWidth, accuracy: 0.5)
                XCTAssertGreaterThanOrEqual(cell.minX, viewport.minX - 0.5)
                XCTAssertLessThanOrEqual(cell.maxX, viewport.maxX + 0.5)
            }

            let renderer = UIGraphicsImageRenderer(size: host.view.bounds.size)
            let image = renderer.image { context in
                host.view.layer.render(in: context.cgContext)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "calendar-month-layout-\(Int(screenWidth))pt"
            attachment.lifetime = .keepAlways
            XCTContext.runActivity(named: "Rendered \(Int(screenWidth))pt calendar layout") { activity in
                activity.add(attachment)
            }
            let snapshotURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appending(path: "dutypark-calendar-month-layout-\(Int(screenWidth))pt.png")
            try XCTUnwrap(image.pngData()).write(to: snapshotURL)
            window.isHidden = true
        }
    }
}

private struct CalendarMonthLayoutPage: Identifiable {
    let id: Int
}

@MainActor
private final class CalendarPanLifecycleEvents {
    var hasTrack = false
    var completedPans = 0
}

@MainActor
private struct CalendarPanLifecycleFixture: View {
    @State private var showsTrack = false
    @State private var drag: CGFloat = 0
    let events: CalendarPanLifecycleEvents
    private let width: CGFloat = 351

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DPSpacing.small) {
                VStack(spacing: 0) {
                    CalendarWeekdayStrip()
                    monthBodyPager
                }
            }
            .padding(.horizontal, DPSpacing.small)
        }
    }

    private var monthBodyPager: some View {
        Group {
            if showsTrack {
                CalendarMonthPageTrack(
                    pages: [-1, 0, 1].map(CalendarMonthLayoutPage.init(id:)),
                    width: width,
                    height: 300,
                    offset: -width + drag
                ) { _, index in
                    monthBody
                        .allowsHitTesting(index == 1)
                }
            } else {
                monthBody.fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipped()
        .dpHorizontalPan(
            onChanged: { translation in
                showsTrack = true
                events.hasTrack = true
                drag = translation.width
            },
            onEnded: { _, _ in events.completedPans += 1 },
            onCancelled: { _ in }
        )
    }

    private var monthBody: some View {
        CalendarMonthCellGrid(items: (0..<35).map(CalendarMonthLayoutCell.init(id:))) { index, _ in
            Text("\(index + 1)")
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                .onTapGesture {}
        }
    }
}

private struct CalendarMonthLayoutCell: Identifiable {
    let id: Int
}

private struct CalendarMonthLayoutFramesPreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

@MainActor
private struct CalendarMonthLayoutFixture: View {
    @State private var pageWidth: CGFloat

    let screenWidth: CGFloat
    let capture: ([String: CGRect]) -> Void

    init(screenWidth: CGFloat, capture: @escaping ([String: CGRect]) -> Void) {
        self.screenWidth = screenWidth
        self.capture = capture
        _pageWidth = State(initialValue: screenWidth - 24)
    }

    var body: some View {
        VStack(spacing: 0) {
            CalendarWeekdayStrip()
                .background(framePreference("header"))

            CalendarMonthPageTrack(
                pages: [CalendarMonthLayoutPage(id: -1), CalendarMonthLayoutPage(id: 0), CalendarMonthLayoutPage(id: 1)],
                width: pageWidth,
                height: 300,
                offset: -pageWidth
            ) { page, pageIndex in
                CalendarMonthCellGrid(items: (0..<35).map(CalendarMonthLayoutCell.init(id:))) { index, _ in
                    Text("\(index + 1)")
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                        .background(Color.cyan)
                        .background(framePreference("cell-\(pageIndex)-\(index)"))
                }
                .background(framePreference("page-\(pageIndex)"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: CalendarMonthLayoutFramesPreferenceKey.self,
                        value: ["viewport-\(Int(screenWidth))": proxy.frame(in: .named("calendar-layout"))]
                    )
                    .onAppear { pageWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in pageWidth = width }
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(width: screenWidth, alignment: .leading)
        .coordinateSpace(name: "calendar-layout")
        .background(Color.black)
        .onPreferenceChange(CalendarMonthLayoutFramesPreferenceKey.self, perform: capture)
    }

    private func framePreference(_ prefix: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: CalendarMonthLayoutFramesPreferenceKey.self,
                value: ["\(prefix)-\(Int(screenWidth))": proxy.frame(in: .named("calendar-layout"))]
            )
        }
    }
}

@MainActor
private final class CalendarMonthHeightFixtureState: ObservableObject {
    @Published var progress: CGFloat = 0
    @Published var targetRowHeight: CGFloat = 60
    @Published var didCommit = false
    @Published var didCancel = false
    var frames: [String: CGRect] = [:]
}

@MainActor
private struct CalendarMonthHeightFixture: View {
    @ObservedObject var state: CalendarMonthHeightFixtureState
    private let width: CGFloat = 351
    private let viewport: CalendarMonthBodyViewport
    let sourceRows: Int
    let targetRows: Int

    init(state: CalendarMonthHeightFixtureState, sourceRows: Int, targetRows: Int) {
        self.state = state
        self.sourceRows = sourceRows
        self.targetRows = targetRows
        viewport = CalendarMonthBodyViewport(sourceHeight: CGFloat(sourceRows) * 60)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DPSpacing.small) {
                VStack(spacing: 0) {
                    CalendarWeekdayStrip()
                    if state.didCommit || state.didCancel {
                        monthBody(
                            rows: state.didCommit ? targetRows : sourceRows,
                            rowHeight: state.didCommit ? state.targetRowHeight : 60,
                            index: state.didCommit ? 2 : 1
                        )
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        CalendarMonthPageTrack(
                            pages: [-1, 0, 1].map(CalendarMonthLayoutPage.init(id:)),
                            width: width,
                            height: viewport.height,
                            offset: -width - width * state.progress
                        ) { _, index in
                            monthBody(rows: index == 1 ? sourceRows : targetRows, rowHeight: index == 1 ? 60 : state.targetRowHeight, index: index)
                        }
                    }
                }
                Color.cyan.frame(height: 60).background(framePreference("dday"))
            }
            .padding(.horizontal, DPSpacing.small)
        }
        .coordinateSpace(name: "calendar-height")
        .onPreferenceChange(CalendarMonthLayoutFramesPreferenceKey.self) { state.frames = $0 }
    }

    private func monthBody(rows: Int, rowHeight: CGFloat, index: Int) -> some View {
        CalendarMonthCellGrid(items: (0..<(rows * 7)).map(CalendarMonthLayoutCell.init(id:))) { cellIndex, _ in
            Text("\(cellIndex + 1)")
                .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .topLeading)
        }
        .background(framePreference("page-\(index)"))
    }

    private func framePreference(_ name: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: CalendarMonthLayoutFramesPreferenceKey.self,
                value: [name: proxy.frame(in: .named("calendar-height"))]
            )
        }
    }
}
