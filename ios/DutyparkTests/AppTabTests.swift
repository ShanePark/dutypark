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
}
