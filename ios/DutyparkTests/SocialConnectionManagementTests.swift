import Foundation
import Testing
@testable import Dutypark

struct SocialConnectionManagementTests {
    @Test
    func impersonationHidesAccountControlsRegardlessOfPasswordAndEmail() {
        for hasPassword in [false, true] {
            for email in [nil, "", "owner@example.com"] as [String?] {
                let visibility = MyInfoAccountActionVisibility(
                    isImpersonating: true, hasPassword: hasPassword, email: email
                )
                #expect(!visibility.showsAccountControls)
                #expect(!visibility.showsPasswordChange)
            }
        }
    }

    @Test
    func passwordChangeRequiresAnEmailAndPasswordOnTheMembersOwnAccount() {
        for email in [nil, "", "   ", "\n\t"] as [String?] {
            let visibility = MyInfoAccountActionVisibility(
                isImpersonating: false, hasPassword: true, email: email
            )
            #expect(visibility.showsAccountControls)
            #expect(!visibility.showsPasswordChange)
        }
        let passwordless = MyInfoAccountActionVisibility(
            isImpersonating: false, hasPassword: false, email: "owner@example.com"
        )
        #expect(passwordless.showsAccountControls)
        #expect(!passwordless.showsPasswordChange)

        let eligible = MyInfoAccountActionVisibility(
            isImpersonating: false, hasPassword: true, email: " owner@example.com "
        )
        #expect(eligible.showsAccountControls)
        #expect(eligible.showsPasswordChange)
    }

    @Test(arguments: OAuthProvider.allCases)
    func impersonationMakesConnectedAndDisconnectedSocialAccountsReadOnly(provider: OAuthProvider) {
        for connected in [false, true] {
            var state = SettingsSocialManagementState(
                provider: provider,
                isConnected: connected,
                connectedProviderCount: connected ? 1 : 2,
                linkingProvider: nil,
                unlinkingProvider: nil
            )
            state.isImpersonating = true

            #expect(!state.canConnect)
            #expect(!state.canRequestUnlink)
            #expect(!state.showsLastProviderReason)
        }
    }

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
    func settingsRowOffersManagementOnlyForConnectedProviders() {
        #expect(SettingsSocialRowAction.resolve(isConnected: true) == .manage)
        #expect(SettingsSocialRowAction.resolve(isConnected: false) == .connect)
    }

    @Test
    func settingsRowRendersTheResolvedActionOnly() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Settings/MyInfoView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("switch SettingsSocialRowAction.resolve(isConnected: connected)"))
        #expect(source.contains("settings.social.connect.\\(provider.rawValue.lowercased())"))
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
