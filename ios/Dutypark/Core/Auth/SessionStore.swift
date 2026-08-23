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

@MainActor
final class SessionStore: ObservableObject {
    private static let impersonationExpirationKey = "dp-impersonation-expires"

    private let authService: AuthService
    private let unregisterPush: @MainActor @Sendable () async -> Void
    private let offlineSessionStore: any OfflineSessionStoring
    private let localDataPurger: any SessionLocalDataPurging
    private let cancelOfflineSync: @MainActor @Sendable (MemberID?) async -> Void
    private var impersonationExpiryTask: Task<Void, Never>?
    private var isTerminatingSession = false
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
    @Published private(set) var serverSessionWarning: ServerSessionWarningPresentation?

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
        initialAvailability: SessionAvailability = .online
    ) {
        self.authService = authService
        self.unregisterPush = unregisterPush
        self.offlineSessionStore = offlineSessionStore
        self.localDataPurger = localDataPurger
        self.cancelOfflineSync = cancelOfflineSync
        self.state = initialState
        self.availability = initialAvailability
        self.impersonationExpiresAt = impersonationExpiresAt
            ?? UserDefaults.standard.object(forKey: Self.impersonationExpirationKey) as? Date
    }

    func restore() async {
        guard state == .restoring else { return }
        accountDeletionAcceptedPresentation = nil
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
        guard case .authenticated = state, availability == .offline else { return }

        do {
            if let member = try await authService.restore() {
                await authenticate(member, availability: .online)
            } else {
                await invalidateAuthenticatedSession()
            }
        } catch let error as APIError where error.isAuthenticationRejection {
            await invalidateAuthenticatedSession()
        } catch {
            // Keep serving the last verified local snapshot until a later
            // foreground/connection-recovery attempt succeeds.
        }
    }

    func continueAsGuestAfterRestoreFailure() async {
        guard state == .restoreFailed else { return }
        await terminateSession(reportServerFailure: true)
    }

    func login(email: String, password: String, rememberMe: Bool) async {
        guard !isWorking else { return }
        isWorking = true
        accountDeletionAcceptedPresentation = nil
        loginErrorKey = nil
        loginErrorStatus = nil
        loginRemainingAttempts = nil
        defer { isWorking = false }

        let previousMember = await beginAuthenticationTransition()
        do {
            let member = try await authService.login(
                email: email,
                password: password,
                rememberMe: rememberMe
            )
            await authenticate(
                member,
                availability: .online,
                syncAlreadyCancelledFor: previousMember?.id
            )
            DPHapticCenter.shared.emit(.success)
        } catch let error as APIError {
            if let previousMember {
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
            if let previousMember {
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
    func completeAccountDeletion() async {
        await invalidateAuthenticationContext()
        if case .authenticated(let member) = state {
            UserDefaults.standard.removeObject(forKey: "selectedDday_\(member.id)")
            await discardLocalSessionData(memberID: member.id)
        } else {
            await discardLocalSessionData(memberID: nil)
        }
        UserDefaults.standard.removeObject(forKey: "dp-remember-email")
        await authService.clearLocalAuthentication()
        pendingDestination = nil
        await becomeGuest()
        accountDeletionAcceptedPresentation = .accepted
        DPHapticCenter.shared.emit(.success)
    }

    func dismissAccountDeletionAcceptedPresentation() {
        accountDeletionAcceptedPresentation = nil
    }

    func dismissServerSessionWarning() {
        serverSessionWarning = nil
    }

    func finishExternalLogin(emitsHaptic: Bool = true) async throws {
        let previousMember = await beginAuthenticationTransition()
        do {
            guard let member = try await authService.status() else {
                throw APIError.invalidResponse
            }
            await authenticate(
                member,
                availability: .online,
                syncAlreadyCancelledFor: previousMember?.id
            )
            if emitsHaptic {
                DPHapticCenter.shared.emit(.success)
            }
        } catch {
            if let previousMember {
                await terminateFailedAuthenticationTransition(for: previousMember.id)
            } else {
                await clearFailedAuthenticationTransition()
            }
            throw error
        }
    }

    func impersonate(memberId: Int64) async throws {
        let previousMember = await beginAuthenticationTransition()
        do {
            let (member, expiresIn) = try await authService.impersonate(memberId: memberId)
            let expiration = Date().addingTimeInterval(TimeInterval(expiresIn))
            impersonationExpiresAt = expiration
            UserDefaults.standard.set(expiration, forKey: Self.impersonationExpirationKey)
            await authenticate(
                member,
                availability: .online,
                syncAlreadyCancelledFor: previousMember?.id
            )
            DPHapticCenter.shared.emit(.success)
        } catch {
            if let previousMember {
                await terminateFailedAuthenticationTransition(for: previousMember.id)
            } else {
                // A guest impersonation attempt has no prior cookie owner to
                // invalidate; still clear credentials partially installed by
                // the failed transition before preserving the thrown error.
                await clearFailedAuthenticationTransition()
            }
            throw error
        }
    }

    func restoreOriginalAccount() async {
        let previousMember = await beginAuthenticationTransition()
        do {
            let member = try await authService.restoreOriginalAccount()
            clearImpersonationExpiration()
            await authenticate(
                member,
                availability: .online,
                syncAlreadyCancelledFor: previousMember?.id
            )
            DPHapticCenter.shared.emit(.success)
        } catch {
            pendingDestination = nil
            // Restoring the original account is a terminal server-side
            // transition. Keep the existing policy of ending the local
            // session, while avoiding a second cancellation of the account
            // whose sync was stopped before the auth call.
            await terminateSession(
                reportServerFailure: true,
                syncAlreadyCancelledFor: previousMember?.id
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
        syncAlreadyCancelledFor: MemberID? = nil
    ) async {
        let sessionContext = beginAuthenticationSession(for: member)
        await purgePreviousAccountIfNeeded(
            for: member,
            syncAlreadyCancelledFor: syncAlreadyCancelledFor
        )
        await localDataPurger.reopenLocalData(for: member.id)
        accountDeletionAcceptedPresentation = nil
        serverSessionWarning = nil
        await authService.setContextualAuthenticationFailureHandler { [weak self] context in
            await self?.authenticationDidFail(for: context)
        }
        await authService.setAuthenticationSessionContext(sessionContext)
        await authService.setImpersonating(member.isImpersonating)
        AIScheduleParsingConsentStore.shared.scope(to: member.id)
        self.availability = availability
        state = .authenticated(member)
        if persistSnapshot {
            try? await offlineSessionStore.save(member, at: nil)
        }
        if member.isImpersonating, let impersonationExpiresAt {
            scheduleImpersonationExpiration(at: impersonationExpiresAt)
        } else if !member.isImpersonating {
            clearImpersonationExpiration()
        }
    }

    private func becomeGuest() async {
        impersonationExpiryTask?.cancel()
        clearImpersonationExpiration()
        await invalidateAuthenticationContext()
        await authService.setImpersonating(false)
        AIScheduleParsingConsentStore.shared.scope(to: nil)
        availability = .online
        state = .guest
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
        await invalidateAuthenticationContext()
        await discardLocalSessionData(memberID: memberIDForCurrentState)
        await authService.clearLocalAuthentication()
        await becomeGuest()
    }

    private func terminateSession(
        reportServerFailure: Bool,
        syncAlreadyCancelledFor: MemberID? = nil
    ) async {
        guard !isTerminatingSession else { return }
        isTerminatingSession = true
        defer { isTerminatingSession = false }
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
        await discardLocalSessionData(memberID: memberID, syncAlreadyCancelled: true)
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
    private func beginAuthenticationTransition() async -> LoginMember? {
        let previousMember = memberForCurrentState
        await invalidateAuthenticationContext()
        if let previousMember {
            await cancelOfflineSync(previousMember.id)
        }
        return previousMember
    }

    /// An authenticated account must not be restored after an auth transition
    /// has changed cookies, even when the auth request failed after partially
    /// installing the replacement credentials.  Clear only local state here:
    /// a server logout could be sent with the replacement account's cookies.
    private func terminateFailedAuthenticationTransition(for memberID: MemberID) async {
        guard !isTerminatingSession else { return }
        isTerminatingSession = true
        defer { isTerminatingSession = false }

        pendingDestination = nil
        await authService.clearLocalAuthentication()
        await discardLocalSessionData(
            memberID: memberID,
            syncAlreadyCancelled: true
        )
        await becomeGuest()
    }

    private func clearFailedAuthenticationTransition() async {
        await authService.clearLocalAuthentication()
        await authService.setImpersonating(false)
    }

    private func beginAuthenticationSession(
        for member: LoginMember
    ) -> AuthenticationSessionContext {
        authenticationSessionGeneration &+= 1
        return AuthenticationSessionContext(
            memberID: member.id,
            generation: authenticationSessionGeneration
        )
    }

    private func invalidateAuthenticationContext() async {
        authenticationSessionGeneration &+= 1
        await authService.invalidateAuthenticationSession()
    }

    private var memberForCurrentState: LoginMember? {
        guard case .authenticated(let member) = state else { return nil }
        return member
    }

    private var memberIDForCurrentState: MemberID? {
        memberForCurrentState?.id
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
        syncAlreadyCancelled: Bool = false
    ) async {
        if !syncAlreadyCancelled {
            await cancelOfflineSync(memberID)
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
