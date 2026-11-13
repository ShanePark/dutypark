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

    /// The navigation bar centres a principal item only when it fits between the leading and
    /// trailing items; otherwise it slides it, so the capsule moved with every name length and
    /// trailing control. Padding both sides to one fixed width instead left a 375pt screen too
    /// little room, and the bar ignored touches on whatever the capsule drew past it. Both
    /// headers now hand the bar one full-width principal header that centres the capsule
    /// itself and gives each side only the room beside it.
    func testCalendarAndTeamHostTheirSideItemsInsideTheSharedHeader() throws {
        let calendar = try Self.source("Dutypark/Features/Calendar/CalendarView.swift")
        let calendarToolbar = try Self.declaration(named: "private var calendarToolbar: some ToolbarContent", in: calendar)
        let team = try Self.source("Dutypark/Features/Team/TeamView.swift")
        let teamToolbar = try Self.declaration(named: "private func teamToolbar(_ team: TeamDTO) -> some ToolbarContent", in: team)

        for (name, toolbar) in [("Calendar", calendarToolbar), ("Team", teamToolbar)] {
            XCTAssertTrue(toolbar.contains("DPDashboardHeaderToolbarItem(placement: .principal) {\n            DPMonthHeaderBar {"), name)
            XCTAssertFalse(toolbar.contains(".topBarLeading"), "\(name): a separate side item would push the capsule off centre again")
            XCTAssertFalse(toolbar.contains(".topBarTrailing"), "\(name): a separate side item would push the capsule off centre again")
            XCTAssertFalse(toolbar.contains("barSideWidth"), "\(name): the header sizes the sides from the capsule, not a fixed cap")
        }
        XCTAssertTrue(calendarToolbar.contains("memberIdentityBar"))
        XCTAssertTrue(calendarToolbar.contains("monthControls"))
        XCTAssertTrue(calendarToolbar.contains("searchControl"))
        XCTAssertTrue(teamToolbar.contains("teamNameChip(team)"))
        XCTAssertTrue(teamToolbar.contains("monthHeader"))
        XCTAssertTrue(teamToolbar.contains("manageControl(team)"))

        let identityBar = try Self.declaration(named: "private var memberIdentityBar: some View", in: calendar)
        XCTAssertFalse(identityBar.contains("maxWidth: .infinity"), "The identity reports its natural width")
        XCTAssertTrue(
            calendar.contains("size: memberBackAction == nil ? Self.barAvatarSize : Self.barAvatarSizeBesideBack"),
            "Beside the back chevron the centred capsule leaves the name too little room at the full avatar size"
        )
    }

    func testTheSharedHeaderKeepsTheCapsuleAtItsFullWidth() throws {
        let source = try Self.source("Dutypark/Components/DPMonthHeaderBar.swift")
        XCTAssertTrue(source.contains("struct DPMonthHeaderBar<Leading: View, Center: View, Trailing: View>: View"))
        XCTAssertTrue(
            source.contains("subviews[1].sizeThatFits(.unspecified)"),
            "The capsule is measured at its ideal size and never squeezed by the side items"
        )
        // A header narrower than the capsule would let the bar clip the arrows' touch area.
        XCTAssertTrue(source.contains("max(width, capsule.width)"))
    }

    /// The capsule's centre is the header's centre whatever the side items hold.
    func testTheCapsuleStaysCentredWhateverTheSideItemsHold() {
        let capsuleWidth: CGFloat = 193
        let containerWidth: CGFloat = 343
        let reference = DPMonthHeaderPlacement(
            containerWidth: containerWidth,
            capsuleWidth: capsuleWidth,
            leadingIdealWidth: 77,
            trailingIdealWidth: 36
        )
        XCTAssertEqual(reference.capsuleMinX + capsuleWidth / 2, containerWidth / 2)

        for (leading, trailing) in [(0, 0), (88, 36), (240, 0), (12, 120)] as [(CGFloat, CGFloat)] {
            let placement = DPMonthHeaderPlacement(
                containerWidth: containerWidth,
                capsuleWidth: capsuleWidth,
                leadingIdealWidth: leading,
                trailingIdealWidth: trailing
            )
            XCTAssertEqual(placement.capsuleMinX, reference.capsuleMinX, "leading \(leading), trailing \(trailing)")
            XCTAssertEqual(placement.sideWidth, reference.sideWidth)
        }
    }

    /// Each side gets only the room beside the capsule: a short item keeps its natural width,
    /// a long one is truncated to the room, and neither reaches the capsule.
    func testEachSideGetsOnlyTheRoomBesideTheCapsule() {
        let placement = DPMonthHeaderPlacement(
            containerWidth: 343,
            capsuleWidth: 193,
            leadingIdealWidth: 240,
            trailingIdealWidth: 36
        )
        let room = (343 - 193) / 2 - DPMonthHeaderPlacement.capsuleSpacing
        XCTAssertEqual(placement.sideWidth, room)
        XCTAssertEqual(placement.leadingWidth, room)
        XCTAssertEqual(placement.trailingWidth, 36)
        XCTAssertLessThanOrEqual(placement.leadingWidth, placement.capsuleMinX)
        XCTAssertGreaterThanOrEqual(343 - placement.trailingWidth, placement.capsuleMinX + 193)
    }

    func testANarrowHeaderGivesTheSidesNoRoomButKeepsTheCapsuleWhole() {
        let placement = DPMonthHeaderPlacement(
            containerWidth: 150,
            capsuleWidth: 193,
            leadingIdealWidth: 77,
            trailingIdealWidth: 36
        )
        XCTAssertEqual(placement.sideWidth, 0)
        XCTAssertEqual(placement.leadingWidth, 0)
        XCTAssertEqual(placement.trailingWidth, 0)
        XCTAssertEqual(placement.capsuleMinX + 193 / 2, 75)
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
