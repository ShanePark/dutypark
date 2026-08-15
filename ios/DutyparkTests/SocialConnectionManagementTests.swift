import Foundation
import Testing
@testable import Dutypark

struct SocialConnectionManagementTests {
    @Test(arguments: [false, true])
    func unlinkConfirmationDisablesSubmissionAndDismissalTogether(isWorking: Bool) {
        #expect(
            SettingsSocialUnlinkConfirmationPolicy.canSubmit(isWorking: isWorking)
                == !isWorking
        )
        #expect(
            SettingsSocialUnlinkConfirmationPolicy.canDismiss(isWorking: isWorking)
                == !isWorking
        )
    }

    @Test
    func unlinkConfirmationUsesCenteredPanelInsteadOfNativeAlert() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Settings/SocialConnectionManagementView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(!source.contains(".alert(SettingsLocalization.string(\"settings.social.unlinkConfirmTitle\")"))
        #expect(source.contains("DPConfirmationPanel("))
        #expect(source.contains("isWorking: isUnlinkWorking"))
    }
}
