import SwiftUI
import UIKit
import XCTest
@testable import Dutypark

@MainActor
final class DPCalendarScheduleLineTests: XCTestCase {
    func testShortTitleAndClockShareTheirLine() {
        let text = label(title: "천안", time: "10:00").text(for: 48)
        XCTAssertEqual(lines(text, width: 48).map(collapsingWhitespace), ["천안 10:00"])
    }

    func testClockSharingTheTitlesLineSitsAtTheRightEdge() throws {
        let text = label(title: "천안", time: "10:00").text(for: 48)
        let extents = timeExtents(text, width: 48)
        XCTAssertEqual(extents.count, 1)
        let clock = try XCTUnwrap(extents.first)
        XCTAssertEqual(clock.line, 0, "The clock stays on the title's line")
        XCTAssertEqual(clock.maxX, 48 - inset - singleMargin, accuracy: 0.5)
    }

    func testClockOnTheTitlesSecondLineSitsAtTheRightEdge() throws {
        let text = label(title: "김김김씨결혼", time: "11:00").text(for: 44)
        let clock = try XCTUnwrap(timeExtents(text, width: 44).first)
        XCTAssertEqual(clock.line, 1)
        XCTAssertEqual(clock.maxX, 44 - inset - singleMargin, accuracy: 0.5)
    }

    func testClockMovedToItsOwnLineIsRightAligned() throws {
        let text = label(title: "김김김씨결혼", time: "11:00").text(for: 35)
        let clock = try XCTUnwrap(timeExtents(text, width: 35).first)
        XCTAssertEqual(clock.line, 2)
        XCTAssertEqual(clock.maxX, 35 - inset - singleMargin, accuracy: 0.5)
        XCTAssertGreaterThan(clock.minX, 0.5, "The clock does not start at the leading edge")
    }

    func testRangeThatDoesNotFitBesideTheTitleMovesWholeToRightAlignedLines() {
        let text = label(title: "천안", time: "12:00~13:00").text(for: 44)
        let extents = timeExtents(text, width: 44)
        XCTAssertFalse(extents.isEmpty)
        XCTAssertTrue(extents.allSatisfy { $0.line > 0 }, "No part of the range shares the title's line")
        for extent in extents {
            XCTAssertEqual(extent.maxX, 44 - inset, accuracy: 0.5)
        }
    }

    func testClockWithoutTitleIsRightAligned() throws {
        let text = label(title: "", time: "10:00").text(for: 44)
        let clock = try XCTUnwrap(timeExtents(text, width: 44).first)
        XCTAssertEqual(clock.maxX, 44 - inset - singleMargin, accuracy: 0.5)
    }

    func testSingleTimeOnItsOwnLineKeepsClearOfTheEdgeWhileARangeReachesIt() throws {
        let single = try XCTUnwrap(label(title: "김김김씨결혼", time: "11:00").chipBoxes(width: 35).last)
        XCTAssertEqual(single.maxX, 35 - singleMargin, accuracy: 0.5)
        let ranges = label(title: "천안", time: "12:00~13:00").chipBoxes(width: 44)
        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(try XCTUnwrap(ranges.first).maxX, 44, accuracy: 0.5, "A range still reaches the row's edge")
    }

    func testRangeSharingTheTitlesLineReachesTheEdge() throws {
        let box = try XCTUnwrap(label(title: "a", time: "12:00~13:00").chipBoxes(width: 60).first)
        XCTAssertEqual(box.maxX, 60, accuracy: 0.5)
    }

    func testChipBoxIsShortInsetAndReachesTheRowEdge() throws {
        let view = label(title: "천안", time: "10:00")
        let boxes = view.chipBoxes(width: 48)
        XCTAssertEqual(boxes.count, 1)
        let box = try XCTUnwrap(boxes.first)
        let clock = try XCTUnwrap(timeExtents(view.text(for: 48), width: 48).first)
        XCTAssertEqual(box.maxX, 48 - singleMargin, accuracy: 0.5, "A single time keeps clear of the row's edge")
        XCTAssertEqual(box.minX, clock.minX - inset, accuracy: 0.01, "The box leaves room before the first digit")
        XCTAssertEqual(box.height, DPCalendarScheduleTime.fontSize * DPCalendarScheduleTime.boxHeightRatio, accuracy: 0.01)
    }

