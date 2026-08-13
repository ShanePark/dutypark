import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

nonisolated enum AppleSignInPurpose: String, Codable, Sendable {
    case login = "LOGIN"
    case link = "LINK"
    case deleteAccount = "DELETE_ACCOUNT"
}

nonisolated enum AppleSignInError: Error, Equatable, Sendable {
    case configurationUnavailable
    case invalidCredential
    case providerUnavailable
    case stateMismatch
    case cancelled
}

extension AppleSignInError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .configurationUnavailable:
            APIErrorLocalization.message(code: "auth.apple.configurationUnavailable")
        case .invalidCredential:
            APIErrorLocalization.message(code: "auth.apple.credential.invalid")
        case .providerUnavailable:
            APIErrorLocalization.message(code: "auth.apple.provider.unavailable")
        case .stateMismatch:
            APIErrorLocalization.message(code: "auth.apple.credential.invalid")
        case .cancelled:
            nil
        }
    }
}

nonisolated struct AppleSignInAttempt: Equatable, Sendable {
    let rawNonce: String
    let hashedNonce: String
    let state: String

    static func make() throws -> AppleSignInAttempt {
        try make(
            nonceBytes: secureRandomBytes(count: 32),
            stateBytes: secureRandomBytes(count: 32)
        )
    }

    static func make(nonceBytes: Data, stateBytes: Data) throws -> AppleSignInAttempt {
        guard nonceBytes.count == 32, stateBytes.count == 32 else {
            throw AppleSignInError.configurationUnavailable
        }
        let rawNonce = base64URL(nonceBytes)
        return AppleSignInAttempt(
            rawNonce: rawNonce,
            hashedNonce: SHA256.hash(data: Data(rawNonce.utf8))
                .map { String(format: "%02x", $0) }
                .joined(),
            state: base64URL(stateBytes)
        )
    }

    private static func secureRandomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw AppleSignInError.configurationUnavailable
        }
        return Data(bytes)
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

nonisolated struct AppleAuthorizationRequest: Equatable, Sendable {
    let nonce: String
    let state: String
}

nonisolated struct AppleAuthorizationCredential: Equatable, Sendable {
    let identityToken: String
    let authorizationCode: String
    let state: String

    static func decode(
        identityToken: Data?,
        authorizationCode: Data?,
        state: String?
    ) throws -> AppleAuthorizationCredential {
        guard let identityToken,
              let authorizationCode,
              let state,
              let token = String(data: identityToken, encoding: .utf8),
              let code = String(data: authorizationCode, encoding: .utf8),
              !token.isEmpty,
              !code.isEmpty,
              !state.isEmpty
        else {
            throw AppleSignInError.invalidCredential
        }
        return AppleAuthorizationCredential(
            identityToken: token,
            authorizationCode: code,
            state: state
        )
    }
}

@MainActor
protocol AppleAuthorizationPerforming: AnyObject {
    func authorize(request: AppleAuthorizationRequest) async throws -> AppleAuthorizationCredential
}

@MainActor
final class AppleAuthorizationController: NSObject, AppleAuthorizationPerforming,
    ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding
{
    private var continuation: CheckedContinuation<AppleAuthorizationCredential, Error>?
    private var controller: ASAuthorizationController?
    private var presentationWindow: ASPresentationAnchor?

    func authorize(request: AppleAuthorizationRequest) async throws -> AppleAuthorizationCredential {
        guard continuation == nil else { throw AppleSignInError.providerUnavailable }
        guard let window = Self.presentationAnchor() else {
            throw AppleSignInError.providerUnavailable
        }

        let appleRequest = ASAuthorizationAppleIDProvider().createRequest()
        appleRequest.requestedScopes = []
        appleRequest.nonce = request.nonce
        appleRequest.state = request.state

        presentationWindow = window
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [appleRequest])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationWindow ?? ASPresentationAnchor()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        do {
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AppleSignInError.invalidCredential
            }
            finish(with: .success(try AppleAuthorizationCredential.decode(
                identityToken: credential.identityToken,
                authorizationCode: credential.authorizationCode,
                state: credential.state
            )))
        } catch {
            finish(with: .failure(error))
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if (error as? ASAuthorizationError)?.code == .canceled {
            finish(with: .failure(AppleSignInError.cancelled))
        } else {
            finish(with: .failure(AppleSignInError.providerUnavailable))
        }
    }

    private func finish(with result: Result<AppleAuthorizationCredential, Error>) {
        let continuation = continuation
        self.continuation = nil
        controller = nil
        presentationWindow = nil
        continuation?.resume(with: result)
    }

    private static func presentationAnchor() -> ASPresentationAnchor? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: { !$0.isHidden })
    }
}

