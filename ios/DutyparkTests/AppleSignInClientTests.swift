import AuthenticationServices
import Foundation
import XCTest
@testable import Dutypark

final class AppleSignInClientTests: XCTestCase {
    private let baseURL = URL(string: "https://dutypark.test/api/")!

    override func tearDown() {
        AppleURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testNonceAndStateUseBase64URLAndNonceUsesLowercaseSHA256Hex() throws {
        let attempt = try AppleSignInAttempt.make(
            nonceBytes: Data(repeating: 0, count: 32),
            stateBytes: Data(repeating: 1, count: 32)
        )

        XCTAssertEqual(attempt.rawNonce, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
        XCTAssertEqual(
            attempt.hashedNonce,
            "0f007385b6f9d4b7eeb2748605afe1a984a0a3bfa3f014d09e2a784ce9e5cd1a"
        )
        XCTAssertEqual(attempt.hashedNonce, attempt.hashedNonce.lowercased())
        XCTAssertEqual(attempt.hashedNonce.count, 64)
        XCTAssertEqual(attempt.state, "AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE")
        XCTAssertFalse(attempt.rawNonce.contains("="))
        XCTAssertFalse(attempt.state.contains("="))
    }

    func testAttemptRejectsUnexpectedRandomByteCounts() {
        XCTAssertThrowsError(try AppleSignInAttempt.make(
            nonceBytes: Data(repeating: 0, count: 31),
            stateBytes: Data(repeating: 1, count: 32)
        )) { error in
            XCTAssertEqual(error as? AppleSignInError, .configurationUnavailable)
        }
    }

    func testCredentialConversionRequiresUTF8TokenCodeAndState() throws {
        XCTAssertEqual(
            try AppleAuthorizationCredential.decode(
                identityToken: Data("identity-token".utf8),
                authorizationCode: Data("authorization-code".utf8),
                state: "state"
            ),
            AppleAuthorizationCredential(
                identityToken: "identity-token",
                authorizationCode: "authorization-code",
                state: "state"
            )
        )
        for invalid in [
            (nil, Data("code".utf8), "state"),
            (Data("token".utf8), nil, "state"),
            (Data("token".utf8), Data("code".utf8), nil),
            (Data([0xFF]), Data("code".utf8), "state"),
        ] as [(Data?, Data?, String?)] {
            XCTAssertThrowsError(try AppleAuthorizationCredential.decode(
                identityToken: invalid.0,
                authorizationCode: invalid.1,
                state: invalid.2
            ))
        }
    }

    @MainActor
    func testConfiguresAppleRequestWithNoScopesAndFreshNonceAndState() throws {
        let client = AppleSignInClient(client: makeClient(), authorizer: AppleAuthorizerStub())
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]

        let attempt = try client.configure(request)

        XCTAssertEqual(request.requestedScopes, [])
        XCTAssertEqual(request.nonce, attempt.hashedNonce)
        XCTAssertEqual(request.state, attempt.state)
        XCTAssertNotEqual(
            try client.configure(ASAuthorizationAppleIDProvider().createRequest()).rawNonce,
            attempt.rawNonce
        )
    }

    @MainActor
    func testLoginExchangeSendsRawNonceAndReturnsAuthenticatedOutcome() async throws {
        let recorder = AppleRequestRecorder()
        recorder.loginResponse = #"{"signupRequired":false,"signupUuid":null,"expiresIn":3600,"reauthProof":null}"#
        AppleURLProtocolStub.handler = { try recorder.response(for: $0) }
        let client = AppleSignInClient(client: makeClient(), authorizer: AppleAuthorizerStub())
        let attempt = try AppleSignInAttempt.make(
            nonceBytes: Data(repeating: 0, count: 32),
            stateBytes: Data(repeating: 1, count: 32)
        )

        let outcome = try await client.exchangeLogin(
            credential: AppleAuthorizationCredential(
                identityToken: "identity-token",
                authorizationCode: "authorization-code",
                state: attempt.state
            ),
            attempt: attempt
        )

        XCTAssertEqual(outcome, .authenticated)
        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.url?.path, "/api/auth/mobile/oauth/apple/exchange")
        let body = try XCTUnwrap(Self.jsonBody(request))
        XCTAssertEqual(body["identityToken"] as? String, "identity-token")
        XCTAssertEqual(body["authorizationCode"] as? String, "authorization-code")
        XCTAssertEqual(body["nonce"] as? String, attempt.rawNonce)
        XCTAssertEqual(body["purpose"] as? String, "LOGIN")
        XCTAssertFalse(String(data: try XCTUnwrap(Self.requestBody(request)), encoding: .utf8)?.contains(attempt.hashedNonce) == true)
    }

