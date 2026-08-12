import SwiftUI

@main
struct DutyparkApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var notificationDelegate
    @StateObject private var session: SessionStore
    @AppStorage(SettingsPreference.languageKey) private var languageCode = ""
    @AppStorage(SettingsPreference.themeKey) private var themeCode = SettingsPreference.defaultTheme

    init() {
        DPBrandChrome.configureAppearance()

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
        guard let language = AppLanguage(rawValue: languageCode) else {
            return .current
        }
        return Locale(identifier: language.rawValue)
    }

    private var selectedColorScheme: ColorScheme? {
        (AppTheme(rawValue: themeCode) ?? .system).preferredColorScheme
    }
}
