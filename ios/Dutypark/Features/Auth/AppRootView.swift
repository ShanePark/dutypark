import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            switch session.state {
            case .restoring:
                ProgressView()
                    .accessibilityLabel(Text("auth.session.restoring"))
            case .restoreFailed:
                ContentUnavailableView {
                    Label("auth.session.error", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("auth.session.error.description")
                } actions: {
                    Button("common.retry") {
                        Task { await session.retryRestore() }
                    }
                    .accessibilityIdentifier("session.retry")
                    Button("auth.session.continueAsGuest") {
                        Task { await session.continueAsGuestAfterRestoreFailure() }
                    }
                    .accessibilityIdentifier("session.continueAsGuest")
                }
            case .guest:
                if session.accountDeletionAcceptedPresentation != nil {
                    AccountDeletionAcceptedView {
                        session.dismissAccountDeletionAcceptedPresentation()
                    }
                } else {
                    GuestRootView()
                }
            case .authenticated(let member):
                RootTabView()
                    .id("\(member.id)-\(member.isImpersonating)-\(member.originalMemberId ?? 0)")
            }
        }
        .task {
            await session.restore()
        }
        .onOpenURL { url in
            if AppRootDeepLinkPolicy.shouldDeferDestination(url, for: session.state) {
                session.deferDestinationUntilAuthenticated(url)
            }
        }
        .alert(
            "auth.logout.serverWarning.title",
            isPresented: Binding(
                get: { session.serverSessionWarning != nil },
                set: { if !$0 { session.dismissServerSessionWarning() } }
            )
        ) {
            Button("auth.logout.serverWarning.ok", role: .cancel) {
                session.dismissServerSessionWarning()
            }
        } message: {
            Text("auth.logout.serverWarning.message")
        }
    }
}

enum AppRootDeepLinkPolicy {
    static func shouldDeferDestination(_ destination: URL, for state: SessionState) -> Bool {
        guard state == .restoring || state == .restoreFailed || state == .guest else {
            return false
        }
        if GuestDeepLink.route(from: destination) != nil {
            return state == .restoring || state == .restoreFailed
        }
        guard destination.scheme?.lowercased() == "https",
              destination.host?.lowercased() == "dutypark.o-r.kr"
        else { return false }

        switch destination.pathComponents.filter({ $0 != "/" }) {
        case ["todo"], ["team"], ["member"], ["friends"], ["notifications"]:
            return true
        default:
            return false
        }
    }

    static func requiresAuthentication(_ destination: URL) -> Bool {
        guard destination.scheme?.lowercased() == "https",
              destination.host?.lowercased() == "dutypark.o-r.kr"
        else { return false }

        switch destination.pathComponents.filter({ $0 != "/" }) {
        case ["todo"], ["team"], ["member"], ["friends"], ["notifications"]:
            return true
        default:
            return false
        }
    }
}
