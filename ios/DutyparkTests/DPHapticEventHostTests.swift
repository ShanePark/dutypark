import Foundation
import SwiftUI
import Testing
@testable import Dutypark

@MainActor
struct DPHapticEventHostTests {
    @Test
    func semanticKindsMapToTheMatchingSystemFeedback() {
        #expect(DPHapticKind.selection.sensoryFeedback == .selection)
        #expect(
            DPHapticKind.routine.sensoryFeedback
                == .impact(flexibility: .soft, intensity: 0.6)
        )
        #expect(DPHapticKind.success.sensoryFeedback == .success)
        #expect(DPHapticKind.warning.sensoryFeedback == .warning)
        #expect(DPHapticKind.error.sensoryFeedback == .error)
    }

    @Test
    func repeatedKindsStillProduceDistinctEvents() {
        let center = DPHapticCenter()

        let first = center.emit(.success)
        let second = center.emit(.success)

        #expect(first.kind == .success)
        #expect(second.kind == .success)
        #expect(first.id != second.id)
        #expect(center.event == second)
    }

    @Test
    func hostIsInstalledAtTheApplicationRoot() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let hostSource = try String(
            contentsOf: sourceURL.appending(path: "Dutypark/Components/DPHapticEventHost.swift"),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: sourceURL.appending(path: "Dutypark/App/DutyparkApp.swift"),
            encoding: .utf8
        )

        #expect(hostSource.contains("sensoryFeedback(trigger: center.event)"))
        #expect(hostSource.contains("DPHapticKind"))
        #expect(appSource.contains("dpHapticEventHost()"))
    }
}
