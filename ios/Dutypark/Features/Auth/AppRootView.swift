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
                } actions: {
                    Button("common.retry") {
                        Task { await session.retryRestore() }
                    }
                    .accessibilityIdentifier("session.retry")
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
    }
}

enum AppRootDeepLinkPolicy {
    static func shouldDeferDestination(_ destination: URL, for state: SessionState) -> Bool {
        guard state == .restoring || state == .restoreFailed || state == .guest else {
            return false
        }
        if GuestDeepLink.route(from: destination) != nil {
            return true
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
}
