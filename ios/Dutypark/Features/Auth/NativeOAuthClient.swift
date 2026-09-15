import AuthenticationServices
import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser
import NidThirdPartyLogin
import UIKit

/// Credentials returned by a provider's native SDK.
///
/// The associated value is deliberately limited to the token that the
/// server-side native exchange accepts for that provider. In particular, the
/// Naver client secret never leaves the SDK process and is never represented
/// by this type.
nonisolated enum NativeOAuthCredential: Equatable, Sendable {
    case kakao(accessToken: String)
    case naver(refreshToken: String)

    var provider: OAuthProvider {
        switch self {
        case .kakao:
            .kakao
        case .naver:
            .naver
        }
    }
}

@MainActor
protocol NativeOAuthAuthenticating: AnyObject {
    func isAvailable(for provider: OAuthProvider) -> Bool
    func authenticate(provider: OAuthProvider) async throws -> NativeOAuthCredential
    func handle(url: URL) -> Bool
}

@MainActor
protocol KakaoOAuthSDK: AnyObject {
    var isLoginAvailable: Bool { get }
    func loginWithKakaoTalk(completion: @escaping (String?, Error?) -> Void)
    func handle(url: URL) -> Bool
}

@MainActor
protocol NaverOAuthSDK: AnyObject {
    var isLoginAvailable: Bool { get }
    func requestLogin(completion: @escaping (String?, String?, Error?) -> Void)
    func handle(url: URL) -> Bool
}

@MainActor
final class NativeOAuthClient: NativeOAuthAuthenticating {
    private let providers: [OAuthProvider: any NativeOAuthProvider]

    init(configuration: OAuthNativeConfiguration = .fromMainBundle()) {
        var providers: [OAuthProvider: any NativeOAuthProvider] = [:]

        if configuration.isKakaoConfigured {
            providers[.kakao] = KakaoNativeOAuthProvider(sdk: LiveKakaoOAuthSDK())
        }
        if configuration.isNaverConfigured {
            providers[.naver] = NaverNativeOAuthProvider(sdk: LiveNaverOAuthSDK())
        }

        self.providers = providers
    }

    init(providers: [any NativeOAuthProvider]) {
        self.providers = Dictionary(
            uniqueKeysWithValues: providers.map { ($0.provider, $0) }
        )
    }

    func isAvailable(for provider: OAuthProvider) -> Bool {
        providers[provider]?.isAvailable == true
    }

    func authenticate(provider: OAuthProvider) async throws -> NativeOAuthCredential {
        guard let nativeProvider = providers[provider], nativeProvider.isAvailable else {
            throw MobileOAuthError.provider("provider_failed")
        }
        let credential = try await nativeProvider.authenticate()
        guard credential.provider == provider else {
            throw MobileOAuthError.provider("provider_failed")
        }
        return credential
    }

    func handle(url: URL) -> Bool {
        providers.values.contains { $0.handle(url: url) }
    }
}

@MainActor
protocol NativeOAuthProvider: AnyObject {
    var provider: OAuthProvider { get }
    var isAvailable: Bool { get }
    func authenticate() async throws -> NativeOAuthCredential
    func handle(url: URL) -> Bool
}

@MainActor
private final class KakaoNativeOAuthProvider: NativeOAuthProvider {
    let provider: OAuthProvider = .kakao
    private let sdk: KakaoOAuthSDK

    init(sdk: KakaoOAuthSDK) {
        self.sdk = sdk
    }

    var isAvailable: Bool {
        sdk.isLoginAvailable
    }

    func authenticate() async throws -> NativeOAuthCredential {
        guard isAvailable else {
            throw MobileOAuthError.provider("provider_failed")
        }

        return try await withCheckedThrowingContinuation { continuation in
            sdk.loginWithKakaoTalk { accessToken, error in
                if let error {
                    continuation.resume(throwing: NativeOAuthErrorMapping.kakao(error))
                    return
                }

                if let accessToken, !accessToken.isEmpty {
                    continuation.resume(returning: .kakao(accessToken: accessToken))
                    return
                }

                continuation.resume(throwing: NativeOAuthErrorMapping.providerFailure)
            }
        }
    }

    func handle(url: URL) -> Bool {
        sdk.handle(url: url)
    }

}

@MainActor
private final class NaverNativeOAuthProvider: NativeOAuthProvider {
    let provider: OAuthProvider = .naver
    private let sdk: NaverOAuthSDK

    init(sdk: NaverOAuthSDK) {
        self.sdk = sdk
    }