    @MainActor
    func testLoginExchangeReturnsSignupOutcome() async throws {
        let recorder = AppleRequestRecorder()
        recorder.loginResponse = #"{"signupRequired":true,"signupUuid":"signup-uuid","expiresIn":300,"reauthProof":null}"#
        AppleURLProtocolStub.handler = { try recorder.response(for: $0) }
        let client = AppleSignInClient(client: makeClient(), authorizer: AppleAuthorizerStub())
        let attempt = try AppleSignInAttempt.make(
            nonceBytes: Data(repeating: 2, count: 32),
            stateBytes: Data(repeating: 3, count: 32)
        )

        let outcome = try await client.exchangeLogin(
            credential: AppleAuthorizationCredential(
                identityToken: "token",
                authorizationCode: "code",
                state: attempt.state
            ),
            attempt: attempt
        )

        XCTAssertEqual(outcome, .signup(uuid: "signup-uuid"))
    }

    @MainActor
    func testStateMismatchStopsBeforeSendingCredential() async throws {
        let recorder = AppleRequestRecorder()
        AppleURLProtocolStub.handler = { try recorder.response(for: $0) }
        let client = AppleSignInClient(client: makeClient(), authorizer: AppleAuthorizerStub())
        let attempt = try AppleSignInAttempt.make(
            nonceBytes: Data(repeating: 4, count: 32),
            stateBytes: Data(repeating: 5, count: 32)
        )

        do {
            _ = try await client.exchangeLogin(
                credential: AppleAuthorizationCredential(
                    identityToken: "token",
                    authorizationCode: "code",
                    state: "unexpected-state"
                ),
                attempt: attempt
            )
            XCTFail("Expected state mismatch")
        } catch {
            XCTAssertEqual(error as? AppleSignInError, .stateMismatch)
        }
        XCTAssertTrue(recorder.requests.isEmpty)
    }

    @MainActor
    func testLinkRetriesExchangeAfterRefreshWithoutRepeatingAppleAuthorization() async throws {
        let recorder = AppleRequestRecorder(challengeFirstLink: true)
        AppleURLProtocolStub.handler = { try recorder.response(for: $0) }
        let authorizer = AppleAuthorizerStub()
        let client = AppleSignInClient(client: makeClient(), authorizer: authorizer)

        try await client.link()

        XCTAssertEqual(authorizer.requests.count, 1)
        XCTAssertEqual(recorder.requests.compactMap(\.url?.path), [
            "/api/auth/mobile/oauth/apple/exchange",
            "/api/auth/refresh",
            "/api/auth/mobile/oauth/apple/exchange",
        ])
        XCTAssertEqual(
            try XCTUnwrap(Self.jsonBody(recorder.requests[0]))["purpose"] as? String,
            "LINK"
        )
    }

    @MainActor
    func testAccountDeletionUsesDeletePurposeAndReturnsProof() async throws {
        let recorder = AppleRequestRecorder()
        AppleURLProtocolStub.handler = { try recorder.response(for: $0) }
        let authorizer = AppleAuthorizerStub()
        let client = AppleSignInClient(client: makeClient(), authorizer: authorizer)

        let proof = try await client.reauthenticateForAccountDeletion()

        XCTAssertEqual(proof, MobileOAuthReauthProof(value: "delete-proof", expiresIn: 300))
        XCTAssertEqual(authorizer.requests.count, 1)
        XCTAssertEqual(
            try XCTUnwrap(Self.jsonBody(try XCTUnwrap(recorder.requests.first)))["purpose"] as? String,
            "DELETE_ACCOUNT"
        )
    }

