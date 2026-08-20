import Foundation
import SwiftUI
import Testing
@testable import Dutypark

@MainActor
struct DPFriendTagFeedbackTests {
    @Test
    func selectingAFriendUsesSelectionFeedback() {
        #expect(
            DPFriendTagFeedback.feedback(
                isEnabled: true,
                previous: [] as Set<MemberID>,
                current: [31]
            ) == .selection
        )
    }

    @Test
    func deselectingAFriendOrClearingAllUsesRoutineImpact() {
        let expected = DPButtonFeedback.routineImpact

        #expect(
            DPFriendTagFeedback.feedback(
                isEnabled: true,
                previous: [31, 32],
                current: [32]
            ) == expected
        )
        #expect(
            DPFriendTagFeedback.feedback(
                isEnabled: true,
                previous: [31, 32],
                current: []
            ) == expected
        )
    }

    @Test
    func unchangedOrDisabledSelectionStaysSilent() {
        #expect(
            DPFriendTagFeedback.feedback(
                isEnabled: true,
                previous: [31],
                current: [31]
            ) == nil
        )
        #expect(
            DPFriendTagFeedback.feedback(
                isEnabled: false,
                previous: [] as Set<MemberID>,
                current: [31]
            ) == nil
        )
    }

    @Test
    func sharedSelectorOwnsFeedbackAtTheSelectionBindingBoundary() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Components/DPFriendTagSelector.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains(".sensoryFeedback(trigger: selection)"))
        #expect(source.contains("DPFriendTagFeedback.feedback("))
    }
}
