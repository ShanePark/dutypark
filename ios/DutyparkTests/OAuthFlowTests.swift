import XCTest
@testable import Dutypark

final class OAuthSignupPresentationTests: XCTestCase {
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

    func testPresentationStringsResolveInEverySupportedLocale() throws {
        let keys = [
            "auth.oauth.close",
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
