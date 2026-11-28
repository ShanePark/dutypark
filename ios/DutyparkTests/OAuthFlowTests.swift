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

final class SsoSignupNamePolicyTests: XCTestCase {
    private func name(given: String? = nil, family: String? = nil) -> PersonNameComponents {
        var components = PersonNameComponents()
        components.givenName = given
        components.familyName = family
        return components
    }

    func testDefaultNameAppendsFourZeroPaddedDigitsToTheLocalizedPrefix() {
        let korean = Locale(identifier: "ko")
        let english = Locale(identifier: "en")

        XCTAssertEqual(SsoSignupNamePolicy.defaultName(locale: korean, randomNumber: { 4821 }), "사용자4821")
        XCTAssertEqual(SsoSignupNamePolicy.defaultName(locale: english, randomNumber: { 0 }), "User0000")
        XCTAssertEqual(SsoSignupNamePolicy.defaultName(locale: english, randomNumber: { 42 }), "User0042")
        XCTAssertEqual(SsoSignupNamePolicy.defaultName(locale: english, randomNumber: { 9999 }), "User9999")
    }

    func testDefaultNameUsesRandomDigitsWithinTheNameLimit() throws {
        for locale in ["ko", "en"] {
            let generated = SsoSignupNamePolicy.defaultName(locale: Locale(identifier: locale))
            let digits = String(generated.suffix(4))
            XCTAssertEqual(digits.count, 4)
            XCTAssertTrue(digits.allSatisfy(\.isASCII))
            XCTAssertNotNil(Int(digits))
            XCTAssertLessThanOrEqual(generated.count, SsoSignupNamePolicy.maxLength)
        }
    }

    func testAppleNameJoinsLatinNamesAsGivenThenFamily() {
        XCTAssertEqual(SsoSignupNamePolicy.appleName(from: name(given: "John", family: "Kim")), "John Kim")
    }

    func testAppleNameJoinsHangulOrCJKNamesAsFamilyThenGivenWithoutSpace() {
        XCTAssertEqual(SsoSignupNamePolicy.appleName(from: name(given: "길동", family: "홍")), "홍길동")
        XCTAssertEqual(SsoSignupNamePolicy.appleName(from: name(given: "Gildong", family: "홍")), "홍Gildong")
        XCTAssertEqual(SsoSignupNamePolicy.appleName(from: name(given: "太郎", family: "山田")), "山田太郎")
        XCTAssertEqual(SsoSignupNamePolicy.appleName(from: name(given: "ひろ", family: "カタ")), "カタひろ")
    }

    func testAppleNameTrimsPartsAndToleratesAMissingPart() {
        XCTAssertEqual(SsoSignupNamePolicy.appleName(from: name(given: "  Jane ")), "Jane")
        XCTAssertEqual(SsoSignupNamePolicy.appleName(from: name(family: " Doe ")), "Doe")
        XCTAssertEqual(SsoSignupNamePolicy.appleName(from: name(given: " 길동 ")), "길동")
    }

    func testAppleNameFallsBackToGivenNameThenTruncatesToTheLimit() {
        XCTAssertEqual(
            SsoSignupNamePolicy.appleName(from: name(given: "Johnathan", family: "Smith")),
            "Johnathan Smith"
        )
        XCTAssertEqual(
            SsoSignupNamePolicy.appleName(from: name(given: "Maximiliano", family: "Rodriguez")),
            "Maximiliano"
        )
        XCTAssertEqual(
            SsoSignupNamePolicy.appleName(from: name(family: "Wolfeschlegelsteinhausen")),
            "Wolfeschlegelsteinha"
        )
        XCTAssertEqual(
            SsoSignupNamePolicy.appleName(from: name(given: "Ann Marie Lee Jones Wu", family: "X")),
            "Ann Marie Lee Jones"
        )
    }

    func testNameLengthCountsUTF16CodeUnitsLikeTheServerAndWeb() {
        let twenty = String(repeating: "가", count: 20)
        let nineteen = String(repeating: "가", count: 19)
        let eighteen = String(repeating: "가", count: 18)
        XCTAssertEqual(SsoSignupNamePolicy.length(of: twenty), 20)
        XCTAssertTrue(SsoSignupNamePolicy.fits(twenty))
        XCTAssertEqual(SsoSignupNamePolicy.length(of: nineteen + "😀"), 21)
        XCTAssertFalse(SsoSignupNamePolicy.fits(nineteen + "😀"))
        XCTAssertTrue(SsoSignupNamePolicy.fits(eighteen + "😀"))
    }

