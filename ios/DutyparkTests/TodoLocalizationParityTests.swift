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

    @Test
    func completedCleanupCopyResolvesInEverySupportedLocale() {
        for localeIdentifier in ["ko", "en"] {
            let locale = Locale(identifier: localeIdentifier)
            for key in [
                "todo.action.clearCompleted",
                "todo.confirm.clearCompletedTitle",
                "todo.confirm.clearCompletedMessage",
                "todo.error.clearCompleted",
                "todo.success.clearCompletedTitle",
                "todo.success.clearCompletedMessage"
            ] {
                #expect(todoLocalized(key, locale: locale) != key)
            }
        }
    }
}
