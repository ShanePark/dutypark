import Foundation
import Combine

enum SessionState: Equatable {
    case restoring
    case restoreFailed
    case guest
    case authenticated(LoginMember)
}

nonisolated enum SessionAvailability: Equatable, Sendable {
    case online
    case offline

    var isOffline: Bool { self == .offline }
}

nonisolated enum AccountDeletionAcceptedPresentation: Equatable, Sendable {
    case accepted
}

nonisolated enum ServerSessionWarningPresentation: Equatable, Sendable {
    case serverMayRemain
}

nonisolated enum AuthenticationTransitionFailurePresentation: Equatable, Sendable {
    case impersonationFailed
}

@MainActor
final class SessionStore: ObservableObject {
    private struct AuthenticationTransitionContext {
        let previousMember: LoginMember?
        let generation: UInt64
    }

    private static let impersonationExpirationKey = "dp-impersonation-expires"

    private let authService: AuthService
    private let unregisterPush: @MainActor @Sendable () async -> Void
    private let offlineSessionStore: any OfflineSessionStoring
    private let localDataPurger: any SessionLocalDataPurging
    private let cancelOfflineSync: @MainActor @Sendable (MemberID?) async -> Void
    private let accountDeletionReceiptStore: AccountDeletionReceiptStore
    private var impersonationExpiryTask: Task<Void, Never>?
    private var isTerminatingSession = false
    private var sessionTerminationWaiters: [CheckedContinuation<Void, Never>] = []
    private var authenticationSessionGeneration: UInt64 = 0

    @Published private(set) var state: SessionState
    @Published private(set) var availability: SessionAvailability
    @Published private(set) var isWorking = false
    @Published private(set) var loginErrorKey: String?
    @Published private(set) var loginErrorStatus: Int?
    @Published private(set) var loginRemainingAttempts: Int?
    @Published private(set) var impersonationExpiresAt: Date?
    @Published private(set) var pendingDestination: URL?
    @Published private(set) var accountDeletionAcceptedPresentation: AccountDeletionAcceptedPresentation?
    @Published private(set) var accountDeletionReceipt: AccountDeletionReceipt?
    @Published private(set) var serverSessionWarning: ServerSessionWarningPresentation?
    @Published private(set) var authenticationTransitionFailure: AuthenticationTransitionFailurePresentation?

    /// Identifies the currently authenticated credentials for views that may
    /// outlive a login/logout transition. A new login receives a new
    /// generation even when it is for the same member, so delayed cleanup
    /// callbacks cannot be mistaken for work from the current session.
    var authenticationSessionGenerationForCurrentAccount: UInt64? {
        guard case .authenticated = state else { return nil }
        return authenticationSessionGeneration
    }

    init(
        authService: AuthService = AuthService(),
        initialState: SessionState = .restoring,
        impersonationExpiresAt: Date? = nil,
        unregisterPush: @escaping @MainActor @Sendable () async -> Void = {},
        offlineSessionStore: any OfflineSessionStoring = OfflineSessionStore.shared,
        localDataPurger: any SessionLocalDataPurging = OfflineLocalDataPurger.shared,
        cancelOfflineSync: @escaping @MainActor @Sendable (MemberID?) async -> Void = { memberID in
            if let memberID {
                OfflineSyncCoordinator.shared.cancel(accountID: memberID)
            } else {
                OfflineSyncCoordinator.shared.cancelAll()
            }
        },
        initialAvailability: SessionAvailability = .online,
        accountDeletionReceiptStore: AccountDeletionReceiptStore = .shared
    ) {
        let storedReceipt = accountDeletionReceiptStore.load()
        self.authService = authService
        self.unregisterPush = unregisterPush
        self.offlineSessionStore = offlineSessionStore
        self.localDataPurger = localDataPurger
        self.cancelOfflineSync = cancelOfflineSync
        self.accountDeletionReceiptStore = accountDeletionReceiptStore
        self.state = initialState
        self.availability = initialAvailability
        self.impersonationExpiresAt = impersonationExpiresAt
            ?? UserDefaults.standard.object(forKey: Self.impersonationExpirationKey) as? Date
        self.accountDeletionReceipt = storedReceipt
        self.accountDeletionAcceptedPresentation = storedReceipt == nil ? nil : .accepted
    }

