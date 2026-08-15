import Foundation
import Testing
@testable import Dutypark

@Suite(.serialized)
@MainActor
struct AppTabTests {
    @Test
    func exposesTheFiveWebNavigationTabsInOrder() {
        #expect(AppTab.allCases == [.home, .calendar, .todo, .team, .settings])
    }

    @Test
    func providesStableAccessibilityIdentifiers() {
        #expect(AppTab.home.accessibilityIdentifier == "tab.home")
        #expect(Set(AppTab.allCases.map(\.accessibilityIdentifier)).count == AppTab.allCases.count)
    }

    @Test
    func usesTheWebCalendarLabelInKorean() throws {
        let localizationURL = try #require(
            Bundle.main.url(forResource: "ko", withExtension: "lproj")
        )
        let localizationBundle = try #require(Bundle(url: localizationURL))

        #expect(
            localizationBundle.localizedString(
                forKey: "tab.calendar",
                value: "tab.calendar",
                table: "Localizable"
            ) == "달력"
        )
    }

    @Test
    func localizedTitlesPreferKoreanAppLanguageOverEnglishDeviceLanguage() {
        let defaults = UserDefaults.standard
        let previousAppLanguage = defaults.object(forKey: SettingsPreference.languageKey)
        let previousDeviceLanguages = defaults.object(forKey: "AppleLanguages")
        defaults.set("ko", forKey: SettingsPreference.languageKey)
        defaults.set(["en"], forKey: "AppleLanguages")
        defer {
            restore(previousAppLanguage, forKey: SettingsPreference.languageKey, in: defaults)
            restore(previousDeviceLanguages, forKey: "AppleLanguages", in: defaults)
        }

        #expect(
            AppTab.allCases.map(\.localizedTitle)
                == ["홈", "달력", "할일", "팀", "설정"]
        )
    }

    @Test
    func selectingCalendarFromTabBarResetsToMyCalendar() {
        #expect(
            RootNavigationPolicy.resetsCalendarTarget(
                for: .calendar,
                origin: .tabBar
            )
        )
        #expect(
            !RootNavigationPolicy.resetsCalendarTarget(
                for: .calendar,
                origin: .explicitRoute
            )
        )
    }

    @Test
    func selectingOtherTabsDoesNotMutateCalendarTarget() {
        for tab in AppTab.allCases where tab != .calendar {
            #expect(
                !RootNavigationPolicy.resetsCalendarTarget(
                    for: tab,
                    origin: .tabBar
                )
            )
        }
    }

    private func restore(_ value: Any?, forKey key: String, in defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
