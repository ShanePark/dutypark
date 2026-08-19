import Foundation
import Testing
@testable import Dutypark

struct AuthLocalizationTests {
    @Test
    func knownOAuthErrorsReadTheServerErrorCatalog() {
        #expect(
            errorCopy("auth.oauth.mobile.callback.invalid", locale: .korean)
                == "소셜 로그인 응답이 올바르지 않습니다. 다시 시도해주세요."
        )
        #expect(
            errorCopy("auth.oauth.mobile.callback.invalid", locale: .english)
                == "The social login response is invalid. Please try again."
        )
        #expect(
            errorCopy("auth.apple.credential.invalid", locale: .korean)
                == "Apple 로그인 응답이 올바르지 않거나 만료되었습니다. 다시 시도해주세요."
        )
        #expect(
            errorCopy("auth.apple.credential.invalid", locale: .english)
                == "The Apple sign-in response is invalid or expired. Please try again."
        )

        // The presented copy reads those same entries in whichever language iOS resolved.
        #expect(
            OAuthLoginErrorMessage.text(for: MobileOAuthError.invalidCallback)
                == APIErrorLocalization.message(code: "auth.oauth.mobile.callback.invalid")
        )
        #expect(
            OAuthLoginErrorMessage.text(for: AppleSignInError.invalidCredential)
                == APIErrorLocalization.message(code: "auth.apple.credential.invalid")
        )
    }

    @Test
    func unknownOAuthErrorsUseTheLocalizedGenericMessage() {
        let systemError = NSError(
            domain: "AuthenticationServices.AuthorizationError",
            code: 1000,
            userInfo: [NSLocalizedDescriptionKey: "Authorization failed."]
        )

        #expect(
            oauthCopy("auth.oauth.error", locale: .korean)
                == "소셜 로그인에 실패했습니다. 다시 시도해주세요."
        )
        #expect(
            oauthCopy("auth.oauth.error", locale: .english)
                == "Social login failed. Please try again."
        )
        #expect(
            OAuthLoginErrorMessage.text(for: systemError)
                == AppLocalization.string("auth.oauth.error", table: "OAuth")
        )
    }

    @Test
    func loginFailuresSeparateNetworkAndServerMessages() {
        #expect(
            LoginErrorMessage.text(key: "auth.login.error.network", status: nil, locale: .korean)
                == "서버에 연결할 수 없습니다. 네트워크 상태를 확인한 뒤 다시 시도해주세요."
        )
        #expect(
            LoginErrorMessage.text(key: "auth.login.error.network", status: nil, locale: .english)
                == "Unable to reach the server. Check your network connection and try again."
        )
        #expect(
            LoginErrorMessage.text(key: "auth.login.error.server", status: 502, locale: .korean)
                == "서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요. (오류 502)"
        )
        #expect(
            LoginErrorMessage.text(key: "auth.login.error.server", status: 502, locale: .english)
                == "The server is temporarily unavailable. Please try again shortly. (error 502)"
        )
        #expect(
            LoginErrorMessage.text(key: "auth.login.error.unknown", status: 400, locale: .korean)
                == "로그인에 실패했습니다. 잠시 후 다시 시도해주세요. (오류 400)"
        )
        #expect(
            LoginErrorMessage.text(key: "auth.login.error.unknown", status: 400, locale: .english)
                == "Failed to log in. Please try again shortly. (error 400)"
        )
    }

    @Test
    func suspendedAccountLoginUsesTheServerErrorLocalization() {
        #expect(
            LoginErrorMessage.text(key: "auth.account.suspended", status: nil, locale: .korean)
                == "계정이 이용 정지되었습니다. 이의제기는 문의 페이지를 이용해 주세요."
        )
        #expect(
            LoginErrorMessage.text(key: "auth.account.suspended", status: nil, locale: .english)
                == "This account has been suspended. Please use the support page to appeal."
        )
    }

    private func errorCopy(_ code: String, locale: Locale) -> String {
        APIErrorLocalization.message(code: code, bundle: AppLocalization.bundle(for: locale))
    }

    private func oauthCopy(_ key: String, locale: Locale) -> String {
        AppLocalization.string(key, table: "OAuth", locale: locale)
    }
}
