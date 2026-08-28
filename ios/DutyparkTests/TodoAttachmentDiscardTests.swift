import Foundation
import Testing
@testable import Dutypark

@MainActor
@Suite(.serialized)
struct TodoAttachmentDiscardTests {
    @Test
    func pendingDiscardStoreIsPersistentAndAccountScoped() {
        let suiteName = "todo-attachment-discard-store-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let accountASession = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let accountBSession = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let firstStore = TodoAttachmentDiscardStore(defaults: defaults)
        firstStore.enqueue(accountID: 42, sessionID: accountASession)
        firstStore.enqueue(accountID: 43, sessionID: accountBSession)

        let recreatedStore = TodoAttachmentDiscardStore(defaults: defaults)
        #expect(recreatedStore.pendingSessionIDs(accountID: 42) == [accountASession])
        #expect(recreatedStore.pendingSessionIDs(accountID: 43) == [accountBSession])

        recreatedStore.remove(accountID: 42, sessionID: accountASession)
        #expect(recreatedStore.pendingSessionIDs(accountID: 42).isEmpty)
        #expect(recreatedStore.pendingSessionIDs(accountID: 43) == [accountBSession])
    }

    @Test
    func retryPendingOnlyProcessesTheAuthenticatedAccount() async throws {
        let suiteName = "todo-attachment-discard-isolation-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let accountASession = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let accountBSession = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let store = TodoAttachmentDiscardStore(defaults: defaults)
        store.enqueue(accountID: 42, sessionID: accountASession)
        store.enqueue(accountID: 43, sessionID: accountBSession)

        let client = TodoAttachmentDiscardClient(sessionID: accountBSession)
        let coordinator = TodoAttachmentDiscardCoordinator(
            store: store,
            retryDelays: [],
            sleep: { _ in },
            persistedDiscard: { accountID, sessionID in
                guard accountID == 43 else { return false }
                return await client.discard(sessionID)
            }
        )
        coordinator.activate(accountID: 43, sessionGeneration: 1)
        coordinator.retryPending(accountID: 43, sessionGeneration: 1)

        #expect(await waitUntil { await client.discardCount == 1 })
        #expect(store.pendingSessionIDs(accountID: 42) == [accountASession])
        #expect(store.pendingSessionIDs(accountID: 43).isEmpty)
    }

    @Test
    func recreatedViewModelCanRetryPersistedDiscardForTheSameAccount() async throws {
        let suiteName = "todo-attachment-discard-recreate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sessionID = UUID(uuidString: "55555555-6666-7777-8888-999999999999")!
        let store = TodoAttachmentDiscardStore(defaults: defaults)
        let firstClient = TodoAttachmentDiscardClient(
            sessionID: sessionID,
            discardOutcomes: [.failure]
        )
        let attachmentModel = AttachmentPickerModel(contextType: .todo, client: firstClient)
        await attachmentModel.add(files: [try uploadFile(named: "draft.txt")])

        let firstCoordinator = TodoAttachmentDiscardCoordinator(
            store: store,
            retryDelays: [],
            sleep: { _ in }
        )
        var firstViewModel: TodoViewModel? = TodoViewModel(
            attachmentDiscardCoordinator: firstCoordinator
        )
        firstCoordinator.activate(accountID: 42, sessionGeneration: 1)
        firstViewModel?.configureSession(
            accountID: 42,
            availability: .online,
            sessionGeneration: 1
        )
        firstViewModel?.scheduleAttachmentDiscard(
            for: attachmentModel,
            accountID: 42,
            sessionGeneration: 1
        )
        #expect(await waitUntil { await firstClient.discardCount == 1 })
        #expect(store.pendingSessionIDs(accountID: 42) == [sessionID])
        firstViewModel = nil

        let secondClient = TodoAttachmentDiscardClient(sessionID: sessionID)
        let secondCoordinator = TodoAttachmentDiscardCoordinator(
            store: store,
            retryDelays: [],
            sleep: { _ in },
            persistedDiscard: { _, sessionID in await secondClient.discard(sessionID) }
        )
        let secondViewModel = TodoViewModel(attachmentDiscardCoordinator: secondCoordinator)
        secondViewModel.configureSession(
            accountID: 42,
            availability: SessionAvailability.online,
            sessionGeneration: 2
        )
        secondCoordinator.activate(accountID: 42, sessionGeneration: 2)
        secondViewModel.retryPendingAttachmentDiscards()

        #expect(await waitUntil { await secondClient.discardCount == 1 })
        #expect(store.pendingSessionIDs(accountID: 42).isEmpty)
    }

