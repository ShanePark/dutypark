import XCTest

/// The "this month" callout is the one-tap way back from another month on both month-capsule
/// headers. Team used to put a text button beside the capsule, which left the navigation bar
/// too little room on a 375pt screen, so Team now shows the same callout as Calendar.
final class ThisMonthCalloutTests: XCTestCase {
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
        let end = rest.range(of: "\n    private ") ?? rest.range(of: "\n    var") ?? rest.range(of: "\n}")
        return String(rest[..<(end?.lowerBound ?? rest.endIndex)])
    }

    func testCalendarAndTeamDrawTheSameSharedCallout() throws {
        let component = try Self.source("Dutypark/Components/DPThisMonthCallout.swift")
        XCTAssertTrue(component.contains("struct DPThisMonthCallout: View"))
        XCTAssertTrue(component.contains("Image(systemName: \"arrow.uturn.backward\")"))

        let calendar = try Self.source("Dutypark/Features/Calendar/CalendarView.swift")
        XCTAssertTrue(calendar.contains("DPThisMonthCallout(label: CalendarLocalization.text(\"calendar.month.goToThisMonth\"))"))
        XCTAssertFalse(calendar.contains("struct CalloutTail"), "The tail moves with the shared callout")

        let team = try Self.source("Dutypark/Features/Team/TeamView.swift")
        XCTAssertTrue(team.contains("DPThisMonthCallout(label: teamLocalized(\"team.view.calendar.thisMonth\"))"))
    }

    func testTeamHasNoThisMonthBarButton() throws {
        let team = try Self.source("Dutypark/Features/Team/TeamView.swift")
        let toolbar = try Self.declaration(named: "private func teamToolbar(_ team: TeamDTO) -> some ToolbarContent", in: team)

        XCTAssertFalse(team.contains("thisMonthControl"))
        XCTAssertFalse(toolbar.contains("team.view.calendar.thisMonth"))
    }

    func testTeamHostsTheCalloutAtTheTopOfItsBodyLikeTheCalendar() throws {
        let team = try Self.source("Dutypark/Features/Team/TeamView.swift")
        let content = try Self.declaration(named: "private func teamContent(_ team: TeamDTO) -> some View", in: team)

        XCTAssertTrue(content.contains("ZStack(alignment: .top) {"))
        XCTAssertTrue(
            content.contains("thisMonthCalloutLayer\n                .offset(y: DPThisMonthCallout.verticalOffset)\n                .alignmentGuide(HorizontalAlignment.center) { _ in DPThisMonthCallout.tailCenter }"),
            "Team places the callout exactly where Calendar does"
        )
        XCTAssertTrue(content.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)"))

        let layer = try Self.declaration(named: "private var thisMonthCalloutLayer: some View", in: team)
        XCTAssertTrue(layer.contains("if !isCurrentMonth {"))
        XCTAssertTrue(layer.contains("Task { await viewModel.goToToday() }"))
    }

    /// Team's calendar starts right below the bar, where Calendar has its legend row, so Team
    /// keeps the callout's room open in every month: the layout does not jump when it appears.
    func testTeamKeepsRoomForTheCalloutInEveryMonth() throws {
        let team = try Self.source("Dutypark/Features/Team/TeamView.swift")
        let content = try Self.declaration(named: "private func teamContent(_ team: TeamDTO) -> some View", in: team)

        XCTAssertTrue(team.contains("private static let thisMonthCalloutClearance: CGFloat = 10"))
        XCTAssertTrue(content.contains(".padding(.top, DPSpacing.medium + Self.thisMonthCalloutClearance)"))
        XCTAssertFalse(content.contains("isCurrentMonth ?"), "The reserved room must not depend on the month")
    }
}