    func testClockSharesTheTitlesLineOnlyWithRoomForItsInsets() throws {
        let titleWidth = NSAttributedString(string: "천안", attributes: [.font: titleFont, .kern: -0.3]).size().width
        let gap = NSAttributedString(string: " ", attributes: [.font: titleFont, .kern: -0.3]).size().width
        var sharedAtLeastOnce = false
        for step in 0...120 {
            let width = 30 + CGFloat(step) * 0.25
            let view = label(title: "천안", time: "10:00")
            let clock = try XCTUnwrap(timeExtents(view.text(for: width), width: width).first)
            guard clock.line == 0 else { continue }
            sharedAtLeastOnce = true
            let box = try XCTUnwrap(view.chipBoxes(width: width).first)
            XCTAssertGreaterThanOrEqual(box.minX, titleWidth + gap - 0.01, "At \(width)pt the box crowds the title")
            XCTAssertEqual(box.maxX, width - singleMargin, accuracy: 0.5)
        }
        XCTAssertTrue(sharedAtLeastOnce)
    }

    func testRangeWiderThanTheRowBreaksAfterItsTildeWithBothBoxesAtTheEdge() {
        // The digits alone (about 45.5pt) fit a 46.5pt row; with the box insets they do not.
        let view = label(title: "", time: "00:40~04:00")
        let text = view.text(for: 46.5)
        XCTAssertEqual(lines(text, width: 46.5), ["00:40~", "04:00"])
        let boxes = view.chipBoxes(width: 46.5)
        XCTAssertEqual(boxes.count, 2)
        for box in boxes {
            XCTAssertEqual(box.maxX, 46.5, accuracy: 0.5)
            XCTAssertGreaterThanOrEqual(box.minX, -0.01)
        }
    }

    func testRightAlignedClockKeepsTheNativeLabelsLineCount() {
        let shared = label(title: "천안", time: "10:00")
        let titleOnly = label(title: "천안", time: nil)
        XCTAssertEqual(shared.fittingSize(width: 48).height, titleOnly.fittingSize(width: 48).height, accuracy: 0.5,
                       "UILabel keeps a clock that fits beside the title on that line")
    }

    func testClockUsesTheSecondTitleLinesRemainingSpace() {
        let text = label(title: "김김김씨결혼", time: "11:00").text(for: 44)
        let wrapped = lines(text, width: 44)
        XCTAssertEqual(wrapped.count, 2)
        XCTAssertTrue(collapsingWhitespace(wrapped[1]).contains("혼 11:00"), wrapped.description)
        XCTAssertEqual(wrapped.joined().filter { !$0.isWhitespace }, "김김김씨결혼11:00")
    }

    func testClockMovesToTheNextLineWhenTheTitleFillsBothLines() {
        let text = label(title: "김김김씨결혼", time: "11:00").text(for: 35)
        let wrapped = lines(text, width: 35)
        XCTAssertEqual(wrapped.count, 3)
        XCTAssertEqual(wrapped.last, "11:00")
    }

    func testTruncatedTitleStillShowsTheCompleteClock() {
        let text = label(title: String(repeating: "긴일정제목", count: 20), time: "11:00").text(for: 44)
        XCTAssertTrue(text.string.contains("…"))
        let wrapped = lines(text, width: 44)
        XCTAssertLessThanOrEqual(wrapped.count, 3)
        XCTAssertTrue(wrapped.joined().hasSuffix("11:00"), wrapped.description)
    }

    func testRangeWrapsBetweenClocksAndNeverInsideTheirDigits() {
        let text = label(title: "천안", time: "12:00~13:00").text(for: 44)
        let wrapped = lines(text, width: 44)
        XCTAssertTrue(wrapped.contains { $0.contains("12:00~") }, wrapped.description)
        XCTAssertTrue(wrapped.contains { $0.contains("13:00") }, wrapped.description)
        XCTAssertEqual(wrapped.joined().filter { !$0.isWhitespace }, "천안12:00~13:00")
    }

    func testEmptyAndUntimedTitlesHaveSafeNativeLayouts() {
        let empty = label(title: "", time: nil)
        XCTAssertEqual(empty.text(for: 44).length, 0)
        XCTAssertEqual(label(title: "", time: "10:00").text(for: 44).string.replacingOccurrences(of: "\u{2060}", with: ""), "10:00")
        XCTAssertEqual(label(title: "천안", time: nil).text(for: 44).string, "천안")
    }