    func restore() async {
        guard state == .restoring else { return }
        if accountDeletionReceipt != nil {
            accountDeletionAcceptedPresentation = .accepted
        }
        do {
            if let member = try await authService.restore() {
                await authenticate(member, availability: .online)
            } else {
                await invalidateAuthenticationContext()
                await discardLocalSessionData(memberID: nil)
                await authService.clearLocalAuthentication()
                await becomeGuest()
            }
        } catch let error as APIError where error.isAuthenticationRejection {
            await invalidateAuthenticationContext()
            await discardLocalSessionData(memberID: nil)
            await authService.clearLocalAuthentication()
            await becomeGuest()
        } catch let error as APIError where error.supportsOfflineSessionFallback {
            if let member = await offlineSessionStore.load(at: nil) {
                await authenticate(
                    member,
                    availability: .offline,
                    persistSnapshot: false
                )
            } else {
                await invalidateAuthenticationContext()
                // Keep local data until the user explicitly chooses guest.
                // `continueAsGuestAfterRestoreFailure` owns that terminal
                // purge; purging here would cancel and clear the same
                // account boundary a second time.
                state = .restoreFailed
            }
        } catch {
            state = .restoreFailed
        }
    }

    func retryRestore() async {
        if case .authenticated = state, availability == .offline {
            await revalidate()
            return
        }
        guard state == .restoreFailed else { return }
        state = .restoring
        await restore()
    }

    /// Re-checks an offline authenticated session after connectivity returns.
    /// Transient failures intentionally keep the cached session visible; an
    /// explicit unauthenticated response follows the same purge path as a
    /// normal session failure.
    func revalidate() async {
        guard case .authenticated(let currentMember) = state,
              availability == .offline
        else { return }
        // `restore()` can outlive a login/logout transition.  The generation
        // and member snapshot bind its result to the offline session that
        // started the request.
        let expectedGeneration = authenticationSessionGeneration
        let expectedMemberID = currentMember.id

        do {
            if let member = try await authService.restore() {
                guard member.id == expectedMemberID,
                      isCurrentRevalidation(
                    generation: expectedGeneration,
                    memberID: expectedMemberID
                ) else { return }
                await authenticate(
                    member,
                    availability: .online,
                    expectedAuthenticationSessionGeneration: expectedGeneration
                )
            } else {
                guard isCurrentRevalidation(
                    generation: expectedGeneration,
                    memberID: expectedMemberID
                ) else { return }
                await invalidateAuthenticatedSession()
            }
        } catch let error as APIError where error.isAuthenticationRejection {
            guard isCurrentRevalidation(
                generation: expectedGeneration,
                memberID: expectedMemberID
            ) else { return }
            await invalidateAuthenticatedSession()
        } catch {
            // Keep serving the last verified local snapshot until a later
            // foreground/connection-recovery attempt succeeds.
        }
    }

    func continueAsGuestAfterRestoreFailure() async {
        guard state == .restoreFailed else { return }
        await terminateSession(
            reportServerFailure: true,
            purgeAttachmentDiscards: true
        )
    }

