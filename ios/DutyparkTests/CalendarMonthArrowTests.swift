import XCTest
@testable import Dutypark

/// The month navigation is one capsule — previous arrow, year-month button and next arrow —
/// matching the web calendar. Each arrow keeps the capsule's full height as a square tap area
/// and paints a soft circle so the segments still read as separate buttons on a touch screen
/// that never hovers. These tests pin the shared control and its adoption by every header.
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

    private static func componentSource() throws -> String {
        try source("Dutypark/Components/DPMonthCapsule.swift")
    }

    func testTheCapsuleIsOneCardSurfaceWithAHairlineRing() throws {
        let source = try Self.componentSource()

        XCTAssertTrue(source.contains("struct DPMonthCapsule: View"))
        XCTAssertTrue(source.contains("static let height: CGFloat = 44"))
        XCTAssertTrue(
            source.contains("Capsule().fill(isMonthPressed ? DPColor.accentSoft : DPColor.backgroundCard)"),
            "The capsule rests on the card surface and tints while the year-month is pressed"
        )
        XCTAssertTrue(
            source.contains(".stroke(isMonthPressed ? DPColor.accentBorder : DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)"),
            "A 1pt ring outlines the capsule and turns accent while the year-month is pressed"
        )
        XCTAssertTrue(source.contains(".shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)"))
        XCTAssertTrue(source.contains(".shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)"))
        XCTAssertFalse(source.contains("Divider()"), "The circles separate the segments; no divider lines")
    }

    func testEachArrowIsASquareSegmentWithAConcentricCircle() throws {
        let source = try Self.componentSource()

        XCTAssertTrue(
            source.contains("static let segmentSize: CGFloat = height"),
            "A square segment keeps the circle concentric with the capsule's rounded end"
        )
        XCTAssertTrue(source.contains("static let circleSize: CGFloat = 32"))
        XCTAssertTrue(
            source.contains(".frame(width: DPMonthCapsuleMetrics.segmentSize, height: DPMonthCapsuleMetrics.segmentSize)\n            .contentShape(Rectangle())"),
            "The whole square segment answers to touch, not just the chevron glyph"
        )
        XCTAssertTrue(
            source.contains("Circle()\n                    .fill(configuration.isPressed ? DPColor.accentSoftHover : DPColor.accentSoft)"),
            "The accent circle is painted at all times and darkens while pressed"
        )
        XCTAssertTrue(
            source.contains(".scaleEffect(configuration.isPressed ? DPMonthCapsuleMetrics.pressedScale : 1)"),
            "Only the circle shrinks while pressed"
        )
        XCTAssertTrue(source.contains("static let pressedScale: CGFloat = 0.92"))
        XCTAssertFalse(
            source.contains("Circle().stroke"),
            "The tint carries the shape; a border made the arrow read as a form field"
        )
    }

    func testTheYearMonthButtonReportsItsPressToTintTheWholeCapsule() throws {
        let source = try Self.componentSource()

        XCTAssertTrue(source.contains("@State private var isMonthPressed = false"))
        XCTAssertTrue(source.contains(".onChange(of: configuration.isPressed)"))
        XCTAssertTrue(
            source.contains(".foregroundStyle(isMonthPressed ? DPColor.accent : DPColor.textMuted)"),
            "The year-month chevron turns accent while pressed"
        )
        XCTAssertTrue(
            source.contains("Text(verbatim: Self.widestDigitTemplate(for: yearMonth))\n                    .hidden()"),
            "The year-month reserves a steady width so the capsule does not resize between months"
        )
        XCTAssertTrue(source.contains("Image(systemName: \"chevron.down\")"))
    }

    /// The app font has no tabular figures, so the capsule reserves the width of the label
    /// drawn with its widest digit ("0") and keeps the same size from month to month.
    func testTheYearMonthWidthIsReservedWithTheWidestDigit() {
        XCTAssertEqual(DPMonthCapsule.widestDigitTemplate(for: "2026-11"), "0000-00")
        XCTAssertEqual(DPMonthCapsule.widestDigitTemplate(for: "2026년 1월"), "0000년 0월")
        XCTAssertEqual(DPMonthCapsule.widestDigitTemplate(for: "1/2027"), "0/0000")
    }

    func testTheCalendarHeaderUsesTheSharedCapsule() throws {
        let source = try Self.source("Dutypark/Features/Calendar/CalendarView.swift")
        let controls = try Self.declaration(named: "private var monthControls: some View", in: source)

        XCTAssertFalse(controls.contains("Image(systemName: \"chevron.left\")"))
        XCTAssertTrue(controls.contains("DPMonthCapsule("))
        XCTAssertTrue(controls.contains("monthFontSize: DPMonthCapsuleMetrics.compactMonthFontSize"))
        XCTAssertTrue(controls.contains("identifier: \"calendar.month.previous\""))
        XCTAssertTrue(controls.contains("identifier: \"calendar.month.next\""))
        XCTAssertTrue(controls.contains("monthIdentifier: \"calendar.month.display\""))
        XCTAssertTrue(source.contains("CalendarLocalization.text(\"calendar.month.previous\")"))
        XCTAssertTrue(source.contains("CalendarLocalization.text(\"calendar.month.next\")"))
    }

    func testTheTeamHeaderUsesTheSharedCapsuleWithDistinctLabels() throws {
        let source = try Self.source("Dutypark/Features/Team/TeamView.swift")
        let header = try Self.declaration(named: "private var monthHeader: some View", in: source)

        XCTAssertFalse(header.contains("Image(systemName: \"chevron.left\")"))
        XCTAssertTrue(header.contains("DPMonthCapsule("))
        XCTAssertTrue(header.contains("monthFontSize: DPMonthCapsuleMetrics.compactMonthFontSize"))
        XCTAssertTrue(header.contains("monthIdentifier: \"team.calendar.month.display\""))
        XCTAssertTrue(
            header.contains("team.view.calendar.previousMonth") && header.contains("team.view.calendar.nextMonth"),
            "Both arrows used to read as the same control to VoiceOver"
        )
    }

    func testTheGuestCalendarUsesTheSharedCapsule() throws {
        let source = try Self.source("Dutypark/Features/Guest/GuestPublicCalendarView.swift")
        let controls = try Self.declaration(named: "private var monthControls: some View", in: source)

        XCTAssertFalse(controls.contains("Image(systemName: \"chevron.left\")"))
        XCTAssertTrue(controls.contains("DPMonthCapsule("))
        XCTAssertTrue(controls.contains("identifier: \"guest.calendar.month.previous\""))
        XCTAssertTrue(controls.contains("identifier: \"guest.calendar.month.next\""))
        XCTAssertTrue(controls.contains("monthIdentifier: \"guest.calendar.monthPicker.open\""))
    }

    /// The navigation bar gives the principal item only the room between the leading and
    /// trailing items, and anything the capsule draws past that room ignores touches. Padding
    /// both sides to one fixed width left a 375pt screen too little room for the capsule, so
    /// the side items keep their natural widths (the leading one capped) and the bar centres
    /// the capsule when it fits, sliding it aside otherwise.
    func testTheBarSideItemsLeaveTheCapsuleItsWidth() throws {
        let calendar = try Self.source("Dutypark/Features/Calendar/CalendarView.swift")
        let calendarToolbar = try Self.declaration(named: "private var calendarToolbar: some ToolbarContent", in: calendar)
        XCTAssertTrue(
            calendarToolbar.contains("memberIdentityBar\n                .frame(maxWidth: Self.barSideWidth, alignment: .leading)\n                .fixedSize(horizontal: true, vertical: false)"),
            "The bar would squeeze the identity to make room and cut the name; it keeps its ideal width up to the cap"
        )
        XCTAssertFalse(calendarToolbar.contains(".frame(width: Self.barSideWidth"))
        let identityBar = try Self.declaration(named: "private var memberIdentityBar: some View", in: calendar)
        XCTAssertFalse(identityBar.contains("maxWidth: .infinity"), "The identity reports its natural width")

        let team = try Self.source("Dutypark/Features/Team/TeamView.swift")
        let teamToolbar = try Self.declaration(named: "private func teamToolbar(_ team: TeamDTO) -> some ToolbarContent", in: team)
        XCTAssertTrue(
            teamToolbar.contains("teamNameChip(team)\n                .frame(maxWidth: Self.barSideWidth, alignment: .leading)\n                .fixedSize(horizontal: true, vertical: false)"),
            "The bar would squeeze the chip down to its icon"
        )
        XCTAssertFalse(teamToolbar.contains(".frame(width: Self.barSideWidth"))
    }

    func testTheOldStandaloneArrowIsGone() throws {
        for path in [
            "Dutypark/Features/Calendar/CalendarView.swift",
            "Dutypark/Features/Team/TeamView.swift",
            "Dutypark/Features/Guest/GuestPublicCalendarView.swift",
        ] {
            XCTAssertFalse(try Self.source(path).contains("DPMonthArrowButton("), "\(path) still uses the standalone arrow")
        }
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
