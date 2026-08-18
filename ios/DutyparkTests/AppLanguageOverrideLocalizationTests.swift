import Foundation
import Testing
@testable import Dutypark

/// The in-app language override lives in `UserDefaults` and is not the process language,
/// so every Foundation-side lookup must resolve against the matching `.lproj` bundle.
/// `String(localized:)` and `LocalizedStringResource` default to `Bundle.main`, which
/// follows the device language instead and silently returns English.
@Suite(.serialized)
@MainActor
struct AppLanguageOverrideLocalizationTests {
    @Test
    func calendarTableFollowsTheAppLanguageOverride() {
        withKoreanOverride {
            #expect(CalendarLocalization.text("calendar.off") == "휴무")
            #expect(CalendarLocalization.text("calendar.pattern.holidayOff") == "공휴일 휴무")
            #expect(CalendarLocalization.text("calendar.pattern.effectiveFrom") == "적용 시작")
            #expect(CalendarLocalization.text("calendar.pattern.delete") == "패턴 해제")
            #expect(
                CalendarLocalization.text("dutyBatch.yearMonthNotMatch", table: "Errors")
                    != "dutyBatch.yearMonthNotMatch"
            )
        }
    }

    @Test
    func tabTitlesFollowTheAppLanguageOverride() {
        withKoreanOverride {
            #expect(AppTab.home.localizedTitle == "홈")
            #expect(AppTab.calendar.localizedTitle == "달력")
            #expect(AppTab.todo.localizedTitle == "할일")
            #expect(AppTab.team.localizedTitle == "팀")
            #expect(AppTab.more.localizedTitle == "더보기")
        }
    }

    @Test
    func moreMenuTitlesFollowTheAppLanguageOverride() {
        withKoreanOverride {
            #expect(MoreMenuItem.visibleItems(isAdmin: true).map(\.title) == [
                "친구관리",
                "알림",
                "관리자",
                "이용 안내",
                "설정",
                "로그아웃",
            ])
        }
    }

    @Test
    func notificationAndOAuthTablesFollowTheAppLanguageOverride() {
        withKoreanOverride {
            #expect(notificationLocalized("notifications.title") == "알림")
            #expect(notificationLocalized("notifications.common.cancel") == "취소")
            #expect(oauthString("auth.oauth.signup.title") != "auth.oauth.signup.title")
            #expect(oauthString("auth.oauth.signup.title").containsHangul)
        }
    }

    @Test
    func serverErrorMessagesFollowTheAppLanguageOverride() {
        withKoreanOverride {
            #expect(
                APIErrorLocalization.message(code: "friend.request.self")
                    == "자기 자신에게는 친구 요청을 보낼 수 없습니다."
            )
            #expect(APIError.server(status: 400, code: "friend.request.self").localizedDescription.containsHangul)
        }
    }

    @Test
    func loginAttemptWarningsFollowTheAppLanguageOverride() {
        withKoreanOverride {
            #expect(LoginAttemptMessage.text(remainingAttempts: 0) == "로그인이 차단되었습니다. 잠시 후 다시 시도해주세요.")
            #expect(LoginAttemptMessage.text(remainingAttempts: 1) == "주의: 마지막 시도입니다!")
            #expect(LoginAttemptMessage.text(remainingAttempts: 3) == "남은 시도 횟수: 3회")
            #expect(LoginAttemptMessage.text(remainingAttempts: 4) == nil)
            #expect(LoginAttemptMessage.text(remainingAttempts: nil) == nil)
        }
    }

    private func withKoreanOverride(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defaults.set("ko", forKey: SettingsPreference.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsPreference.languageKey) }
            else { defaults.removeObject(forKey: SettingsPreference.languageKey) }
        }
        body()
    }
}

private extension String {
    var containsHangul: Bool {
        unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) }
    }
}
