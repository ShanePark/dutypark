import Foundation
import UserNotifications
import XCTest
@testable import Dutypark

final class APIClientAuthTests: XCTestCase {
    private let baseURL = URL(string: "https://dutypark.test/api/")!

    override func tearDown() {
        URLProtocolStub.handler = nil
        URLProtocolStub.error = nil
        URLProtocolStub.deliversAsynchronously = false
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

    @MainActor
    func testRefreshCurrentMemberPatchesCreatedTeamWhenStatusIsUnavailable() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-created-team-session-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let offlineStore = OfflineSessionStore(directoryURL: directory)
        URLProtocolStub.error = URLError(.notConnectedToInternet)
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            offlineSessionStore: offlineStore
        )
        let createdTeam = try XCTUnwrap(
            JSONDecoder().decode(
                TeamDTO.self,
                from: Data(#"{"id":7,"name":"Created Team","description":null,"dutyTypes":[],"members":[],"createdDate":"2026-08-12T00:00:00","lastModifiedDate":"2026-08-12T00:00:00","adminId":1,"adminName":"Test","dutyBatchTemplate":null}"#.utf8)
            )
        )

        let refreshed = await store.refreshCurrentMember(fallbackTeam: createdTeam)

        XCTAssertTrue(refreshed)
        let expectedMember = LoginMember(
            id: Self.testMember.id,
            email: Self.testMember.email,
            name: Self.testMember.name,
            teamId: createdTeam.id,
            team: createdTeam.name,
            isAdmin: Self.testMember.isAdmin,
            isImpersonating: Self.testMember.isImpersonating,
            originalMemberId: Self.testMember.originalMemberId
        )
        XCTAssertEqual(store.state, .authenticated(expectedMember))
        let persistedMember = await offlineStore.load(at: nil)
        XCTAssertEqual(persistedMember, expectedMember)
    }