    @MainActor
    func testCancellationDoesNotSendExchangeRequest() async throws {
        let recorder = AppleRequestRecorder()
        AppleURLProtocolStub.handler = { try recorder.response(for: $0) }
        let authorizer = AppleAuthorizerStub(error: AppleSignInError.cancelled)
        let client = AppleSignInClient(client: makeClient(), authorizer: authorizer)

        do {
            try await client.link()
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertEqual(error as? AppleSignInError, .cancelled)
        }
        XCTAssertTrue(recorder.requests.isEmpty)
    }

    func testAccountDeletionMapsAppleFailuresToDistinctLocalizedKeys() {
        XCTAssertEqual(
            AccountDeletionViewModel.errorKey(for: AppleSignInError.configurationUnavailable),
            "settings.accountDeletion.error.appleConfigurationUnavailable"
        )
        XCTAssertEqual(
            AccountDeletionViewModel.errorKey(for: AppleSignInError.invalidCredential),
            "settings.accountDeletion.error.appleCredentialInvalid"
        )
        XCTAssertEqual(
            AccountDeletionViewModel.errorKey(for: AppleSignInError.providerUnavailable),
            "settings.accountDeletion.error.appleProviderUnavailable"
        )
        XCTAssertEqual(
            AccountDeletionViewModel.errorKey(
                for: APIError.server(status: 403, code: "auth.apple.accountMismatch")
            ),
            "settings.accountDeletion.error.appleAccountMismatch"
        )
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppleURLProtocolStub.self]
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        return APIClient(baseURL: baseURL, session: URLSession(configuration: configuration))
    }

    fileprivate static func jsonBody(_ request: URLRequest) -> [String: Any]? {
        guard let body = requestBody(request) else { return nil }
        return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }

    fileprivate static func requestBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

@MainActor
private final class AppleAuthorizerStub: AppleAuthorizationPerforming {
    private(set) var requests: [AppleAuthorizationRequest] = []
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func authorize(request: AppleAuthorizationRequest) async throws -> AppleAuthorizationCredential {
        requests.append(request)
        if let error { throw error }
        return AppleAuthorizationCredential(
            identityToken: "identity-token",
            authorizationCode: "authorization-code",
            state: request.state
        )
    }
}

private final class AppleRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequests: [URLRequest] = []
    private let challengeFirstLink: Bool
    private var didChallengeLink = false
    var loginResponse = #"{"signupRequired":false,"signupUuid":null,"expiresIn":3600,"reauthProof":null}"#

    init(challengeFirstLink: Bool = false) {
        self.challengeFirstLink = challengeFirstLink
    }

    var requests: [URLRequest] { lock.withLock { storedRequests } }

    func response(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let result: (Int, String) = lock.withLock {
            storedRequests.append(request)
            let body = AppleSignInClientTests.jsonBody(request)
            let purpose = body?["purpose"] as? String
            if challengeFirstLink,
               request.url?.path == "/api/auth/mobile/oauth/apple/exchange",
               purpose == "LINK",
               !didChallengeLink {
                didChallengeLink = true
                return (401, #"{"code":"auth.required"}"#)
            }
            switch request.url?.path {
            case "/api/auth/mobile/oauth/apple/exchange" where purpose == "DELETE_ACCOUNT":
                return (200, #"{"signupRequired":false,"signupUuid":null,"expiresIn":300,"reauthProof":"delete-proof"}"#)
            case "/api/auth/mobile/oauth/apple/exchange" where purpose == "LINK":
                return (200, #"{"signupRequired":false,"signupUuid":null,"expiresIn":null,"reauthProof":null}"#)
            case "/api/auth/mobile/oauth/apple/exchange":
                return (200, loginResponse)
            case "/api/auth/refresh":
                return (200, "{}")
            default:
                return (404, #"{"code":"not_found"}"#)
            }
        }
        return (
            HTTPURLResponse(
                url: request.url!,
                statusCode: result.0,
                httpVersion: nil,
                headerFields: nil
            )!,
            Data(result.1.utf8)
        )
    }
}

private final class AppleURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let result = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: result.0, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: result.1)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