    func testTruncatedDropsWholeGraphemesUntilTheNameFitsTheLimit() {
        let twenty = String(repeating: "가", count: 20)
        let nineteen = String(repeating: "가", count: 19)
        let eighteen = String(repeating: "가", count: 18)
        XCTAssertEqual(SsoSignupNamePolicy.truncated(nineteen + "😀"), nineteen)
        XCTAssertEqual(SsoSignupNamePolicy.truncated(twenty + "카"), twenty)
        XCTAssertEqual(SsoSignupNamePolicy.truncated("123456789012345678🇰🇷"), "123456789012345678")
        XCTAssertEqual(SsoSignupNamePolicy.truncated("1234567890123456789👨‍👩‍👧"), "1234567890123456789")
        XCTAssertEqual(SsoSignupNamePolicy.truncated(eighteen + "😀"), eighteen + "😀")
        XCTAssertEqual(SsoSignupNamePolicy.truncated("Jane"), "Jane")
    }

    func testAppleNameMeasuresTheLimitInUTF16CodeUnits() {
        let seventeen = String(repeating: "가", count: 17)
        let nineteen = String(repeating: "가", count: 19)
        XCTAssertEqual(
            SsoSignupNamePolicy.appleName(from: name(given: "아자😀", family: seventeen)),
            "아자😀"
        )
        XCTAssertEqual(
            SsoSignupNamePolicy.appleName(from: name(family: nineteen + "😀")),
            nineteen
        )
    }

    func testSignupFieldCountsAndTruncatesThroughThePolicy() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Auth/SsoSignupView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("username = SsoSignupNamePolicy.truncated(value)"))
        XCTAssertTrue(source.contains("SsoSignupNamePolicy.fits(name)"))
        XCTAssertTrue(source.contains("SsoSignupNamePolicy.length(of: username)"))
        XCTAssertFalse(source.contains("value.prefix(10)"))
    }

    func testAppleNameIsNilWhenAppleSharedNoUsableName() {
        XCTAssertNil(SsoSignupNamePolicy.appleName(from: nil))
        XCTAssertNil(SsoSignupNamePolicy.appleName(from: PersonNameComponents()))
        XCTAssertNil(SsoSignupNamePolicy.appleName(from: name(given: "   ", family: "")))
    }

    func testInitialNamePrefersTheAppleNameAndOtherwiseUsesTheDefault() {
        let english = Locale(identifier: "en")
        XCTAssertEqual(
            SsoSignupNamePolicy.initialName(suggestedName: "홍길동", locale: english, randomNumber: { 1 }),
            "홍길동"
        )
        XCTAssertEqual(
            SsoSignupNamePolicy.initialName(suggestedName: nil, locale: english, randomNumber: { 1 }),
            "User0001"
        )
        XCTAssertEqual(
            SsoSignupNamePolicy.initialName(suggestedName: "  ", locale: english, randomNumber: { 7 }),
            "User0007"
        )
    }

    func testUnchangedPrefilledNameIsNotADraft() {
        XCTAssertEqual(
            SsoSignupPresentationPolicy.cancellationDecision(
                username: "User0042",
                initialUsername: "User0042",
                agreesToTerms: false,
                agreesToPrivacy: false,
                isWorking: false
            ),
            .dismiss
        )
        XCTAssertEqual(
            SsoSignupPresentationPolicy.cancellationDecision(
                username: "Edited",
                initialUsername: "User0042",
                agreesToTerms: false,
                agreesToPrivacy: false,
                isWorking: false
            ),
            .confirmDiscard
        )
        XCTAssertTrue(
            SsoSignupPresentationPolicy.hasDraft(
                username: "User0042",
                initialUsername: "User0042",
                agreesToTerms: true,
                agreesToPrivacy: false
            )
        )
    }

    func testSignupViewPrefillsTheNameOnceFromThePolicy() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Auth/SsoSignupView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("guard initialUsername == nil else { return }"))
        XCTAssertTrue(source.contains("SsoSignupNamePolicy.initialName(suggestedName: suggestedName)"))
    }

    func testDefaultNamePrefixResolvesInEverySupportedLocale() throws {
        let expected = ["en": "User", "ko": "사용자"]
        for (locale, prefix) in expected {
            let url = try XCTUnwrap(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try XCTUnwrap(Bundle(url: url))
            XCTAssertEqual(
                bundle.localizedString(forKey: "auth.oauth.signup.name.defaultPrefix", value: nil, table: "OAuth"),
                prefix
            )
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