    @MainActor
    func testRefreshCurrentMemberAuthoritativelyPatchesCreatedTeamOverStaleStatusClaim() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-created-team-stale-claim-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        URLProtocolStub.handler = { request in
            Self.response(
                request,
                status: 200,
                body: #"{"id":1,"email":"fresh@duty.park","name":"Fresh Name","teamId":2,"team":"Old Team","isAdmin":true,"isImpersonating":false,"originalMemberId":null}"#
            )
        }
        let offlineStore = OfflineSessionStore(directoryURL: directory)
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            offlineSessionStore: offlineStore
        )
        let createdTeam = try XCTUnwrap(
            JSONDecoder().decode(
                TeamDTO.self,
                from: Data(#"{"id":7,"name":"Created Team","description":null,"dutyTypes":[],"members":[],"createdDate":"2026-08-12T00:00:00","lastModifiedDate":"2026-08-12T00:00:00","adminId":1,"adminName":"Test","dutyBatchTemplate":null}"#.utf8)
            )
        )

        let refreshed = await store.refreshCurrentMember(fallbackTeam: createdTeam)

        XCTAssertTrue(refreshed)
        let expectedMember = LoginMember(
            id: 1,
            email: "fresh@duty.park",
            name: "Fresh Name",
            teamId: createdTeam.id,
            team: createdTeam.name,
            isAdmin: true,
            isImpersonating: false,
            originalMemberId: nil
        )
        XCTAssertEqual(store.state, .authenticated(expectedMember))
        let persistedMember = await offlineStore.load(at: nil)
        XCTAssertEqual(persistedMember, expectedMember)
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

        let deletionGeneration = try XCTUnwrap(
            store.authenticationSessionGenerationForCurrentAccount
        )
        await store.completeAccountDeletion(
            expectedMemberID: Self.testMember.id,
            expectedAuthenticationSessionGeneration: deletionGeneration
        )

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
    func testClearingAccountDeletionReceiptClearsInMemoryAndPersistedState() throws {
        let suiteName = "APIClientAuthTests.clearAccountDeletionReceipt.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let receiptStore = AccountDeletionReceiptStore(
            defaults: defaults,
            tokenStore: APIClientAuthReceiptTokenStore()
        )
        let receipt = AccountDeletionReceipt(
            jobId: 42,
            status: "PENDING",
            ownerMemberID: Self.testMember.id,
            receiptToken: String(repeating: "R", count: 43),
            estimatedCompletionAt: "2026-08-30T12:05:00Z"
        )
        try receiptStore.save(receipt)
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            accountDeletionReceiptStore: receiptStore
        )

        XCTAssertEqual(store.accountDeletionReceipt?.ownerMemberID, receipt.ownerMemberID)
        XCTAssertEqual(store.accountDeletionReceipt?.receiptToken, receipt.receiptToken)
        XCTAssertEqual(
            store.accountDeletionReceipt?.estimatedCompletionAt,
            receipt.estimatedCompletionAt
        )
        XCTAssertEqual(store.accountDeletionAcceptedPresentation, .accepted)

        let deletionGeneration = try XCTUnwrap(
            store.authenticationSessionGenerationForCurrentAccount
        )
        XCTAssertTrue(
            store.clearAccountDeletionReceipt(
                expectedMemberID: Self.testMember.id,
                expectedAuthenticationSessionGeneration: deletionGeneration
            )
        )

        XCTAssertNil(store.accountDeletionReceipt)
        XCTAssertNil(store.accountDeletionAcceptedPresentation)
        XCTAssertNil(receiptStore.load())
    }

    @MainActor
    func testLateAccountDeletionReceiptClearDoesNotClearReplacementReceipt() throws {
        let suiteName = "APIClientAuthTests.lateAccountDeletionReceiptClear.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let receiptStore = AccountDeletionReceiptStore(
            defaults: defaults,
            tokenStore: APIClientAuthReceiptTokenStore()
        )
        let receipt = AccountDeletionReceipt(
            jobId: 42,
            status: "PENDING",
            ownerMemberID: Self.testMember.id,
            receiptToken: String(repeating: "S", count: 43),
            estimatedCompletionAt: "2026-08-30T12:05:00Z"
        )
        try receiptStore.save(receipt)
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(LoginMember(
                id: 2,
                email: "other@duty.park",
                name: "Other",
                teamId: nil,
                team: nil,
                isAdmin: false,
                isImpersonating: false,
                originalMemberId: nil
            )),
            accountDeletionReceiptStore: receiptStore
        )

        XCTAssertFalse(
            store.clearAccountDeletionReceipt(
                expectedMemberID: Self.testMember.id,
                expectedAuthenticationSessionGeneration: 0
            )
        )
        XCTAssertEqual(store.accountDeletionReceipt?.ownerMemberID, receipt.ownerMemberID)
        XCTAssertEqual(store.accountDeletionReceipt?.receiptToken, receipt.receiptToken)
        XCTAssertEqual(receiptStore.load()?.ownerMemberID, receipt.ownerMemberID)
        XCTAssertEqual(receiptStore.load()?.receiptToken, receipt.receiptToken)
    }

    @MainActor
    func testLateAccountDeletionCompletionDoesNotClearReplacementSession() async throws {
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/token":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"expiresIn":3600}"#
                )
            case "/api/auth/status":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":2,"email":"other@duty.park","name":"Other","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            default:
                return Self.response(request, status: 404)
            }
        }

        let suiteName = "APIClientAuthTests.lateAccountDeletion.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let receiptStore = AccountDeletionReceiptStore(
            defaults: defaults,
            tokenStore: APIClientAuthReceiptTokenStore()
        )
        let purger = SessionBoundaryProbe()
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            localDataPurger: purger,
            accountDeletionReceiptStore: receiptStore
        )
        let deletionGeneration = try XCTUnwrap(
            store.authenticationSessionGenerationForCurrentAccount
        )

        await store.login(
            email: "other@duty.park",
            password: "12345678",
            rememberMe: false
        )
        XCTAssertEqual(
            store.state,
            .authenticated(LoginMember(
                id: 2,
                email: "other@duty.park",
                name: "Other",
                teamId: nil,
                team: nil,
                isAdmin: false,
                isImpersonating: false,
                originalMemberId: nil
            ))
        )

        // This completion belongs to the account and auth generation that was
        // active before the login above. It must not touch the replacement.
        let completed = await store.completeAccountDeletion(
            expectedMemberID: Self.testMember.id,
            expectedAuthenticationSessionGeneration: deletionGeneration
        )

        XCTAssertFalse(completed)
        XCTAssertEqual(
            store.state,
            .authenticated(LoginMember(
                id: 2,
                email: "other@duty.park",
                name: "Other",
                teamId: nil,
                team: nil,
                isAdmin: false,
                isImpersonating: false,
                originalMemberId: nil
            ))
        )
        let purgedMemberIDs = await purger.memberIDs()
        XCTAssertFalse(purgedMemberIDs.contains(2))
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
        let deletionGeneration = store.authenticationSessionGenerationForCurrentAccount!
        await store.completeAccountDeletion(
            expectedMemberID: Self.testMember.id,
            expectedAuthenticationSessionGeneration: deletionGeneration
        )
        XCTAssertEqual(store.accountDeletionAcceptedPresentation, .accepted)

        await store.login(email: "test@duty.park", password: "12345678", rememberMe: false)

        XCTAssertEqual(store.state, .authenticated(Self.testMember))
        XCTAssertNil(store.accountDeletionAcceptedPresentation)
    }

    @MainActor
    func testRestoreKeepsVerifiedMemberAuthenticatedWhenServerIsUnavailable() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-offline-session-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_000)
        let offlineStore = OfflineSessionStore(
            directoryURL: directory,
            now: { now }
        )
        try await offlineStore.save(Self.testMember, at: nil)
        URLProtocolStub.error = URLError(.notConnectedToInternet)

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            offlineSessionStore: offlineStore
        )
        await store.restore()

        XCTAssertEqual(store.state, .authenticated(Self.testMember))
        XCTAssertEqual(store.availability, .offline)
    }

    @MainActor
    func testUnauthorizedRestorePurgesSnapshotInsteadOfUsingItOffline() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-offline-session-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let offlineStore = OfflineSessionStore(directoryURL: directory)
        try await offlineStore.save(Self.testMember, at: nil)
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status", "/api/auth/refresh":
                return Self.response(request, status: 401)
            default:
                return Self.response(request, status: 404)
            }
        }

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            offlineSessionStore: offlineStore
        )
        await store.restore()

        XCTAssertEqual(store.state, .guest)
        XCTAssertEqual(store.availability, .online)
        let restored = await offlineStore.load(at: nil)
        XCTAssertNil(restored)
    }

    @MainActor
    func testLoginAsAnotherAccountPurgesSnapshotOwnedByPreviousAccount() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-offline-session-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let offlineStore = OfflineSessionStore(directoryURL: directory)
        try await offlineStore.save(Self.testMember, at: nil)
        let boundary = SessionBoundaryProbe()
        let replacementMember = LoginMember(
            id: 2,
            email: "other@duty.park",
            name: "Other",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: false,
            originalMemberId: nil
        )
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/token":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            case "/api/auth/status":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":2,"email":"other@duty.park","name":"Other","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            default:
                return Self.response(request, status: 404)
            }
        }

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .guest,
            offlineSessionStore: offlineStore,
            localDataPurger: boundary,
            cancelOfflineSync: { memberID in
                await boundary.recordCancel(for: memberID)
            }
        )
        await store.login(email: "other@duty.park", password: "password", rememberMe: false)

        XCTAssertEqual(store.state, .authenticated(replacementMember))
        let purgedMemberIDs = await boundary.memberIDs()
        XCTAssertEqual(purgedMemberIDs, [1])
        let events = await boundary.events()
        XCTAssertEqual(events, ["cancel:1", "purge:1"])
        let restored = await offlineStore.load(at: nil)
        XCTAssertEqual(restored, replacementMember)
    }

    @MainActor
    func testOfflineRevalidateKeepsSessionOnTransientFailureAndBecomesOnlineAfterSuccess() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-offline-session-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_000)
        let offlineStore = OfflineSessionStore(directoryURL: directory, now: { now })
        try await offlineStore.save(Self.testMember, at: nil)
        URLProtocolStub.error = URLError(.timedOut)

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            offlineSessionStore: offlineStore
        )
        await store.restore()
        XCTAssertEqual(store.availability, .offline)

        await store.revalidate()
        XCTAssertEqual(store.availability, .offline)
        XCTAssertEqual(store.state, .authenticated(Self.testMember))

        URLProtocolStub.error = nil
        URLProtocolStub.handler = { request in
            if request.url?.path == "/api/auth/status" {
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":1,"email":"test@duty.park","name":"Test","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            }
            return Self.response(request, status: 404)
        }
        await store.revalidate()

        XCTAssertEqual(store.availability, .online)
        XCTAssertEqual(store.state, .authenticated(Self.testMember))
    }

    @MainActor
    func testLogoutPurgesOwnedOfflineDataThroughSessionBoundary() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-offline-session-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let offlineStore = OfflineSessionStore(directoryURL: directory)
        try await offlineStore.save(Self.testMember, at: nil)
        let boundary = SessionBoundaryProbe()
        URLProtocolStub.handler = { request in
            if request.url?.path == "/api/auth/logout" {
                return Self.response(request, status: 204)
            }
            return Self.response(request, status: 404)
        }

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            offlineSessionStore: offlineStore,
            localDataPurger: boundary,
            cancelOfflineSync: { memberID in
                await boundary.recordCancel(for: memberID)
            }
        )
        await store.logout()

        XCTAssertEqual(store.state, .guest)
        let purgedMemberIDs = await boundary.memberIDs()
        XCTAssertEqual(purgedMemberIDs, [1])
        let events = await boundary.events()
        XCTAssertEqual(events, ["cancel:1", "purge:1"])
        let restored = await offlineStore.load(at: nil)
        XCTAssertNil(restored)
    }

    @MainActor
    func testContinueAsGuestAfterRestoreFailurePurgesAllLocalData() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-offline-session-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let offlineStore = OfflineSessionStore(directoryURL: directory)
        let boundary = SessionBoundaryProbe()
        URLProtocolStub.handler = { request in
            Self.response(request, status: 503)
        }

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            offlineSessionStore: offlineStore,
            localDataPurger: boundary,
            cancelOfflineSync: { memberID in
                await boundary.recordCancel(for: memberID)
            }
        )
        await store.restore()
        XCTAssertEqual(store.state, .restoreFailed)

        await store.continueAsGuestAfterRestoreFailure()

        XCTAssertEqual(store.state, .guest)
        let purgedMemberIDs = await boundary.memberIDs()
        XCTAssertEqual(purgedMemberIDs, [Int64?](arrayLiteral: nil))
        let events = await boundary.events()
        XCTAssertEqual(events, ["cancel:all", "purge:all"])
    }

    @MainActor
    func testFinalUnauthorizedResponsePurgesAuthenticatedOfflineData() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-offline-session-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let offlineStore = OfflineSessionStore(directoryURL: directory)
        try await offlineStore.save(Self.testMember, at: nil)
        let boundary = SessionBoundaryProbe()
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/protected", "/api/auth/refresh":
                return Self.response(request, status: 401)
            case "/api/auth/logout":
                return Self.response(request, status: 204)
            default:
                return Self.response(request, status: 404)
            }
        }

        let client = makeClient()
        let store = SessionStore(
            authService: AuthService(client: client),
            initialState: .authenticated(Self.testMember),
            offlineSessionStore: offlineStore,
            localDataPurger: boundary,
            cancelOfflineSync: { memberID in
                await boundary.recordCancel(for: memberID)
            }
        )
        await store.restore()
        // The store starts authenticated for this focused boundary test; wire
        // the API client's failure callback exactly as a restored session does.
        await client.setAuthenticationFailureHandler {
            await store.logout()
        }
        do {
            let _: ValueResponse = try await client.request("protected")
            XCTFail("Expected unauthorized response")
        } catch {
            // Expected.
        }

        let purgedMemberIDs = await boundary.memberIDs()
        XCTAssertEqual(purgedMemberIDs, [1])
        let events = await boundary.events()
        XCTAssertEqual(events, ["cancel:1", "purge:1"])
        XCTAssertEqual(store.state, .guest)
        let restored = await offlineStore.load(at: nil)
        XCTAssertNil(restored)
    }

    @MainActor
    func testDelayedUnauthorizedResponseFromPreviousAccountDoesNotTerminateReplacementSession() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dutypark-offline-session-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let offlineStore = OfflineSessionStore(directoryURL: directory)
        let delayedUnauthorized = DelayedUnauthorizedResponse()
        let replacementMember = LoginMember(
            id: 2,
            email: "other@duty.park",
            name: "Other",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: false,
            originalMemberId: nil
        )

        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                let body = delayedUnauthorized.nextStatusResponseBody()
                return Self.response(request, status: 200, body: body)
            case "/api/auth/token":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            case "/api/protected":
                return delayedUnauthorized.protectedResponse(for: request)
            case "/api/auth/refresh":
                return Self.response(
                    request,
                    status: 401,
                    body: #"{"status":401,"code":"auth.refresh.invalid"}"#
                )
            case "/api/auth/logout":
                return Self.response(request, status: 204)
            default:
                return Self.response(request, status: 404)
            }
        }
        URLProtocolStub.deliversAsynchronously = true

        let client = makeClient()
        let store = SessionStore(
            authService: AuthService(client: client),
            offlineSessionStore: offlineStore,
            localDataPurger: NoopSessionLocalDataPurger(),
            cancelOfflineSync: { _ in }
        )
        await store.restore()
        XCTAssertEqual(store.state, .authenticated(Self.testMember))

        let delayedRequest = Task {
            await requestFails(client)
        }
        for _ in 0..<500 where !delayedUnauthorized.protectedRequestStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(delayedUnauthorized.protectedRequestStarted)

        await store.login(email: "other@duty.park", password: "password", rememberMe: false)
        XCTAssertEqual(store.state, .authenticated(replacementMember))

        delayedUnauthorized.releaseProtectedRequest()
        let delayedRequestFailed = await delayedRequest.value
        XCTAssertTrue(delayedRequestFailed)
        XCTAssertEqual(
            store.state,
            .authenticated(replacementMember),
            "A 401 from account A must not log out account B"
        )
    }

    @MainActor
    func testDelayedOfflineRevalidationCannotReplaceNewerLogin() async throws {
        let delayedStatus = DelayedAuthenticationStatusResponse()
        let replacementMember = LoginMember(
            id: 2,
            email: "other@duty.park",
            name: "Other",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: false,
            originalMemberId: nil
        )
        let statusRequestCount = LockedCounter()

        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                if statusRequestCount.increment() == 1 {
                    return delayedStatus.response(for: request)
                }
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":2,"email":"other@duty.park","name":"Other","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            case "/api/auth/token":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            default:
                return Self.response(request, status: 404)
            }
        }
        URLProtocolStub.deliversAsynchronously = true

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            localDataPurger: NoopSessionLocalDataPurger(),
            cancelOfflineSync: { _ in },
            initialAvailability: .offline
        )
        let revalidation = Task { await store.revalidate() }
        for _ in 0..<500 where !delayedStatus.requestStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(delayedStatus.requestStarted)

        await store.login(email: "other@duty.park", password: "password", rememberMe: false)
        XCTAssertEqual(store.state, .authenticated(replacementMember))

        delayedStatus.release()
        await revalidation.value

        XCTAssertEqual(
            store.state,
            .authenticated(replacementMember),
            "A delayed restore result must not replace a newer login"
        )
    }

    @MainActor
    func testDelayedOfflineRevalidationUnauthenticatedResultCannotLogOutNewerLogin() async throws {
        let delayedStatus = DelayedAuthenticationStatusResponse(
            statusCode: 200,
            body: ""
        )
        let replacementMember = LoginMember(
            id: 2,
            email: "other@duty.park",
            name: "Other",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: false,
            originalMemberId: nil
        )
        let statusRequestCount = LockedCounter()

        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                if statusRequestCount.increment() == 1 {
                    return delayedStatus.response(for: request)
                }
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":2,"email":"other@duty.park","name":"Other","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            case "/api/auth/refresh":
                return Self.response(request, status: 401)
            case "/api/auth/token":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            default:
                return Self.response(request, status: 404)
            }
        }
        URLProtocolStub.deliversAsynchronously = true

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            localDataPurger: NoopSessionLocalDataPurger(),
            cancelOfflineSync: { _ in },
            initialAvailability: .offline
        )
        let revalidation = Task { await store.revalidate() }
        for _ in 0..<500 where !delayedStatus.requestStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(delayedStatus.requestStarted)

        await store.login(email: "other@duty.park", password: "password", rememberMe: false)
        XCTAssertEqual(store.state, .authenticated(replacementMember))

        delayedStatus.release()
        await revalidation.value

        XCTAssertEqual(
            store.state,
            .authenticated(replacementMember),
            "A delayed unauthenticated result must not log out a newer login"
        )
    }

    @MainActor
    func testOfflineRevalidationIgnoresMemberFromDifferentAccount() async throws {
        let delayedStatus = DelayedAuthenticationStatusResponse(
            body: #"{"id":2,"email":"other@duty.park","name":"Other","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
        )
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                return delayedStatus.response(for: request)
            default:
                return Self.response(request, status: 404)
            }
        }
        URLProtocolStub.deliversAsynchronously = true

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            localDataPurger: NoopSessionLocalDataPurger(),
            cancelOfflineSync: { _ in },
            initialAvailability: .offline
        )
        let revalidation = Task { await store.revalidate() }
        for _ in 0..<500 where !delayedStatus.requestStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(delayedStatus.requestStarted)

        delayedStatus.release()
        await revalidation.value

        XCTAssertEqual(
            store.state,
            .authenticated(Self.testMember),
            "A restore response for another account must not replace the offline session"
        )
        XCTAssertEqual(store.availability, .offline)
    }

    @MainActor
    func testAuthenticatedLoginCancelsCurrentAccountSyncBeforeChangingAuthCookies() async {
        let transition = AuthTransitionProbe()
        let replacementMember = LoginMember(
            id: 2,
            email: "other@duty.park",
            name: "Other",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: false,
            originalMemberId: nil
        )
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                let body = transition.authRequestStarted
                    ? #"{"id":2,"email":"other@duty.park","name":"Other","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                    : #"{"id":1,"email":"test@duty.park","name":"Test","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                return Self.response(request, status: 200, body: body)
            case "/api/auth/token":
                transition.markAuthRequestStarted()
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            case "/api/protected", "/api/auth/refresh":
                return Self.response(request, status: 401)
            default:
                return Self.response(request, status: 404)
            }
        }

        let client = makeClient()
        let store = SessionStore(
            authService: AuthService(client: client),
            localDataPurger: NoopSessionLocalDataPurger(),
            cancelOfflineSync: { memberID in
                transition.markCancellationStarted(for: memberID)
                await transition.waitForCancellationRelease()
            }
        )
        await store.restore()
        XCTAssertEqual(store.state, .authenticated(Self.testMember))

        let loginTask = Task {
            await store.login(email: "other@duty.park", password: "password", rememberMe: false)
        }
        for _ in 0..<500 where !transition.cancellationStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }

        XCTAssertTrue(transition.cancellationStarted)
        XCTAssertEqual(transition.cancelledMemberID, 1)
        XCTAssertFalse(
            transition.authRequestStarted,
            "The token request must wait until the previous account's sync is cancelled"
        )

        let staleRequestFinished = LockedFlag()
        let staleRequest = Task {
            defer { staleRequestFinished.set() }
            return await requestFails(client)
        }
        for _ in 0..<500
        where !staleRequestFinished.value && transition.cancellationCount < 2 {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(staleRequestFinished.value)
        XCTAssertEqual(
            transition.cancellationCount,
            1,
            "A request started after transition invalidation must not cancel the old session again"
        )
        XCTAssertEqual(store.state, .authenticated(Self.testMember))

        transition.releaseCancellation()
        await loginTask.value
        let staleRequestFailed = await staleRequest.value
        XCTAssertTrue(staleRequestFailed)

        XCTAssertTrue(transition.authRequestStarted)
        XCTAssertEqual(store.state, .authenticated(replacementMember))
    }

    @MainActor
    func testAuthenticatedExternalLoginCancelsBeforeStatusAuthCall() async throws {
        let transition = AuthTransitionProbe()
        let replacementMember = LoginMember(
            id: 2,
            email: "other@duty.park",
            name: "Other",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: false,
            originalMemberId: nil
        )
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                transition.markAuthRequestStarted()
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":2,"email":"other@duty.park","name":"Other","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            default:
                return Self.response(request, status: 404)
            }
        }

        let client = makeClient()
        let store = SessionStore(
            authService: AuthService(client: client),
            initialState: .authenticated(Self.testMember),
            localDataPurger: NoopSessionLocalDataPurger(),
            cancelOfflineSync: { memberID in
                transition.markCancellationStarted(for: memberID)
                await transition.waitForCancellationRelease()
            }
        )
        let externalLoginTask = Task {
            try? await store.finishExternalLogin(emitsHaptic: false)
        }
        for _ in 0..<500 where !transition.cancellationStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }

        XCTAssertTrue(transition.cancellationStarted)
        XCTAssertEqual(transition.cancelledMemberID, 1)
        XCTAssertFalse(transition.authRequestStarted)

        transition.releaseCancellation()
        await externalLoginTask.value

        XCTAssertEqual(store.state, .authenticated(replacementMember))
        XCTAssertEqual(transition.cancellationCount, 1)
    }

    @MainActor
    func testAuthenticatedImpersonationCancelsBeforeTokenAuthCall() async throws {
        let transition = AuthTransitionProbe()
        let impersonatedMember = LoginMember(
            id: 2,
            email: nil,
            name: "Managed",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: true,
            originalMemberId: 1
        )
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/impersonate/2":
                transition.markAuthRequestStarted()
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            case "/api/auth/status":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":2,"email":null,"name":"Managed","teamId":null,"team":null,"isAdmin":false,"isImpersonating":true,"originalMemberId":1}"#
                )
            default:
                return Self.response(request, status: 404)
            }
        }

        let client = makeClient()
        let store = SessionStore(
            authService: AuthService(client: client),
            initialState: .authenticated(Self.testMember),
            localDataPurger: NoopSessionLocalDataPurger(),
            cancelOfflineSync: { memberID in
                transition.markCancellationStarted(for: memberID)
                await transition.waitForCancellationRelease()
            }
        )
        let impersonationTask = Task {
            try? await store.impersonate(memberId: 2)
        }
        for _ in 0..<500 where !transition.cancellationStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }

        XCTAssertTrue(transition.cancellationStarted)
        XCTAssertEqual(transition.cancelledMemberID, 1)
        XCTAssertFalse(transition.authRequestStarted)

        transition.releaseCancellation()
        await impersonationTask.value

        XCTAssertEqual(store.state, .authenticated(impersonatedMember))
        XCTAssertEqual(transition.cancellationCount, 1)
    }

    @MainActor
    func testAuthenticatedRestoreOriginalAccountCancelsBeforeRestoreAuthCall() async {
        let transition = AuthTransitionProbe()
        let impersonatedMember = LoginMember(
            id: 2,
            email: nil,
            name: "Managed",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: true,
            originalMemberId: 1
        )
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/restore":
                transition.markAuthRequestStarted()
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

        let client = makeClient()
        let store = SessionStore(
            authService: AuthService(client: client),
            initialState: .authenticated(impersonatedMember),
            localDataPurger: NoopSessionLocalDataPurger(),
            cancelOfflineSync: { memberID in
                transition.markCancellationStarted(for: memberID)
                await transition.waitForCancellationRelease()
            }
        )
        let restoreTask = Task {
            await store.restoreOriginalAccount()
        }
        for _ in 0..<500 where !transition.cancellationStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }

        XCTAssertTrue(transition.cancellationStarted)
        XCTAssertEqual(transition.cancelledMemberID, 2)
        XCTAssertFalse(transition.authRequestStarted)

        transition.releaseCancellation()
        await restoreTask.value

        XCTAssertEqual(store.state, .authenticated(Self.testMember))
        XCTAssertEqual(transition.cancellationCount, 1)
    }

    @MainActor
    func testLateExternalLoginFailureCannotTerminateNewerLogin() async throws {
        let delayedStatus = DelayedAuthenticationStatusResponse(statusCode: 500)
        let replacementMember = LoginMember(
            id: 2,
            email: "other@duty.park",
            name: "Other",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: false,
            originalMemberId: nil
        )
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/status":
                if !delayedStatus.requestStarted {
                    return delayedStatus.response(for: request)
                }
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":2,"email":"other@duty.park","name":"Other","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            case "/api/auth/token":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            default:
                return Self.response(request, status: 404)
            }
        }
        URLProtocolStub.deliversAsynchronously = true

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            localDataPurger: NoopSessionLocalDataPurger(),
            cancelOfflineSync: { _ in }
        )
        let externalLogin = Task {
            try? await store.finishExternalLogin(emitsHaptic: false)
        }
        for _ in 0..<500 where !delayedStatus.requestStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(delayedStatus.requestStarted)

        await store.login(
            email: "other@duty.park",
            password: "password",
            rememberMe: false
        )
        XCTAssertEqual(store.state, .authenticated(replacementMember))

        delayedStatus.release()
        await externalLogin.value

        XCTAssertEqual(
            store.state,
            .authenticated(replacementMember),
            "A late external-login failure must not terminate a newer login"
        )
    }

    @MainActor
    func testLateImpersonationFailureCannotTerminateNewerLogin() async throws {
        let delayedStatus = DelayedAuthenticationStatusResponse(statusCode: 500)
        let replacementMember = LoginMember(
            id: 2,
            email: "other@duty.park",
            name: "Other",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: false,
            originalMemberId: nil
        )
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/impersonate/2":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            case "/api/auth/status":
                if !delayedStatus.requestStarted {
                    return delayedStatus.response(for: request)
                }
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":2,"email":"other@duty.park","name":"Other","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            case "/api/auth/token":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            default:
                return Self.response(request, status: 404)
            }
        }
        URLProtocolStub.deliversAsynchronously = true

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            localDataPurger: NoopSessionLocalDataPurger(),
            cancelOfflineSync: { _ in }
        )
        let impersonation = Task {
            try? await store.impersonate(memberId: 2)
        }
        for _ in 0..<500 where !delayedStatus.requestStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(delayedStatus.requestStarted)

        await store.login(
            email: "other@duty.park",
            password: "password",
            rememberMe: false
        )
        XCTAssertEqual(store.state, .authenticated(replacementMember))

        delayedStatus.release()
        await impersonation.value

        XCTAssertEqual(
            store.state,
            .authenticated(replacementMember),
            "A late impersonation failure must not terminate a newer login"
        )
        XCTAssertNil(store.authenticationTransitionFailure)
    }

    @MainActor
    func testLateRestoreOriginalAccountFailureCannotTerminateNewerLogin() async throws {
        let delayedStatus = DelayedAuthenticationStatusResponse(statusCode: 500)
        let impersonatedMember = LoginMember(
            id: 3,
            email: nil,
            name: "Managed",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: true,
            originalMemberId: 1
        )
        let replacementMember = LoginMember(
            id: 2,
            email: "other@duty.park",
            name: "Other",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: false,
            originalMemberId: nil
        )
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/restore":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            case "/api/auth/status":
                if !delayedStatus.requestStarted {
                    return delayedStatus.response(for: request)
                }
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":2,"email":"other@duty.park","name":"Other","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            case "/api/auth/token":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            default:
                return Self.response(request, status: 404)
            }
        }
        URLProtocolStub.deliversAsynchronously = true

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(impersonatedMember),
            localDataPurger: NoopSessionLocalDataPurger(),
            cancelOfflineSync: { _ in }
        )
        let restore = Task {
            await store.restoreOriginalAccount()
        }
        for _ in 0..<500 where !delayedStatus.requestStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(delayedStatus.requestStarted)

        await store.login(
            email: "other@duty.park",
            password: "password",
            rememberMe: false
        )
        XCTAssertEqual(store.state, .authenticated(replacementMember))

        delayedStatus.release()
        await restore.value

        XCTAssertEqual(
            store.state,
            .authenticated(replacementMember),
            "A late restore failure must not terminate a newer login"
        )
    }

    @MainActor
    func testCleanupBlocksNewLoginUntilRestoreFailureCleanupCompletes() async throws {
        let delayedCleanup = DelayedCleanupProbe()
        let replacementMember = LoginMember(
            id: 2,
            email: "other@duty.park",
            name: "Other",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: false,
            originalMemberId: nil
        )
        let impersonatedMember = LoginMember(
            id: 3,
            email: nil,
            name: "Managed",
            teamId: nil,
            team: nil,
            isAdmin: false,
            isImpersonating: true,
            originalMemberId: 1
        )
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/restore":
                return Self.response(request, status: 500)
            case "/api/auth/token":
                return Self.response(request, status: 200, body: #"{"expiresIn":3600}"#)
            case "/api/auth/status":
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":2,"email":"other@duty.park","name":"Other","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
                )
            case "/api/auth/logout":
                return Self.response(request, status: 204)
            default:
                return Self.response(request, status: 404)
            }
        }

        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(impersonatedMember),
            unregisterPush: {
                await delayedCleanup.waitForRelease()
            },
            localDataPurger: NoopSessionLocalDataPurger(),
            cancelOfflineSync: { _ in }
        )
        let restore = Task {
            await store.restoreOriginalAccount()
        }
        for _ in 0..<500 {
            if await delayedCleanup.started { break }
            try? await Task.sleep(for: .milliseconds(1))
        }
        let cleanupStarted = await delayedCleanup.started
        XCTAssertTrue(cleanupStarted)

        let loginFinished = LockedFlag()
        let login = Task {
            await store.login(
                email: "other@duty.park",
                password: "password",
                rememberMe: false
            )
            loginFinished.set()
        }
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(
            loginFinished.value,
            "A new login must wait while the previous session cleanup is in progress"
        )

        await delayedCleanup.release()
        await restore.value
        await login.value

        XCTAssertEqual(store.state, SessionState.authenticated(replacementMember))
    }

    func testRequestUsesSnapshotCookieWhenAutomaticCookieHandlingIsDisabled() async throws {
        let cookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: "dutypark.test",
            .path: "/",
            .name: "access_token",
            .value: "snapshot-token",
            .secure: "TRUE",
        ]))
        HTTPCookieStorage.shared.setCookie(cookie)
        let receivedCookie = LockedString()
        URLProtocolStub.handler = { request in
            receivedCookie.set(request.value(forHTTPHeaderField: "Cookie") ?? "")
            return Self.response(request, status: 200, body: #"{"value":1}"#)
        }

        let value: ValueResponse = try await makeClient().request("protected")

        XCTAssertEqual(value.value, 1)
        XCTAssertTrue(receivedCookie.value.contains("access_token=snapshot-token"))
    }

    func testRefreshRetryUsesAccessCookieIssuedByRefreshResponse() async throws {
        let oldCookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: "dutypark.test",
            .path: "/",
            .name: "access_token",
            .value: "old-access",
            .secure: "TRUE",
        ]))
        HTTPCookieStorage.shared.setCookie(oldCookie)
        let protectedRequestCookies = LockedRequests()
        let protectedRequestCount = LockedCounter()
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/protected":
                protectedRequestCookies.append(
                    request.value(forHTTPHeaderField: "Cookie") ?? ""
                )
                if protectedRequestCount.increment() == 1 {
                    return Self.response(
                        request,
                        status: 401,
                        body: #"{"status":401,"code":"auth.required"}"#
                    )
                }
                guard request.value(forHTTPHeaderField: "Cookie")?.contains(
                    "access_token=new-access"
                ) == true else {
                    return Self.response(request, status: 401)
                }
                return Self.response(request, status: 200, body: #"{"value":1}"#)
            case "/api/auth/refresh":
                return Self.response(
                    request,
                    status: 200,
                    headers: [
                        "Set-Cookie": "access_token=new-access; Path=/; Secure; HttpOnly"
                    ],
                    body: #"{"expiresIn":3600}"#
                )
            default:
                return Self.response(request, status: 404)
            }
        }

        let response: ValueResponse = try await makeClient().request("protected")

        XCTAssertEqual(response.value, 1)
        XCTAssertEqual(protectedRequestCookies.values.count, 2)
        XCTAssertTrue(protectedRequestCookies.values[0].contains("access_token=old-access"))
        XCTAssertTrue(protectedRequestCookies.values[1].contains("access_token=new-access"))
    }

    func testClearLocalAuthenticationDropsLateSetCookieFromOldRequest() async throws {
        let delayedResponse = DelayedSetCookieResponse()
        let storage = CookieStorageProbe(
            onDelete: {},
            onSetCookies: {}
        )
        let oldCookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: "dutypark.test",
            .path: "/",
            .name: "access_token",
            .value: "old-access",
            .secure: "TRUE",
        ]))
        storage.setCookie(oldCookie)
        storage.beginObservingSetCookies()
        URLProtocolStub.handler = { request in
            delayedResponse.response(for: request)
        }

        let client = makeClient(cookieStorage: storage)
        let requestTask = Task {
            _ = try? await client.request("protected") as ValueResponse
        }
        for _ in 0..<500 where !delayedResponse.requestStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(delayedResponse.requestStarted)

        await client.clearLocalAuthentication()
        delayedResponse.release()
        await requestTask.value

        XCTAssertFalse(storage.cookies?.contains {
            $0.name == "access_token" || $0.name == "refresh_token"
        } == true)
    }

    func testLateSetCookieFromPreviousAuthenticationEpochCannotOverwriteReplacementCookie() async throws {
        let delayedResponse = DelayedSetCookieResponse()
        let replacementCookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: "dutypark.test",
            .path: "/",
            .name: "access_token",
            .value: "replacement-token",
            .secure: "TRUE",
        ]))
        URLProtocolStub.handler = { request in
            delayedResponse.response(for: request)
        }

        let client = makeClient()
        let requestTask = Task {
            try await client.request("protected") as ValueResponse
        }
        for _ in 0..<500 where !delayedResponse.requestStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(delayedResponse.requestStarted)

        await client.invalidateAuthenticationSession()
        HTTPCookieStorage.shared.setCookie(replacementCookie)
        delayedResponse.release()

        let response = try await requestTask.value
        XCTAssertEqual(response.value, 1)
        XCTAssertEqual(
            HTTPCookieStorage.shared.cookies?.first(where: {
                $0.name == "access_token"
            })?.value,
            "replacement-token"
        )
    }

    func testAuthenticatedResponseFromPreviousEpochIsCancelled() async throws {
        let delayedResponse = DelayedSetCookieResponse()
        URLProtocolStub.handler = { request in
            delayedResponse.response(for: request)
        }

        let client = makeClient()
        await client.setAuthenticationSessionContext(
            AuthenticationSessionContext(memberID: 1, generation: 1)
        )
        let requestTask = Task {
            try await client.request("protected") as ValueResponse
        }
        for _ in 0..<500 where !delayedResponse.requestStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(delayedResponse.requestStarted)

        await client.invalidateAuthenticationSession()
        delayedResponse.release()

        do {
            _ = try await requestTask.value
            XCTFail("A response from a previous authenticated epoch must be cancelled")
        } catch is CancellationError {
            // Expected.
        }
    }

    func testLateRefreshSetCookieFromPreviousAuthenticationEpochCannotOverwriteReplacementCookie() async throws {
        let delayedRefresh = DelayedSetCookieResponse()
        let protectedRequestCount = LockedCounter()
        let replacementCookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: "dutypark.test",
            .path: "/",
            .name: "access_token",
            .value: "replacement-token",
            .secure: "TRUE",
        ]))
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/protected":
                if protectedRequestCount.increment() == 1 {
                    return Self.response(
                        request,
                        status: 401,
                        body: #"{"status":401,"code":"auth.required"}"#
                    )
                }
                return Self.response(request, status: 200, body: #"{"value":1}"#)
            case "/api/auth/refresh":
                return delayedRefresh.response(for: request)
            default:
                return Self.response(request, status: 404)
            }
        }

        let client = makeClient()
        let requestTask = Task {
            do {
                let _: ValueResponse = try await client.request("protected")
            } catch {
                // A transition may cancel the old refresh task; the cookie
                // assertion below is independent of that request outcome.
            }
        }
        for _ in 0..<500 where !delayedRefresh.requestStarted {
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(delayedRefresh.requestStarted)

        await client.invalidateAuthenticationSession()
        HTTPCookieStorage.shared.setCookie(replacementCookie)
        delayedRefresh.release()
        await requestTask.value

        XCTAssertEqual(
            HTTPCookieStorage.shared.cookies?.first(where: {
                $0.name == "access_token"
            })?.value,
            "replacement-token"
        )
    }

    @MainActor
    func testAuthenticatedLoginFailureAfterReplacementCookieDoesNotRestorePreviousAccount() async throws {
        let boundary = SessionBoundaryProbe()
        let oldCookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: "dutypark.test",
            .path: "/",
            .name: "access_token",
            .value: "account-a",
            .secure: "TRUE",
        ]))
        HTTPCookieStorage.shared.setCookie(oldCookie)
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/token":
                return Self.response(
                    request,
                    status: 200,
                    headers: [
                        "Set-Cookie": "access_token=replacement; Path=/; Secure; HttpOnly"
                    ],
                    body: #"{"expiresIn":3600}"#
                )
            case "/api/auth/status", "/api/auth/refresh":
                return Self.response(request, status: 401)
            default:
                return Self.response(request, status: 404)
            }
        }
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            localDataPurger: boundary,
            cancelOfflineSync: { memberID in
                await boundary.recordCancel(for: memberID)
            }
        )

        await store.login(
            email: "other@duty.park",
            password: "password",
            rememberMe: false
        )

        XCTAssertEqual(store.state, .guest)
        let events = await boundary.events()
        XCTAssertEqual(events, ["cancel:1", "purge:1"])
        XCTAssertFalse(HTTPCookieStorage.shared.cookies?.contains {
            $0.name == "access_token" || $0.name == "refresh_token"
        } == true)
    }

    @MainActor
    func testAuthenticatedImpersonationFailureAfterReplacementCookieDoesNotRestorePreviousAccount() async throws {
        let boundary = SessionBoundaryProbe()
        let oldCookie = try XCTUnwrap(HTTPCookie(properties: [
            .domain: "dutypark.test",
            .path: "/",
            .name: "access_token",
            .value: "account-a",
            .secure: "TRUE",
        ]))
        HTTPCookieStorage.shared.setCookie(oldCookie)
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/impersonate/2":
                return Self.response(
                    request,
                    status: 200,
                    headers: [
                        "Set-Cookie": "access_token=replacement; Path=/; Secure; HttpOnly"
                    ],
                    body: #"{"expiresIn":3600}"#
                )
            case "/api/auth/status":
                return Self.response(request, status: 401)
            default:
                return Self.response(request, status: 404)
            }
        }
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .authenticated(Self.testMember),
            localDataPurger: boundary,
            cancelOfflineSync: { memberID in
                await boundary.recordCancel(for: memberID)
            }
        )

        do {
            try await store.impersonate(memberId: 2)
            XCTFail("Expected impersonation status failure")
        } catch {
            // Expected.
        }

        XCTAssertEqual(store.state, .guest)
        XCTAssertEqual(
            store.authenticationTransitionFailure,
            .impersonationFailed
        )
        let events = await boundary.events()
        XCTAssertEqual(events, ["cancel:1", "purge:1"])
        XCTAssertFalse(HTTPCookieStorage.shared.cookies?.contains {
            $0.name == "access_token" || $0.name == "refresh_token"
        } == true)

        store.dismissAuthenticationTransitionFailure()
        XCTAssertNil(store.authenticationTransitionFailure)
    }

    @MainActor
    func testGuestLoginFailureAfterReplacementCookieClearsCredentials() async throws {
        URLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/auth/token":
                return Self.response(
                    request,
                    status: 200,
                    headers: [
                        "Set-Cookie": "access_token=replacement; Path=/; Secure; HttpOnly"
                    ],
                    body: #"{"expiresIn":3600}"#
                )
            case "/api/auth/status", "/api/auth/refresh":
                return Self.response(request, status: 401)
            default:
                return Self.response(request, status: 404)
            }
        }
        let store = SessionStore(
            authService: AuthService(client: makeClient()),
            initialState: .guest
        )

        await store.login(
            email: "other@duty.park",
            password: "password",
            rememberMe: false
        )

        XCTAssertEqual(store.state, .guest)
        XCTAssertFalse(HTTPCookieStorage.shared.cookies?.contains {
            $0.name == "access_token" || $0.name == "refresh_token"
        } == true)
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

    private func makeClient(cookieStorage: HTTPCookieStorage = .shared) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        configuration.httpCookieStorage = cookieStorage
        configuration.httpShouldSetCookies = false
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

