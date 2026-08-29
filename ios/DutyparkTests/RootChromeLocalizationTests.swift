import Foundation
import Testing
@testable import Dutypark

struct RootChromeLocalizationTests {
    private let korean = Locale(identifier: "ko")

    @Test
    func moreMenuAndNotificationChromeUseTheRequestedLocale() {
        // The dashboard panel names the people; the menu entry names the screen it opens.
        #expect(RootChromeLocalization.home("home.friends", locale: korean) == "친구")
        #expect(RootChromeLocalization.social("social.title", locale: korean) == "친구관리")
        #expect(RootChromeLocalization.localizable("root.menu.guide", locale: korean) == "이용 안내")
        #expect(RootChromeLocalization.localizable("root.menu.support", locale: korean) == "문의하기")
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
        #expect(MoreMenuItem.visibleItems() == [
            .friends,
            .notifications,
            .guide,
            .support,
            .settings,
            .logout,
        ])
        #expect(MoreMenuItem.visibleGroups() == [
            [.friends, .notifications],
            [.guide, .support, .settings],
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
                "more.guide",
                "more.support",
                "more.settings",
                "more.logout",
            ]
        )
    }

    @Test
    func myInfoEntryIsLocalizedWithoutBecomingAMenuRow() {
        #expect(RootChromeLocalization.localizable("root.menu.myInfo", locale: korean) == "내 정보")
        #expect(
            RootChromeLocalization.localizable("root.menu.myInfo", locale: Locale(identifier: "en"))
                == "My info"
        )
        // The profile card is the entry point, so the menu must not duplicate it.
        #expect(!MoreMenuItem.allCases.map(\.rawValue).contains("myInfo"))
    }

    @Test
    func profileCardPrefersTheTeamAndFallsBackToTheEmail() {
        #expect(summary(team: "1팀", email: "member@dutypark.dev").supportingText == "1팀")
        #expect(summary(team: nil, email: "member@dutypark.dev").supportingText == "member@dutypark.dev")
        #expect(summary(team: "  ", email: "member@dutypark.dev").supportingText == "member@dutypark.dev")
        #expect(summary(team: nil, email: nil).supportingText == nil)
    }

    @Test
    func profileCardFallsBackToTheScreenTitleWhenTheMemberHasNoName() {
        #expect(summary(name: "선우").displayName == "선우")
        #expect(summary(name: "   ").displayName == RootChromeLocalization.localizable("root.menu.myInfo"))
    }

    @Test
    func profileCardPreservesPhotoAvailabilityFromTheMemberPayload() {
        #expect(summary(hasProfilePhoto: true).hasProfilePhoto == true)
        #expect(summary(hasProfilePhoto: false).hasProfilePhoto == false)
        #expect(summary(hasProfilePhoto: nil).hasProfilePhoto == nil)
    }

    private func summary(
        name: String = "선우",
        team: String? = nil,
        email: String? = nil,
        hasProfilePhoto: Bool? = nil,
        profilePhotoVersion: Int64 = 0
    ) -> MoreProfileSummary {
        MoreProfileSummary(
            member: LoginMember(
                id: 7,
                email: email,
                name: name,
                teamId: team == nil ? nil : 3,
                team: team,
                isAdmin: false,
                isImpersonating: false,
                originalMemberId: nil
            ),
            hasProfilePhoto: hasProfilePhoto,
            profilePhotoVersion: profilePhotoVersion
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