    func login(email: String, password: String, rememberMe: Bool) async {
        guard !isWorking else { return }
        isWorking = true
        accountDeletionAcceptedPresentation = nil
        loginErrorKey = nil
        loginErrorStatus = nil
        loginRemainingAttempts = nil
        defer { isWorking = false }

        let transition = await beginAuthenticationTransition()
        do {
            let member = try await authService.login(
                email: email,
                password: password,
                rememberMe: rememberMe
            )
            guard await authenticate(
                member,
                availability: .online,
                syncAlreadyCancelledFor: transition.previousMember?.id,
                expectedAuthenticationSessionGeneration: transition.generation
            ) else {
                return
            }
            DPHapticCenter.shared.emit(.success)
        } catch let error as APIError {
            guard isCurrentAuthenticationTransition(transition) else { return }
            if let previousMember = transition.previousMember {
                await terminateFailedAuthenticationTransition(for: previousMember.id)
            } else {
                await clearFailedAuthenticationTransition()
            }
            switch error {
            case .serverWithDetails(status: 429, _, let details):
                loginErrorKey = "auth.login.error.rateLimited"
                loginRemainingAttempts = details.remainingAttempts
            case .serverWithDetails(status: 401, code: "auth.account.suspended", _):
                loginErrorKey = "auth.account.suspended"
            case .serverWithDetails(status: 401, _, let details):
                loginErrorKey = "auth.login.error.invalidCredentials"
                loginRemainingAttempts = details.remainingAttempts
            case .server(status: 429, _):
                loginErrorKey = "auth.login.error.rateLimited"
            case .server(status: 401, code: "auth.account.suspended"):
                loginErrorKey = "auth.account.suspended"
            case .server(status: 401, _):
                loginErrorKey = "auth.login.error.invalidCredentials"
            case .transport:
                loginErrorKey = "auth.login.error.network"
            case .server(let status, _), .serverWithDetails(let status, _, _):
                loginErrorKey = status >= 500
                    ? "auth.login.error.server"
                    : "auth.login.error.unknown"
                loginErrorStatus = status
            default:
                loginErrorKey = "auth.login.error.generic"
            }
            DPHapticCenter.shared.emit(.error)
        } catch {
            guard isCurrentAuthenticationTransition(transition) else { return }
            if let previousMember = transition.previousMember {
                await terminateFailedAuthenticationTransition(for: previousMember.id)
            } else {
                await clearFailedAuthenticationTransition()
            }
            loginErrorKey = "auth.login.error.generic"
            DPHapticCenter.shared.emit(.error)
        }
    }

