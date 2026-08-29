import XCTest
@testable import Dutypark

final class OAuthSignupPresentationTests: XCTestCase {
    func testDirectUITestDestinationsStayBehindDebugCompilation() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Auth/AppRootView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("#if DEBUG\nnonisolated enum UITestingDestination"))
        XCTAssertTrue(source.contains("UITestingDestination(arguments: ProcessInfo.processInfo.arguments)"))
        XCTAssertTrue(source.contains("guard uiTestingDestination == nil else { return }"))
    }

    func testDirectUITestDestinationRequiresAnExplicitLaunchArgument() {
        XCTAssertNil(UITestingDestination(arguments: []))
        XCTAssertNil(UITestingDestination(arguments: ["-ui-testing-authenticated"]))
        XCTAssertEqual(
            UITestingDestination(arguments: ["-ui-testing-sso-signup"]),
            .ssoSignup
        )
        XCTAssertEqual(
            UITestingDestination(arguments: ["-ui-testing-direct-attachment-gallery"]),
            .attachmentGallery
        )
    }

    func testEmptySignupCanDismissImmediately() {
        XCTAssertEqual(
            SsoSignupPresentationPolicy.cancellationDecision(
                username: "  \n",
                agreesToTerms: false,
                agreesToPrivacy: false,
                isWorking: false
            ),
            .dismiss
        )
    }

    func testNameOrEitherAgreementCountsAsDraft() {
        XCTAssertTrue(
            SsoSignupPresentationPolicy.hasDraft(
                username: "Dutyparker",
                agreesToTerms: false,
                agreesToPrivacy: false
            )
        )
        XCTAssertTrue(
            SsoSignupPresentationPolicy.hasDraft(
                username: "",
                agreesToTerms: true,
                agreesToPrivacy: false
            )
        )
        XCTAssertTrue(
            SsoSignupPresentationPolicy.hasDraft(
                username: "",
                agreesToTerms: false,
                agreesToPrivacy: true
            )
        )
    }

    func testDraftRequiresDiscardConfirmation() {
        XCTAssertEqual(
            SsoSignupPresentationPolicy.cancellationDecision(
                username: "Dutyparker",
                agreesToTerms: true,
                agreesToPrivacy: true,
                isWorking: false
            ),
            .confirmDiscard
        )
    }

    func testWorkingSignupBlocksCancellationEvenWithoutDraft() {
        XCTAssertEqual(
            SsoSignupPresentationPolicy.cancellationDecision(
                username: "",
                agreesToTerms: false,
                agreesToPrivacy: false,
                isWorking: true
            ),
            .blocked
        )
    }

    func testDiscardConfirmationUsesCenteredPanelAndBlocksExternalDismissalWhileWorking() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Auth/SsoSignupView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(
            source.contains(
                ".alert(\n            oauthString(\"auth.oauth.signup.discard.title\")"
            )
        )
        XCTAssertTrue(source.contains("DPConfirmationPanel("))
        XCTAssertTrue(source.contains("canDismiss: !isWorking"))
        XCTAssertTrue(source.contains(".interactiveDismissDisabled(isWorking)"))
        XCTAssertTrue(source.contains("case .blocked:"))
    }

    func testPresentationStringsResolveInEverySupportedLocale() throws {
        let keys = [
            "auth.oauth.close",
            "auth.oauth.apple",
            "auth.oauth.signup.discard.action",
            "auth.oauth.signup.discard.continue",
            "auth.oauth.signup.discard.message",
            "auth.oauth.signup.discard.title",
            "auth.oauth.signup.privacy",
            "auth.oauth.signup.terms",
        ]

        for locale in ["en", "ko"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try XCTUnwrap(Bundle(url: url))
            for key in keys {
                XCTAssertNotEqual(
                    bundle.localizedString(forKey: key, value: key, table: "OAuth"),
                    key,
                    "Missing \(key) for \(locale)"
                )
            }
        }
    }
}

final class LoginOAuthButtonPresentationTests: XCTestCase {
    func testIdleStateShowsNoProgressAndEnablesBothProviders() {
        for provider in OAuthProvider.allCases {
            let presentation = LoginOAuthButtonPresentation(
                provider: provider,
                activeProvider: nil,
                isSessionWorking: false
            )

            XCTAssertFalse(presentation.showsProgress)
            XCTAssertFalse(presentation.isDisabled)
        }
    }

    func testOnlyActiveProviderShowsProgressWhileBothProvidersAreDisabled() {
        for activeProvider in OAuthProvider.allCases {
            for provider in OAuthProvider.allCases {
                let presentation = LoginOAuthButtonPresentation(
                    provider: provider,
                    activeProvider: activeProvider,
                    isSessionWorking: false
                )

                XCTAssertEqual(presentation.showsProgress, provider == activeProvider)
                XCTAssertTrue(presentation.isDisabled)
            }
        }
    }

    func testEmailLoginDisablesBothProvidersWithoutShowingOAuthProgress() {
        for provider in OAuthProvider.allCases {
            let presentation = LoginOAuthButtonPresentation(
                provider: provider,
                activeProvider: nil,
                isSessionWorking: true
            )

            XCTAssertFalse(presentation.showsProgress)
            XCTAssertTrue(presentation.isDisabled)
        }
    }
}
