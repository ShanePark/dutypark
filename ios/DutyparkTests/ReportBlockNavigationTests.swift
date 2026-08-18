import Foundation
import XCTest
@testable import Dutypark

/// A report submitted with "also block" applies exactly the same server-side block as the
/// dedicated block action, so it has to leave the blocked member's calendar the same way.
/// Staying there signs the user out: the next calendar load is rejected by the visibility
/// check and the retried 401 terminates the session.
@MainActor
final class ReportBlockNavigationTests: XCTestCase {

    // MARK: - What the sheet knows

    func testASubmittedReportRemembersThatItAlsoBlocked() async {
        let model = ReportViewModel(
            target: ReportTarget(type: .member, targetID: "7", name: "홍길동"),
            repository: ReportBlockRepositoryStub()
        )
        model.alsoBlock = true

        XCTAssertFalse(model.didBlock, "Nothing is blocked before the report is sent")
        let submitted = await model.submit()
        XCTAssertTrue(submitted)
        XCTAssertTrue(model.didBlock)
    }

    func testAReportWithoutTheBlockToggleNeverClaimsToHaveBlocked() async {
        let model = ReportViewModel(
            target: ReportTarget(type: .schedule, targetID: "42", name: "회식"),
            repository: ReportBlockRepositoryStub()
        )

        let submitted = await model.submit()
        XCTAssertTrue(submitted)
        XCTAssertTrue(model.didSubmit)
        XCTAssertFalse(model.didBlock)
    }

    func testAFailedReportBlocksNobodyEvenWithTheToggleOn() async {
        let model = ReportViewModel(
            target: ReportTarget(type: .member, targetID: "7", name: "홍길동"),
            repository: ReportBlockRepositoryStub(error: APIError.server(status: 400, code: "report.self"))
        )
        model.alsoBlock = true

        let submitted = await model.submit()
        XCTAssertFalse(submitted)
        XCTAssertFalse(model.didBlock, "A rejected report leaves the user where they are")
    }

    // MARK: - What the sheet tells its host

    func testTheReportSheetHandsTheBlockOutcomeToItsHostBeforeDismissing() throws {
        let source = try source(of: "Dutypark/Features/Report/ReportSheet.swift")

        for wiring in [
            "private let onBlocked: () -> Void",
            "onBlocked: @escaping () -> Void = {}",
            // The host records the outcome while the cover is still up, so its dismissal
            // callback already knows whether it has to leave.
            "if model.didBlock { onBlocked() }",
        ] {
            XCTAssertTrue(source.contains(wiring), "ReportSheet is missing: \(wiring)")
        }
    }

    // MARK: - Leaving the calendar

    func testAMemberReportThatBlocksLeavesTheCalendarThroughTheDedicatedBlockMechanism() throws {
        let source = try source(of: "Dutypark/Features/Calendar/CalendarView.swift")

        for wiring in [
            // Both the report cover and the block confirmation land in the same pop.
            "private func leaveBlockedMemberCalendar()",
            "guard leavesAfterBlock else { return }",
            "leavesAfterBlock = false",
            "memberBackAction?()",
            "private func finishReportDismissal()",
            "onDismiss: { finishReportDismissal() }",
            "onBlocked: { leavesAfterBlock = true }",
        ] {
            XCTAssertTrue(source.contains(wiring), "CalendarView is missing: \(wiring)")
        }
        // The pop still runs from the cover's dismissal callback, never from the alert.
        XCTAssertFalse(
            source.contains("onBlocked: { memberBackAction?() }"),
            "SwiftUI drops navigation requested while a cover is still on screen"
        )
    }

    func testAScheduleReportThatBlocksTheCalendarOwnerClosesTheDayModalThenLeaves() throws {
        let source = try source(of: "Dutypark/Features/Calendar/CalendarView.swift")

        for wiring in [
            // Only the calendar's own member strands the reporter: a schedule a third
            // party tagged this member into belongs to somebody else entirely.
            "private func blockEndsCalendarAccess(_ schedule: ScheduleDTO) -> Bool",
            "!model.isMyCalendar && !schedule.isTagged",
            "reportBlockEndsCalendarAccess = blockEndsCalendarAccess(schedule)",
            "onBlocked: { leavesAfterBlock = reportBlockEndsCalendarAccess }",
            "let onBlockedCalendarOwner: () -> Void",
            "onBlockedCalendarOwner: { leavesAfterBlock = true }",
            // The day modal has to be gone before the calendar pops.
            "onBlockedCalendarOwner()",
            "leaveBlockedMemberCalendar()",
        ] {
            XCTAssertTrue(source.contains(wiring), "CalendarView is missing: \(wiring)")
        }
    }

    func testTheToDoReportStaysPutBecauseTheBoardBelongsToTheReporter() throws {
        let source = try source(of: "Dutypark/Features/Todo/TodoModalViews.swift")

        // The to-do board is always the signed-in member's own, and only a to-do somebody
        // else tagged them into is reportable, so blocking that owner never revokes access
        // to the screen the reporter is standing on.
        XCTAssertTrue(source.contains("if todo.isTagged {"))
        XCTAssertFalse(source.contains("onBlocked:"), "Nothing to leave from the reporter's own board")
        XCTAssertFalse(source.contains("leavesAfterBlock"))
    }

    // MARK: - Helpers

    private func source(of relativePath: String) throws -> String {
        try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: relativePath),
            encoding: .utf8
        )
    }
}

private final class ReportBlockRepositoryStub: ReportRepository, @unchecked Sendable {
    private let error: (any Error)?

    init(error: (any Error)? = nil) {
        self.error = error
    }

    func createReport(_ request: CreateReportRequest) async throws {
        if let error { throw error }
    }

    func block(memberID: MemberID) async throws {
        if let error { throw error }
    }
}
