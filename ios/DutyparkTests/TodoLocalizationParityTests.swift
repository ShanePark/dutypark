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
                "todo.success.clearCompletedTitle"
            ] {
                #expect(todoLocalized(key, locale: locale) != key)
            }
        }
    }

    @Test
    func completedCleanupCopyStaysConciseAndUsesOneSuccessLine() {
        #expect(
            todoLocalized("todo.confirm.clearCompletedMessage", locale: Locale(identifier: "ko"))
                == "내가 만든 항목은 삭제되고, 태그된 항목은 내 보드에서만 제거됩니다."
        )
        #expect(
            todoLocalized("todo.confirm.clearCompletedMessage", locale: Locale(identifier: "en"))
                == "Tasks you created will be deleted, and tagged tasks will be removed from your board only."
        )
        #expect(
            todoLocalized("todo.success.clearCompletedTitle", locale: Locale(identifier: "ko"))
                == "완료 항목을 정리했습니다."
        )
        #expect(
            todoLocalized("todo.success.clearCompletedTitle", locale: Locale(identifier: "en"))
                == "Completed items cleared."
        )
    }
}
