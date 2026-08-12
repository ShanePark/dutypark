import Foundation
import XCTest
@testable import Dutypark

final class APIClientAuthTests: XCTestCase {
    private let baseURL = URL(string: "https://dutypark.test/api/")!

    override func tearDown() {
        URLProtocolStub.handler = nil
        HTTPCookieStorage.shared.cookies?.forEach(HTTPCookieStorage.shared.deleteCookie)
        super.tearDown()
    }

    func testLoginStoresSetCookieAndReturnsStatus() async throws {
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/token":
                return Self.response(
                    request,
                    status: 200,
                    headers: ["Set-Cookie": "access_token=abc; Path=/; Secure; HttpOnly"],
                    body: #"{"expiresIn":3600}"#
                )
            case "/api/auth/status":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":1,"email":"test@duty.park","name":"Test","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            default:
                return Self.response(request, status: 404)
            }
        }

        let service = AuthService(client: makeClient())
        let member = try await service.login(
            email: "test@duty.park",
            password: "12345678",
            rememberMe: true
        )

        XCTAssertEqual(member.id, 1)
        XCTAssertEqual(member.name, "Test")
        XCTAssertTrue(
            HTTPCookieStorage.shared.cookies?.contains {
                $0.name == "access_token" && $0.value == "abc"
            } == true
        )
    }

    @MainActor
    func testLoginPreservesRemainingAttemptsFromErrorDetails() async {
        URLProtocolStub.handler = { request in
            Self.response(
                request,
                status: 401,
                body: #"{"status":401,"code":"auth.login.invalid","details":{"remainingAttempts":2}}"#
            )
        }

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .guest
        )
        await store.login(email: "test@duty.park", password: "wrong", rememberMe: false)

        XCTAssertEqual(store.loginErrorKey, "auth.login.error.invalidCredentials")
        XCTAssertEqual(store.loginRemainingAttempts, 2)
    }

    func testStatusHandlesMemberAndEmptyGuestResponse() async throws {
        let responses = LockedCounter()
        URLProtocolStub.handler = { request in
            if responses.increment() == 1 {
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":7,"email":null,"name":"Shane","teamId":2,"team":"Dutypark","isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            }
            return Self.response(request, status: 200)
        }

        let service = AuthService(client: makeClient())
        let member = try await service.status()
        let guest = try await service.status()

        XCTAssertEqual(member?.team, "Dutypark")
        XCTAssertNil(guest)
    }

    func testConcurrentUnauthorizedRequestsRefreshOnlyOnce() async throws {
        let recorder = RefreshRecorder()
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/protected":
                return recorder.protectedResponse(for: request)
            case "/api/auth/refresh":
                return recorder.refreshResponse(for: request)
            default:
                return Self.response(request, status: 404)
            }
        }

        let client = makeClient()
        async let first: ValueResponse = client.request("protected")
        async let second: ValueResponse = client.request("protected")
        let values = try await [first.value, second.value]

        XCTAssertEqual(values, [1, 1])
        XCTAssertEqual(recorder.refreshCount, 1)
    }

    @MainActor
    func testInvalidRefreshTransitionsAuthenticatedSessionToGuest() async throws {
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":1,"email":"test@duty.park","name":"Test","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            case "/api/protected":
                return Self.response(
                    request,
                    status: 401,
                    body: #"{"status":401,"code":"auth.required"}"#
                )
            case "/api/auth/refresh":
                return Self.response(
                    request,
                    status: 401,
                    body: #"{"status":401,"code":"auth.refresh.invalid"}"#
                )
            default:
                return Self.response(request, status: 404)
            }
        }

        let client = makeClient()
        let store = SessionStore(authService: AuthService(client: client))
        await store.restore()
        XCTAssertEqual(store.state, .authenticated(Self.testMember))

        do {
            let _: ValueResponse = try await client.request("protected")
            XCTFail("Expected invalid refresh response")
        } catch APIError.server(status: 401, code: "auth.refresh.invalid") {
            XCTAssertEqual(store.state, .guest)
        }
    }

    func testImpersonationDoesNotRefreshUnauthorizedRequest() async throws {
        let refreshCount = LockedCounter()
        URLProtocolStub.handler = { request in
            if request.url?.path == "/api/auth/refresh" {
                _ = refreshCount.increment()
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            }
            return Self.response(
                request,
                status: 401,
                body: #"{"status":401,"code":"auth.required"}"#
            )
        }

        let client = makeClient()
        await client.setImpersonating(true)

        do {
            let _: ValueResponse = try await client.request("protected")
            XCTFail("Expected unauthorized response")
        } catch APIError.server(status: 401, code: "auth.required") {
            XCTAssertEqual(refreshCount.current, 0)
        }
    }

    func testRefreshGateDoesNotRefreshAgainForAStaleUnauthorizedResponse() async throws {
        let gate = RefreshGate()
        let observedGeneration = await gate.generation
        let refreshCount = LockedCounter()

        try await gate.run(ifGenerationIs: observedGeneration) {
            _ = refreshCount.increment()
        }
        try await gate.run(ifGenerationIs: observedGeneration) {
            _ = refreshCount.increment()
        }

        XCTAssertEqual(refreshCount.current, 1)
    }

    @MainActor
    func testSessionRestoreFailureOffersRetryInsteadOfBecomingGuest() async {
        let attempt = LockedCounter()
        URLProtocolStub.handler = { request in
            if attempt.increment() == 1 {
                return Self.response(request, status: 503)
            }
            if request.url?.path == "/api/auth/status" {
                return Self.response(request, status: 200)
            }
            return Self.response(
                request,
                status: 401,
                body: #"{"status":401,"code":"auth.refresh.invalid"}"#
            )
        }

        let store = SessionStore(authService: AuthService(client: makeClient()))
        await store.restore()
        XCTAssertEqual(store.state, .restoreFailed)

        await store.retryRestore()
        XCTAssertEqual(store.state, .guest)
    }

    @MainActor
    func testPendingDestinationSurvivesLoginBoundaryUntilConsumed() {
        let destination = URL(string: "dutypark://schedule/123")!
        let store = SessionStore(initialState: .guest)

        store.deferDestinationUntilAuthenticated(destination)

        XCTAssertEqual(store.consumePendingDestination(), destination)
        XCTAssertNil(store.consumePendingDestination())
    }

    @MainActor
    func testColdLaunchHTTPSDestinationIsKeptUntilRootConsumesIt() {
        let destination = URL(string: "https://dutypark.o-r.kr/todo")!
        let store = SessionStore(initialState: .restoring)

        store.deferDestinationUntilAuthenticated(destination)

        XCTAssertEqual(store.pendingDestination, destination)
        XCTAssertEqual(store.consumePendingDestination(), destination)
        XCTAssertNil(store.pendingDestination)
    }

    @MainActor
    func testImpersonationExposesExpirationAndFailedRestoreBecomesGuest() async throws {
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/impersonate/2":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            case "/api/auth/status":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":2,"email":null,"name":"Managed","teamId":null,"team":null,"isAdmin":false,"isImpersonating":true,"originalMemberId":1}"#
                )
            case "/api/auth/restore":
                return Self.response(
                    request,
                    status: 401,
                    body: #"{"status":401,"code":"auth.required"}"#
                )
            default:
                return Self.response(request, status: 404)
            }
        }

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .guest
        )
        try await store.impersonate(memberId: 2)

        XCTAssertNotNil(store.impersonationExpiresAt)
        XCTAssertGreaterThan(store.impersonationRemainingTime() ?? 0, 3500)

        await store.restoreOriginalAccount()
        XCTAssertEqual(store.state, .guest)
        XCTAssertNil(store.impersonationExpiresAt)
    }

    func testLogoutCallsServerAndClearsCookie() async throws {
        let cookie = HTTPCookie(properties: [
            .domain: "dutypark.test",
            .path: "/",
            .name: "refresh_token",
            .value: "refresh",
            .secure: "TRUE"
        ])!
        HTTPCookieStorage.shared.setCookie(cookie)

        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/logout")
            return Self.response(
                request,
                status: 204,
                headers: [
                    "Set-Cookie": "refresh_token=; Path=/; Max-Age=0; Secure; HttpOnly"
                ]
            )
        }

        try await AuthService(client: makeClient()).logout()

        XCTAssertFalse(
            HTTPCookieStorage.shared.cookies?.contains { $0.name == "refresh_token" } == true
        )
    }

    @MainActor
    func testLogoutServerFailureStillTransitionsSessionToGuest() async {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/logout")
            return Self.response(request, status: 503)
        }

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember)
        )

        await store.logout()

        XCTAssertEqual(store.state, .guest)
    }

    private static let testMember = LoginMember(
        id: 1,
        email: "test@duty.park",
        name: "Test",
        teamId: nil,
        team: nil,
        isAdmin: false,
        isImpersonating: false,
        originalMemberId: nil
    )

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        configuration.httpCookieStorage = .shared
        configuration.httpShouldSetCookies = true
        return APIClient(
            baseURL: baseURL,
            session: URLSession(configuration: configuration)
        )
    }

    private static func response(
        _ request: URLRequest,
        status: Int,
        headers: [String: String] = [:],
        body: String = ""
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: headers
            )!,
            Data(body.utf8)
        )
    }
}

private struct ValueResponse: Decodable, Sendable {
    let value: Int
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }

    var current: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class RefreshRecorder: @unchecked Sendable {
    private let condition = NSCondition()
    private var protectedCount = 0
    private var storedRefreshCount = 0

    var refreshCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return storedRefreshCount
    }

    func protectedResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
        condition.lock()
        defer { condition.unlock() }
        if storedRefreshCount == 0 {
            protectedCount += 1
            condition.broadcast()
            return response(request, status: 401)
        }
        return response(request, status: 200, body: #"{"value":1}"#)
    }

    func refreshResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
        condition.lock()
        while protectedCount < 2 {
            condition.wait(until: Date().addingTimeInterval(1))
            if protectedCount < 2 {
                break
            }
        }
        storedRefreshCount += 1
        condition.unlock()
        return response(request, status: 200, body: #"{"expiresIn":3600}"#)
    }

    private func response(
        _ request: URLRequest,
        status: Int,
        body: String = ""
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!,
            Data(body.utf8)
        )
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("URLProtocolStub.handler is not set")
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !data.isEmpty {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
