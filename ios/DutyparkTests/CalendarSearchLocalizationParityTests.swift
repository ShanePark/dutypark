import Foundation
import Testing
@testable import Dutypark

@Suite(.serialized)
@MainActor
struct CalendarSearchLocalizationParityTests {
    @Test
    func searchPlaceholderMatchesResponsiveWebInKoreanAndEnglish() {
        let defaults = UserDefaults.standard
        let previousLanguage = defaults.string(forKey: SettingsPreference.languageKey)
        defer {
            if let previousLanguage {
                defaults.set(previousLanguage, forKey: SettingsPreference.languageKey)
            } else {
                defaults.removeObject(forKey: SettingsPreference.languageKey)
            }
        }

        defaults.set("ko", forKey: SettingsPreference.languageKey)
        #expect(
            CalendarLocalization.text("calendar.search.placeholder")
                == "제목이나 상세로 검색"
        )

        defaults.set("en", forKey: SettingsPreference.languageKey)
        #expect(
            CalendarLocalization.text("calendar.search.placeholder")
                == "Search by title or details"
        )
    }
}