private final class LockedString: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = ""

    func set(_ value: String) {
        lock.lock()
        storedValue = value
        lock.unlock()
    }

    var value: String {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
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

private final class AuthTransitionProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let cancellationGate = TestAsyncGate()
    private var storedCancellationCount = 0
    private var storedCancellationStarted = false
    private var storedCancelledMemberID: Int64?
    private var storedAuthRequestStarted = false

    var cancellationStarted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedCancellationStarted
    }

    var cancellationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedCancellationCount
    }

    var cancelledMemberID: Int64? {
        lock.lock()
        defer { lock.unlock() }
        return storedCancelledMemberID
    }

    var authRequestStarted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedAuthRequestStarted
    }

    func markCancellationStarted(for memberID: Int64?) {
        lock.lock()
        storedCancellationCount += 1
        storedCancellationStarted = true
        storedCancelledMemberID = memberID
        lock.unlock()
    }

    func markAuthRequestStarted() {
        lock.lock()
        storedAuthRequestStarted = true
        lock.unlock()
    }

    func waitForCancellationRelease() async {
        await cancellationGate.wait()
    }

    func releaseCancellation() {
        Task { await cancellationGate.open() }
    }
}

private final class DelayedUnauthorizedResponse: @unchecked Sendable {
    private let condition = NSCondition()
    private var protectedRequestHasStarted = false
    private var protectedRequestIsReleased = false
    private var statusRequestCount = 0

