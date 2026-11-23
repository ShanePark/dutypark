import SwiftUI
import UIKit
import XCTest
@testable import Dutypark

@MainActor
final class DPCalendarScheduleLineTests: XCTestCase {
    func testShortTitleAndClockShareTheirLine() {
        let text = label(title: "천안", time: "10:00").text(for: 48)
        XCTAssertEqual(lines(text, width: 48), ["천안 10:00"])
    }

    func testClockUsesTheSecondTitleLinesRemainingSpace() {
        let text = label(title: "김김김씨결혼", time: "11:00").text(for: 44)
        let wrapped = lines(text, width: 44)
        XCTAssertEqual(wrapped.count, 2)
        XCTAssertTrue(wrapped[1].contains("혼 11:00"), wrapped.description)
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
        XCTAssertTrue(lines(text, width: label.bounds.width).last?.contains("혼 11:00") == true)
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
