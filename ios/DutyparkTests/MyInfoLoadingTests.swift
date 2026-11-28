import Foundation
import Testing
@testable import Dutypark

@Suite(.serialized)
@MainActor
struct MyInfoLoadingTests {
    @Test
    func showsTheMemberBeforeSlowSectionsFinishAndFillsThemInIndependently() async throws {
        let responder = MyInfoStubResponder(bodies: Self.bodies)
        responder.hold("/api/auth/refresh-tokens")
        let model = SettingsViewModel(service: Self.service(responder))

        let load = Task { await model.load(.myInfo) }
        try await waitUntil { model.loadedSections.isSuperset(of: [.family, .friends, .managers, .managedAccounts, .dutyPattern]) }

        #expect(model.member?.id == 1)
        #expect(model.isLoading)
        #expect(!model.isLoadingMember)
        #expect(!model.loadedSections.contains(.sessions))
        #expect(model.loadingSections == [.sessions])

        responder.release("/api/auth/refresh-tokens")
        await load.value

        #expect(model.loadedSections.contains(.sessions))
        #expect(model.loadingSections.isEmpty)
        #expect(!model.isLoading)
    }

    @Test
    func aSectionFailureKeepsTheScreenAndOtherSections() async throws {
        var bodies = Self.bodies
        bodies["/api/auth/refresh-tokens"] = nil
        bodies["/api/members/managers"] = nil
        let responder = MyInfoStubResponder(bodies: bodies)
        let model = SettingsViewModel(service: Self.service(responder))

        await model.load(.myInfo)

        #expect(model.member?.id == 1)
        #expect(!model.loadedSections.contains(.sessions))
        #expect(!model.loadedSections.contains(.managers))
        #expect(model.loadedSections.isSuperset(of: [.family, .friends, .managedAccounts, .dutyPattern]))
        #expect(model.loadingSections.isEmpty)
        #expect(model.noticeKey == nil)
    }

    @Test
    func storesSessionsSortedOnceWhenTheyArrive() async throws {
        let responder = MyInfoStubResponder(bodies: Self.bodies)
        let model = SettingsViewModel(service: Self.service(responder))

        await model.load(.myInfo)

        // The server returns 102 (older), 103 (current) and 101 (newest other session).
        #expect(model.sessions.map(\.id) == [103, 101, 102])
    }

    @Test
    func reentryShowsTheLastSnapshotForTheSameSignedInAccountWhileRefreshing() async throws {
        let store = MyInfoSnapshotStore()
        let scope = MyInfoSnapshotScope(memberID: 1, sessionGeneration: 7)
        let first = MyInfoStubResponder(bodies: Self.bodies)
        let firstModel = SettingsViewModel(service: Self.service(first), snapshotStore: store)
        await firstModel.load(.myInfo, snapshotScope: scope)
        #expect(store.snapshot(for: scope) != nil)

        let second = MyInfoStubResponder(bodies: Self.bodies)
        second.holdAll()
        let secondModel = SettingsViewModel(service: Self.service(second), snapshotStore: store)
        let load = Task { await secondModel.load(.myInfo, snapshotScope: scope) }
        try await waitUntil { second.requestedPaths.contains("/api/members/me") }

        #expect(secondModel.member?.id == 1)
        #expect(secondModel.sessions.map(\.id) == [103, 101, 102])
        #expect(secondModel.loadedSections.isSuperset(of: [
            .family, .friends, .managers, .managedAccounts, .sessions, .dutyPattern,
        ]))
        // Sections refresh in the background, but none falls back to a loading placeholder.
        #expect(!secondModel.loadingSections.isEmpty)
        #expect(secondModel.loadingSections.isSubset(of: secondModel.loadedSections))

        second.releaseAll()
        await load.value
        #expect(secondModel.member?.id == 1)
    }

    @Test
    func snapshotsNeverCrossSessionsOrMembers() async throws {
        let store = MyInfoSnapshotStore()
        let scope = MyInfoSnapshotScope(memberID: 1, sessionGeneration: 7)
        let model = SettingsViewModel(
            service: Self.service(MyInfoStubResponder(bodies: Self.bodies)),
            snapshotStore: store
        )
        await model.load(.myInfo, snapshotScope: scope)

        // A new login, account switch or impersonation always starts a new session generation.
        #expect(store.snapshot(for: MyInfoSnapshotScope(memberID: 1, sessionGeneration: 8)) == nil)
        #expect(store.snapshot(for: scope) == nil)

        for otherScope in [
            MyInfoSnapshotScope(memberID: 2, sessionGeneration: 9),
            nil,
        ] {
            let responder = MyInfoStubResponder(bodies: Self.bodies)
            responder.holdAll()
            let other = SettingsViewModel(service: Self.service(responder), snapshotStore: store)
            let load = Task { await other.load(.myInfo, snapshotScope: otherScope) }
            try await waitUntil { responder.requestedPaths.contains("/api/members/me") }
            #expect(other.member == nil)
            responder.releaseAll()
            await load.value
        }

        // `members/me` returned member 1, so it must not be stored for member 2.
        #expect(store.snapshot(for: MyInfoSnapshotScope(memberID: 2, sessionGeneration: 9)) == nil)
    }

    @Test
    func snapshotKeepsSuccessfulMutations() async throws {
        let store = MyInfoSnapshotStore()
        let scope = MyInfoSnapshotScope(memberID: 1, sessionGeneration: 7)
        let model = SettingsViewModel(
            service: Self.service(MyInfoStubResponder(bodies: Self.bodies)),
            snapshotStore: store
        )
        await model.load(.myInfo, snapshotScope: scope)

        #expect(await model.revokeSession(id: 102))

        #expect(store.snapshot(for: scope)?.sessions.map(\.id) == [103, 101])
    }

    @Test
    func parsesServerLocalTimestampsLikeBefore() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let expected = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 1, hour: 10, minute: 0, second: 0
        )))
        for value in ["2026-08-01T10:00:00", "2026-08-01T10:00:00.000"] {
            #expect(SettingsSessionFormatter.date(from: value) == expected)
        }
        let fractional = try #require(SettingsSessionFormatter.date(from: "2026-08-01T10:00:00.817864"))
        #expect(abs(fractional.timeIntervalSince(expected) - 0.817) < 0.01)
        #expect(SettingsSessionFormatter.date(from: "2026-08-01") == calendar.startOfDay(for: expected))
        #expect(SettingsSessionFormatter.date(from: "2026-08-01T10:00:00Z")
            == ISO8601DateFormatter().date(from: "2026-08-01T10:00:00Z"))
    }

    // MARK: - Fixtures

    private static let member = #"{"id":1,"name":"Owner","email":"owner@example.com","teamId":7,"team":"Team","calendarVisibility":"FRIENDS","kakaoId":null,"naverId":null,"appleId":null,"hasPassword":true,"hasProfilePhoto":false,"profilePhotoVersion":0}"#

    private static let bodies: [String: String] = [
        "/api/members/me": member,
        "/api/members/family": "[]",
        "/api/friends": "[]",
        "/api/members/managers": "[]",
        "/api/members/managed": "[]",
        "/api/auth/refresh-tokens": "["
            + session(id: 102, lastUsed: "2026-08-13T10:00:00", current: false) + ","
            + session(id: 103, lastUsed: "2026-07-01T10:00:00", current: true) + ","
            + session(id: 101, lastUsed: "2026-08-15T10:00:00.123456", current: false)
            + "]",
        "/api/duty/pattern/me": #"{"configurable":true,"reason":null,"dutyTypes":[],"pattern":null}"#,
    ]

    private static func session(id: Int64, lastUsed: String, current: Bool) -> String {
        #"{"memberName":"Owner","memberId":1,"validUntil":"2026-09-01T10:00:00","createdDate":"2026-06-01T10:00:00","lastUsed":"\#(lastUsed)","remoteAddr":"127.0.0.1","id":\#(id),"userAgent":null,"isCurrentLogin":\#(current)}"#
    }

    private static func service(_ responder: MyInfoStubResponder) -> SettingsService {
        MyInfoURLProtocolStub.responder = responder
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MyInfoURLProtocolStub.self]
        configuration.httpCookieStorage = nil
        return SettingsService(client: APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        ))
    }

    private func waitUntil(
        timeout: Duration = .seconds(3),
        _ condition: () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else {
                Issue.record("Timed out waiting for the condition")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }
}

