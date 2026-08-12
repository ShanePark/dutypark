import Foundation
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

    func testProviderCallbackErrorsUseSpecificLocalizedMessages() throws {
        let bundle = try localizedBundle("ko")

        XCTAssertEqual(
            APIErrorLocalization.message(code: "provider_failed", bundle: bundle),
            "소셜 로그인 제공자 인증에 실패했습니다. 다시 시도해주세요."
        )
        XCTAssertEqual(
            APIErrorLocalization.message(code: "already_linked", bundle: bundle),
            "이미 다른 계정에 연결된 소셜 계정입니다."
        )
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
    private var didChallengeLinkAuthorize = false

    init(challengeFirstLinkAuthorize: Bool = false) {
        self.challengeFirstLinkAuthorize = challengeFirstLinkAuthorize
    }

    var requests: [URLRequest] {
        lock.withLock { storedRequests }
    }

    func response(for request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let statusAndBody: (Int, String) = lock.withLock {
            storedRequests.append(request)
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
        case "/api/auth/mobile/oauth/authorize":
            #"{"authorizationUrl":"https://accounts.example/authorize","expiresIn":300}"#
        case "/api/auth/mobile/oauth/exchange":
            #"{"signupRequired":false,"signupUuid":null,"expiresIn":3600}"#
        case "/api/auth/refresh":
            #"{}"#
        default:
            #"{"code":"not_found"}"#
        }
    }
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
