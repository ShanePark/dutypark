import SwiftUI

@main
struct DutyparkApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var notificationDelegate
    @StateObject private var session: SessionStore
    @AppStorage(SettingsPreference.languageKey) private var languageCode = ""
    @AppStorage(SettingsPreference.themeKey) private var themeCode = SettingsPreference.defaultTheme

    init() {
        let initialState: SessionState
        if CommandLine.arguments.contains("-ui-testing-authenticated") {
            initialState = .authenticated(
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
        } else {
            initialState = .restoring
        }
        _session = StateObject(wrappedValue: SessionStore(initialState: initialState))
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
