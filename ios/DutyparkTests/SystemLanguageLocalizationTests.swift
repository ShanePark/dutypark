import Foundation
import Testing
@testable import Dutypark

/// The app follows the system language, so Foundation-side lookups resolve against
/// `Bundle.main`. Copy is asserted per language through the explicit-locale seam, and the
/// default lookups are pinned to whichever language iOS resolved for the process.
struct SystemLanguageLocalizationTests {
    @Test
    func calendarTableIsTranslatedInEverySupportedLanguage() {
        #expect(CalendarLocalization.text("calendar.off", locale: .korean) == "휴무")
        #expect(CalendarLocalization.text("calendar.off", locale: .english) == "Off")
        #expect(CalendarLocalization.text("calendar.pattern.holidayOff", locale: .korean) == "공휴일 휴무")
        #expect(CalendarLocalization.text("calendar.pattern.holidayOff", locale: .english) == "Off on holidays")
        #expect(CalendarLocalization.text("calendar.pattern.effectiveFrom", locale: .korean) == "적용 시작")
        #expect(CalendarLocalization.text("calendar.pattern.effectiveFrom", locale: .english) == "Effective from")
        #expect(CalendarLocalization.text("calendar.pattern.delete", locale: .korean) == "패턴 해제")
        #expect(CalendarLocalization.text("calendar.pattern.delete", locale: .english) == "Disable pattern")

        // Tables outside Calendar stay reachable through the same helper.
        #expect(
            CalendarLocalization.text("dutyBatch.yearMonthNotMatch", table: "Errors", locale: .korean)
                != "dutyBatch.yearMonthNotMatch"
        )

        #expect(CalendarLocalization.text("calendar.off") == CalendarLocalization.text("calendar.off", locale: AppLocalization.locale))
    }

    @Test
    func moreMenuTitlesAreTranslatedInEverySupportedLanguage() {
        #expect(moreMenuTitles(locale: .korean) == [
            "친구관리",
            "알림",
            "이용 안내",
            "문의하기",
            "설정",
            "로그아웃",
        ])
        #expect(moreMenuTitles(locale: .english) == [
            "Manage friends",
            "Notifications",
            "Guide",
            "Support",
            "Settings",
            "Log out",
        ])

        // The menu renders those same entries in the language iOS resolved.
        #expect(MoreMenuItem.visibleItems().map(\.title) == moreMenuTitles(locale: AppLocalization.locale))
    }

    @Test
    func notificationAndOAuthTablesAreTranslatedInEverySupportedLanguage() {
        #expect(notificationLocalized("notifications.title", locale: .korean) == "알림")
        #expect(notificationLocalized("notifications.title", locale: .english) == "Notifications")
        #expect(notificationLocalized("notifications.common.cancel", locale: .korean) == "취소")
        #expect(notificationLocalized("notifications.common.cancel", locale: .english) == "Cancel")
        #expect(oauthString("auth.oauth.signup.title", locale: .korean) == "회원가입")
        #expect(oauthString("auth.oauth.signup.title", locale: .english) == "Create account")
    }

    @Test
    func serverErrorMessagesAreTranslatedInEverySupportedLanguage() {
        #expect(
            APIErrorLocalization.message(
                code: "friend.request.self",
                bundle: AppLocalization.bundle(for: .korean)
            ) == "자기 자신에게는 친구 요청을 보낼 수 없습니다."
        )
        #expect(
            APIErrorLocalization.message(
                code: "friend.request.self",
                bundle: AppLocalization.bundle(for: .english)
            ) == "You cannot send a friend request to yourself."
        )

        // `LocalizedError` conformances have no locale seam, so they follow the process language.
        #expect(
            APIError.server(status: 400, code: "friend.request.self").localizedDescription
                == APIErrorLocalization.message(code: "friend.request.self")
        )
    }

    @Test
    func loginAttemptWarningsAreTranslatedInEverySupportedLanguage() {
        #expect(LoginAttemptMessage.text(remainingAttempts: 0, locale: .korean) == "로그인이 차단되었습니다. 잠시 후 다시 시도해주세요.")
        #expect(
            LoginAttemptMessage.text(remainingAttempts: 0, locale: .english)
                == "Login has been temporarily blocked. Please try again later."
        )
        #expect(LoginAttemptMessage.text(remainingAttempts: 1, locale: .korean) == "주의: 마지막 시도입니다!")
        #expect(LoginAttemptMessage.text(remainingAttempts: 1, locale: .english) == "Warning: this is your last attempt.")
        #expect(LoginAttemptMessage.text(remainingAttempts: 3, locale: .korean) == "남은 시도 횟수: 3회")
        #expect(LoginAttemptMessage.text(remainingAttempts: 3, locale: .english) == "Remaining attempts: 3")
        #expect(LoginAttemptMessage.text(remainingAttempts: 4) == nil)
        #expect(LoginAttemptMessage.text(remainingAttempts: nil) == nil)
    }

    private func moreMenuTitles(locale: Locale?) -> [String] {
        [
            RootChromeLocalization.social("social.title", locale: locale),
            RootChromeLocalization.notifications("notifications.title", locale: locale),
            RootChromeLocalization.localizable("root.menu.guide", locale: locale),
            RootChromeLocalization.localizable("root.menu.support", locale: locale),
            RootChromeLocalization.localizable("root.menu.settings", locale: locale),
            SettingsLocalization.string("settings.logout", locale: locale),
        ]
    }
}
