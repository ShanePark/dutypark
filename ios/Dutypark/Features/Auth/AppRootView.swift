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
            if session.state == .restoring || session.state == .restoreFailed {
                session.deferDestinationUntilAuthenticated(url)
            }
        }
    }
}