    var protectedRequestStarted: Bool {
        condition.lock()
        defer { condition.unlock() }
        return protectedRequestHasStarted
    }

    func nextStatusResponseBody() -> String {
        condition.lock()
        defer { condition.unlock() }
        defer { statusRequestCount += 1 }
        if statusRequestCount == 0 {
            return #"{"id":1,"email":"test@duty.park","name":"Test","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
        }
        return #"{"id":2,"email":"other@duty.park","name":"Other","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
    }

    func protectedResponse(for request: URLRequest) -> (HTTPURLResponse, Data) {
        condition.lock()
        protectedRequestHasStarted = true
        condition.broadcast()
        while !protectedRequestIsReleased {
            condition.wait()
        }
        condition.unlock()
        return response(request, status: 401)
    }

    func releaseProtectedRequest() {
        condition.lock()
        protectedRequestIsReleased = true
        condition.broadcast()
        condition.unlock()
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

private final class DelayedSetCookieResponse: @unchecked Sendable {
    private let condition = NSCondition()
    private var hasStarted = false
    private var isReleased = false

    var requestStarted: Bool {
        condition.lock()
        defer { condition.unlock() }
        return hasStarted
    }

    func response(for request: URLRequest) -> (HTTPURLResponse, Data) {
        condition.lock()
        hasStarted = true
        condition.broadcast()
        while !isReleased {
            condition.wait()
        }
        condition.unlock()
        return (
            HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "Set-Cookie": "access_token=stale-token; Path=/; Secure; HttpOnly"
                ]
            )!,
            Data(#"{"value":1}"#.utf8)
        )
    }

    func release() {
        condition.lock()
        isReleased = true
        condition.broadcast()
        condition.unlock()
    }
}

private final class DelayedAuthenticationStatusResponse: @unchecked Sendable {
    private let condition = NSCondition()
    private let statusCode: Int
    private let responseBody: Data
    private var hasStarted = false
    private var isReleased = false

