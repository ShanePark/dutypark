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

@MainActor
final class SessionStore: ObservableObject {
    private static let impersonationExpirationKey = "dp-impersonation-expires"

    private let authService: AuthService
    private var impersonationExpiryTask: Task<Void, Never>?

    @Published private(set) var state: SessionState
    @Published private(set) var isWorking = false
    @Published private(set) var loginErrorKey: String?
    @Published private(set) var loginRemainingAttempts: Int?
    @Published private(set) var impersonationExpiresAt: Date?
    @Published private(set) var pendingDestination: URL?
    @Published private(set) var accountDeletionAcceptedPresentation: AccountDeletionAcceptedPresentation?

    init(
        authService: AuthService = AuthService(),
        initialState: SessionState = .restoring,
        impersonationExpiresAt: Date? = nil
    ) {
        self.authService = authService
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

    func login(email: String, password: String, rememberMe: Bool) async {
        guard !isWorking else { return }
        isWorking = true
        accountDeletionAcceptedPresentation = nil
        loginErrorKey = nil
        loginRemainingAttempts = nil
        defer { isWorking = false }

        do {
            let member = try await authService.login(
                email: email,
                password: password,
                rememberMe: rememberMe
            )
            await authenticate(member)
        } catch let error as APIError {
            switch error {
            case .serverWithDetails(status: 429, _, let details):
                loginErrorKey = "auth.login.error.rateLimited"
                loginRemainingAttempts = details.remainingAttempts
            case .serverWithDetails(status: 401, _, let details):
                loginErrorKey = "auth.login.error.invalidCredentials"
                loginRemainingAttempts = details.remainingAttempts
            case .server(status: 429, _):
                loginErrorKey = "auth.login.error.rateLimited"
            case .server(status: 401, _):
                loginErrorKey = "auth.login.error.invalidCredentials"
            default:
                loginErrorKey = "auth.login.error.generic"
            }
        } catch {
            loginErrorKey = "auth.login.error.generic"
        }
    }

    func logout() async {
        guard !isWorking else { return }
        isWorking = true
        defer {
            isWorking = false
        }
        try? await authService.logout()
        await authService.clearLocalAuthentication()
        await becomeGuest()
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
    }

    func dismissAccountDeletionAcceptedPresentation() {
        accountDeletionAcceptedPresentation = nil
    }

    func finishExternalLogin() async throws {
        guard let member = try await authService.status() else {
            throw APIError.invalidResponse
        }
        await authenticate(member)
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
    }

    func restoreOriginalAccount() async {
        do {
            let member = try await authService.restoreOriginalAccount()
            clearImpersonationExpiration()
            AIScheduleParsingConsentStore.shared.scope(to: member.id)
            accountDeletionAcceptedPresentation = nil
            state = .authenticated(member)
        } catch {
            await becomeGuest()
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
