import Testing
@testable import Dutypark

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
}