    func testPrivateAndDetailsSymbolsStayInlineAndDoNotLeakIntoTime() {
        let view = label(title: "개인일정제목", time: "11:00", hasDetails: true, isPrivate: true)
        let text = view.text(for: 44)
        var attachments = 0
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            if value != nil {
                attachments += 1
                XCTAssertEqual(range.length, 1)
            }
        }
        XCTAssertEqual(attachments, 2)
        XCTAssertEqual(text.attribute(.attachment, at: text.length - 1, effectiveRange: nil) as? NSTextAttachment, nil)
        XCTAssertEqual(view.accessibilityLabel, "개인일정제목 11:00")
    }

    func testHostedScheduleUsesItsNaturalWrappingHeight() throws {
        let host = UIHostingController(rootView:
            DPCalendarScheduleLine(
                title: "김김김씨결혼", time: "11:00", dutyColor: nil, isCurrentMonth: true
            )
            .frame(width: 44)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .environment(\.dynamicTypeSize, .large)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        host.view.layoutIfNeeded()

        func scheduleLabel(in view: UIView) -> DPCalendarScheduleLabel? {
            if let label = view as? DPCalendarScheduleLabel { return label }
            return view.subviews.compactMap { scheduleLabel(in: $0) }.first
        }
        let label = try XCTUnwrap(scheduleLabel(in: host.view))
        let text = try XCTUnwrap(label.attributedText)
        XCTAssertEqual(label.bounds.width, 44, accuracy: 0.5)
        XCTAssertGreaterThan(label.bounds.height, 20)
        XCTAssertEqual(lines(text, width: label.bounds.width).count, 2)
        XCTAssertTrue(lines(text, width: label.bounds.width).last.map(collapsingWhitespace)?.contains("혼 11:00") == true)
    }

    private func label(title: String, time: String?, hasDetails: Bool = false, isPrivate: Bool = false) -> DPCalendarScheduleLabel {
        let label = DPCalendarScheduleLabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContent(
            title: title, time: time, hasDetails: hasDetails, showsPrivateLock: isPrivate,
            titleFont: UIFont(name: DPFont.lightPostScriptName, size: 10) ?? .systemFont(ofSize: 10, weight: .light),
            timeFont: UIFont(name: DPFont.boldPostScriptName, size: DPCalendarScheduleTime.fontSize) ?? .systemFont(ofSize: DPCalendarScheduleTime.fontSize, weight: .bold),
            foreground: .label, timeForeground: .label, timeBackground: .secondarySystemBackground
        )
        return label
    }

    private let inset = DPCalendarScheduleTime.horizontalPadding
    private let singleMargin: CGFloat = 2
    private var titleFont: UIFont { UIFont(name: DPFont.lightPostScriptName, size: 10) ?? .systemFont(ofSize: 10, weight: .light) }

    private func collapsingWhitespace(_ line: String) -> String {
        line.replacingOccurrences(of: "\t", with: " ")
    }

    /// The horizontal extent of the time chip on each line it occupies.
    private func timeExtents(_ text: NSAttributedString, width: CGFloat) -> [(line: Int, minX: CGFloat, maxX: CGFloat)] {
        var timeRange = NSRange(location: NSNotFound, length: 0)
        text.enumerateAttribute(DPCalendarScheduleLabel.timeChip, in: NSRange(location: 0, length: text.length)) { value, range, stop in
            if value != nil { timeRange = range; stop.pointee = true }
        }
        guard timeRange.location != NSNotFound else { return [] }
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        let timeGlyphs = layout.glyphRange(forCharacterRange: timeRange, actualCharacterRange: nil)
        var result: [(line: Int, minX: CGFloat, maxX: CGFloat)] = []
        var line = 0
        layout.enumerateLineFragments(forGlyphRange: layout.glyphRange(for: container)) { _, _, _, glyphs, _ in
            defer { line += 1 }
            var visible = NSIntersectionRange(glyphs, timeGlyphs)
            // Zero-width break hints at a line's end do not extend the chip.
            while visible.length > 0,
                  ["\u{200B}", "\u{2060}"].contains((text.string as NSString).substring(with: layout.characterRange(
                      forGlyphRange: NSRange(location: NSMaxRange(visible) - 1, length: 1), actualGlyphRange: nil))) {
                visible.length -= 1
            }
            guard visible.length > 0 else { return }
            let rect = layout.boundingRect(forGlyphRange: visible, in: container)
            result.append((line, rect.minX, rect.maxX))
        }
        return result
    }

    private func lines(_ text: NSAttributedString, width: CGFloat) -> [String] {
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        var result: [String] = []
        layout.enumerateLineFragments(forGlyphRange: layout.glyphRange(for: container)) { _, _, _, glyphs, _ in
            let range = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            result.append((text.string as NSString).substring(with: range)
                .replacingOccurrences(of: "\u{2060}", with: "")
                .replacingOccurrences(of: "\u{200B}", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return result
    }
}
