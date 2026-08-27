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
    @StateObject private var push = APNsRegistrationManager.shared
    @StateObject private var offlineSyncCoordinator = OfflineSyncCoordinator.shared

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
            ContentFilterStore.shared.load()
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
        .alert(
            SettingsLocalization.string("settings.push.permissionTitle"),
            isPresented: $push.showsPermissionPreprompt
        ) {
            Button(SettingsLocalization.string("settings.action.cancel"), role: .cancel) {}
            Button(SettingsLocalization.string("settings.push.continue")) {
                Task { await push.continuePermissionRequest() }
            }
        } message: {
            SettingsLocalization.text("settings.push.permissionMessage")
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
                // Keep the offline status in the root layout itself. An outer
                // `safeAreaInset` is not adopted by the UIKit navigation bars inside
                // RootTabView, so it can paint over the header and blend with its
                // material backdrop. A sibling in this stack reserves real vertical
                // space and keeps the status text readable in every root tab.
                VStack(spacing: 0) {
                    OfflineSessionBanner(
                        accountID: member.id,
                        availability: session.availability,
                        coordinator: offlineSyncCoordinator
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    RootTabView()
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .id("\(member.id)-\(member.isImpersonating)-\(member.originalMemberId ?? 0)")
                }
            }
        }
        .alert(
            "auth.transition.failure.title",
            isPresented: Binding(
                get: { session.authenticationTransitionFailure != nil },
                set: {
                    if !$0 {
                        session.dismissAuthenticationTransitionFailure()
                    }
                }
            )
        ) {
            Button("auth.transition.failure.ok", role: .cancel) {
                session.dismissAuthenticationTransitionFailure()
            }
        } message: {
            Text("auth.transition.failure.message")
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

private struct OfflineSessionBanner: View {
    let accountID: MemberID
    let availability: SessionAvailability
    @ObservedObject var coordinator: OfflineSyncCoordinator

    var body: some View {
        let hasStatus = availability.isOffline
            || coordinator.isSyncing
            || coordinator.pendingCount > 0
            || coordinator.permanentFailureCount > 0
        Group {
            if hasStatus {
                VStack(alignment: .leading, spacing: 2) {
                    if availability.isOffline {
                        Label(
                            "auth.session.offline",
                            systemImage: "wifi.slash"
                        )
                    }
                    if coordinator.isSyncing {
                        Label(
                            "root.offline.syncing",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                    if coordinator.pendingCount > 0 {
                        Text(
                            formatted(
                                "root.offline.pending",
                                count: coordinator.pendingCount
                            )
                        )
                    }
                    if coordinator.permanentFailureCount > 0 {
                        Text(
                            formatted(
                                "root.offline.failures",
                                count: coordinator.permanentFailureCount
                            )
                        )
                        Button("root.offline.retryFailures") {
                            Task {
                                await coordinator.retryPermanentFailures(
                                    accountID: accountID,
                                    networkStatus: availability.isOffline
                                        ? .unsatisfied
                                        : .satisfied
                                )
                            }
                        }
                        .accessibilityIdentifier("session.offline.retry-failures")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                // This surface must be opaque. A translucent fill lets the system
                // navigation/tab materials show through the text when the banner is
                // stacked above a root tab.
                .background(DPColor.backgroundSecondary)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(DPColor.warningBorder)
                        .frame(height: 1)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("session.offline")
            }
        }
    }

    private func formatted(_ key: String, count: Int) -> String {
        let locale = AppLocalization.locale
        return String(
            format: RootChromeLocalization.localizable(key, locale: locale),
            locale: locale,
            arguments: [count]
        )
    }
}

nonisolated enum LaunchSplashPresentation {
    static let assetName = "LaunchSplash"
}

struct LaunchSplashView: View {
    var body: some View {
        // `Color.clear` pins the layout to the proposed screen size so the aspect-filled
        // artwork overflows symmetrically. Sizing the image itself would make this view
        // wider than the screen, and the window would pin it to the leading edge, shifting
        // the artwork sideways as the launch storyboard hands off to SwiftUI.
        Color.clear
            .overlay {
                Image(LaunchSplashPresentation.assetName)
                    .resizable()
                    .scaledToFill()
            }
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