nonisolated private struct AppleExchangeRequest: Encodable, Equatable, Sendable {
    let identityToken: String
    let authorizationCode: String
    let nonce: String
    let purpose: AppleSignInPurpose
}

nonisolated private struct AppleExchangeResponse: Decodable, Equatable, Sendable {
    let signupRequired: Bool
    let signupUuid: String?
    let expiresIn: Int?
    let reauthProof: String?
}

@MainActor
final class AppleSignInClient {
    // Apple user identifiers and credentials are intentionally not persisted on-device.
    // The backend owns the durable sub mapping, so an Apple credential-state change must
    // not invalidate a still-valid Dutypark session that may use another authentication method.
    private let client: APIClient
    private let authorizer: AppleAuthorizationPerforming

    init(
        client: APIClient = .shared,
        authorizer: AppleAuthorizationPerforming = AppleAuthorizationController()
    ) {
        self.client = client
        self.authorizer = authorizer
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) throws -> AppleSignInAttempt {
        let attempt = try AppleSignInAttempt.make()
        request.requestedScopes = []
        request.nonce = attempt.hashedNonce
        request.state = attempt.state
        return attempt
    }

    func completeLogin(
        result: Result<ASAuthorization, Error>,
        attempt: AppleSignInAttempt
    ) async throws -> MobileOAuthLoginOutcome {
        let authorization: ASAuthorization
        switch result {
        case .success(let value):
            authorization = value
        case .failure(let error) where (error as? ASAuthorizationError)?.code == .canceled:
            throw AppleSignInError.cancelled
        case .failure:
            throw AppleSignInError.providerUnavailable
        }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppleSignInError.invalidCredential
        }
        return try await exchangeLogin(
            credential: AppleAuthorizationCredential.decode(
                identityToken: credential.identityToken,
                authorizationCode: credential.authorizationCode,
                state: credential.state
            ),
            attempt: attempt
        )
    }

    func login() async throws -> MobileOAuthLoginOutcome {
        let exchange = try await authorizeAndExchange(purpose: .login)
        return try loginOutcome(from: exchange)
    }

    func link() async throws {
        let response = try await authorizeAndExchange(purpose: .link)
        guard response.signupRequired == false else {
            throw AppleSignInError.invalidCredential
        }
    }

    func reauthenticateForAccountDeletion() async throws -> MobileOAuthReauthProof {
        let response = try await authorizeAndExchange(purpose: .deleteAccount)
        guard response.signupRequired == false,
              let proof = response.reauthProof,
              !proof.isEmpty,
              let expiresIn = response.expiresIn,
              expiresIn > 0
        else {
            throw AppleSignInError.invalidCredential
        }
        return MobileOAuthReauthProof(value: proof, expiresIn: expiresIn)
    }

    func exchangeLogin(
        credential: AppleAuthorizationCredential,
        attempt: AppleSignInAttempt
    ) async throws -> MobileOAuthLoginOutcome {
        try await loginOutcome(from: exchange(
            credential: credential,
            attempt: attempt,
            purpose: .login
        ))
    }

    private func authorizeAndExchange(purpose: AppleSignInPurpose) async throws -> AppleExchangeResponse {
        let attempt = try AppleSignInAttempt.make()
        let credential = try await authorizer.authorize(request: AppleAuthorizationRequest(
            nonce: attempt.hashedNonce,
            state: attempt.state
        ))
        return try await exchange(credential: credential, attempt: attempt, purpose: purpose)
    }

    private func exchange(
        credential: AppleAuthorizationCredential,
        attempt: AppleSignInAttempt,
        purpose: AppleSignInPurpose
    ) async throws -> AppleExchangeResponse {
        guard credential.state == attempt.state else {
            throw AppleSignInError.stateMismatch
        }
        return try await client.request(
            "auth/mobile/oauth/apple/exchange",
            method: .post,
            body: AppleExchangeRequest(
                identityToken: credential.identityToken,
                authorizationCode: credential.authorizationCode,
                nonce: attempt.rawNonce,
                purpose: purpose
            ),
            retryingAfterUnauthorized: purpose != .login
        )
    }

    private func loginOutcome(from response: AppleExchangeResponse) throws -> MobileOAuthLoginOutcome {
        if response.signupRequired, let uuid = response.signupUuid, !uuid.isEmpty {
            return .signup(uuid: uuid)
        }
        guard response.signupRequired == false else {
            throw AppleSignInError.invalidCredential
        }
        return .authenticated
    }
}
