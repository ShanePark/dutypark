import Foundation
import KakaoSDKCommon
import NidThirdPartyLogin
import XCTest
@testable import Dutypark

final class MobileOAuthClientTests: XCTestCase {
    private let baseURL = URL(string: "https://dutypark.test/api/")!

    override func tearDown() {
        OAuthURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testPKCEUsesRFC7636SHA256Challenge() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

        XCTAssertEqual(
            PKCEPair.challenge(for: verifier),
            "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        )
        XCTAssertEqual(PKCEPair.make(randomBytes: Data(repeating: 0, count: 32)).verifier.count, 43)
    }

    func testParsesCodeErrorAndLinkedCallbacks() throws {
        let code = try MobileOAuthCallback(url: URL(string: "dutypark://oauth/callback?code=once")!)
        XCTAssertEqual(code.code, "once")
        XCTAssertNil(code.error)
        XCTAssertFalse(code.linked)

        let error = try MobileOAuthCallback(
            url: URL(string: "dutypark://oauth/callback?error=oauth_cancelled")!
        )
        XCTAssertNil(error.code)
        XCTAssertEqual(error.error, "oauth_cancelled")
        XCTAssertFalse(error.linked)

        XCTAssertTrue(
            try MobileOAuthCallback(url: URL(string: "dutypark://oauth/callback?linked=success")!).linked
        )
        XCTAssertThrowsError(
            try MobileOAuthCallback(url: URL(string: "other://oauth/callback?code=secret")!)
        )
    }

    @MainActor
    func testLoginSendsAuthorizeAndExchangeRequests() async throws {
        let recorder = OAuthRequestRecorder()
        OAuthURLProtocolStub.handler = { request in
            try recorder.response(for: request)
        }
        let web = OAuthWebAuthenticatorStub(
            callback: URL(string: "dutypark://oauth/callback?code=one-time-code")!
        )
        let client = MobileOAuthClient(client: makeClient(), webAuthenticator: web)

        let outcome = try await client.login(provider: .kakao)

        XCTAssertEqual(outcome, .authenticated)
        XCTAssertEqual(web.openedURL?.host, "accounts.example")
        let requests = recorder.requests
        XCTAssertEqual(requests.map(\.url?.path), [
            "/api/auth/mobile/oauth/authorize",
            "/api/auth/mobile/oauth/exchange"
        ])
        let authorize = try XCTUnwrap(Self.jsonBody(requests[0]))
        let exchange = try XCTUnwrap(Self.jsonBody(requests[1]))
        XCTAssertEqual(authorize["provider"] as? String, "KAKAO")
        XCTAssertEqual(authorize["purpose"] as? String, "LOGIN")
        XCTAssertEqual(authorize["callbackUri"] as? String, MobileOAuthClient.callbackURI)
        XCTAssertEqual(exchange["code"] as? String, "one-time-code")
        XCTAssertEqual(exchange["callbackUri"] as? String, MobileOAuthClient.callbackURI)
        XCTAssertEqual(
            PKCEPair.challenge(for: try XCTUnwrap(exchange["codeVerifier"] as? String)),
            authorize["codeChallenge"] as? String
        )
    }

    @MainActor
    func testNativeOAuthConfigurationRequiresCompleteProviderCredentials() {
        let kakaoOnly = OAuthNativeConfiguration(
            kakaoNativeAppKey: "kakao-app-key",
            naverClientID: nil,
            naverClientSecret: nil,
            naverAppName: "Dutypark"
        )

        XCTAssertTrue(kakaoOnly.isKakaoConfigured)
        XCTAssertFalse(kakaoOnly.isNaverConfigured)
        XCTAssertEqual(kakaoOnly.kakaoCallbackScheme, "kakaokakao-app-key")

        let naver = OAuthNativeConfiguration(
            kakaoNativeAppKey: nil,
            naverClientID: "naver-client-id",
            naverClientSecret: "naver-client-secret",
            naverAppName: "Dutypark"
        )
        XCTAssertFalse(naver.isKakaoConfigured)
        XCTAssertTrue(naver.isNaverConfigured)
        XCTAssertEqual(naver.naverCallbackScheme, OAuthNativeConfiguration.naverCallbackScheme)
        XCTAssertEqual(OAuthNativeConfiguration.naverCallbackHost, "thirdPartyLoginResult")

        let callback = URL(
            string: "\(OAuthNativeConfiguration.naverCallbackScheme)://\(OAuthNativeConfiguration.naverCallbackHost)?authCode=code"
        )!
        XCTAssertEqual(callback.scheme, OAuthNativeConfiguration.naverCallbackScheme)
        XCTAssertEqual(callback.host, OAuthNativeConfiguration.naverCallbackHost)
    }

    func testNativeSDKCancellationErrorsMapToCancellation() {
        XCTAssertEqual(
            NativeOAuthErrorMapping.kakao(SdkError(reason: .Cancelled)),
            .cancelled
        )
        XCTAssertEqual(
            NativeOAuthErrorMapping.kakao(
                SdkError.AuthFailed(reason: .AccessDenied, errorInfo: nil)
            ),
            .cancelled
        )
        XCTAssertEqual(
            NativeOAuthErrorMapping.naver(NidError.clientError(.canceledByUser)),
            .cancelled
        )
        XCTAssertEqual(
            NativeOAuthErrorMapping.naverAuthError(
                errorCode: "2",
                errorDescription: nil
            ),
            .cancelled
        )
        XCTAssertEqual(
            NativeOAuthErrorMapping.naverAuthError(
                errorCode: "undefined",
                errorDescription: "사용자가 취소했습니다."
            ),
            .cancelled
        )
        XCTAssertEqual(
            NativeOAuthErrorMapping.naverAuthError(
                errorCode: "undefined",
                errorDescription: "An unexpected provider error"
            ),
            .provider("auth.oauth.mobile.provider.failed")
        )
    }

    @MainActor
    func testConfiguredNativeKakaoLoginExchangesAccessTokenWithoutOpeningWeb() async throws {
        let recorder = OAuthRequestRecorder()
        OAuthURLProtocolStub.handler = { request in
            try recorder.response(for: request)
        }
        let web = OAuthWebAuthenticatorStub(
            callback: URL(string: "dutypark://oauth/callback?code=web-code")!
        )
        let native = NativeOAuthAuthenticatorStub(
            availableProviders: [.kakao],
            credential: .kakao(accessToken: "kakao-access-token")
        )
        let client = MobileOAuthClient(
            client: makeClient(),
            webAuthenticator: web,
            nativeOAuth: native
        )

        let outcome = try await client.login(provider: .kakao)
        XCTAssertEqual(outcome, .authenticated)
        XCTAssertNil(web.openedURL)
        XCTAssertEqual(native.authenticatedProviders, [.kakao])
        XCTAssertEqual(
            recorder.requests.map(\.url?.path),
            [
                "/api/auth/mobile/oauth/native/capabilities",
                "/api/auth/mobile/oauth/native/exchange",
            ]
        )
        let exchange = try XCTUnwrap(Self.jsonBody(recorder.requests[1]))
        XCTAssertEqual(exchange["provider"] as? String, "KAKAO")
        XCTAssertEqual(exchange["purpose"] as? String, "LOGIN")
        XCTAssertEqual(exchange["accessToken"] as? String, "kakao-access-token")
        XCTAssertNil(exchange["refreshToken"])
    }

    @MainActor
    func testConfiguredNativeNaverLinkExchangesOnlyRefreshToken() async throws {
        let recorder = OAuthRequestRecorder()
        OAuthURLProtocolStub.handler = { request in
            try recorder.response(for: request)
        }
        let web = OAuthWebAuthenticatorStub(
            callback: URL(string: "dutypark://oauth/callback?linked=success")!
        )
        let native = NativeOAuthAuthenticatorStub(
            availableProviders: [.naver],
            credential: .naver(refreshToken: "naver-refresh-token")
        )
        let client = MobileOAuthClient(
            client: makeClient(),
            webAuthenticator: web,
            nativeOAuth: native
        )

        try await client.link(provider: .naver)

        XCTAssertNil(web.openedURL)
        XCTAssertEqual(recorder.requests.map(\.url?.path), [
            "/api/auth/mobile/oauth/native/capabilities",
            "/api/auth/mobile/oauth/native/exchange",
        ])
        let exchange = try XCTUnwrap(Self.jsonBody(recorder.requests[1]))
        XCTAssertEqual(exchange["provider"] as? String, "NAVER")
        XCTAssertEqual(exchange["purpose"] as? String, "LINK")
        XCTAssertEqual(exchange["refreshToken"] as? String, "naver-refresh-token")
        XCTAssertNil(exchange["accessToken"])
    }

    @MainActor
    func testNativeCapability404FallsBackToExistingWebFlow() async throws {
        let recorder = OAuthRequestRecorder(nativeCapabilityStatus: 404)
        OAuthURLProtocolStub.handler = { request in
            try recorder.response(for: request)
        }
        let web = OAuthWebAuthenticatorStub(
            callback: URL(string: "dutypark://oauth/callback?code=web-code")!
        )
        let native = NativeOAuthAuthenticatorStub(
            availableProviders: [.kakao],
            credential: .kakao(accessToken: "kakao-access-token")
        )
        let client = MobileOAuthClient(
            client: makeClient(),
            webAuthenticator: web,
            nativeOAuth: native
        )

        let outcome = try await client.login(provider: .kakao)
        XCTAssertEqual(outcome, .authenticated)
        XCTAssertEqual(web.openedURL?.host, "accounts.example")
        XCTAssertEqual(recorder.requests.map(\.url?.path), [
            "/api/auth/mobile/oauth/native/capabilities",
            "/api/auth/mobile/oauth/authorize",
            "/api/auth/mobile/oauth/exchange",
        ])
    }

    @MainActor
    func testEmptyNativeCapabilityResponseFallsBackToExistingWebFlow() async throws {
        let recorder = OAuthRequestRecorder(nativeCapabilityBody: "{}")
        OAuthURLProtocolStub.handler = { request in
            try recorder.response(for: request)
        }
        let web = OAuthWebAuthenticatorStub(
            callback: URL(string: "dutypark://oauth/callback?code=web-code")!
        )
        let native = NativeOAuthAuthenticatorStub(
            availableProviders: [.kakao],
            credential: .kakao(accessToken: "kakao-access-token")
        )
        let client = MobileOAuthClient(
            client: makeClient(),
            webAuthenticator: web,
            nativeOAuth: native
        )

        let outcome = try await client.login(provider: .kakao)

        XCTAssertEqual(outcome, .authenticated)
        XCTAssertEqual(web.openedURL?.host, "accounts.example")
        XCTAssertEqual(native.authenticatedProviders, [])
        XCTAssertEqual(recorder.requests.map(\.url?.path), [
            "/api/auth/mobile/oauth/native/capabilities",
            "/api/auth/mobile/oauth/authorize",
            "/api/auth/mobile/oauth/exchange",
        ])
    }

    @MainActor
    func testNativeCapabilityProviderExclusionFallsBackToExistingWebFlow() async throws {
        let recorder = OAuthRequestRecorder(nativeCapabilityProviders: [.naver])
        OAuthURLProtocolStub.handler = { request in
            try recorder.response(for: request)
        }
        let web = OAuthWebAuthenticatorStub(
            callback: URL(string: "dutypark://oauth/callback?code=web-code")!
        )
        let native = NativeOAuthAuthenticatorStub(
            availableProviders: [.kakao],
            credential: .kakao(accessToken: "kakao-access-token")
        )
        let client = MobileOAuthClient(
            client: makeClient(),
            webAuthenticator: web,
            nativeOAuth: native
        )

        let outcome = try await client.login(provider: .kakao)

        XCTAssertEqual(outcome, .authenticated)
        XCTAssertEqual(web.openedURL?.host, "accounts.example")
        XCTAssertEqual(native.authenticatedProviders, [])
        XCTAssertEqual(recorder.requests.map(\.url?.path), [
            "/api/auth/mobile/oauth/native/capabilities",
            "/api/auth/mobile/oauth/authorize",
            "/api/auth/mobile/oauth/exchange",
        ])
    }

    @MainActor
    func testNativeUnavailableUsesWebWithoutCapabilityRequest() async throws {
        let recorder = OAuthRequestRecorder()
        OAuthURLProtocolStub.handler = { request in
            try recorder.response(for: request)
        }
        let web = OAuthWebAuthenticatorStub(
            callback: URL(string: "dutypark://oauth/callback?code=web-code")!
        )
        let native = NativeOAuthAuthenticatorStub(availableProviders: [])
        let client = MobileOAuthClient(
            client: makeClient(),
            webAuthenticator: web,
            nativeOAuth: native
        )

        let outcome = try await client.login(provider: .kakao)

        XCTAssertEqual(outcome, .authenticated)
        XCTAssertEqual(web.openedURL?.host, "accounts.example")
        XCTAssertEqual(native.authenticatedProviders, [])
        XCTAssertEqual(recorder.requests.map(\.url?.path), [
            "/api/auth/mobile/oauth/authorize",
            "/api/auth/mobile/oauth/exchange",
        ])
    }

    @MainActor
    func testNativeProviderFailureDoesNotFallBackToWeb() async throws {
        let recorder = OAuthRequestRecorder()
        OAuthURLProtocolStub.handler = { request in
            try recorder.response(for: request)
        }
        let web = OAuthWebAuthenticatorStub(
            callback: URL(string: "dutypark://oauth/callback?code=web-code")!
        )
        let native = NativeOAuthAuthenticatorStub(
            availableProviders: [.kakao],
            error: MobileOAuthError.provider("auth.oauth.mobile.provider.failed")
        )
        let client = MobileOAuthClient(
            client: makeClient(),
            webAuthenticator: web,
            nativeOAuth: native
        )

        do {
            _ = try await client.login(provider: .kakao)
            XCTFail("Expected native provider failure")
        } catch let error as MobileOAuthError {
            XCTAssertEqual(error, .provider("auth.oauth.mobile.provider.failed"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(web.openedURL)
        XCTAssertEqual(native.authenticatedProviders, [.kakao])
        XCTAssertEqual(recorder.requests.map(\.url?.path), [
            "/api/auth/mobile/oauth/native/capabilities",
        ])
    }

    @MainActor
    func testNativeCancellationDoesNotFallBackToWeb() async throws {
        let recorder = OAuthRequestRecorder()
        OAuthURLProtocolStub.handler = { request in
            try recorder.response(for: request)
        }
        let web = OAuthWebAuthenticatorStub(
            callback: URL(string: "dutypark://oauth/callback?code=web-code")!
        )
        let native = NativeOAuthAuthenticatorStub(
            availableProviders: [.kakao],
            error: MobileOAuthError.cancelled
        )
        let client = MobileOAuthClient(
            client: makeClient(),
            webAuthenticator: web,
            nativeOAuth: native
        )

        do {
            _ = try await client.login(provider: .kakao)
            XCTFail("Expected native cancellation")
        } catch MobileOAuthError.cancelled {
            XCTAssertNil(web.openedURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testLinkRefreshesExpiredSessionBeforeOpeningProvider() async throws {
        let recorder = OAuthRequestRecorder(challengeFirstLinkAuthorize: true)
        OAuthURLProtocolStub.handler = { request in
            try recorder.response(for: request)
        }
        let web = OAuthWebAuthenticatorStub(
            callback: URL(string: "dutypark://oauth/callback?linked=success")!
        )
        let client = MobileOAuthClient(client: makeClient(), webAuthenticator: web)

        try await client.link(provider: .naver)

        let requests = recorder.requests
        XCTAssertEqual(requests.map(\.url?.path), [
            "/api/auth/mobile/oauth/authorize",
            "/api/auth/refresh",
            "/api/auth/mobile/oauth/authorize"
        ])
        XCTAssertEqual(
            try XCTUnwrap(Self.jsonBody(requests[0]))["purpose"] as? String,
            "LINK"
        )
        XCTAssertEqual(web.openedURL?.host, "accounts.example")
    }

    @MainActor
    func testAccountDeletionReauthUsesDeletePurposeAndReturnsProof() async throws {
        let recorder = OAuthRequestRecorder()
        OAuthURLProtocolStub.handler = { request in
            try recorder.response(for: request)
        }
        let web = OAuthWebAuthenticatorStub(
            callback: URL(string: "dutypark://oauth/callback?code=delete-code")!
        )
        let native = NativeOAuthAuthenticatorStub(
            availableProviders: [.naver],
            credential: .naver(refreshToken: "naver-refresh-token")
        )
        let client = MobileOAuthClient(
            client: makeClient(),
            webAuthenticator: web,
            nativeOAuth: native
        )

        let proof = try await client.reauthenticateForAccountDeletion(provider: .naver)

        XCTAssertEqual(proof, MobileOAuthReauthProof(value: "delete-proof", expiresIn: 300))
        XCTAssertEqual(native.authenticatedProviders, [])
        let requests = recorder.requests
        XCTAssertEqual(requests.map(\.url?.path), [
            "/api/auth/mobile/oauth/authorize",
            "/api/auth/mobile/oauth/exchange",
        ])
        XCTAssertEqual(
            try XCTUnwrap(Self.jsonBody(requests[0]))["purpose"] as? String,
            "DELETE_ACCOUNT"
        )
        XCTAssertEqual(try XCTUnwrap(Self.jsonBody(requests[1]))["code"] as? String, "delete-code")
    }

    func testProviderCallbackErrorsUseSpecificLocalizedMessages() throws {
        let bundle = try localizedBundle("ko")

        XCTAssertEqual(
            APIErrorLocalization.message(code: "provider_failed", bundle: bundle),
            "소셜 로그인 제공자 인증에 실패했습니다. 다시 시도해주세요."
        )
        XCTAssertEqual(
            APIErrorLocalization.message(
                code: "auth.oauth.mobile.provider.failed",
                bundle: bundle
            ),
            "소셜 로그인 제공자 인증에 실패했습니다. 다시 시도해주세요."
        )
        XCTAssertEqual(
            APIErrorLocalization.message(
                code: "auth.oauth.mobile.provider.unavailable",
                bundle: bundle
            ),
            "소셜 로그인 제공자를 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해주세요."
        )
        XCTAssertEqual(
            APIErrorLocalization.message(code: "already_linked", bundle: bundle),
            "이미 다른 계정에 연결된 소셜 계정입니다."
        )
    }

    @MainActor
    func testAppleCannotFallThroughToBrowserOAuthEndpoints() async {
        let client = MobileOAuthClient(
            client: makeClient(),
            webAuthenticator: OAuthWebAuthenticatorStub(
                callback: URL(string: "dutypark://oauth/callback?code=unexpected")!
            )
        )

        do {
            _ = try await client.login(provider: .apple)
            XCTFail("Expected native-only Apple login to reject browser OAuth")
        } catch {
            XCTAssertEqual(error as? MobileOAuthError, .invalidAuthorizationURL)
        }
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OAuthURLProtocolStub.self]
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        return APIClient(baseURL: baseURL, session: URLSession(configuration: configuration))
    }

    fileprivate static func jsonBody(_ request: URLRequest) -> [String: Any]? {
        guard let body = requestBody(request) else { return nil }
        return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }

    private static func requestBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
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

    private func localizedBundle(_ locale: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: locale, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }
}

@MainActor
private final class OAuthWebAuthenticatorStub: OAuthWebAuthenticating {
    let callback: URL
    private(set) var openedURL: URL?

    init(callback: URL) {
        self.callback = callback
    }

    func authenticate(at url: URL) async throws -> URL {
        openedURL = url
        return callback
    }
}

private final class OAuthRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequests: [URLRequest] = []
    private let challengeFirstLinkAuthorize: Bool
    private let nativeCapabilityStatus: Int
    private let nativeCapabilityProviders: [OAuthProvider]
    private let nativeCapabilityBody: String?
    private var didChallengeLinkAuthorize = false
    private var didAuthorizeDeletion = false

    init(
        challengeFirstLinkAuthorize: Bool = false,
        nativeCapabilityStatus: Int = 200,
        nativeCapabilityProviders: [OAuthProvider] = [.kakao, .naver],
        nativeCapabilityBody: String? = nil
    ) {
        self.challengeFirstLinkAuthorize = challengeFirstLinkAuthorize
        self.nativeCapabilityStatus = nativeCapabilityStatus
        self.nativeCapabilityProviders = nativeCapabilityProviders
        self.nativeCapabilityBody = nativeCapabilityBody
    }

    var requests: [URLRequest] {
        lock.withLock { storedRequests }
    }

    func response(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let statusAndBody: (Int, String) = lock.withLock {
            storedRequests.append(request)
            if request.url?.path == "/api/auth/mobile/oauth/native/capabilities" {
                return (
                    nativeCapabilityStatus,
                    nativeCapabilityBody
                        ?? (nativeCapabilityStatus == 200
                            ? #"{"providers":[\#(nativeCapabilityProviders.map { "\"\($0.rawValue)\"" }.joined(separator: ","))]}"#
                            : #"{"code":"not_found"}"#)
                )
            }
            if request.url?.path == "/api/auth/mobile/oauth/authorize",
               let body = MobileOAuthClientTests.jsonBody(request),
               body["purpose"] as? String == "DELETE_ACCOUNT" {
                didAuthorizeDeletion = true
            }
            if challengeFirstLinkAuthorize,
               request.url?.path == "/api/auth/mobile/oauth/authorize",
               let body = MobileOAuthClientTests.jsonBody(request),
               body["purpose"] as? String == "LINK",
               !didChallengeLinkAuthorize {
                didChallengeLinkAuthorize = true
                return (401, #"{"code":"auth.required"}"#)
            }
            return (200, responseBody(for: request))
        }
        return (
            HTTPURLResponse(
                url: request.url!,
                statusCode: statusAndBody.0,
                httpVersion: nil,
                headerFields: nil
            )!,
            Data(statusAndBody.1.utf8)
        )
    }

    private func responseBody(for request: URLRequest) -> String {
        switch request.url?.path {
        case "/api/auth/mobile/oauth/native/exchange":
            #"{"signupRequired":false,"signupUuid":null,"expiresIn":3600}"#
        case "/api/auth/mobile/oauth/authorize":
            #"{"authorizationUrl":"https://accounts.example/authorize","expiresIn":300}"#
        case "/api/auth/mobile/oauth/exchange":
            didAuthorizeDeletion
                ? #"{"signupRequired":false,"signupUuid":null,"expiresIn":300,"reauthProof":"delete-proof"}"#
                : #"{"signupRequired":false,"signupUuid":null,"expiresIn":3600}"#
        case "/api/auth/refresh":
            #"{}"#
        default:
            #"{"code":"not_found"}"#
        }
    }
}

@MainActor
private final class NativeOAuthAuthenticatorStub: NativeOAuthAuthenticating {
    private let availableProviders: Set<OAuthProvider>
    private let credential: NativeOAuthCredential?
    private let error: Error?
    private(set) var authenticatedProviders: [OAuthProvider] = []

    init(
        availableProviders: Set<OAuthProvider>,
        credential: NativeOAuthCredential? = nil,
        error: Error? = nil
    ) {
        self.availableProviders = availableProviders
        self.credential = credential
        self.error = error
    }

    func isAvailable(for provider: OAuthProvider) -> Bool {
        availableProviders.contains(provider)
    }

    func authenticate(provider: OAuthProvider) async throws -> NativeOAuthCredential {
        authenticatedProviders.append(provider)
        if let error { throw error }
        guard let credential, credential.provider == provider else {
            throw MobileOAuthError.provider("provider_failed")
        }
        return credential
    }

    func handle(url: URL) -> Bool { false }
}

private final class OAuthURLProtocolStub: URLProtocol, @unchecked Sendable {
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