    var isAvailable: Bool {
        sdk.isLoginAvailable
    }

    func authenticate() async throws -> NativeOAuthCredential {
        guard isAvailable else {
            throw MobileOAuthError.provider("provider_failed")
        }

        return try await withCheckedThrowingContinuation { continuation in
            sdk.requestLogin { _, refreshToken, error in
                if let error {
                    // Naver's app callback can report cancellation as an
                    // authError instead of clientError.canceledByUser.
                    continuation.resume(throwing: NativeOAuthErrorMapping.naver(error))
                    return
                }

                if let refreshToken, !refreshToken.isEmpty {
                    continuation.resume(returning: .naver(refreshToken: refreshToken))
                    return
                }

                continuation.resume(throwing: NativeOAuthErrorMapping.providerFailure)
            }
        }
    }

    func handle(url: URL) -> Bool {
        sdk.handle(url: url)
    }

}

/// Converts SDK failures into the app's auth error contract without exposing
/// provider error descriptions (which may contain token or request details).
///
/// Naver's current SDK maps an app callback's numeric error codes 6...10 to
/// `serverError(.authError(...))`. Older Naver app protocol responses used
/// code `2` for user cancellation; when the current SDK receives that value it
/// reports `undefined` and carries the original detail. Both representations
/// are handled here while unknown auth errors remain visible as failures.
nonisolated enum NativeOAuthErrorMapping {
    static let providerFailure = MobileOAuthError.provider("auth.oauth.mobile.provider.failed")
    private static let providerUnavailable = MobileOAuthError.provider(
        "auth.oauth.mobile.provider.unavailable"
    )

    static func kakao(_ error: Error) -> MobileOAuthError {
        guard let sdkError = error as? SdkError else {
            if let sessionError = error as? ASWebAuthenticationSessionError,
               sessionError.code == .canceledLogin {
                return .cancelled
            }
            return providerFailure
        }

        switch sdkError {
        case .ClientFailed(reason: .Cancelled, _),
             .AuthFailed(reason: .AccessDenied, _):
            return .cancelled
        case .ClientFailed(reason: .NotSupported, _):
            return providerUnavailable
        default:
            return providerFailure
        }
    }

    static func naver(_ error: Error) -> MobileOAuthError {
        guard let nidError = error as? NidError else {
            return providerFailure
        }

        switch nidError {
        case .clientError(.canceledByUser):
            return .cancelled
        case .clientError(.naverAppNotInstalled):
            return providerUnavailable
        case .serverError(.authError(let errorCode, let errorDescription)):
            return naverAuthError(errorCode: errorCode, errorDescription: errorDescription)
        default:
            return providerFailure
        }
    }

    static func naverAuthError(
        errorCode: String,
        errorDescription: String?
    ) -> MobileOAuthError {
        let code = errorCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch code {
        case "2", "access_denied", "cancelled", "canceled", "user_cancelled", "user_canceled":
            return .cancelled
        case "undefined":
            guard let errorDescription,
                  Self.containsCancellationMarker(errorDescription)
            else {
                return providerFailure
            }
            return .cancelled
        default:
            return providerFailure
        }
    }

    private static func containsCancellationMarker(_ description: String) -> Bool {
        let normalized = description
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let knownMarkers = [
            "user canceled the request",
            "user cancelled the request",
            "user canceled login",
            "user cancelled login",
            "사용자가 취소했습니다",
            "사용자가 취소함",
        ]
        return knownMarkers.contains { normalized.contains($0) }
    }
}

@MainActor
private final class LiveKakaoOAuthSDK: KakaoOAuthSDK {
    var isLoginAvailable: Bool {
        UserApi.isKakaoTalkLoginAvailable()
    }

    func loginWithKakaoTalk(completion: @escaping (String?, Error?) -> Void) {
        UserApi.shared.loginWithKakaoTalk(launchMethod: .UniversalLink) { token, error in
            completion(token?.accessToken, error)
        }
    }

    func handle(url: URL) -> Bool {
        guard AuthApi.isKakaoTalkLoginUrl(url) else { return false }
        return AuthController.handleOpenUrl(url: url)
    }
}