    @Test
    func cancelledModelDiscardIsRehydratedWithFreshCredentials() async throws {
        let suiteName = "todo-attachment-discard-cancel-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sessionID = UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
        let store = TodoAttachmentDiscardStore(defaults: defaults)
        let gate = TodoAttachmentDiscardGate()
        let oldClient = TodoAttachmentDiscardClient(
            sessionID: sessionID,
            discardOutcomes: [.success],
            firstDiscardGate: gate
        )
        let attachmentModel = AttachmentPickerModel(contextType: .todo, client: oldClient)
        await attachmentModel.add(files: [try uploadFile(named: "draft.txt")])

        let firstCoordinator = TodoAttachmentDiscardCoordinator(
            store: store,
            retryDelays: [],
            sleep: { _ in }
        )
        firstCoordinator.activate(accountID: 42, sessionGeneration: 1)
        firstCoordinator.schedule(
            model: attachmentModel,
            accountID: 42,
            sessionGeneration: 1
        )
        #expect(await waitUntil { await oldClient.discardCount == 1 })

        firstCoordinator.cancelAll()
        await gate.release()
        await Task.yield()
        #expect(store.pendingSessionIDs(accountID: 42) == [sessionID])

        let replacementClient = TodoAttachmentDiscardClient(sessionID: sessionID)
        let replacementCoordinator = TodoAttachmentDiscardCoordinator(
            store: store,
            retryDelays: [],
            sleep: { _ in },
            persistedDiscard: { _, sessionID in
                await replacementClient.discard(sessionID)
            }
        )
        replacementCoordinator.activate(accountID: 42, sessionGeneration: 2)
        replacementCoordinator.retryPending(accountID: 42, sessionGeneration: 2)

        #expect(await waitUntil { await replacementClient.discardCount == 1 })
        #expect(store.pendingSessionIDs(accountID: 42).isEmpty)
    }

    @Test
    func lateDisappearAfterLogoutCannotReviveThePreviousSession() async throws {
        let suiteName = "todo-attachment-discard-late-logout-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sessionID = UUID(uuidString: "12121212-3434-5656-7878-909090909090")!
        let store = TodoAttachmentDiscardStore(defaults: defaults)
        let client = TodoAttachmentDiscardClient(sessionID: sessionID)
        let attachmentModel = AttachmentPickerModel(contextType: .todo, client: client)
        await attachmentModel.add(files: [try uploadFile(named: "draft.txt")])

        let coordinator = TodoAttachmentDiscardCoordinator(
            store: store,
            retryDelays: [],
            sleep: { _ in }
        )
        coordinator.activate(accountID: 42, sessionGeneration: 1)
        coordinator.cancelAll()

        // This represents the old form's onDisappear arriving after logout.
        coordinator.schedule(
            model: attachmentModel,
            accountID: 42,
            sessionGeneration: 1
        )

        await Task.yield()
        #expect(await client.discardCount == 0)
        #expect(store.pendingSessionIDs(accountID: 42).isEmpty)
    }

    @Test
    func lateDisappearCannotSwitchTheCoordinatorBackToAnOldAccount() async throws {
        let suiteName = "todo-attachment-discard-late-switch-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let oldSessionID = UUID(uuidString: "13131313-3535-5757-7979-919191919191")!
        let store = TodoAttachmentDiscardStore(defaults: defaults)
        let oldClient = TodoAttachmentDiscardClient(sessionID: oldSessionID)
        let oldModel = AttachmentPickerModel(contextType: .todo, client: oldClient)
        await oldModel.add(files: [try uploadFile(named: "old-draft.txt")])

        let coordinator = TodoAttachmentDiscardCoordinator(
            store: store,
            retryDelays: [],
            sleep: { _ in }
        )
        coordinator.activate(accountID: 43, sessionGeneration: 2)

        // A stale view must not be able to overwrite the current account
        // context before its disappearance callback schedules cleanup.
        coordinator.activate(accountID: 42, sessionGeneration: 1)
        coordinator.schedule(
            model: oldModel,
            accountID: 42,
            sessionGeneration: 1
        )

        await Task.yield()
        #expect(await oldClient.discardCount == 0)
        #expect(store.pendingSessionIDs(accountID: 42).isEmpty)
    }

