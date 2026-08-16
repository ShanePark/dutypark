import Foundation
import Testing
@testable import Dutypark

@Suite(.serialized)
@MainActor
struct AuthLocalizationTests {
    @Test
    func knownOAuthErrorsFollowTheAppLanguageOverride() {
        withKoreanOverride {
            #expect(
                OAuthLoginErrorMessage.text(for: MobileOAuthError.invalidCallback)
                    == "소셜 로그인 응답이 올바르지 않습니다. 다시 시도해주세요."
            )
            #expect(
                OAuthLoginErrorMessage.text(for: AppleSignInError.invalidCredential)
                    == "Apple 로그인 응답이 올바르지 않거나 만료되었습니다. 다시 시도해주세요."
            )
        }
    }

    @Test
    func unknownOAuthErrorsUseTheLocalizedGenericMessage() {
        withKoreanOverride {
            let systemError = NSError(
                domain: "AuthenticationServices.AuthorizationError",
                code: 1000,
                userInfo: [NSLocalizedDescriptionKey: "Authorization failed."]
            )

            #expect(
                OAuthLoginErrorMessage.text(for: systemError)
                    == "소셜 로그인에 실패했습니다. 다시 시도해주세요."
            )
        }
    }

    private func withKoreanOverride(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defaults.set("ko", forKey: SettingsPreference.languageKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: SettingsPreference.languageKey)
            } else {
                defaults.removeObject(forKey: SettingsPreference.languageKey)
            }
        }
        body()
    }
}
