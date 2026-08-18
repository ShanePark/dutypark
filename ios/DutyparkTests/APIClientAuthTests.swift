import Foundation
import UserNotifications
import XCTest
@testable import Dutypark

final class APIClientAuthTests: XCTestCase {
    private let baseURL = URL(string: "https://dutypark.test/api/")!

    override func tearDown() {
        URLProtocolStub.handler = nil
        URLProtocolStub.error = nil
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

    @MainActor
    func testLoginPreservesSuspendedAccountErrorCode() async {
        URLProtocolStub.handler = { request in
            Self.response(
                request,
                status: 401,
                body: #"{"status":401,"code":"auth.account.suspended"}"#
            )
        }

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .guest
        )
        await store.login(email: "test@duty.park", password: "12345678", rememberMe: false)

        XCTAssertEqual(store.loginErrorKey, "auth.account.suspended")
        XCTAssertNil(store.loginErrorStatus)
        XCTAssertNil(store.loginRemainingAttempts)
    }

    @MainActor
    func testLoginReportsServerOutageWithTheStatusCode() async {
        URLProtocolStub.handler = { request in
            Self.response(
                request,
                status: 502,
                body: "<html><body>502 Bad Gateway</body></html>"
            )
        }

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .guest
        )
        await store.login(email: "test@duty.park", password: "12345678", rememberMe: false)

