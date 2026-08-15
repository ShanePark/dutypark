import Foundation
import Testing
@testable import Dutypark

struct RootLogoutConfirmationTests {
    @Test
    func idleConfirmationCanSubmitAndDismiss() {
        #expect(RootLogoutConfirmationPolicy.canSubmit(isLoggingOut: false))
        #expect(RootLogoutConfirmationPolicy.canDismiss(isLoggingOut: false))
    }

    @Test
    func workingConfirmationRejectsDuplicateSubmissionAndDismissal() {
        #expect(!RootLogoutConfirmationPolicy.canSubmit(isLoggingOut: true))
        #expect(!RootLogoutConfirmationPolicy.canDismiss(isLoggingOut: true))
    }

    @Test
    func rootUsesTheCenteredPanelWhileKeepingTheUnsupportedLinkAlert() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/App/RootTabView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("DPConfirmationPanel("))
        #expect(!source.contains(".confirmationDialog("))
        #expect(source.contains(".alert(\"link.unsupported.title\""))
    }
}