    init(
        statusCode: Int = 200,
        body: String = #"{"id":1,"email":"test@duty.park","name":"Test","teamId":null,"team":null,"isAdmin":false,"isImpersonating":false,"originalMemberId":null}"#
    ) {
        self.statusCode = statusCode
        self.responseBody = Data(body.utf8)
    }

    var requestStarted: Bool {
        condition.lock()
        defer { condition.unlock() }
        return hasStarted
    }

    func response(for request: URLRequest) -> (HTTPURLResponse, Data) {
        condition.lock()
        hasStarted = true
        condition.broadcast()
        while !isReleased {
            condition.wait()
        }
        condition.unlock()
        return (
            HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!,
            responseBody
        )
    }

    func release() {
        condition.lock()
        isReleased = true
        condition.broadcast()
        condition.unlock()
    }
}

private actor DelayedCleanupProbe {
    private var hasStarted = false
    private var isReleased = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var started: Bool {
        hasStarted
    }

    func waitForRelease() async {
        hasStarted = true
        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        isReleased = true
        let pendingWaiters = waiters
        waiters.removeAll()
        pendingWaiters.forEach { $0.resume() }
    }
}

private final class CookieStorageProbe: HTTPCookieStorage, @unchecked Sendable {
    private let onDelete: @Sendable () -> Void
    private let onSetCookies: @Sendable () -> Void
    private let lock = NSLock()
    private var isObservingSetCookies = false