    @Test
    func sameAccountReloginRejectsThePreviousGenerationButAcceptsTheCurrentOne() async throws {
        let suiteName = "todo-attachment-discard-relogin-generation-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let oldSessionID = UUID(uuidString: "14141414-3636-5858-8080-929292929292")!
        let currentSessionID = UUID(uuidString: "15151515-3737-5959-8181-939393939393")!
        let store = TodoAttachmentDiscardStore(defaults: defaults)
        let oldClient = TodoAttachmentDiscardClient(sessionID: oldSessionID)
        let currentClient = TodoAttachmentDiscardClient(sessionID: currentSessionID)
        let oldModel = AttachmentPickerModel(contextType: .todo, client: oldClient)
        let currentModel = AttachmentPickerModel(contextType: .todo, client: currentClient)
        await oldModel.add(files: [try uploadFile(named: "old-draft.txt")])
        await currentModel.add(files: [try uploadFile(named: "current-draft.txt")])

        let coordinator = TodoAttachmentDiscardCoordinator(
            store: store,
            retryDelays: [],
            sleep: { _ in }
        )
        coordinator.activate(accountID: 42, sessionGeneration: 1)
        coordinator.cancelAll()
        coordinator.activate(accountID: 42, sessionGeneration: 2)

        coordinator.schedule(
            model: oldModel,
            accountID: 42,
            sessionGeneration: 1
        )
        coordinator.schedule(
            model: currentModel,
            accountID: 42,
            sessionGeneration: 2
        )

        #expect(await waitUntil { await currentClient.discardCount == 1 })
        #expect(await oldClient.discardCount == 0)
        #expect(store.pendingSessionIDs(accountID: 42).isEmpty)
    }