@MainActor
private final class LiveNaverOAuthSDK: NaverOAuthSDK {
    var isLoginAvailable: Bool {
        guard let url = URL(string: "naversearchthirdlogin://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    func requestLogin(completion: @escaping (String?, String?, Error?) -> Void) {
        // The SDK refreshes a previously stored Naver token for the default
        // login behavior. Clearing only that SDK-local token ensures every
        // explicit Dutypark login/link opens Naver for the account the user
        // just chose; this does not disconnect the Naver service.
        NidOAuth.shared.logout()
        NidOAuth.shared.setLoginBehavior(.app)
        NidOAuth.shared.requestLogin(from: nil) { result in
            switch result {
            case .success(let loginResult):
                completion(
                    loginResult.accessToken.tokenString,
                    loginResult.refreshToken.tokenString,
                    nil
                )
            case .failure(let error):
                completion(nil, nil, error)
            }
        }
    }

    func handle(url: URL) -> Bool {
        NidOAuth.shared.handleURL(url)
    }
}

/// Reads native provider credentials from build settings exposed through the
/// app's Info.plist. Unexpanded build-setting placeholders are treated as
/// missing so a checkout without local credentials keeps the web flow.
nonisolated struct OAuthNativeConfiguration: Equatable, Sendable {
    let kakaoNativeAppKey: String?
    let naverClientID: String?
    let naverClientSecret: String?
    let naverAppName: String

    /// A provider-specific scheme prevents Naver's app callback from being
    /// mistaken for Dutypark's existing browser OAuth callback.
    static let naverCallbackScheme = "io.github.shanepark.dutypark.naver"
    static let naverCallbackHost = "thirdPartyLoginResult"

    init(
        kakaoNativeAppKey: String?,
        naverClientID: String?,
        naverClientSecret: String?,
        naverAppName: String?
    ) {
        self.kakaoNativeAppKey = Self.normalized(kakaoNativeAppKey)
        self.naverClientID = Self.normalized(naverClientID)
        self.naverClientSecret = Self.normalized(naverClientSecret)
        self.naverAppName = Self.normalized(naverAppName) ?? "Dutypark"
    }

    static func fromMainBundle() -> OAuthNativeConfiguration {
        OAuthNativeConfiguration(
            kakaoNativeAppKey: value(for: "KakaoNativeAppKey", in: .main),
            naverClientID: value(for: "NaverClientID", in: .main),
            naverClientSecret: value(for: "NaverClientSecret", in: .main),
            naverAppName: value(for: "NaverAppName", in: .main)
        )
    }

    var isKakaoConfigured: Bool {
        kakaoNativeAppKey != nil
    }

    var isNaverConfigured: Bool {
        naverClientID != nil && naverClientSecret != nil
    }

    var kakaoCallbackScheme: String? {
        kakaoNativeAppKey.map { "kakao\($0)" }
    }

    var naverCallbackScheme: String {
        Self.naverCallbackScheme
    }

    private static func value(for key: String, in bundle: Bundle) -> String? {
        normalized(bundle.object(forInfoDictionaryKey: key) as? String)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("$("),
              !trimmed.hasPrefix("YOUR_"),
              !trimmed.hasPrefix("<")
        else {
            return nil
        }
        return trimmed
    }
}

/// One-time SDK initialization and app-wide callback routing.
@MainActor
enum OAuthNativeRuntime {
    private static var didConfigure = false
    private static var configuration = OAuthNativeConfiguration.fromMainBundle()

    static func configure(
        configuration: OAuthNativeConfiguration = .fromMainBundle()
    ) {
        guard !didConfigure else { return }
        didConfigure = true
        self.configuration = configuration

        if let appKey = configuration.kakaoNativeAppKey,
           let callbackScheme = configuration.kakaoCallbackScheme {
            KakaoSDK.initSDK(
                appKey: appKey,
                customScheme: callbackScheme,
                loggingEnable: false
            )
        }

        if let clientID = configuration.naverClientID,
           let clientSecret = configuration.naverClientSecret {
            NidOAuth.shared.initialize(
                appName: configuration.naverAppName,
                clientId: clientID,
                clientSecret: clientSecret,
                urlScheme: configuration.naverCallbackScheme
            )
            // Native eligibility is checked before this SDK is called, so an
            // unavailable provider must continue through Dutypark's web flow.
            NidOAuth.shared.setLoginBehavior(.app)
        }
    }

    static func handle(url: URL) -> Bool {
        var handled = false

        if configuration.isKakaoConfigured,
           AuthApi.isKakaoTalkLoginUrl(url) {
            handled = AuthController.handleOpenUrl(url: url) || handled
        }

        if configuration.isNaverConfigured,
           url.scheme?.caseInsensitiveCompare(configuration.naverCallbackScheme) == .orderedSame,
           url.host == OAuthNativeConfiguration.naverCallbackHost {
            handled = NidOAuth.shared.handleURL(url) || handled
        }

        return handled
    }
}
