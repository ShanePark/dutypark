import Foundation
import Testing
@testable import Dutypark

struct TodoLocalizationParityTests {
    @Test
    func inProgressShortTitleMatchesResponsiveWebExactly() {
        #expect(TodoStatus.inProgress.shortTitleKey == "todo.statusShort.inProgress")
        #expect(todoLocalized(TodoStatus.inProgress.shortTitleKey, locale: Locale(identifier: "ko")) == "진행중")
        #expect(todoLocalized(TodoStatus.inProgress.shortTitleKey, locale: Locale(identifier: "en")) == "Doing")
    }
}