    @Test
    func sessionBoundaryKeepsLogoutCleanupAndPurgesAccountDeletionCleanup() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "Dutypark/Core/Auth/SessionStore.swift"),
            encoding: .utf8
        )

        #expect(source.contains("purgeAttachmentDiscards: true"))
        #expect(source.contains("TodoAttachmentDiscardCoordinator.shared.cancelAll()"))
        #expect(source.contains("TodoAttachmentDiscardStore.shared.purge(accountID: memberID)"))
        #expect(source.contains("TodoAttachmentDiscardStore.shared.purgeAll()"))
        #expect(source.contains("} else if purgeAttachmentDiscards {"))
        #expect(source.contains("await authService.clearLocalAuthentication()"))
        #expect(source.contains("TodoAttachmentDiscardCoordinator.shared.activate("))
        #expect(source.contains("sessionGeneration: sessionContext.generation"))
        #expect(source.contains("TodoAttachmentDiscardCoordinator.shared.retryPending("))
    }

    @Test
    func coldLaunchWithoutCookiesPreservesPendingDiscardQueue() async throws {
        let accountID: MemberID = 420001
        let sessionID = UUID(uuidString: "16161616-3838-6060-8282-949494949494")!
        let store = TodoAttachmentDiscardStore.shared
        store.enqueue(accountID: accountID, sessionID: sessionID)
        defer { store.purge(accountID: accountID) }

        let sessionStore = makeSessionStore { request in
            switch request.url?.path {
            case "/api/auth/status":
                todoDiscardResponse(request, status: 200)
            case "/api/auth/refresh":
                todoDiscardResponse(request, status: 401)
            default:
                todoDiscardResponse(request, status: 404)
            }
        }

        await sessionStore.restore()

        #expect(sessionStore.state == .guest)
        #expect(store.pendingSessionIDs(accountID: accountID) == [sessionID])
    }

    @Test
    func restoreAuthenticationRejectionPreservesPendingDiscardQueue() async throws {
        let accountID: MemberID = 420002
        let sessionID = UUID(uuidString: "17171717-3939-6161-8383-959595959595")!
        let store = TodoAttachmentDiscardStore.shared
        store.enqueue(accountID: accountID, sessionID: sessionID)
        defer { store.purge(accountID: accountID) }

        let sessionStore = makeSessionStore { request in
            switch request.url?.path {
            case "/api/auth/status":
                todoDiscardResponse(request, status: 403)
            default:
                todoDiscardResponse(request, status: 404)
            }
        }

        await sessionStore.restore()

        #expect(sessionStore.state == .guest)
        #expect(store.pendingSessionIDs(accountID: accountID) == [sessionID])
    }

    @Test
    func explicitAccountDeletionPurgesOnlyDeletedAccountDiscardQueue() async throws {
        let deletedAccountID: MemberID = 420003
        let otherAccountID: MemberID = 420004
        let deletedSessionID = UUID(uuidString: "18181818-4040-6262-8484-969696969696")!
        let otherSessionID = UUID(uuidString: "19191919-4141-6363-8585-979797979797")!
        let store = TodoAttachmentDiscardStore.shared
        store.enqueue(accountID: deletedAccountID, sessionID: deletedSessionID)
        store.enqueue(accountID: otherAccountID, sessionID: otherSessionID)
        defer {
            store.purge(accountID: deletedAccountID)
            store.purge(accountID: otherAccountID)
        }

        let sessionStore = makeSessionStore(
            initialState: .authenticated(
                LoginMember(
                    id: deletedAccountID,
                    email: nil,
                    name: "Deleted",
                    teamId: nil,
                    team: nil,
                    isAdmin: false,
                    isImpersonating: false,
                    originalMemberId: nil
                )
            )
        ) { request in
            todoDiscardResponse(request, status: 204)
        }

        await sessionStore.completeAccountDeletion()

        #expect(store.pendingSessionIDs(accountID: deletedAccountID).isEmpty)
        #expect(store.pendingSessionIDs(accountID: otherAccountID) == [otherSessionID])
    }

    @Test
    func explicitContinueAsGuestPerformsFullDiscardQueuePurge() async throws {
        let accountA: MemberID = 420005
        let accountB: MemberID = 420006
        let sessionA = UUID(uuidString: "20202020-4242-6464-8686-989898989898")!
        let sessionB = UUID(uuidString: "21212121-4343-6565-8787-999999999999")!
        let store = TodoAttachmentDiscardStore.shared
        store.enqueue(accountID: accountA, sessionID: sessionA)
        store.enqueue(accountID: accountB, sessionID: sessionB)
        defer {
            store.purge(accountID: accountA)
            store.purge(accountID: accountB)
        }

        let sessionStore = makeSessionStore(initialState: .restoreFailed) { request in
            todoDiscardResponse(request, status: 204)
        }

        await sessionStore.continueAsGuestAfterRestoreFailure()

        #expect(sessionStore.state == .guest)
        #expect(store.pendingSessionIDs(accountID: accountA).isEmpty)
        #expect(store.pendingSessionIDs(accountID: accountB).isEmpty)
    }

    @Test
    func formRoutesTeardownCleanupThroughTheViewModelCoordinator() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "Dutypark/Features/Todo/TodoView.swift"),
            encoding: .utf8
        )

        #expect(source.contains("model.scheduleAttachmentDiscard("))
        #expect(source.contains("sessionGeneration: boundSessionGeneration"))
        #expect(!source.contains("Task { await attachmentModel.discard() }"))
    }

    @Test
    func transientDiscardFailureIsRetriedWithoutKeepingTheFormOpen() async throws {
        let sessionID = UUID(uuidString: "55555555-6666-7777-8888-999999999999")!
        let client = TodoAttachmentDiscardClient(
            sessionID: sessionID,
            discardOutcomes: [.failure, .success]
        )
        let attachmentModel = AttachmentPickerModel(contextType: .todo, client: client)
        await attachmentModel.add(files: [try uploadFile(named: "draft.txt")])

        let coordinator = TodoAttachmentDiscardCoordinator(
            retryDelays: [.zero],
            sleep: { _ in }
        )
        coordinator.activate(accountID: 42, sessionGeneration: 1)
        coordinator.schedule(
            model: attachmentModel,
            accountID: 42,
            sessionGeneration: 1
        )

        #expect(await waitUntil { await client.discardCount == 2 })
        #expect(attachmentModel.attachmentSessionId == nil)
        #expect(coordinator.pendingSessionIDs(accountID: 42).isEmpty)
    }

    @Test
    func failedDiscardRemainsPendingAndCanBeRetriedAfterTheFormDisappears() async throws {
        let sessionID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let client = TodoAttachmentDiscardClient(
            sessionID: sessionID,
            discardOutcomes: [.failure, .success]
        )
        let attachmentModel = AttachmentPickerModel(contextType: .todo, client: client)
        await attachmentModel.add(files: [try uploadFile(named: "draft.txt")])

        let coordinator = TodoAttachmentDiscardCoordinator(
            retryDelays: [],
            sleep: { _ in }
        )
        coordinator.activate(accountID: 42, sessionGeneration: 1)
        coordinator.schedule(
            model: attachmentModel,
            accountID: 42,
            sessionGeneration: 1
        )

        #expect(await waitUntil { await client.discardCount == 1 })
        #expect(attachmentModel.attachmentSessionId == sessionID)
        #expect(coordinator.pendingSessionIDs(accountID: 42) == Set([sessionID]))

        coordinator.retryPending(accountID: 42, sessionGeneration: 1)

        #expect(await waitUntil { await client.discardCount == 2 })
        #expect(attachmentModel.attachmentSessionId == nil)
        #expect(coordinator.pendingSessionIDs(accountID: 42).isEmpty)
    }

    @Test
    func schedulingTheSameSessionWhileDiscardIsInFlightDoesNotDuplicateTheRequest() async throws {
        let sessionID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let gate = TodoAttachmentDiscardGate()
        let client = TodoAttachmentDiscardClient(
            sessionID: sessionID,
            discardOutcomes: [.success],
            firstDiscardGate: gate
        )
        let attachmentModel = AttachmentPickerModel(contextType: .todo, client: client)
        await attachmentModel.add(files: [try uploadFile(named: "draft.txt")])

        let coordinator = TodoAttachmentDiscardCoordinator(
            retryDelays: [],
            sleep: { _ in }
        )
        coordinator.activate(accountID: 42, sessionGeneration: 1)
        coordinator.schedule(
            model: attachmentModel,
            accountID: 42,
            sessionGeneration: 1
        )
        #expect(await waitUntil { await client.discardCount == 1 })

        coordinator.schedule(
            model: attachmentModel,
            accountID: 42,
            sessionGeneration: 1
        )
        #expect(await client.discardCount == 1)

        await gate.release()
        #expect(await waitUntil { attachmentModel.attachmentSessionId == nil })
        #expect(await client.discardCount == 1)
    }

    private func uploadFile(named name: String) throws -> AttachmentUploadFile {
        try AttachmentUploadFile(
            filename: name,
            contentType: "text/plain",
            data: Data("draft".utf8)
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () async -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if await condition() { return true }
            await Task.yield()
        }
        return await condition()
    }

    private func makeSessionStore(
        initialState: SessionState = .restoring,
        handler: @escaping @Sendable (URLRequest) -> (HTTPURLResponse, Data)
    ) -> SessionStore {
        TodoAttachmentSessionURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TodoAttachmentSessionURLProtocol.self]
        configuration.httpShouldSetCookies = false
        let client = APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        )
        return SessionStore(
            authService: AuthService(client: client),
            initialState: initialState
        )
    }
}

