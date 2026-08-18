import SwiftUI

nonisolated enum DutyparkLaunchPolicy {
    static func initialSessionState(arguments: [String]) -> SessionState {
#if DEBUG
        if arguments.contains("-ui-testing-service-admin") ||
            arguments.contains("-ui-testing-admin") {
            return .authenticated(
                LoginMember(
                    id: 1,
                    email: "admin@duty.park",
                    name: "Service Admin",
                    teamId: nil,
                    team: nil,
                    isAdmin: true,
                    isImpersonating: false,
                    originalMemberId: nil
                )
            )
        }
        if arguments.contains("-ui-testing-impersonating") {
            return .authenticated(
                LoginMember(
                    id: 2,
                    email: "managed@duty.park",
                    name: "Managed",
                    teamId: nil,
                    team: nil,
                    isAdmin: false,
                    isImpersonating: true,
                    originalMemberId: 1
                )
            )
        }
        if arguments.contains("-ui-testing-authenticated") {
            return .authenticated(
                LoginMember(
                    id: 1,
                    email: "test@duty.park",
                    name: "Test",
                    teamId: nil,
                    team: nil,
                    isAdmin: false,
                    isImpersonating: false,
                    originalMemberId: nil
                )
            )
        }
        if arguments.contains("-ui-testing-guest") {
            return .guest
        }
#endif
        return .restoring
    }

    /// Deterministic impersonation countdown for the UI-test fixture so the banner's
    /// remaining-time row renders without a live impersonation session.
    static func initialImpersonationExpiration(
        arguments: [String],
        now: Date = .now
    ) -> Date? {
#if DEBUG
        if arguments.contains("-ui-testing-impersonating") {
            return now.addingTimeInterval(600)
        }
#endif
        return nil
    }
}

@main
struct DutyparkApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var notificationDelegate
    @StateObject private var session: SessionStore
    @AppStorage(SettingsPreference.languageKey) private var languageCode = ""
    @AppStorage(SettingsPreference.themeKey) private var themeCode = SettingsPreference.defaultTheme

    init() {
        let arguments = CommandLine.arguments
        let initialState = DutyparkLaunchPolicy.initialSessionState(arguments: arguments)
        _session = StateObject(wrappedValue: SessionStore(
            initialState: initialState,
            impersonationExpiresAt: DutyparkLaunchPolicy.initialImpersonationExpiration(
                arguments: arguments
            ),
            unregisterPush: { await APNsRegistrationManager.shared.unregister() }
        ))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(session)
                .environment(\.locale, selectedLocale)
                .preferredColorScheme(selectedColorScheme)
        }
    }

    private var selectedLocale: Locale {
        AppLocalization.supportedLocale(languageCode: languageCode)
    }

    private var selectedColorScheme: ColorScheme? {
        (AppTheme(rawValue: themeCode) ?? .system).preferredColorScheme
    }
}
