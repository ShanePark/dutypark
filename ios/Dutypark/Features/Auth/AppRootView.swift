import SwiftUI

#if DEBUG
nonisolated enum UITestingDestination: Equatable {
    case ssoSignup
    case attachmentGallery
    case admin

    init?(arguments: [String]) {
        if arguments.contains("-ui-testing-sso-signup") {
            self = .ssoSignup
        } else if arguments.contains("-ui-testing-direct-attachment-gallery") {
            self = .attachmentGallery
        } else if arguments.contains("-ui-testing-admin") {
            self = .admin
        } else {
            return nil
        }
    }
}
#endif

struct AppRootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            #if DEBUG
            if let uiTestingDestination {
                uiTestingContent(for: uiTestingDestination)
            } else {
                sessionContent
            }
            #else
            sessionContent
            #endif
        }
        .task {
            #if DEBUG
            guard uiTestingDestination == nil else { return }
            #endif
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

    @ViewBuilder
    private var sessionContent: some View {
        Group {
            switch session.state {
            case .restoring:
                LaunchSplashView()
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
    }

    #if DEBUG
    private var uiTestingDestination: UITestingDestination? {
        UITestingDestination(arguments: ProcessInfo.processInfo.arguments)
    }

    @ViewBuilder
    private func uiTestingContent(for destination: UITestingDestination) -> some View {
        switch destination {
        case .ssoSignup:
            SsoSignupView(
                uuid: "ui-test-signup",
                oauthClient: MobileOAuthClient()
            )
            .environmentObject(session)
        case .attachmentGallery:
            AttachmentGalleryUITestingFixtureView()
        case .admin:
            NavigationStack {
                AdminRootView(onOpenCalendar: { _ in })
            }
            .environmentObject(session)
        }
    }
    #endif
}

nonisolated enum LaunchSplashPresentation {
    static let assetName = "LaunchSplash"
}

private struct LaunchSplashView: View {
    var body: some View {
        Image(LaunchSplashPresentation.assetName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea()
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