/// Answers stubbed requests, and can hold chosen paths until a test releases them so the
/// order in which sections arrive is deterministic.
private final class MyInfoStubResponder: @unchecked Sendable {
    private let lock = NSLock()
    private let bodies: [String: String]
    private var heldPaths: Set<String> = []
    private var holdsAll = false
    private var pending: [(path: String, request: MyInfoURLProtocolStub)] = []
    private var requested: [String] = []

    init(bodies: [String: String]) {
        self.bodies = bodies
    }

    var requestedPaths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return requested
    }

    func hold(_ path: String) {
        lock.lock()
        heldPaths.insert(path)
        lock.unlock()
    }

    func holdAll() {
        lock.lock()
        holdsAll = true
        lock.unlock()
    }

    func release(_ path: String) {
        lock.lock()
        heldPaths.remove(path)
        let released = pending.filter { $0.path == path }
        pending.removeAll { $0.path == path }
        lock.unlock()
        released.forEach { respond(to: $0.request, path: $0.path) }
    }

    func releaseAll() {
        lock.lock()
        holdsAll = false
        heldPaths.removeAll()
        let released = pending
        pending.removeAll()
        lock.unlock()
        released.forEach { respond(to: $0.request, path: $0.path) }
    }

    func handle(_ request: MyInfoURLProtocolStub) {
        let path = request.request.url?.path ?? ""
        lock.lock()
        requested.append(path)
        let isHeld = holdsAll || heldPaths.contains(path)
        if isHeld { pending.append((path, request)) }
        lock.unlock()
        if !isHeld { respond(to: request, path: path) }
    }

    private func respond(to request: MyInfoURLProtocolStub, path: String) {
        let method = request.request.httpMethod ?? "GET"
        let body = method == "GET" ? bodies[path] : ""
        let status = body == nil ? 500 : (method == "GET" ? 200 : 204)
        let response = HTTPURLResponse(
            url: request.request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        request.client?.urlProtocol(request, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = (body ?? #"{"code":"test.error"}"#).data(using: .utf8), !data.isEmpty {
            request.client?.urlProtocol(request, didLoad: data)
        }
        request.client?.urlProtocolDidFinishLoading(request)
    }
}

private final class MyInfoURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responder: MyInfoStubResponder?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responder = Self.responder else {
            fatalError("MyInfoURLProtocolStub.responder is not set")
        }
        responder.handle(self)
    }

    override func stopLoading() {}
}
