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

    func testBlockOutcomeUsesTheValueSentBeforeTheRequestSuspends() async {
        let repository = SuspendedReportRepository()
        let model = ReportViewModel(
            target: ReportTarget(type: .member, targetID: "7", name: "홍길동"),
            repository: repository
        )
        model.alsoBlock = true

        let submission = Task { await model.submit() }
        while await repository.recordedRequest == nil {
            await Task.yield()
        }
        model.alsoBlock = false
        await repository.finish()

        let submitted = await submission.value
        let recordedRequest = await repository.recordedRequest
        XCTAssertTrue(submitted)
        XCTAssertEqual(recordedRequest?.alsoBlock, true)
        XCTAssertTrue(model.didBlock, "The server received alsoBlock=true")
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
            "onBlocked: { dismissesAfterReportedBlock = true }",
            "let onBlockedScheduleOwner: (Bool) -> Void",
            "onBlockedScheduleOwner: { leavesCalendar in",
            // The day modal has to be gone before the calendar pops.
            "onBlockedScheduleOwner(reportBlockEndsCalendarAccess)",
            "leaveBlockedMemberCalendar()",
            "refreshesAfterReportedBlock",
            "await model.load()",
        ] {
            XCTAssertTrue(source.contains(wiring), "CalendarView is missing: \(wiring)")
        }
    }

    func testTheToDoReportThatBlocksRefreshesTheBoardAndClosesTheRemovedDetail() throws {
        let source = try source(of: "Dutypark/Features/Todo/TodoModalViews.swift")

        // The board remains accessible, but blocking the owner deletes this tag on the
        // server. Refresh the board and close the detail that is no longer accessible.
        XCTAssertTrue(source.contains("if todo.isTagged {"))
        XCTAssertTrue(source.contains("onBlocked: { dismissesAfterReportedBlock = true }"))
        XCTAssertTrue(source.contains("await model.refresh()"))
        XCTAssertTrue(source.contains("await onTodoChanged()"))
        XCTAssertTrue(source.contains("dismiss()"))
        let finish = try XCTUnwrap(source.range(of: "private func finishReportDismissal()"))
        let dismiss = try XCTUnwrap(
            source.range(of: "dismiss()", range: finish.lowerBound..<source.endIndex)
        )
        let refresh = try XCTUnwrap(
            source.range(of: "await model.refresh()", range: dismiss.upperBound..<source.endIndex)
        )
        XCTAssertLessThan(dismiss.lowerBound, refresh.lowerBound)
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

private actor SuspendedReportRepository: ReportRepository {
    private(set) var recordedRequest: CreateReportRequest?
    private var isFinished = false

    func createReport(_ request: CreateReportRequest) async throws {
        recordedRequest = request
        while !isFinished {
            await Task.yield()
        }
    }

    func block(memberID: MemberID) async throws {}

    func finish() {
        isFinished = true
    }
}