private func todoDiscardResponse(
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

private final class TodoAttachmentSessionURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
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

private actor TodoAttachmentDiscardClient: AttachmentPickerClient {
    private let sessionID: UUID
    private var discardOutcomes: [DiscardOutcome]
    private let firstDiscardGate: TodoAttachmentDiscardGate?
    private(set) var discardCount = 0

    enum DiscardOutcome: Sendable {
        case success
        case failure
    }

    init(
        sessionID: UUID,
        discardOutcomes: [DiscardOutcome] = [],
        firstDiscardGate: TodoAttachmentDiscardGate? = nil
    ) {
        self.sessionID = sessionID
        self.discardOutcomes = discardOutcomes
        self.firstDiscardGate = firstDiscardGate
    }

    func createSession(
        contextType: AttachmentContextType,
        targetContextId: String?
    ) async throws -> CreateAttachmentSessionResponse {
        CreateAttachmentSessionResponse(
            sessionId: sessionID,
            expiresAt: "2026-08-28T00:00:00Z",
            contextType: contextType
        )
    }

    func discardSession(_ sessionId: UUID) async throws {
        discardCount += 1
        if discardCount == 1, let firstDiscardGate {
            await firstDiscardGate.wait()
        }
        switch discardOutcomes.isEmpty ? .success : discardOutcomes.removeFirst() {
        case .success:
            return
        case .failure:
            throw APIError.transport
        }
    }

    func discard(_ sessionId: UUID) async -> Bool {
        do {
            try await discardSession(sessionId)
            return true
        } catch {
            return false
        }
    }

    func upload(
        _ file: AttachmentUploadFile,
        sessionId: UUID
    ) async throws -> AttachmentDTO {
        AttachmentDTO(
            id: UUID(),
            contextType: .todo,
            contextId: nil,
            originalFilename: file.filename,
            contentType: file.contentType,
            size: Int64(file.data.count),
            hasThumbnail: false,
            thumbnailUrl: nil,
            orderIndex: 0,
            createdAt: "2026-08-28T00:00:00Z",
            createdBy: 1
        )
    }
}

private actor TodoAttachmentDiscardGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
