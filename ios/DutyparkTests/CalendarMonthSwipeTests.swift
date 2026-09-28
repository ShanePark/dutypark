import CoreGraphics
import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import Dutypark

final class CalendarMonthSwipeTests: XCTestCase {
    func testASidewaysDragPastTheThresholdPicksTheNeighbouringMonth() {
        let travel = CalendarMonthSwipe.threshold

        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(translation: CGSize(width: travel, height: 0)),
            -1,
            "Dragging left to right pulls the previous month in"
        )
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(translation: CGSize(width: -travel, height: 0)),
            1,
            "Dragging right to left pulls the next month in"
        )
    }

    func testAShortDragKeepsTheMonth() {
        let travel = CalendarMonthSwipe.threshold - 1

        XCTAssertEqual(CalendarMonthSwipe.monthOffset(translation: CGSize(width: travel, height: 0)), 0)
        XCTAssertEqual(CalendarMonthSwipe.monthOffset(translation: CGSize(width: -travel, height: 0)), 0)
        XCTAssertEqual(CalendarMonthSwipe.monthOffset(translation: .zero), 0)
    }

    /// The grid lives inside the scrolling calendar, so a scroll that drifts sideways
    /// must not land on another month.
    func testAScrollThatDriftsSidewaysKeepsTheMonth() {
        let translation = CGSize(
            width: CalendarMonthSwipe.threshold + 20,
            height: CalendarMonthSwipe.threshold + 20
        )

        XCTAssertEqual(CalendarMonthSwipe.monthOffset(translation: translation), 0)
        XCTAssertEqual(
            CalendarMonthSwipe.monthOffset(
                translation: CGSize(width: -translation.width, height: translation.height)
            ),
            0
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

    func testTheGridStaysPutWhileTheDragIsMostlyVertical() {
        XCTAssertEqual(
            CalendarMonthSwipe.followOffset(
                translation: CGSize(width: 20, height: 40),
                viewportWidth: 360
            ),
            0,
            accuracy: 0.001
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

    func testBodyHeightTracksTheIncomingMonthWithoutAnInitialJump() {
        let source: CGFloat = 240
        let target: CGFloat = 360

        XCTAssertEqual(CalendarMonthSwipe.interpolatedBodyHeight(source: source, target: target, progress: 0), source)
        XCTAssertEqual(CalendarMonthSwipe.interpolatedBodyHeight(source: source, target: target, progress: 0.5), 300)
        XCTAssertEqual(CalendarMonthSwipe.interpolatedBodyHeight(source: source, target: target, progress: 1), target)
        XCTAssertEqual(CalendarMonthSwipe.interpolatedBodyHeight(source: source, target: target, progress: 2), target)
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

        XCTAssertTrue(source.contains("dpHorizontalPan(onChanged:"))
        XCTAssertFalse(
            source.contains("simultaneousGesture(monthSwipeGesture)"),
            "A plain DragGesture over the grid takes drags that belong to the scroll"
        )
        XCTAssertTrue(
            source.contains("guard !isSwipingMonth, !isSlidingMonth else { return }"),
            "A day that was dragged sideways must not open its detail modal"
        )
        XCTAssertTrue(source.contains("CalendarMonthSwipe.monthOffset(translation:"))
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
        XCTAssertTrue(pagerDeclaration.contains("CalendarMonthSwipe.interpolatedBodyHeight"))
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
