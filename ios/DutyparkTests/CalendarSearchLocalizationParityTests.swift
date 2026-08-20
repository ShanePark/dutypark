import Foundation
import Testing
@testable import Dutypark

@Suite(.serialized)
@MainActor
struct CalendarSearchLocalizationParityTests {
    @Test
    func searchPlaceholderMatchesResponsiveWebInKoreanAndEnglish() {
        #expect(
            CalendarLocalization.text("calendar.search.placeholder", locale: .korean)
                == "제목이나 상세로 검색"
        )
        #expect(
            CalendarLocalization.text("calendar.search.placeholder", locale: .english)
                == "Search by title or details"
        )
    }
}
