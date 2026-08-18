import Foundation
import Testing
@testable import Dutypark

@Suite(.serialized)
@MainActor
struct AppTabTests {
    @Test
    func exposesTheFiveWebNavigationTabsInOrder() {
        #expect(AppTab.allCases == [.home, .calendar, .todo, .team, .more])
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
                == ["홈", "달력", "할일", "팀", "더보기"]
        )
    }

    @Test
    func tappingATabInTheTabBarPopsThatTabToItsRoot() {
        #expect(RootNavigationPolicy.popsToRoot(origin: .tabBar))
        // A route that pushed a screen must keep it: it selects the tab itself.
        #expect(!RootNavigationPolicy.popsToRoot(origin: .explicitRoute))
    }

    @Test
    func aMemberCalendarIsPushedOntoTheStackOfTheTabItWasOpenedFrom() {
        for tab in AppTab.allCases where tab != .todo {
            #expect(RootNavigationPolicy.memberCalendarHost(for: tab) == tab)
        }
        // The todo tab has no member entry point, so a calendar reached from it lands on
        // the calendar tab, whose root is the member's own calendar.
        #expect(RootNavigationPolicy.memberCalendarHost(for: .todo) == .calendar)
    }

    @Test
    func moreMenuScreensPushOntoTheMoreTabInsteadOfSwitchingTabs() {
        #expect(RootNavigationPolicy.moreDestination(for: .friends) == .friends)
        #expect(RootNavigationPolicy.moreDestination(for: .admin) == .admin)
        #expect(RootNavigationPolicy.moreDestination(for: .guide) == .guide)
        #expect(RootNavigationPolicy.moreDestination(for: .settings) == .settings)
        // Presented as an overlay and a confirmation, so neither owns a pushed screen.
        #expect(RootNavigationPolicy.moreDestination(for: .notifications) == nil)
        #expect(RootNavigationPolicy.moreDestination(for: .logout) == nil)
    }

    @Test
    func onlyNavigationThatAsksForAPolicyPageCarriesASettingsDestination() {
        #expect(
            RootNavigationPolicy.settingsDestination(for: .settings, requested: .terms) == .terms
        )
        #expect(RootNavigationPolicy.settingsDestination(for: .settings, requested: nil) == nil)
        // Opening settings from the menu must not re-push a page a deep link asked for.
        #expect(RootNavigationPolicy.settingsDestination(for: .myInfo, requested: .terms) == nil)
        #expect(RootNavigationPolicy.settingsDestination(for: .guide, requested: .guide) == nil)
    }

    @Test
    func everyTabWithAStackIsPoppedByItsOwnTabBarItem() throws {
        let rootSource = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Dutypark/App/RootTabView.swift"),
            encoding: .utf8
        )

        #expect(rootSource.contains("popToRoot(destination, origin: .tabBar)"))
        for pop in [
            "case .home:\n            homePath.removeAll()",
            "case .calendar:\n            calendarPath.removeAll()",
            "case .team:\n            teamPath.removeAll()",
            "case .more:\n            morePath.removeAll()",
        ] {
            #expect(rootSource.contains(pop), "RootTabView is missing: \(pop)")
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
