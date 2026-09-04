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
    func localizedTitlesAreTranslatedInEverySupportedLanguage() {
        #expect(
            AppTab.allCases.map { title(for: $0, locale: .korean) }
                == ["홈", "달력", "할일", "팀", "더보기"]
        )
        #expect(
            AppTab.allCases.map { title(for: $0, locale: .english) }
                == ["Home", "Calendar", "Todo", "Team", "More"]
        )
        // The tab bar reads the same entry for whichever language iOS resolved.
        #expect(AppTab.home.localizedTitle == title(for: .home, locale: nil))
    }

    private func title(for tab: AppTab, locale: Locale?) -> String {
        AppLocalization.string("tab.\(tab.rawValue)", table: "Localizable", locale: locale)
    }

    @Test
    func tappingATabInTheTabBarPopsThatTabToItsRoot() {
        #expect(RootNavigationPolicy.popsToRoot(origin: .tabBar))
        // A route that pushed a screen must keep it: it selects the tab itself.
        #expect(!RootNavigationPolicy.popsToRoot(origin: .explicitRoute))
    }

    @Test
    func tabBarHapticsOnlyFireForAnActualUserTabChange() {
        #expect(
            RootHapticPolicy.tabSelectionFeedback(from: .home, to: .calendar)
                == .selection
        )
        // SwiftUI may write the selected value again while updating the tab view; that
        // is not a new interaction and must stay silent.
        #expect(RootHapticPolicy.tabSelectionFeedback(from: .home, to: .home) == nil)
        // Programmatic routes assign the state directly and therefore do not consult
        // the tab-bar binding, but this policy keeps the distinction explicit in tests.
        #expect(
            RootHapticPolicy.tabSelectionFeedback(origin: .explicitRoute) == nil
        )
    }

    @Test
    func reselectingTheOwnCalendarRootRequestsTheCurrentMonthWithoutTabFeedback() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let rootSource = try String(
            contentsOf: projectRoot.appending(path: "Dutypark/App/RootTabView.swift"),
            encoding: .utf8
        )
        let calendarSource = try String(
            contentsOf: projectRoot.appending(path: "Dutypark/Features/Calendar/CalendarView.swift"),
            encoding: .utf8
        )

        #expect(rootSource.contains("@State private var calendarCurrentMonthRequestID = 0"))
        #expect(rootSource.contains("currentMonthRequestID: calendarCurrentMonthRequestID"))
        for condition in [
            "selectedTab == .calendar",
            "destination == .calendar",
            "calendarPath.isEmpty",
            "calendarCurrentMonthRequestID &+= 1",
        ] {
            #expect(rootSource.contains(condition), "RootTabView is missing: \(condition)")
        }
        #expect(calendarSource.contains("currentMonthRequestID: Int = 0"))
        #expect(calendarSource.contains(".onChange(of: currentMonthRequestID)"))
        #expect(calendarSource.contains("await model.goToToday(emitFeedback: false)"))
        #expect(RootHapticPolicy.tabSelectionFeedback(from: .calendar, to: .calendar) == nil)
    }

    @Test
    func moreMenuHapticsSeparateNavigationFromDestructiveIntent() {
        #expect(RootHapticPolicy.moreMenuFeedback(for: .guide) == .routine)
        // The destructive confirmation button emits the warning; opening the prompt
        // itself stays silent so one logout action does not warn twice.
        #expect(RootHapticPolicy.moreMenuFeedback(for: .logout) == nil)
    }

    @Test
    func notificationDropdownUsesRoutineFeedbackForExplicitOpenAndDismiss() {
        #expect(RootHapticPolicy.notificationDropdownFeedback == .routine)
        #expect(RootHapticPolicy.notificationNavigationFeedback == .routine)
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
        #expect(RootNavigationPolicy.moreDestination(for: .guide) == .guide)
        #expect(RootNavigationPolicy.moreDestination(for: .settings) == .settings)
        // Notifications are a screen like every other menu entry, so they are pushed too.
        #expect(RootNavigationPolicy.moreDestination(for: .notifications) == .notifications)
        // Logout is a confirmation, so it owns no pushed screen.
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
}