        XCTAssertEqual(store.loginErrorKey, "auth.login.error.server")
        XCTAssertEqual(store.loginErrorStatus, 502)
    }

    @MainActor
    func testLoginReportsUnreachableServerAsANetworkFailure() async {
        URLProtocolStub.error = URLError(.notConnectedToInternet)

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .guest
        )
        await store.login(email: "test@duty.park", password: "12345678", rememberMe: false)

        XCTAssertEqual(store.loginErrorKey, "auth.login.error.network")
        XCTAssertNil(store.loginErrorStatus)
    }

    @MainActor
    func testLoginReportsUnclassifiedFailuresWithTheStatusCode() async {
        URLProtocolStub.handler = { request in
            Self.response(request, status: 400, body: "Bad Request")
        }

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .guest
        )
        await store.login(email: "test@duty.park", password: "12345678", rememberMe: false)

        XCTAssertEqual(store.loginErrorKey, "auth.login.error.unknown")
        XCTAssertEqual(store.loginErrorStatus, 400)
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

    func testAdminRequestUsesAdminBaseAndRefreshesThroughRegularAPI() async throws {
        let adminRequestCount = LockedCounter()
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/admin/api/members":
                if adminRequestCount.increment() == 1 {
                    return Self.response(
                        request,
                        status: 401,
                        body: #"{"status":401,"code":"auth.required"}"#
                    )
                }
                return Self.response(request, status: 200, body: #"{"value":7}"#)
            case "/api/auth/refresh":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            default:
                return Self.response(request, status: 404)
            }
        }

        let response: ValueResponse = try await makeClient().request(
            "/members",
            scope: .admin
        )

        XCTAssertEqual(response.value, 7)
        XCTAssertEqual(adminRequestCount.current, 2)
    }

    func testAdminRequestPreservesQueryAndNormalizesLeadingSlash() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/admin/api/teams")
            XCTAssertEqual(request.url?.query, "page=2")
            return Self.response(request, status: 200, body: #"{"value":1}"#)
        }

        let response: ValueResponse = try await makeClient().request(
            "/teams",
            queryItems: [URLQueryItem(name: "page", value: "2")],
            scope: .admin
        )

        XCTAssertEqual(response.value, 1)
    }

    func testAdminRequestRejectsParentPathTraversal() async {
        URLProtocolStub.handler = { request in
            XCTFail("Traversal request must not reach the network: \(request.url?.absoluteString ?? "nil")")
            return Self.response(request, status: 500)
        }

        do {
            let _: ValueResponse = try await makeClient().request(
                "../members",
                scope: .admin
            )
            XCTFail("Expected invalid URL")
        } catch APIError.invalidURL {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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

    @MainActor
    func testImpersonationUnauthorizedTerminatesStaleSessionWithoutRefresh() async {
        let refreshCount = LockedCounter()
        let pushCount = LockedCounter()
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":2,"email":null,"name":"Managed","teamId":null,"team":null,"isAdmin":false,"isImpersonating":true,"originalMemberId":1}"#
                )
            case "/api/protected":
                return Self.response(request, status: 401)
            case "/api/auth/refresh":
                _ = refreshCount.increment()
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            case "/api/auth/logout":
                return Self.response(request, status: 204)
            default:
                return Self.response(request, status: 404)
            }
        }
        let client = makeClient()
        let store = SessionStore(
            authService: AuthService(client: client),
            unregisterPush: { _ = pushCount.increment() }
        )
        await store.restore()

        do {
            let _: ValueResponse = try await client.request("protected")
            XCTFail("Expected unauthorized response")
        } catch APIError.server(status: 401, code: _) {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(refreshCount.current, 0)
        XCTAssertEqual(pushCount.current, 1)
        XCTAssertEqual(store.state, .guest)
        XCTAssertNil(store.impersonationExpiresAt)
    }

    func testDeferredAuthenticationFailureDoesNotWaitForAPNsOperationLockCleanup() async {
        let handlerStarted = LockedFlag()
        let requestFinished = LockedFlag()
        let cleanupCanContinue = TestAsyncGate()
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/push/apns/register", "/api/auth/refresh":
                return Self.response(request, status: 401)
            default:
                return Self.response(request, status: 404)
            }
        }
        let client = makeClient()
        await client.setAuthenticationFailureHandler {
            handlerStarted.set()
            await cleanupCanContinue.wait()
        }

        let requestTask = Task {
            defer { requestFinished.set() }
            do {
                let _: ValueResponse = try await client.request(
                    "auth/push/apns/register",
                    method: .post,
                    body: EmptyTestRequest(),
                    authenticationFailureHandling: .deferred
                )
                XCTFail("Expected invalid refresh response")
            } catch {
                // Expected.
            }
        }

        for _ in 0..<200 where !handlerStarted.value {
            try? await Task.sleep(for: .milliseconds(1))
        }
        for _ in 0..<200 where !requestFinished.value {
            try? await Task.sleep(for: .milliseconds(1))
        }

        XCTAssertTrue(handlerStarted.value)
        XCTAssertTrue(
            requestFinished.value,
            "APNs register must release its operation lock before session cleanup unregisters push"
        )
        await cleanupCanContinue.open()
        await requestTask.value
    }

    @MainActor
    func testAPNsRegistrationAuthenticationFailureReleasesManagerLockBeforeSessionCleanup() async throws {
        let suiteName = "APIClientAuthTests.apnsAuthenticationFailure.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("stored-token", forKey: "dutypark.apns.device-token")
        let unregisterCount = LockedCounter()
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":1,"email":"test@duty.park","name":"Test","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            case "/api/auth/push/apns/register", "/api/auth/refresh":
                return Self.response(request, status: 401)
            case "/api/auth/push/apns/unregister":
                _ = unregisterCount.increment()
                return Self.response(request, status: 204)
            case "/api/auth/logout":
                return Self.response(request, status: 204)
            default:
                return Self.response(request, status: 404)
            }
        }
        let client = makeClient()
        let manager = APNsRegistrationManager(
            api: APNsRegistrationAPI(client: client),
            notificationCenter: APIClientAuthNotificationCenter(),
            remoteNotificationRegistrar: APIClientAuthRemoteNotificationRegistrar(),
            defaults: defaults
        )
        let store = SessionStore(
            authService: AuthService(client: client),
            unregisterPush: { await manager.unregister() }
        )
        await store.restore()
        await manager.activateForAuthenticatedSession()
        let registrationFinished = LockedFlag()
        let registrationTask = Task { @MainActor in
            await manager.didRegisterForRemoteNotifications(deviceToken: Data([0xAA]))
            registrationFinished.set()
        }

        for _ in 0..<500 where store.state != .guest || !registrationFinished.value {
            try? await Task.sleep(for: .milliseconds(1))
        }

        XCTAssertEqual(store.state, .guest)
        XCTAssertTrue(registrationFinished.value, "APNs registration must not deadlock session cleanup")
        XCTAssertGreaterThanOrEqual(unregisterCount.current, 1)
        if registrationFinished.value {
            await registrationTask.value
        } else {
            registrationTask.cancel()
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
    func testSessionRestoreTreatsUnauthorizedStatusAndInvalidRefreshAsGuest() async {
        let requests = LockedRequests()
        URLProtocolStub.handler = { request in
            requests.append(request.url?.path ?? "")
            switch request.url?.path {
            case "/api/auth/status":
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

        let store = SessionStore(authService: AuthService(client: makeClient()))

        await store.restore()

        XCTAssertEqual(store.state, .guest)
        XCTAssertEqual(requests.values, ["/api/auth/status", "/api/auth/refresh"])
    }

    @MainActor
    func testContinueAsGuestAfterRestoreFailureClearsCookiesWithoutDiscardingDeepLink() async throws {
        let destination = URL(string: "https://dutypark.o-r.kr/todo")!
        let events = LockedEvents()
        let cookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: "dutypark.test",
            .path: "/",
            .name: "refresh_token",
            .value: "possibly-stale",
            .secure: "TRUE",
        ]))
        HTTPCookieStorage.shared.setCookie(cookie)
        URLProtocolStub.handler = { request in
            events.append("server")
            return Self.response(request, status: 503)
        }
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            unregisterPush: { events.append("push") }
        )
        store.deferDestinationUntilAuthenticated(destination)
        await store.restore()
        XCTAssertEqual(store.state, .restoreFailed)

        await store.continueAsGuestAfterRestoreFailure()

        XCTAssertEqual(store.state, .guest)
        XCTAssertEqual(store.pendingDestination, destination)
        XCTAssertEqual(events.values, ["server", "push", "server"])
        XCTAssertEqual(store.serverSessionWarning, .serverMayRemain)
        XCTAssertFalse(HTTPCookieStorage.shared.cookies?.contains {
            $0.name == "access_token" || $0.name == "refresh_token"
        } == true)

        await store.retryRestore()
        XCTAssertEqual(store.state, .guest)
    }

    @MainActor
    func testOfflineAndTimeoutRestoreOfferRecoveryInsteadOfChangingSessionSilently() async {
        for code in [URLError.notConnectedToInternet, URLError.timedOut] {
            URLProtocolStub.error = URLError(code)
            let store = SessionStore(authService: AuthService(client: makeClient()))

            await store.restore()

            XCTAssertEqual(store.state, .restoreFailed, "Failed for \(code)")
            await store.restore()
            XCTAssertEqual(store.state, .restoreFailed, "Restore must not retry automatically for \(code)")
        }
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
    func testLoginFailurePreservesAuthenticatedDestinationForRetry() async {
        URLProtocolStub.handler = { request in
            Self.response(request, status: 401)
        }
        let destination = URL(string: "https://dutypark.o-r.kr/todo")!
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .guest
        )
        store.deferDestinationUntilAuthenticated(destination)

        await store.login(email: "test@duty.park", password: "wrong", rememberMe: false)

        XCTAssertEqual(store.state, .guest)
        XCTAssertEqual(store.pendingDestination, destination)
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
    func testLogoutServerFailureStillTransitionsSessionToGuest() async throws {
        for name in ["access_token", "refresh_token"] {
            let cookie = try XCTUnwrap(HTTPCookie(properties: [
                .domain: "dutypark.test",
                .path: "/",
                .name: name,
                .value: "secret",
                .secure: "TRUE",
            ]))
            HTTPCookieStorage.shared.setCookie(cookie)
        }
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/logout")
            return Self.response(request, status: 503)
        }

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            impersonationExpiresAt: Date().addingTimeInterval(60)
        )

        await store.logout()

        XCTAssertEqual(store.state, .guest)
        XCTAssertNil(store.impersonationExpiresAt)
        XCTAssertFalse(HTTPCookieStorage.shared.cookies?.contains {
            $0.name == "access_token" || $0.name == "refresh_token"
        } == true)
        XCTAssertEqual(store.serverSessionWarning, .serverMayRemain)

        store.dismissServerSessionWarning()
        XCTAssertNil(store.serverSessionWarning)
    }

    @MainActor
    func testLogoutRunsPushServerAndLocalCleanupInOrderAndDiscardsPendingDestination() async throws {
        let events = LockedEvents()
        let cachedRequest = URLRequest(url: URL(string: "https://dutypark.test/cached-member")!)
        URLCache.shared.storeCachedResponse(
            CachedURLResponse(
                response: HTTPURLResponse(
                    url: cachedRequest.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                data: Data("cached".utf8)
            ),
            for: cachedRequest
        )
        XCTAssertNotNil(URLCache.shared.cachedResponse(for: cachedRequest))
        let cookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: "dutypark.test",
            .path: "/",
            .name: "access_token",
            .value: "secret",
            .secure: "TRUE",
        ]))
        HTTPCookieStorage.shared.setCookie(cookie)
        URLProtocolStub.handler = { request in
            events.append("server")
            return Self.response(request, status: 204)
        }
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            unregisterPush: { events.append("push") }
        )
        store.deferDestinationUntilAuthenticated(URL(string: "https://dutypark.o-r.kr/todo")!)

        await store.logout()

        XCTAssertEqual(events.values, ["push", "server"])
        XCTAssertEqual(store.state, .guest)
        XCTAssertNil(store.pendingDestination)
        XCTAssertNil(store.serverSessionWarning)
        XCTAssertFalse(HTTPCookieStorage.shared.cookies?.contains {
            $0.name == "access_token" || $0.name == "refresh_token"
        } == true)
        XCTAssertNil(URLCache.shared.cachedResponse(for: cachedRequest))
    }

    @MainActor
    func testInvalidRefreshUsesSameTerminationOrderAndWarnsWhenServerLogoutFails() async throws {
        let events = LockedEvents()
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":1,"email":"test@duty.park","name":"Test","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            case "/api/protected":
                return Self.response(request, status: 401)
            case "/api/auth/refresh":
                return Self.response(request, status: 401)
            case "/api/auth/logout":
                events.append("server")
                return Self.response(request, status: 503)
            default:
                return Self.response(request, status: 404)
            }
        }
        let client = makeClient()
        let store = SessionStore(
            authService: AuthService(client: client),
            unregisterPush: { events.append("push") }
        )
        await store.restore()

        do {
            let _: ValueResponse = try await client.request("protected")
            XCTFail("Expected invalid refresh response")
        } catch {
            // Expected.
        }

        XCTAssertEqual(events.values, ["push", "server"])
        XCTAssertEqual(store.state, .guest)
        XCTAssertEqual(store.serverSessionWarning, .serverMayRemain)
    }

    @MainActor
    func testConcurrentInvalidRefreshTerminatesSessionOnlyOnce() async {
        let refreshCount = LockedCounter()
        let logoutCount = LockedCounter()
        let pushCount = LockedCounter()
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":1,"email":"test@duty.park","name":"Test","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            case "/api/protected":
                return Self.response(request, status: 401)
            case "/api/auth/refresh":
                _ = refreshCount.increment()
                return Self.response(request, status: 401)
            case "/api/auth/logout":
                _ = logoutCount.increment()
                return Self.response(request, status: 204)
            default:
                return Self.response(request, status: 404)
            }
        }
        let client = makeClient()
        let store = SessionStore(
            authService: AuthService(client: client),
            unregisterPush: { _ = pushCount.increment() }
        )
        await store.restore()

        async let first = requestFails(client)
        async let second = requestFails(client)
        let failures = await [first, second]

        XCTAssertEqual(failures, [true, true])
        XCTAssertEqual(refreshCount.current, 1)
        XCTAssertEqual(pushCount.current, 1)
        XCTAssertEqual(logoutCount.current, 1)
        XCTAssertEqual(store.state, .guest)
    }

    @MainActor
    func testUnauthorizedRetryAfterSuccessfulRefreshTerminatesWithoutAnotherRefresh() async {
        let protectedCount = LockedCounter()
        let refreshCount = LockedCounter()
        let events = LockedEvents()
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":1,"email":"test@duty.park","name":"Test","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            case "/api/protected":
                _ = protectedCount.increment()
                return Self.response(request, status: 401)
            case "/api/auth/refresh":
                _ = refreshCount.increment()
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            case "/api/auth/logout":
                events.append("server")
                return Self.response(request, status: 204)
            default:
                return Self.response(request, status: 404)
            }
        }
        let client = makeClient()
        let store = SessionStore(
            authService: AuthService(client: client),
            unregisterPush: { events.append("push") }
        )
        await store.restore()

        do {
            let _: ValueResponse = try await client.request("protected")
            XCTFail("Expected retried unauthorized response")
        } catch APIError.server(status: 401, code: _) {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(protectedCount.current, 2)
        XCTAssertEqual(refreshCount.current, 1)
        XCTAssertEqual(events.values, ["push", "server"])
        XCTAssertEqual(store.state, .guest)
        XCTAssertNil(store.serverSessionWarning)
    }

    @MainActor
    func testUnauthorizedLogoutStillClearsLocalSessionAndShowsServerWarning() async {
        URLProtocolStub.handler = { request in
            Self.response(request, status: 401)
        }
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember)
        )

        await store.logout()

        XCTAssertEqual(store.state, .guest)
        XCTAssertEqual(store.serverSessionWarning, .serverMayRemain)
    }

    @MainActor
    func testOfflineAndTimeoutLogoutStillClearLocalSessionAndShowServerWarning() async {
        for code in [URLError.notConnectedToInternet, URLError.timedOut] {
            URLProtocolStub.error = URLError(code)
            let store = SessionStore(
                authService: AuthService(client: makeClient()),
                initialState: .authenticated(Self.testMember)
            )

            await store.logout()

            XCTAssertEqual(store.state, .guest, "Failed for \(code)")
            XCTAssertEqual(store.serverSessionWarning, .serverMayRemain, "Failed for \(code)")
        }
    }

    @MainActor
    func testAcceptedAccountDeletionClearsLocalCookiesImpersonationAndSession() async throws {
        for name in ["access_token", "refresh_token"] {
            let cookie = try XCTUnwrap(HTTPCookie(properties: [
                .domain: "dutypark.test",
                .path: "/",
                .name: name,
                .value: "secret",
                .secure: "TRUE",
            ]))
            HTTPCookieStorage.shared.setCookie(cookie)
        }
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            impersonationExpiresAt: Date().addingTimeInterval(60)
        )
        store.deferDestinationUntilAuthenticated(URL(string: "dutypark://todo")!)
        UserDefaults.standard.set("test@duty.park", forKey: "dp-remember-email")
        UserDefaults.standard.set(12, forKey: "selectedDday_1")

        await store.completeAccountDeletion()

        XCTAssertEqual(store.state, .guest)
        XCTAssertEqual(store.accountDeletionAcceptedPresentation, .accepted)
        XCTAssertNil(store.pendingDestination)
        XCTAssertNil(store.impersonationExpiresAt)
        XCTAssertNil(UserDefaults.standard.string(forKey: "dp-remember-email"))
        XCTAssertNil(UserDefaults.standard.object(forKey: "selectedDday_1"))
        XCTAssertFalse(HTTPCookieStorage.shared.cookies?.contains {
            $0.name == "access_token" || $0.name == "refresh_token"
        } == true)

        store.dismissAccountDeletionAcceptedPresentation()

        XCTAssertEqual(store.state, .guest)
        XCTAssertNil(store.accountDeletionAcceptedPresentation)

        let freshStore = SessionStore(initialState: .restoring)
        XCTAssertNil(freshStore.accountDeletionAcceptedPresentation)
    }

    @MainActor
    func testNewAuthenticatedSessionClearsAcceptedAccountDeletionPresentation() async {
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/token":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
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

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember)
        )
        await store.completeAccountDeletion()
        XCTAssertEqual(store.accountDeletionAcceptedPresentation, .accepted)

        await store.login(email: "test@duty.park", password: "12345678", rememberMe: false)

        XCTAssertEqual(store.state, .authenticated(Self.testMember))
        XCTAssertNil(store.accountDeletionAcceptedPresentation)
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

private struct EmptyTestRequest: Encodable, Sendable {}

private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = false

    func set() {
        lock.lock()
        storedValue = true
        lock.unlock()
    }

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }
}

private actor TestAsyncGate {
    private var isOpen = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let waiting = continuations
        continuations.removeAll()
        for continuation in waiting {
            continuation.resume()
        }
    }
}

@MainActor
private final class APIClientAuthNotificationCenter: NotificationAuthorizationCenter {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        true
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        .authorized
    }
}

@MainActor
private final class APIClientAuthRemoteNotificationRegistrar: RemoteNotificationRegistrar {
    func registerForRemoteNotifications() {}
}

private func requestFails(_ client: APIClient) async -> Bool {
    do {
        let _: ValueResponse = try await client.request("protected")
        return false
    } catch {
        return true
    }
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

private final class LockedRequests: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [String] = []

    func append(_ value: String) {
        lock.lock()
        storedValues.append(value)
        lock.unlock()
    }

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedValues
    }
}

private typealias LockedEvents = LockedRequests

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
    nonisolated(unsafe) static var error: URLError?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
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