    init(
        onDelete: @escaping @Sendable () -> Void,
        onSetCookies: @escaping @Sendable () -> Void
    ) {
        self.onDelete = onDelete
        self.onSetCookies = onSetCookies
        super.init()
    }

    func beginObservingSetCookies() {
        lock.lock()
        isObservingSetCookies = true
        lock.unlock()
    }

    override func deleteCookie(_ cookie: HTTPCookie) {
        onDelete()
        super.deleteCookie(cookie)
    }

    override func setCookies(
        _ cookies: [HTTPCookie],
        for URL: URL?,
        mainDocumentURL: URL?
    ) {
        super.setCookies(cookies, for: URL, mainDocumentURL: mainDocumentURL)
        lock.lock()
        let shouldNotify = isObservingSetCookies
        lock.unlock()
        if shouldNotify {
            onSetCookies()
        }
    }
}

private actor SessionBoundaryProbe: SessionLocalDataPurging {
    private var storedMemberIDs: [Int64?] = []
    private var storedEvents: [String] = []

    func purgeLocalData(for memberID: Int64?) async {
        storedMemberIDs.append(memberID)
        storedEvents.append(memberID.map { "purge:" + String($0) } ?? "purge:all")
    }

    func memberIDs() -> [Int64?] {
        storedMemberIDs
    }

    func recordCancel(for memberID: Int64?) {
        storedEvents.append(memberID.map { "cancel:" + String($0) } ?? "cancel:all")
    }

    func events() -> [String] {
        storedEvents
    }
}

@MainActor
private final class APIClientAuthReceiptTokenStore: AccountDeletionReceiptTokenStoring {
    private var token: String?

    func loadToken() throws -> String? { token }

    func saveToken(_ token: String) throws { self.token = token }

    func clearToken() { token = nil }
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
    nonisolated(unsafe) static var error: URLError?
    nonisolated(unsafe) static var deliversAsynchronously = false

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
        let deliver = { [weak self] in
            guard let self else { return }
            let (response, data) = handler(request)
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !data.isEmpty {
                self.client?.urlProtocol(self, didLoad: data)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        if Self.deliversAsynchronously {
            DispatchQueue.global().async(execute: deliver)
        } else {
            deliver()
        }
    }

    override func stopLoading() {}
}
