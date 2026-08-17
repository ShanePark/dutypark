import Foundation
import Testing
@testable import Dutypark

struct RootChromeLocalizationTests {
    private let korean = Locale(identifier: "ko")

    @Test
    func moreMenuAndNotificationChromeUseTheRequestedLocale() {
        #expect(RootChromeLocalization.home("home.friends", locale: korean) == "친구관리")
        #expect(RootChromeLocalization.localizable("root.menu.guide", locale: korean) == "이용 안내")
        #expect(RootChromeLocalization.localizable("root.menu.settings", locale: korean) == "설정")
        #expect(RootChromeLocalization.notifications("notifications.title", locale: korean) == "알림")
        #expect(RootChromeLocalization.notifications("notifications.common.close", locale: korean) == "알림 닫기")
        #expect(RootChromeLocalization.notifications("notifications.common.loading", locale: korean) == "불러오는 중...")
        #expect(RootChromeLocalization.notifications("notifications.common.empty", locale: korean) == "알림이 없습니다")
        #expect(RootChromeLocalization.notifications("notifications.dropdown.viewAll", locale: korean) == "전체보기")
    }

    @Test
    func moreGuideLabelKeepsTheSameEnglishMeaningAsTheWebMenu() {
        #expect(
            RootChromeLocalization.localizable("root.menu.guide", locale: Locale(identifier: "en"))
                == "Guide"
        )
    }

    @Test
    func moreMenuKeepsGlobalActionsAndExcludesDockDestinations() {
        #expect(MoreMenuItem.visibleItems(isAdmin: false) == [
            .friends,
            .notifications,
            .guide,
            .settings,
            .logout,
        ])
        #expect(MoreMenuItem.visibleItems(isAdmin: true) == [
            .friends,
            .notifications,
            .admin,
            .guide,
            .settings,
            .logout,
        ])
        #expect(MoreMenuItem.visibleGroups(isAdmin: true) == [
            [.friends, .notifications],
            [.admin, .guide, .settings],
            [.logout],
        ])

        let exposedIdentifiers = Set(MoreMenuItem.allCases.map(\.rawValue))
        #expect(exposedIdentifiers.isDisjoint(with: AppTab.allCases.map(\.rawValue)))
        #expect(exposedIdentifiers.isDisjoint(with: [
            "home",
            "calendar",
            "todo",
            "team",
            "more",
        ]))
    }

    @Test
    func moreMenuRowsExposeStableIdentifiers() {
        #expect(MoreMenuItem.logout.isDestructive)
        #expect(!MoreMenuItem.settings.isDestructive)
        #expect(
            MoreMenuItem.allCases.map(\.accessibilityIdentifier) == [
                "more.friends",
                "more.notifications",
                "more.admin",
                "more.guide",
                "more.settings",
                "more.logout",
            ]
        )
    }

    @Test
    func impersonationBannerUsesTheRequestedLocale() {
        #expect(
            RootChromeLocalization.localizable("auth.impersonation.active", locale: korean)
                == "관리 계정으로 사용 중"
        )
        #expect(
            RootChromeLocalization.impersonationRemaining("4:32", locale: korean)
                == "남은 시간: 4:32"
        )
        #expect(
            RootChromeLocalization.settings("settings.managed.restore", locale: korean)
                == "내 계정으로 돌아가기"
        )
    }
}
