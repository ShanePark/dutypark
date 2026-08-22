import Foundation
import Combine

enum SessionState: Equatable {
    case restoring
    case restoreFailed
    case guest
    case authenticated(LoginMember)
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
    private var impersonationExpiryTask: Task<Void, Never>?
    private var isTerminatingSession = false

    @Published private(set) var state: SessionState
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
        unregisterPush: @escaping @MainActor @Sendable () async -> Void = {}
    ) {
        self.authService = authService
        self.unregisterPush = unregisterPush
        self.state = initialState
        self.impersonationExpiresAt = impersonationExpiresAt
            ?? UserDefaults.standard.object(forKey: Self.impersonationExpirationKey) as? Date
    }

    func restore() async {
        guard state == .restoring else { return }
        accountDeletionAcceptedPresentation = nil
        do {
            if let member = try await authService.restore() {
                await authenticate(member)
            } else {
                await authService.clearLocalAuthentication()
                await becomeGuest()
            }
        } catch {
            state = .restoreFailed
        }
    }

    func retryRestore() async {
        guard state == .restoreFailed else { return }
        state = .restoring
        await restore()
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

        do {
            let member = try await authService.login(
                email: email,
                password: password,
                rememberMe: rememberMe
            )
            await authenticate(member)
            DPHapticCenter.shared.emit(.success)
        } catch let error as APIError {
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
        if case .authenticated(let member) = state {
            UserDefaults.standard.removeObject(forKey: "selectedDday_\(member.id)")
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
        guard let member = try await authService.status() else {
            throw APIError.invalidResponse
        }
        await authenticate(member)
        if emitsHaptic {
            DPHapticCenter.shared.emit(.success)
        }
    }

    func impersonate(memberId: Int64) async throws {
        let (member, expiresIn) = try await authService.impersonate(memberId: memberId)
        let expiration = Date().addingTimeInterval(TimeInterval(expiresIn))
        impersonationExpiresAt = expiration
        UserDefaults.standard.set(expiration, forKey: Self.impersonationExpirationKey)
        AIScheduleParsingConsentStore.shared.scope(to: member.id)
        accountDeletionAcceptedPresentation = nil
        state = .authenticated(member)
        scheduleImpersonationExpiration(at: expiration)
        DPHapticCenter.shared.emit(.success)
    }

    func restoreOriginalAccount() async {
        do {
            let member = try await authService.restoreOriginalAccount()
            clearImpersonationExpiration()
            AIScheduleParsingConsentStore.shared.scope(to: member.id)
            accountDeletionAcceptedPresentation = nil
            state = .authenticated(member)
            DPHapticCenter.shared.emit(.success)
        } catch {
            pendingDestination = nil
            await terminateSession(reportServerFailure: true)
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

    private func authenticate(_ member: LoginMember) async {
        accountDeletionAcceptedPresentation = nil
        serverSessionWarning = nil
        await authService.setAuthenticationFailureHandler { [weak self] in
            await self?.authenticationDidFail()
        }
        await authService.setImpersonating(member.isImpersonating)
        AIScheduleParsingConsentStore.shared.scope(to: member.id)
        state = .authenticated(member)
        if member.isImpersonating, let impersonationExpiresAt {
            scheduleImpersonationExpiration(at: impersonationExpiresAt)
        } else if !member.isImpersonating {
            clearImpersonationExpiration()
        }
    }

    private func becomeGuest() async {
        impersonationExpiryTask?.cancel()
        clearImpersonationExpiration()
        await authService.setImpersonating(false)
        AIScheduleParsingConsentStore.shared.scope(to: nil)
        state = .guest
    }

    private func authenticationDidFail() async {
        pendingDestination = nil
        await terminateSession(reportServerFailure: true)
    }

    private func terminateSession(reportServerFailure: Bool) async {
        guard !isTerminatingSession else { return }
        isTerminatingSession = true
        defer { isTerminatingSession = false }
        await unregisterPush()
        do {
            try await authService.logout()
            serverSessionWarning = nil
        } catch {
            serverSessionWarning = reportServerFailure ? .serverMayRemain : nil
        }
        await authService.clearLocalAuthentication()
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
}
