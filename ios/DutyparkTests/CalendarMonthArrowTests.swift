import XCTest

/// The month step arrows were a bare chevron inside a transparent frame: nothing marked
/// where the button was, and without a content shape only the glyph itself answered to
/// touch. These tests pin the shared control and its adoption by every calendar header.
final class CalendarMonthArrowTests: XCTestCase {
    private static func source(_ path: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func declaration(named name: String, in source: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: name), "\(name) is missing")
        let rest = source[start.upperBound...]
        let end = rest.range(of: "\n    private var") ?? rest.range(of: "\n    var") ?? rest.range(of: "\n}")
        return String(rest[..<(end?.lowerBound ?? rest.endIndex)])
    }

    func testTheSharedArrowPaintsItsTargetAndTakesTheWholeSlot() throws {
        let source = try Self.source("Dutypark/Components/DPMonthArrowButton.swift")

        XCTAssertTrue(source.contains("struct DPMonthArrowButton: View"))
        XCTAssertTrue(
            source.contains("Circle().fill(configuration.isPressed ? DPColor.accentSoftHover : DPColor.accentSoft)"),
            "The accent circle is painted at all times, not only while hovered or pressed"
        )
        XCTAssertFalse(
            source.contains("Circle().stroke"),
            "The tint carries the shape; a border made the arrow read as a form field"
        )
        XCTAssertTrue(
            source.contains(".frame(width: slotWidth, height: DPSize.minimumTouchTarget)\n            .contentShape(Rectangle())"),
            "The whole 44pt slot answers to touch, not just the chevron glyph"
        )
        XCTAssertTrue(source.contains("static let controlSize: CGFloat = 34"))
        XCTAssertTrue(source.contains("static let slotWidth: CGFloat = 42"))
    }

    func testTheCalendarHeaderUsesTheSharedArrows() throws {
        let source = try Self.source("Dutypark/Features/Calendar/CalendarView.swift")
        let controls = try Self.declaration(named: "private var monthControls: some View", in: source)

        XCTAssertFalse(
            controls.contains("Image(systemName: \"chevron.left\")"),
            "The header no longer draws a bare chevron of its own"
        )
        XCTAssertTrue(controls.contains("DPMonthArrowButton(direction: .previous"))
        XCTAssertTrue(controls.contains("DPMonthArrowButton(direction: .next"))
        XCTAssertTrue(source.contains("CalendarLocalization.text(\"calendar.month.previous\")"))
        XCTAssertTrue(source.contains("CalendarLocalization.text(\"calendar.month.next\")"))
    }

    func testTheTeamHeaderUsesTheSharedArrowsWithDistinctLabels() throws {
        let source = try Self.source("Dutypark/Features/Team/TeamView.swift")
        let header = try Self.declaration(named: "private var monthHeader: some View", in: source)

        XCTAssertFalse(header.contains("Image(systemName: \"chevron.left\")"))
        XCTAssertTrue(header.contains("DPMonthArrowButton(direction: .previous"))
        XCTAssertTrue(header.contains("DPMonthArrowButton(direction: .next"))
        XCTAssertTrue(
            header.contains("team.view.calendar.previousMonth") && header.contains("team.view.calendar.nextMonth"),
            "Both arrows used to read as the same control to VoiceOver"
        )
    }

    func testTheGuestCalendarUsesTheSharedArrows() throws {
        let source = try Self.source("Dutypark/Features/Guest/GuestPublicCalendarView.swift")
        let controls = try Self.declaration(named: "private var monthControls: some View", in: source)

        XCTAssertFalse(controls.contains("Image(systemName: \"chevron.left\")"))
        XCTAssertTrue(controls.contains("DPMonthArrowButton(direction: .previous"))
        XCTAssertTrue(controls.contains("DPMonthArrowButton(direction: .next"))
    }

    func testTheArrowLabelsAreLocalized() throws {
        let calendar = try Self.source("Dutypark/Features/Calendar/Calendar.xcstrings")
        XCTAssertTrue(calendar.contains("\"calendar.month.previous\""))
        XCTAssertTrue(calendar.contains("\"calendar.month.next\""))

        let team = try Self.source("Dutypark/Resources/Team.xcstrings")
        XCTAssertTrue(team.contains("\"team.view.calendar.previousMonth\""))
        XCTAssertTrue(team.contains("\"team.view.calendar.nextMonth\""))

        let guest = try Self.source("Dutypark/Features/Guest/Guest.xcstrings")
        XCTAssertTrue(guest.contains("\"guest.calendar.month.previous\""))
        XCTAssertTrue(guest.contains("\"guest.calendar.month.next\""))
    }
}
