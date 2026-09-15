import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

nonisolated enum OAuthProvider: String, Codable, CaseIterable, Sendable {
    case kakao = "KAKAO"
    case naver = "NAVER"
    case apple = "APPLE"
}

nonisolated enum MobileOAuthError: Error, Equatable, Sendable {
    case invalidAuthorizationURL
    case invalidCallback
    case provider(String)
    case cancelled
}

extension MobileOAuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidAuthorizationURL:
            APIErrorLocalization.message(code: "auth.oauth.mobile.authorizationUrl.invalid")
        case .invalidCallback:
            APIErrorLocalization.message(code: "auth.oauth.mobile.callback.invalid")
        case .provider(let code):
            APIErrorLocalization.message(code: code)
        case .cancelled:
            nil
        }
    }
}

nonisolated enum MobileOAuthLoginOutcome: Equatable, Sendable {
    case authenticated
    case signup(uuid: String)
}

nonisolated struct MobileOAuthReauthProof: Equatable, Sendable {
    let value: String
    let expiresIn: Int
}

nonisolated struct PKCEPair: Equatable, Sendable {
    let verifier: String
    let challenge: String

    static func make() -> PKCEPair {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return make(randomBytes: Data(bytes))
    }

    static func make(randomBytes: Data) -> PKCEPair {
        let verifier = base64URL(randomBytes)
        return PKCEPair(verifier: verifier, challenge: challenge(for: verifier))
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

nonisolated struct MobileOAuthCallback: Equatable, Sendable {
    let code: String?
    let error: String?
    let linked: Bool

    init(url: URL) throws {
        guard url.scheme == "dutypark",
              url.host == "oauth",
              url.path == "/callback",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            throw MobileOAuthError.invalidCallback
        }

        let values = (components.queryItems ?? []).reduce(into: [String: String]()) {
            $0[$1.name] = $1.value ?? ""
        }
        code = values["code"]
        error = values["error"]
        linked = values["linked"] == "success"

        guard code != nil || error != nil || linked else {
            throw MobileOAuthError.invalidCallback
        }
    }
}

@MainActor
protocol OAuthWebAuthenticating: AnyObject {
    func authenticate(at url: URL) async throws -> URL
}

@MainActor
final class OAuthWebAuthenticationSession: NSObject, OAuthWebAuthenticating,
    ASWebAuthenticationPresentationContextProviding
{
    private var session: ASWebAuthenticationSession?

    func authenticate(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "dutypark"
            ) { [weak self] callbackURL, error in
                self?.session = nil
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                    continuation.resume(throwing: MobileOAuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? MobileOAuthError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            guard session.start() else {
                self.session = nil
                continuation.resume(throwing: MobileOAuthError.invalidAuthorizationURL)
                return
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

nonisolated private struct OAuthAuthorizeRequest: Encodable, Sendable {
    let provider: OAuthProvider
    let purpose: String
    let callbackUri: String
    let codeChallenge: String
}

nonisolated private struct OAuthAuthorizeResponse: Decodable, Sendable {
    let authorizationUrl: String
}

nonisolated private struct OAuthExchangeRequest: Encodable, Sendable {
    let code: String
    let codeVerifier: String
    let callbackUri: String
}

nonisolated private struct OAuthExchangeResponse: Decodable, Sendable {
    let signupRequired: Bool
    let signupUuid: String?
    let expiresIn: Int?
    let reauthProof: String?
}

nonisolated private struct NativeOAuthCapabilitiesResponse: Decodable, Sendable {
    let providers: [OAuthProvider]
}

nonisolated private struct NativeOAuthExchangeRequest: Encodable, Sendable {
    let provider: OAuthProvider
    let purpose: String
    let accessToken: String?
    let refreshToken: String?

    init(provider: OAuthProvider, purpose: String, credential: NativeOAuthCredential) {
        self.provider = provider
        self.purpose = purpose
        switch credential {
        case .kakao(let accessToken):
            self.accessToken = accessToken
            self.refreshToken = nil
        case .naver(let refreshToken):
            self.accessToken = nil
            self.refreshToken = refreshToken
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(provider, forKey: .provider)
        try container.encode(purpose, forKey: .purpose)
        // The backend contract requires provider-specific credentials and
        // rejects the unused field, so omit nil values instead of encoding
        // JSON nulls.
        try container.encodeIfPresent(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
    }

    private enum CodingKeys: String, CodingKey {
        case provider
        case purpose
        case accessToken
        case refreshToken
    }
}

nonisolated struct SsoSignupRequest: Encodable, Sendable {
    let uuid: String
    let username: String
    let termAgree: Bool
    let privacyAgree: Bool
    let termsVersion: String
    let privacyVersion: String
}

nonisolated private struct OAuthTokenResponse: Decodable, Sendable {
    let expiresIn: Int
}

@MainActor
final class MobileOAuthClient {
    static let callbackScheme = "dutypark"
    static let callbackURI = "\(callbackScheme)://oauth/callback"

    private let client: APIClient
    private let webAuthenticator: OAuthWebAuthenticating
    private let nativeOAuth: NativeOAuthAuthenticating

    init(
        client: APIClient = .shared,
        webAuthenticator: OAuthWebAuthenticating = OAuthWebAuthenticationSession(),
        nativeOAuth: NativeOAuthAuthenticating = NativeOAuthClient()
    ) {
        self.client = client
        self.webAuthenticator = webAuthenticator
        self.nativeOAuth = nativeOAuth
    }

    func login(provider: OAuthProvider) async throws -> MobileOAuthLoginOutcome {
        guard provider != .apple else { throw MobileOAuthError.invalidAuthorizationURL }

        if try await shouldUseNative(provider: provider) {
            let response = try await exchangeNative(
                provider: provider,
                purpose: "LOGIN",
                credential: try await nativeOAuth.authenticate(provider: provider)
            )
            if response.signupRequired, let uuid = response.signupUuid {
                return .signup(uuid: uuid)
            }
            guard !response.signupRequired else {
                throw MobileOAuthError.invalidCallback
            }
            return .authenticated
        }

        let pkce = PKCEPair.make()
        let callback = try await authorize(provider: provider, purpose: "LOGIN", pkce: pkce)
        if callback.error == "oauth_cancelled" {
            throw MobileOAuthError.cancelled
        }
        if let error = callback.error {
            throw MobileOAuthError.provider(error)
        }
        guard let code = callback.code else {
            throw MobileOAuthError.invalidCallback
        }

        let response: OAuthExchangeResponse = try await client.request(
            "auth/mobile/oauth/exchange",
            method: .post,
            body: OAuthExchangeRequest(
                code: code,
                codeVerifier: pkce.verifier,
                callbackUri: Self.callbackURI
            ),
            retryingAfterUnauthorized: false
        )
        if response.signupRequired, let uuid = response.signupUuid {
            return .signup(uuid: uuid)
        }
        guard !response.signupRequired else {
            throw MobileOAuthError.invalidCallback
        }
        return .authenticated
    }

    /// Authenticated settings screens can use this to connect a social account.
    func link(provider: OAuthProvider) async throws {
        guard provider != .apple else { throw MobileOAuthError.invalidAuthorizationURL }

        if try await shouldUseNative(provider: provider) {
            let response = try await exchangeNative(
                provider: provider,
                purpose: "LINK",
                credential: try await nativeOAuth.authenticate(provider: provider)
            )
            guard !response.signupRequired else {
                throw MobileOAuthError.invalidCallback
            }
            return
        }

        let callback = try await authorize(provider: provider, purpose: "LINK", pkce: PKCEPair.make())
        if callback.error == "oauth_cancelled" {
            throw MobileOAuthError.cancelled
        }
        if let error = callback.error {
            throw MobileOAuthError.provider(error)
        }
        guard callback.linked else {
            throw MobileOAuthError.invalidCallback
        }
    }

    /// Reauthenticates the current member without creating a new login session.
    /// The short-lived proof is intentionally returned only to the in-memory deletion flow.
    func reauthenticateForAccountDeletion(provider: OAuthProvider) async throws -> MobileOAuthReauthProof {
        guard provider != .apple else { throw MobileOAuthError.invalidAuthorizationURL }
        let pkce = PKCEPair.make()
        let callback = try await authorize(provider: provider, purpose: "DELETE_ACCOUNT", pkce: pkce)
        if callback.error == "oauth_cancelled" {
            throw MobileOAuthError.cancelled
        }
        if let error = callback.error {
            throw MobileOAuthError.provider(error)
        }
        guard let code = callback.code else {
            throw MobileOAuthError.invalidCallback
        }

        let response: OAuthExchangeResponse = try await client.request(
            "auth/mobile/oauth/exchange",
            method: .post,
            body: OAuthExchangeRequest(
                code: code,
                codeVerifier: pkce.verifier,
                callbackUri: Self.callbackURI
            ),
            retryingAfterUnauthorized: false
        )
        guard response.signupRequired == false,
              let proof = response.reauthProof,
              !proof.isEmpty,
              let expiresIn = response.expiresIn,
              expiresIn > 0
        else {
            throw MobileOAuthError.invalidCallback
        }
        return MobileOAuthReauthProof(value: proof, expiresIn: expiresIn)
    }

    func currentPolicies() async throws -> CurrentPoliciesDTO {
        try await client.request("policies/current")
    }

    func signup(_ request: SsoSignupRequest) async throws {
        let _: OAuthTokenResponse = try await client.request(
            "auth/sso/signup/token",
            method: .post,
            body: request,
            retryingAfterUnauthorized: false
        )
    }

    private func authorize(
        provider: OAuthProvider,
        purpose: String,
        pkce: PKCEPair
    ) async throws -> MobileOAuthCallback {
        let response: OAuthAuthorizeResponse = try await client.request(
            "auth/mobile/oauth/authorize",
            method: .post,
            body: OAuthAuthorizeRequest(
                provider: provider,
                purpose: purpose,
                callbackUri: Self.callbackURI,
                codeChallenge: pkce.challenge
            ),
            retryingAfterUnauthorized: purpose == "LINK"
        )
        guard let url = URL(string: response.authorizationUrl) else {
            throw MobileOAuthError.invalidAuthorizationURL
        }
        return try MobileOAuthCallback(url: await webAuthenticator.authenticate(at: url))
    }

    private func shouldUseNative(provider: OAuthProvider) async throws -> Bool {
        guard nativeOAuth.isAvailable(for: provider) else { return false }

        do {
            let response: NativeOAuthCapabilitiesResponse = try await client.request(
                "auth/mobile/oauth/native/capabilities"
            )
            return response.providers.contains(provider)
        } catch APIError.server(status: 404, _),
                APIError.serverWithDetails(status: 404, _, _),
                APIError.decoding {
            // A server that predates the native exchange contract continues
            // through the existing authorization URL flow.
            return false
        }
    }

    private func exchangeNative(
        provider: OAuthProvider,
        purpose: String,
        credential: NativeOAuthCredential
    ) async throws -> OAuthExchangeResponse {
        guard credential.provider == provider else {
            throw MobileOAuthError.provider("provider_failed")
        }

        return try await client.request(
            "auth/mobile/oauth/native/exchange",
            method: .post,
            body: NativeOAuthExchangeRequest(
                provider: provider,
                purpose: purpose,
                credential: credential
            ),
            retryingAfterUnauthorized: purpose == "LINK"
        )
    }
}