    func logout() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        pendingDestination = nil
        await terminateSession(reportServerFailure: true)
    }

    /// Completes the irreversible local side of account deletion after the server
    /// accepted the deletion job (or reports that the account is already pending).
    ///
    /// When the completion started in a view that can outlive an auth
    /// transition, the expected account and generation bind the cleanup to the
    /// session that initiated it. The optional callback runs while the session
    /// boundary is locked, so account-scoped notification cleanup cannot race a
    /// replacement login.
    @discardableResult
    func completeAccountDeletion(
        expectedMemberID: MemberID,
        expectedAuthenticationSessionGeneration: UInt64,
        receipt: AccountDeletionReceipt? = nil,
        accountCleanup: (@MainActor @Sendable () async -> Void)? = nil
    ) async -> Bool {
        guard !isTerminatingSession,
              isCurrentAccount(
                  memberID: expectedMemberID,
                  generation: expectedAuthenticationSessionGeneration
              )
        else { return false }

        isTerminatingSession = true
        defer { finishSessionTermination() }

        // Snapshot the account before the first await. `isTerminatingSession`
        // makes login/switch transitions wait until this whole boundary is
        // complete, while the snapshot keeps the purge target explicit.
        let member = memberForCurrentState
        if let receipt {
            do {
                try accountDeletionReceiptStore.save(receipt)
                accountDeletionReceipt = receipt
            } catch {
                accountDeletionReceipt = accountDeletionReceiptStore.load()
            }
        } else if accountDeletionReceipt == nil {
            accountDeletionReceipt = accountDeletionReceiptStore.load()
        }
        await invalidateAuthenticationContext()
        if let member {
            UserDefaults.standard.removeObject(forKey: "selectedDday_\(member.id)")
            await discardLocalSessionData(
                memberID: member.id,
                purgeAttachmentDiscards: true
            )
        } else {
            await discardLocalSessionData(
                memberID: nil,
                purgeAttachmentDiscards: true
            )
        }
        await accountCleanup?()
        UserDefaults.standard.removeObject(forKey: "dp-remember-email")
        await authService.clearLocalAuthentication()
        pendingDestination = nil
        await becomeGuest()
        accountDeletionAcceptedPresentation = .accepted
        return true
    }

    func dismissAccountDeletionAcceptedPresentation(clearReceipt: Bool = true) {
        guard clearReceipt else {
            accountDeletionAcceptedPresentation = nil
            return
        }
        clearAccountDeletionReceipt()
    }

    /// Clears the account-deletion receipt from both memory and persistence.
    /// The presentation is also dismissed so a later guest session cannot show
    /// a status screen for a receipt that no longer exists.
    func clearAccountDeletionReceipt() {
        accountDeletionAcceptedPresentation = nil
        accountDeletionReceiptStore.clear()
        accountDeletionReceipt = nil
    }

    /// Clears a receipt only when the caller still belongs to the session that
    /// owned the deletion flow. This prevents a late callback from removing a
    /// replacement account's receipt.
    @discardableResult
    func clearAccountDeletionReceipt(
        expectedMemberID: MemberID,
        expectedAuthenticationSessionGeneration: UInt64
    ) -> Bool {
        guard isCurrentAccount(
            memberID: expectedMemberID,
            generation: expectedAuthenticationSessionGeneration
        ) else { return false }
        clearAccountDeletionReceipt()
        return true
    }

    func dismissServerSessionWarning() {
        serverSessionWarning = nil
    }

    func dismissAuthenticationTransitionFailure() {
        authenticationTransitionFailure = nil
    }

    func finishExternalLogin(emitsHaptic: Bool = true) async throws {
        let transition = await beginAuthenticationTransition()
        do {
            guard let member = try await authService.status() else {
                throw APIError.invalidResponse
            }
            guard isCurrentAuthenticationTransition(transition) else {
                throw CancellationError()
            }
            guard await authenticate(
                member,
                availability: .online,
                syncAlreadyCancelledFor: transition.previousMember?.id,
                expectedAuthenticationSessionGeneration: transition.generation
            ) else {
                throw CancellationError()
            }
            if emitsHaptic {
                DPHapticCenter.shared.emit(.success)
            }
        } catch {
            guard isCurrentAuthenticationTransition(transition) else {
                throw error
            }
            if let previousMember = transition.previousMember {
                await terminateFailedAuthenticationTransition(for: previousMember.id)
            } else {
                await clearFailedAuthenticationTransition()
            }
            throw error
        }
    }

    func impersonate(memberId: Int64) async throws {
        let transition = await beginAuthenticationTransition()
        do {
            let (member, expiresIn) = try await authService.impersonate(memberId: memberId)
            guard isCurrentAuthenticationTransition(transition) else {
                throw CancellationError()
            }
            let expiration = Date().addingTimeInterval(TimeInterval(expiresIn))
            impersonationExpiresAt = expiration
            UserDefaults.standard.set(expiration, forKey: Self.impersonationExpirationKey)
            guard await authenticate(
                member,
                availability: .online,
                syncAlreadyCancelledFor: transition.previousMember?.id,
                expectedAuthenticationSessionGeneration: transition.generation
            ) else {
                throw CancellationError()
            }
            DPHapticCenter.shared.emit(.success)
        } catch {
            guard isCurrentAuthenticationTransition(transition) else {
                throw error
            }
            if let previousMember = transition.previousMember {
                await terminateFailedAuthenticationTransition(for: previousMember.id)
            } else {
                // A guest impersonation attempt has no prior cookie owner to
                // invalidate; still clear credentials partially installed by
                // the failed transition before preserving the thrown error.
                await clearFailedAuthenticationTransition()
            }
            authenticationTransitionFailure = .impersonationFailed
            throw error
        }
    }

    func restoreOriginalAccount() async {
        let transition = await beginAuthenticationTransition()
        do {
            let member = try await authService.restoreOriginalAccount()
            guard isCurrentAuthenticationTransition(transition) else { return }
            clearImpersonationExpiration()
            guard await authenticate(
                member,
                availability: .online,
                syncAlreadyCancelledFor: transition.previousMember?.id,
                expectedAuthenticationSessionGeneration: transition.generation
            ) else {
                return
            }
            DPHapticCenter.shared.emit(.success)
        } catch {
            guard isCurrentAuthenticationTransition(transition) else { return }
            pendingDestination = nil
            // Restoring the original account is a terminal server-side
            // transition. Keep the existing policy of ending the local
            // session, while avoiding a second cancellation of the account
            // whose sync was stopped before the auth call.
            await terminateSession(
                reportServerFailure: true,
                syncAlreadyCancelledFor: transition.previousMember?.id
            )
        }
    }

    func impersonationRemainingTime(at date: Date = .now) -> TimeInterval? {
        impersonationExpiresAt.map { max(0, $0.timeIntervalSince(date)) }
    }

    func deferDestinationUntilAuthenticated(_ destination: URL) {
        pendingDestination = destination
    }

    func consumePendingDestination() -> URL? {
        defer { pendingDestination = nil }
        return pendingDestination
    }

    private func authenticate(
        _ member: LoginMember,
        availability: SessionAvailability,
        persistSnapshot: Bool = true,
        syncAlreadyCancelledFor: MemberID? = nil,
        expectedAuthenticationSessionGeneration: UInt64? = nil
    ) async -> Bool {
        if let expectedAuthenticationSessionGeneration,
           authenticationSessionGeneration != expectedAuthenticationSessionGeneration {
            return false
        }
        let sessionContext = beginAuthenticationSession(for: member)
        await purgePreviousAccountIfNeeded(
            for: member,
            syncAlreadyCancelledFor: syncAlreadyCancelledFor
        )
        guard authenticationSessionGeneration == sessionContext.generation else {
            return false
        }
        await localDataPurger.reopenLocalData(for: member.id)
        guard authenticationSessionGeneration == sessionContext.generation else {
            return false
        }
        accountDeletionAcceptedPresentation = nil
        serverSessionWarning = nil
        await authService.setContextualAuthenticationFailureHandler { [weak self] context in
            await self?.authenticationDidFail(for: context)
        }
        guard authenticationSessionGeneration == sessionContext.generation else {
            return false
        }
        await authService.setAuthenticationSessionContext(sessionContext)
        guard authenticationSessionGeneration == sessionContext.generation else {
            return false
        }
        await authService.setImpersonating(member.isImpersonating)
        guard authenticationSessionGeneration == sessionContext.generation else {
            return false
        }
        AIScheduleParsingConsentStore.shared.scope(to: member.id)
        self.availability = availability
        state = .authenticated(member)
        if persistSnapshot {
            try? await offlineSessionStore.save(member, at: nil)
        }
        guard authenticationSessionGeneration == sessionContext.generation else {
            return false
        }
        TodoAttachmentDiscardCoordinator.shared.activate(
            accountID: member.id,
            sessionGeneration: sessionContext.generation
        )
        if availability == .online {
            TodoAttachmentDiscardCoordinator.shared.retryPending(
                accountID: member.id,
                sessionGeneration: sessionContext.generation
            )
        }
        if member.isImpersonating, let impersonationExpiresAt {
            scheduleImpersonationExpiration(at: impersonationExpiresAt)
        } else if !member.isImpersonating {
            clearImpersonationExpiration()
        }
        return true
    }

    private func becomeGuest() async {
        impersonationExpiryTask?.cancel()
        clearImpersonationExpiration()
        await invalidateAuthenticationContext()
        await authService.setImpersonating(false)
        AIScheduleParsingConsentStore.shared.scope(to: nil)
        availability = .online
        state = .guest
        if accountDeletionReceipt != nil {
            accountDeletionAcceptedPresentation = .accepted
        }
    }

    private func authenticationDidFail(
        for context: AuthenticationSessionContext?
    ) async {
        guard let context,
              context.generation == authenticationSessionGeneration,
              case .authenticated(let member) = state,
              member.id == context.memberID
        else { return }

        pendingDestination = nil
        await terminateSession(reportServerFailure: true)
    }

    private func invalidateAuthenticatedSession() async {
        guard !isTerminatingSession else { return }
        isTerminatingSession = true
        defer { finishSessionTermination() }

        await invalidateAuthenticationContext()
        await discardLocalSessionData(memberID: memberIDForCurrentState)
        await authService.clearLocalAuthentication()
        await becomeGuest()
    }

    private func isCurrentRevalidation(
        generation: UInt64,
        memberID: MemberID
    ) -> Bool {
        guard authenticationSessionGeneration == generation,
              availability == .offline,
              case .authenticated(let member) = state,
              member.id == memberID
        else { return false }
        return true
    }

    private func terminateSession(
        reportServerFailure: Bool,
        syncAlreadyCancelledFor: MemberID? = nil,
        purgeAttachmentDiscards: Bool = false
    ) async {
        guard !isTerminatingSession else { return }
        isTerminatingSession = true
        defer { finishSessionTermination() }
        let memberID = memberIDForCurrentState
        await invalidateAuthenticationContext()
        if syncAlreadyCancelledFor == nil || memberID != syncAlreadyCancelledFor {
            await cancelOfflineSync(memberID)
        }
        await unregisterPush()
        do {
            try await authService.logout()
            serverSessionWarning = nil
        } catch {
            serverSessionWarning = reportServerFailure ? .serverMayRemain : nil
        }
        await authService.clearLocalAuthentication()
        await discardLocalSessionData(
            memberID: memberID,
            syncAlreadyCancelled: true,
            purgeAttachmentDiscards: purgeAttachmentDiscards
        )
        await becomeGuest()
    }

    private func scheduleImpersonationExpiration(at expiration: Date) {
        impersonationExpiryTask?.cancel()
        impersonationExpiryTask = Task { [weak self] in
            let delay = max(0, expiration.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.restoreOriginalAccount()
        }
    }

    private func clearImpersonationExpiration() {
        impersonationExpiryTask?.cancel()
        impersonationExpiryTask = nil
        impersonationExpiresAt = nil
        UserDefaults.standard.removeObject(forKey: Self.impersonationExpirationKey)
    }

    /// Stops the previous account's work before any auth API is allowed to
    /// replace its cookies. Clearing the request context first also makes an
    /// in-flight failure from the old account harmless while the transition
    /// waits for cancellation to finish.
    private func beginAuthenticationTransition() async -> AuthenticationTransitionContext {
        await waitForSessionTermination()
        let previousMember = memberForCurrentState
        authenticationTransitionFailure = nil
        let generation = await invalidateAuthenticationContext()
        if let previousMember {
            await cancelOfflineSync(previousMember.id)
        }
        return AuthenticationTransitionContext(
            previousMember: previousMember,
            generation: generation
        )
    }

    /// An authenticated account must not be restored after an auth transition
    /// has changed cookies, even when the auth request failed after partially
    /// installing the replacement credentials.  Clear only local state here:
    /// a server logout could be sent with the replacement account's cookies.
    private func terminateFailedAuthenticationTransition(for memberID: MemberID) async {
        guard !isTerminatingSession else { return }
        isTerminatingSession = true
        defer { finishSessionTermination() }

        pendingDestination = nil
        await authService.clearLocalAuthentication()
        await discardLocalSessionData(
            memberID: memberID,
            syncAlreadyCancelled: true
        )
        await becomeGuest()
    }

    private func clearFailedAuthenticationTransition() async {
        guard !isTerminatingSession else { return }
        isTerminatingSession = true
        defer { finishSessionTermination() }

        await authService.clearLocalAuthentication()
        await authService.setImpersonating(false)
    }

    private func waitForSessionTermination() async {
        guard isTerminatingSession else { return }
        await withCheckedContinuation { continuation in
            if isTerminatingSession {
                sessionTerminationWaiters.append(continuation)
            } else {
                continuation.resume()
            }
        }
    }

    private func finishSessionTermination() {
        isTerminatingSession = false
        let waiters = sessionTerminationWaiters
        sessionTerminationWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    private func beginAuthenticationSession(
        for member: LoginMember
    ) -> AuthenticationSessionContext {
        // A successful authentication starts a fresh credential generation.
        // Stop any prior model-backed discard task before the new context is
        // published; its durable session IDs remain available for retry below.
        TodoAttachmentDiscardCoordinator.shared.cancelAll()
        authenticationSessionGeneration &+= 1
        return AuthenticationSessionContext(
            memberID: member.id,
            generation: authenticationSessionGeneration
        )
    }

    @discardableResult
    private func invalidateAuthenticationContext() async -> UInt64 {
        authenticationSessionGeneration &+= 1
        let generation = authenticationSessionGeneration
        // Attachment discard requests retain only account-scoped session IDs,
        // but a model-backed request must not continue after auth cookies are
        // invalidated. The durable record remains for the same account to
        // retry after a later login.
        TodoAttachmentDiscardCoordinator.shared.cancelAll()
        await authService.invalidateAuthenticationSession()
        return generation
    }

    private func isCurrentAuthenticationTransition(
        _ transition: AuthenticationTransitionContext
    ) -> Bool {
        authenticationSessionGeneration == transition.generation
    }

    private var memberForCurrentState: LoginMember? {
        guard case .authenticated(let member) = state else { return nil }
        return member
    }

    private var memberIDForCurrentState: MemberID? {
        memberForCurrentState?.id
    }

    private func isCurrentAccount(
        memberID: MemberID,
        generation: UInt64
    ) -> Bool {
        memberIDForCurrentState == memberID
            && authenticationSessionGeneration == generation
    }

    private func purgePreviousAccountIfNeeded(
        for member: LoginMember,
        syncAlreadyCancelledFor: MemberID? = nil
    ) async {
        let currentMember: LoginMember?
        if case .authenticated(let authenticatedMember) = state {
            currentMember = authenticatedMember
        } else {
            // A process can be relaunched after a crash or an interrupted
            // logout with a regular snapshot but no in-memory authenticated
            // state.  A successful login as another account must still clear
            // that account's feature cache and outbox.
            currentMember = await offlineSessionStore.load(at: nil)
        }
        guard let currentMember,
              currentMember.id != member.id ||
                currentMember.isImpersonating != member.isImpersonating
        else { return }

        if currentMember.id != syncAlreadyCancelledFor {
            await cancelOfflineSync(currentMember.id)
        }
        await localDataPurger.purgeLocalData(for: currentMember.id)
        await offlineSessionStore.purge()
    }

    private func discardLocalSessionData(
        memberID: MemberID?,
        syncAlreadyCancelled: Bool = false,
        purgeAttachmentDiscards: Bool = false
    ) async {
        if !syncAlreadyCancelled {
            await cancelOfflineSync(memberID)
        }
        if let memberID {
            if purgeAttachmentDiscards {
                TodoAttachmentDiscardStore.shared.purge(accountID: memberID)
            }
        } else if purgeAttachmentDiscards {
            TodoAttachmentDiscardStore.shared.purgeAll()
        }
        await localDataPurger.purgeLocalData(for: memberID)
        await offlineSessionStore.purge()
    }
}

private extension APIError {
    var isAuthenticationRejection: Bool {
        switch self {
        case .server(status: 401, _), .serverWithDetails(status: 401, _, _),
             .server(status: 403, _), .serverWithDetails(status: 403, _, _):
            true
        default:
            false
        }
    }

    var supportsOfflineSessionFallback: Bool {
        switch self {
        case .transport:
            true
        case .server(let status, _), .serverWithDetails(let status, _, _):
            status >= 500
        default:
            false
        }
    }
}
