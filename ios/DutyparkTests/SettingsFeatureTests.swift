import Foundation
import Testing
import UIKit
@testable import Dutypark

@Suite(.serialized)
@MainActor
struct SettingsFeatureTests {
    @Test
    func supportsKoreanAndEnglishLanguageChoices() {
        #expect(AppLanguage.allCases.map(\.rawValue) == ["ko", "en"])
        #expect(AppLanguage.allCases.map(\.nativeName) == ["한국어", "English"])
    }

    @Test
    func unsupportedLocalesFallBackToEnglish() {
        #expect(AppLocalization.supportedLocale(languageCode: "ko-KR").identifier == "ko")
        #expect(AppLocalization.supportedLocale(languageCode: "en-US").identifier == "en")
        #expect(AppLocalization.supportedLocale(languageCode: "fr-FR").identifier == "en")
        #expect(AppLocalization.supportedLocale(
            languageCode: "",
            preferredLanguages: ["fr-FR"]
        ).identifier == "en")
    }

    @Test
    func supportsSystemLightAndDarkAppearanceChoices() {
        #expect(AppTheme.allCases.map(\.rawValue) == ["system", "light", "dark"])
        #expect(SettingsPreference.defaultTheme == AppTheme.system.rawValue)
        #expect(AppTheme.system.preferredColorScheme == nil)
        #expect(AppTheme.light.preferredColorScheme == .light)
        #expect(AppTheme.dark.preferredColorScheme == .dark)
    }

    @Test
    func resolvesSettingsCopyFromTheSettingsCatalog() {
        let key = "settings.profile.title"

        #expect(SettingsLocalization.string(key) != key)
    }

    @Test
    func settingsOverviewCopyMatchesResponsiveWeb() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsPreference.languageKey) }
            else { defaults.removeObject(forKey: SettingsPreference.languageKey) }
        }

        let expectedByLanguage: [String: [String: String]] = [
            "ko": [
                "settings.profile.title": "기본 정보",
                "settings.visibility.title": "시간표 공개 설정",
                "settings.visibility.description": "내 시간표를 볼 수 있는 사람을 설정합니다",
                "settings.appearance.title": "화면 테마 설정",
                "settings.push.title": "푸시 알림 설정",
                "settings.push.description": "새로운 알림이 있을 때 이 기기로 알려드려요.",
                "settings.aiConsent.title": "AI 시간 자동 인식",
                "settings.aiConsent.description": "선택 동의이며 언제든 철회할 수 있습니다. 동의하지 않아도 일정을 그대로 저장하거나 시간을 직접 입력할 수 있습니다.",
                "settings.aiConsent.dataFlow": "일정의 날짜와 내용 텍스트만 외부 AI 처리 서비스로 전송해 시작·종료 시간을 추출합니다. 회원 ID와 팀 ID는 전송하지 않습니다.",
                "settings.manager.title": "관리 권한 위임",
                "settings.manager.description": "가족만 관리자로 추가할 수 있어요",
                "settings.managed.title": "내가 관리 중인 계정",
                "settings.sessions.title": "접속 세션 관리",
                "settings.social.title": "소셜 계정 연동",
                "settings.account.title": "회원정보 관리",
            ],
            "en": [
                "settings.profile.title": "Profile",
                "settings.visibility.title": "Calendar Visibility",
                "settings.visibility.description": "Choose who can view your schedule.",
                "settings.appearance.title": "Theme",
                "settings.push.title": "Push Notifications",
                "settings.push.description": "Get notified on this device when something new happens.",
                "settings.aiConsent.title": "Automatic AI time recognition",
                "settings.aiConsent.description": "This is optional and can be withdrawn at any time. You can still save schedules unchanged or enter times manually without consenting.",
                "settings.aiConsent.dataFlow": "Only the schedule date and content text are sent to an external AI processing service to extract start and end times. Member and team IDs are not sent.",
                "settings.manager.title": "Delegated Management",
                "settings.manager.description": "Only family members can be added as managers.",
                "settings.managed.title": "Accounts I manage",
                "settings.sessions.title": "Sessions",
                "settings.social.title": "Social Sign-in",
                "settings.account.title": "Account Management",
            ],
        ]

        for (language, expectedCopy) in expectedByLanguage {
            defaults.set(language, forKey: SettingsPreference.languageKey)
            for (key, expected) in expectedCopy {
                #expect(SettingsLocalization.string(key) == expected)
            }
        }
    }

    @Test
    func webParitySettingsCopyExistsInEverySupportedLanguage() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsPreference.languageKey) }
            else { defaults.removeObject(forKey: SettingsPreference.languageKey) }
        }

        let keys = [
            "settings.profile.name",
            "settings.visibility.modalTitle",
            "settings.visibility.private.description",
            "settings.visibility.close",
            "settings.password.change",
            "settings.password.current",
            "settings.password.new",
            "settings.password.confirm",
            "settings.action.save",
            "settings.action.cancel",
            "settings.auxiliary.create",
            "settings.auxiliary.description",
            "settings.auxiliary.name",
            "settings.theme.system",
            "settings.theme.current.system",
            "settings.theme.current.dark",
            "settings.pattern.title",
            "settings.pattern.createDescription",
            "settings.pattern.unavailable.team",
            "settings.pattern.unavailable.dutyType",
            "settings.pattern.unavailable.default",
            "settings.pattern.saveConfirm",
            "settings.pattern.deleteConfirm",
            "settings.photo.deleteConfirm",
            "settings.manager.removeMessage",
            "settings.managed.switchMessage",
            "settings.accessibility.on",
            "settings.accessibility.off",
            "settings.sessions.empty",
            "settings.sessions.justNow",
            "settings.sessions.ipLabel",
            "settings.sessions.deviceLabel",
            "settings.sessions.browserLabel",
            "settings.sessions.revokeMessage",
            "settings.sessions.revokeOthersTitle",
            "settings.sessions.revokeOthersMessage",
            "settings.social.unlink",
            "settings.social.apple",
            "settings.social.unlinking",
            "settings.social.linked",
            "settings.social.unlinked",
            "settings.social.unlinkConfirmTitle",
            "settings.social.unlinkConfirmMessage",
            "settings.social.unlinkAppleConfirmMessage",
            "settings.social.unlinkAppleDescription",
            "settings.social.unlinkLastAuthenticationMethod",
            "settings.social.unlinkImpersonationForbidden",
            "settings.social.unlinkFailed",
            "settings.social.manage",
            "settings.social.manageHint",
            "settings.social.disconnected",
        ]
        for language in AppLanguage.allCases {
            defaults.set(language.rawValue, forKey: SettingsPreference.languageKey)
            for key in keys {
                #expect(SettingsLocalization.string(key) != key)
            }
        }
    }

    @Test
    func socialLinkSuccessNoticeClearsPreviousErrorState() {
        let model = SettingsViewModel()
        model.noticeIsError = true
        model.noticeKey = "settings.social.unlinkFailed"

        model.showNotice("settings.social.linked")

        #expect(model.noticeKey == "settings.social.linked")
        #expect(!model.noticeIsError)
    }

    @Test
    func modalDismissPolicyKeepsBackdropAndAccessibilityRulesIndependent() {
        let explicitOnly = DPModalDismissPolicy(
            closeOnBackdrop: false,
            canDismiss: true,
            isDismissing: false
        )

        #expect(!explicitOnly.allows(.backdrop))
        #expect(explicitOnly.allows(.accessibilityEscape))
        #expect(explicitOnly.allows(.content))

        let blockedWhileWorking = DPModalDismissPolicy(
            closeOnBackdrop: true,
            canDismiss: false,
            isDismissing: false
        )
        #expect(!blockedWhileWorking.allows(.backdrop))
        #expect(!blockedWhileWorking.allows(.accessibilityEscape))
        #expect(!blockedWhileWorking.allows(.content))

        let blockedAfterDismissStarts = DPModalDismissPolicy(
            closeOnBackdrop: true,
            canDismiss: true,
            isDismissing: true
        )
        #expect(!blockedAfterDismissStarts.allows(.backdrop))
        #expect(!blockedAfterDismissStarts.allows(.accessibilityEscape))
        #expect(!blockedAfterDismissStarts.allows(.content))
    }

    @Test
    func localizationHelpersFollowTheExplicitAppLanguage() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsPreference.languageKey) }
            else { defaults.removeObject(forKey: SettingsPreference.languageKey) }
        }

        defaults.set("ko", forKey: SettingsPreference.languageKey)

        #expect(SettingsLocalization.string("settings.guide") == "사용 가이드")
        #expect(GuestLocalization.text("guest.retry") == "다시 시도")
        #expect(SettingsLocalization.string("settings.guide.loadError.title") == "페이지를 불러올 수 없습니다")
    }

    @Test
    func decodesSessionWithoutKeepingServerTokenValue() throws {
        let data = Data(
            #"{"memberName":"Test","memberId":1,"validUntil":"2026-09-01T10:00:00","createdDate":"2026-08-01T10:00:00","lastUsed":null,"remoteAddr":"127.0.0.1","id":9,"token":"server-secret","userAgent":{"os":"iOS","browser":"Dutypark","device":"iPhone"},"isCurrentLogin":true}"#.utf8
        )

        let session = try JSONDecoder().decode(SettingsRefreshToken.self, from: data)

        #expect(session.id == 9)
        #expect(session.userAgent?.device == "iPhone")
        #expect(session.isCurrentLogin == true)
    }

    @Test
    func formatsSessionDatesWithoutExposingRawISOValues() throws {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsPreference.languageKey) }
            else { defaults.removeObject(forKey: SettingsPreference.languageKey) }
        }
        defaults.set("ko", forKey: SettingsPreference.languageKey)

        let now = try #require(SettingsSessionFormatter.date(from: "2026-08-12T12:00:00Z"))
        #expect(SettingsSessionFormatter.relativeTime("2026-08-12T11:59:30Z", now: now) == "방금 전")
        #expect(SettingsSessionFormatter.relativeTime("2026-08-12T11:55:00Z", now: now).contains("5"))
        #expect(SettingsSessionFormatter.relativeTime("2026-08-12T10:00:00Z", now: now).contains("2"))
        #expect(SettingsSessionFormatter.relativeTime("2026-08-10T12:00:00Z", now: now).contains("2"))

        let older = SettingsSessionFormatter.relativeTime("2026-08-01T12:00:00Z", now: now)
        #expect(!older.contains("T12:00:00"))
        #expect(older.contains("2026"))
        #expect(!SettingsSessionFormatter.dateText("2026-08-01T10:00:00.817864").contains("T"))
        #expect(SettingsSessionFormatter.relativeTime(nil, now: now) == "-")
        #expect(SettingsSessionFormatter.relativeTime("invalid", now: now) == "-")
        #expect(SettingsSessionFormatter.dateText(nil) == "-")
        #expect(SettingsSessionFormatter.dateText("invalid") == "-")
    }

    @Test
    func sortsCurrentSessionFirstThenMostRecentlyUsedAndNeverRevokesCurrent() {
        let old = sessionToken(id: 1, lastUsed: "2026-08-01T10:00:00Z")
        let recent = sessionToken(id: 2, lastUsed: "2026-08-12T10:00:00Z")
        let current = sessionToken(id: 3, lastUsed: "2026-07-01T10:00:00Z", isCurrent: true)

        #expect(SettingsSessionFormatter.sorted([old, current, recent]).map(\.id) == [3, 2, 1])
        #expect(!SettingsSessionPolicy.canRevoke(current))
        #expect(SettingsSessionPolicy.canRevoke(recent))
    }

    @Test
    func sessionConfirmationsExplainTheAffectedScope() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsPreference.languageKey) }
            else { defaults.removeObject(forKey: SettingsPreference.languageKey) }
        }
        defaults.set("ko", forKey: SettingsPreference.languageKey)

        let individual = SettingsSessionConfirmation.session(sessionToken(id: 9))
        #expect(individual.titleKey == "settings.sessions.revokeTitle")
        #expect(individual.message.contains("Apple iOS Device"))
        #expect(individual.message.contains("Dutypark"))
        #expect(individual.message.contains("127.0.0.1"))
        #expect(!individual.message.contains("{device}"))

        let allOthers = SettingsSessionConfirmation.otherSessions(count: 3)
        #expect(allOthers.titleKey == "settings.sessions.revokeOthersTitle")
        #expect(allOthers.message.contains("현재 접속을 제외"))
        #expect(allOthers.message.contains("3"))
    }

    @Test
    func consequentialSettingsActionsUseCentralConfirmationContent() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsPreference.languageKey) }
            else { defaults.removeObject(forKey: SettingsPreference.languageKey) }
        }
        defaults.set(AppLanguage.korean.rawValue, forKey: SettingsPreference.languageKey)

        let photo = SettingsConfirmation.deleteProfilePhoto
        #expect(photo.titleKey == "settings.photo.delete")
        #expect(photo.message.contains("프로필 사진"))
        #expect(photo.confirmTitleKey == "settings.photo.delete")
        #expect(photo.isDestructive)

        let manager = SettingsConfirmation.removeManager(id: 7, name: "Alex")
        #expect(manager.message.contains("Alex"))
        #expect(!manager.message.contains("{name}"))
        #expect(manager.isDestructive)

        let managedAccount = SettingsConfirmation.switchManagedAccount(id: 9, name: "Mina")
        #expect(managedAccount.message.contains("Mina"))
        #expect(managedAccount.confirmTitleKey == "settings.managed.switch")
        #expect(!managedAccount.isDestructive)

        let sessions = SettingsConfirmation.session(.otherSessions(count: 2))
        #expect(sessions.message.contains("2"))
        #expect(sessions.isDestructive)
        #expect(SettingsConfirmation.logout.isDestructive)
    }

    @Test
    func destructiveConfirmationCancelsWithoutAPIAndBlocksDuplicateConfirmation() async throws {
        let recorder = SettingsRequestRecorder()
        SettingsURLProtocolStub.handler = { request in
            recorder.record(request)
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data()
            )
        }
        defer { SettingsURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SettingsURLProtocolStub.self]
        let service = SettingsService(client: APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        ))
        var gate = SettingsDestructiveActionGate()

        // Cancelling the confirmation panel never starts the destructive action.
        #expect(!gate.isWorking)
        #expect(recorder.requests.isEmpty)

        let firstConfirmationStarted = gate.start()
        let duplicateConfirmationStarted = gate.start()
        #expect(firstConfirmationStarted)
        #expect(!duplicateConfirmationStarted)
        try await service.revokeSession(id: 41)
        gate.finish()

        #expect(!gate.isWorking)
        #expect(recorder.requests.count == 1)
        #expect(recorder.requests.first?.url?.path == "/api/auth/refresh-tokens/41")
    }

    @Test
    func sessionServiceUsesDedicatedDeleteEndpointsAndPreservesCurrentCookie() async throws {
        let recorder = SettingsRequestRecorder()
        SettingsURLProtocolStub.handler = { request in
            recorder.record(request)
            let body = request.url?.path == "/api/auth/refresh-tokens/others"
                ? #"{"deletedCount":2}"#
                : ""
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: request.url?.path == "/api/auth/refresh-tokens/others" ? 200 : 204,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data(body.utf8)
            )
        }
        defer { SettingsURLProtocolStub.handler = nil }

        let cookieStorage = HTTPCookieStorage.sharedCookieStorage(
            forGroupContainerIdentifier: "SettingsFeatureTests-\(UUID().uuidString)"
        )
        let cookie = try #require(HTTPCookie(properties: [
            .domain: "dutypark.test",
            .path: "/",
            .name: "refresh_token",
            .value: "current-session",
            .secure: "TRUE",
        ]))
        cookieStorage.setCookie(cookie)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SettingsURLProtocolStub.self]
        configuration.httpCookieStorage = cookieStorage
        configuration.httpShouldSetCookies = true
        let client = APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        )
        let service = SettingsService(client: client)

        try await service.revokeSession(id: 41)
        let deletedCount = try await service.revokeOtherSessions()

        #expect(deletedCount == 2)
        #expect(recorder.requests.map(\.httpMethod) == ["DELETE", "DELETE"])
        #expect(recorder.requests.compactMap { $0.url?.path } == [
            "/api/auth/refresh-tokens/41",
            "/api/auth/refresh-tokens/others",
        ])
        #expect(cookieStorage.cookies?.contains { cookie in
            cookie.name == "refresh_token" && cookie.value == "current-session"
        } == true)
    }

    @Test
    func socialAccountUnlinkUsesProviderDeleteEndpointAndAcceptsNoContent() async throws {
        let recorder = SettingsRequestRecorder()
        SettingsURLProtocolStub.handler = { request in
            recorder.record(request)
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data()
            )
        }
        defer { SettingsURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SettingsURLProtocolStub.self]
        let service = SettingsService(client: APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        ))

        try await service.unlinkSocialAccount(.kakao)
        try await service.unlinkSocialAccount(.naver)
        try await service.unlinkSocialAccount(.apple)

        #expect(recorder.requests.map(\.httpMethod) == ["DELETE", "DELETE", "DELETE"])
        #expect(recorder.requests.compactMap { $0.url?.path } == [
            "/api/members/me/social-accounts/KAKAO",
            "/api/members/me/social-accounts/NAVER",
            "/api/members/me/social-accounts/APPLE",
        ])
    }

    @Test
    func socialAccountUnlinkMapsSpecificErrorsAndExplainsLocalOnlyDisconnect() {
        #expect(!SettingsSocialUnlinkPolicy.canUnlink(connectedProviderCount: 0))
        #expect(!SettingsSocialUnlinkPolicy.canUnlink(connectedProviderCount: 1))
        #expect(SettingsSocialUnlinkPolicy.canUnlink(connectedProviderCount: 2))
        #expect(SettingsSocialUnlinkPolicy.noticeKey(for: APIError.server(
            status: 409,
            code: "member.social.unlink.lastAuthenticationMethod"
        )) == "settings.social.unlinkLastAuthenticationMethod")
        #expect(SettingsSocialUnlinkPolicy.noticeKey(for: APIError.server(
            status: 403,
            code: "auth.impersonation.forbidden"
        )) == "settings.social.unlinkImpersonationForbidden")
        #expect(SettingsSocialUnlinkPolicy.noticeKey(for: APIError.server(
            status: 500,
            code: "errors.generic"
        )) == "settings.social.unlinkFailed")

        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsPreference.languageKey) }
            else { defaults.removeObject(forKey: SettingsPreference.languageKey) }
        }

        defaults.set(AppLanguage.korean.rawValue, forKey: SettingsPreference.languageKey)
        let koreanMessage = SettingsSocialUnlinkPolicy.confirmationMessage(for: .kakao)
        #expect(koreanMessage.contains("Dutypark 내부 연결만 해제"))
        #expect(koreanMessage.contains("Kakao 계정"))
        #expect(koreanMessage.contains("권한은 삭제되지 않습니다"))
        let koreanLastProviderReason = SettingsLocalization.string(
            "settings.social.unlinkLastAuthenticationMethod"
        )
        #expect(koreanLastProviderReason.contains("다른 소셜 계정을 먼저 연결"))
        #expect(!koreanLastProviderReason.contains("비밀번호"))

        for language in AppLanguage.allCases {
            defaults.set(language.rawValue, forKey: SettingsPreference.languageKey)
            let message = SettingsSocialUnlinkPolicy.confirmationMessage(for: .kakao)
            #expect(message.contains("Kakao"))
            #expect(message != "settings.social.unlinkConfirmMessage")
            let lastProviderReason = SettingsLocalization.string(
                "settings.social.unlinkLastAuthenticationMethod"
            )
            #expect(!lastProviderReason.contains("{count}"))
            #expect(lastProviderReason != "settings.social.unlinkLastAuthenticationMethod")
        }

        defaults.set(AppLanguage.english.rawValue, forKey: SettingsPreference.languageKey)
        let appleMessage = SettingsSocialUnlinkPolicy.confirmationMessage(for: .apple)
        #expect(appleMessage.contains("Apple"))
    }

    @Test
    func appleUnlinkCopyExplainsProviderRevocationWhileOtherProvidersStayLocalOnly() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsPreference.languageKey) }
            else { defaults.removeObject(forKey: SettingsPreference.languageKey) }
        }

        defaults.set(AppLanguage.korean.rawValue, forKey: SettingsPreference.languageKey)
        let kakaoDescription = SettingsSocialUnlinkPolicy.managementDescription(for: .kakao)
        let naverDescription = SettingsSocialUnlinkPolicy.managementDescription(for: .naver)
        let appleDescription = SettingsSocialUnlinkPolicy.managementDescription(for: .apple)
        let appleConfirmation = SettingsSocialUnlinkPolicy.confirmationMessage(for: .apple)

        #expect(kakaoDescription.contains("권한은 삭제되지 않습니다"))
        #expect(naverDescription.contains("Naver 계정"))
        #expect(naverDescription.contains("권한은 삭제되지 않습니다"))
        #expect(appleDescription.contains("먼저 Apple 인증 권한을 철회한 뒤"))
        #expect(appleDescription.contains("철회에 실패하면"))
        #expect(appleConfirmation.contains("Apple 인증 권한을 철회하고"))
        #expect(appleConfirmation.contains("이후 이 Apple 계정으로 Dutypark에 로그인할 수 없습니다"))
        #expect(!appleDescription.contains("권한은 삭제되지 않습니다"))
        #expect(!appleConfirmation.contains("권한은 삭제되지 않습니다"))

        defaults.set(AppLanguage.english.rawValue, forKey: SettingsPreference.languageKey)
        #expect(
            SettingsSocialUnlinkPolicy.managementDescription(for: .apple)
                .contains("first revokes its Apple authorization")
        )
        #expect(
            SettingsSocialUnlinkPolicy.confirmationMessage(for: .apple)
                .contains("You will no longer be able to sign in")
        )
    }

    @Test
    func socialManagementPresentationAndStateKeepActionsInsideTheSelectedProviderPanel() {
        let presentation = SettingsSocialManagementPresentation(provider: .kakao)
        #expect(presentation.id == OAuthProvider.kakao.rawValue)

        let lastConnectedProvider = SettingsSocialManagementState(
            provider: .kakao,
            isConnected: true,
            connectedProviderCount: 1,
            linkingProvider: nil,
            unlinkingProvider: nil
        )
        #expect(lastConnectedProvider.statusKey == "settings.social.connected")
        #expect(lastConnectedProvider.showsLastProviderReason)
        #expect(!lastConnectedProvider.canRequestUnlink)

        let removableProvider = SettingsSocialManagementState(
            provider: .naver,
            isConnected: true,
            connectedProviderCount: 2,
            linkingProvider: nil,
            unlinkingProvider: nil
        )
        #expect(removableProvider.canRequestUnlink)

        let disconnectedProvider = SettingsSocialManagementState(
            provider: .naver,
            isConnected: false,
            connectedProviderCount: 1,
            linkingProvider: nil,
            unlinkingProvider: nil
        )
        #expect(disconnectedProvider.statusKey == "settings.social.disconnected")
        #expect(disconnectedProvider.canConnect)

        let busyProvider = SettingsSocialManagementState(
            provider: .naver,
            isConnected: false,
            connectedProviderCount: 1,
            linkingProvider: .kakao,
            unlinkingProvider: nil
        )
        #expect(busyProvider.isWorking)
        #expect(!busyProvider.canConnect)

        let appleProvider = SettingsSocialManagementState(
            provider: .apple,
            isConnected: true,
            connectedProviderCount: 3,
            linkingProvider: nil,
            unlinkingProvider: nil
        )
        #expect(appleProvider.canRequestUnlink)
        #expect(SettingsSocialManagementPolicy.providerName(.apple) == "Apple")
    }

    @Test
    func decodesDutyPatternUsedByTheSettingsCard() throws {
        let data = Data(
            ##"{"configurable":true,"reason":null,"dutyTypes":[{"id":4,"name":"Day","color":"#3B82F6"}],"pattern":{"days":[{"weekday":"MONDAY","dutyType":{"id":4,"name":"Day","color":"#3B82F6"}}],"holidayOff":true,"effectiveFrom":"2026-08-01"}}"##.utf8
        )

        let pattern = try JSONDecoder().decode(DutyPatternDTO.self, from: data)

        #expect(pattern.configurable)
        #expect(pattern.pattern?.days.first?.weekday == .monday)
        #expect(pattern.pattern?.holidayOff == true)
    }

    @Test
    func dutyPatternEditorShowsOnlySelectedWeekdaysAndUsesTheFirstTypeForNewSelections() {
        let day = DutyPatternDutyTypeDTO(id: 4, name: "Day", color: "#3B82F6")
        var state = DutyPatternSelectionState(pattern: nil, dutyTypes: [day])

        #expect(state.selectedWeekdays == [.monday, .tuesday, .wednesday, .thursday, .friday])
        #expect(state.dutyTypeID(for: .monday) == day.id)
        #expect(!state.isSelected(.saturday))

        state.toggle(.monday, defaultDutyTypeID: day.id)
        state.toggle(.saturday, defaultDutyTypeID: day.id)

        #expect(state.selectedWeekdays == [.tuesday, .wednesday, .thursday, .friday, .saturday])
        #expect(state.dutyTypeID(for: .monday) == nil)
        #expect(state.dutyTypeID(for: .saturday) == day.id)
    }

    @Test
    func dutyPatternEditorPreservesAnExistingHiddenDutyTypeForItsWeekday() {
        let hidden = DutyPatternDutyTypeDTO(id: 8, name: "Legacy night", color: "#312E81")
        let visible = DutyPatternDutyTypeDTO(id: 4, name: "Day", color: "#3B82F6")
        let pattern = DutyPatternDetailsDTO(
            days: [.init(weekday: .sunday, dutyType: hidden)],
            holidayOff: true,
            effectiveFrom: DateOnly(rawValue: "2026-08-01")
        )
        let state = DutyPatternSelectionState(pattern: pattern, dutyTypes: [visible])

        #expect(state.selectedWeekdays == [.sunday])
        #expect(state.dutyType(for: .sunday, visibleDutyTypes: [visible], pattern: pattern) == hidden)
        #expect(state.hasHiddenSelection(visibleDutyTypes: [visible]))
        #expect(state.isHiddenSelection(.sunday, visibleDutyTypes: [visible]))
    }

    @Test
    func selectingAVisibleDutyTypeClearsTheHiddenDutyPatternWarning() {
        let hidden = DutyPatternDutyTypeDTO(id: 8, name: "Legacy night", color: "#312E81")
        let visible = DutyPatternDutyTypeDTO(id: 4, name: "Day", color: "#3B82F6")
        let pattern = DutyPatternDetailsDTO(
            days: [.init(weekday: .sunday, dutyType: hidden)],
            holidayOff: true,
            effectiveFrom: DateOnly(rawValue: "2026-08-01")
        )
        var state = DutyPatternSelectionState(pattern: pattern, dutyTypes: [visible])

        state.select(visible.id, for: .sunday)

        #expect(!state.hasHiddenSelection(visibleDutyTypes: [visible]))
        #expect(!state.isHiddenSelection(.sunday, visibleDutyTypes: [visible]))
    }

    @Test
    func dutyPatternConfirmationsKeepSaveAndDeleteRolesDistinct() {
        #expect(DutyPatternConfirmation.save.titleKey == "settings.pattern.saveConfirmTitle")
        #expect(DutyPatternConfirmation.save.messageKey == "settings.pattern.saveConfirm")
        #expect(!DutyPatternConfirmation.save.isDestructive)
        #expect(DutyPatternConfirmation.delete.titleKey == "settings.pattern.deleteConfirmTitle")
        #expect(DutyPatternConfirmation.delete.messageKey == "settings.pattern.deleteConfirm")
        #expect(DutyPatternConfirmation.delete.isDestructive)
    }

    @Test
    func dutyPatternUnavailableReasonsUseLocalizedCopyInsteadOfServerCodes() {
        #expect(DutyPatternUnavailableCopy.key(reason: "TEAM_REQUIRED") == "settings.pattern.unavailable.team")
        #expect(DutyPatternUnavailableCopy.key(reason: "DUTY_TYPE_REQUIRED") == "settings.pattern.unavailable.dutyType")
        #expect(DutyPatternUnavailableCopy.key(reason: "UNKNOWN_REASON") == "settings.pattern.unavailable.default")
        #expect(DutyPatternUnavailableCopy.key(reason: nil) == "settings.pattern.unavailable.default")

        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsPreference.languageKey) }
            else { defaults.removeObject(forKey: SettingsPreference.languageKey) }
        }

        defaults.set(AppLanguage.korean.rawValue, forKey: SettingsPreference.languageKey)
        #expect(SettingsLocalization.string(DutyPatternUnavailableCopy.key(reason: "TEAM_REQUIRED")).contains("팀에 소속"))
        #expect(SettingsLocalization.string(DutyPatternUnavailableCopy.key(reason: "DUTY_TYPE_REQUIRED")).contains("근무 유형"))
        #expect(SettingsLocalization.string(DutyPatternUnavailableCopy.key(reason: "UNKNOWN")).contains("설정"))
    }

    @Test
    func decodesAccountDeletionPreviewAndTeamImpact() throws {
        let data = Data(#"{"hasPassword":true,"socialProviders":["KAKAO","APPLE"],"teamImpact":{"teamId":7,"teamName":"Dutypark","isAdmin":true,"activeMemberCount":2,"willDeleteTeam":false,"transferCandidates":[{"memberId":9,"name":"Alex"}]},"auxiliaryImpacts":[{"memberId":12,"name":"Child","willDelete":true}]}"#.utf8)

        let preview = try JSONDecoder().decode(AccountDeletionPreview.self, from: data)

        #expect(preview.hasPassword)
        #expect(preview.socialProviders == [.kakao, .apple])
        #expect(preview.teamImpact?.transferCandidates.first?.memberId == 9)
        #expect(preview.auxiliaryImpacts.first?.willDelete == true)
    }

    @Test
    func accountDeletionFlowRequiresTransferExactNameAndUnexpiredProof() throws {
        let preview = AccountDeletionPreview(
            hasPassword: true,
            socialProviders: [],
            teamImpact: AccountDeletionTeamImpact(
                teamId: 7,
                teamName: "Dutypark",
                isAdmin: true,
                activeMemberCount: 2,
                willDeleteTeam: false,
                transferCandidates: [.init(memberId: 9, name: "Alex")]
            ),
            auxiliaryImpacts: []
        )
        var flow = AccountDeletionFlowState()
        #expect(!flow.canLeaveTeamStep(preview: preview))
        flow.selectedTransferMemberID = 9
        #expect(flow.canLeaveTeamStep(preview: preview))
        flow.typedName = "Shane "
        #expect(!flow.nameMatches("Shane"))
        flow.typedName = "Shane"
        #expect(flow.nameMatches("Shane"))

        let now = Date(timeIntervalSince1970: 100)
        flow.storeProof("proof", expiresIn: 30, now: now)
        #expect(flow.validProof(at: now.addingTimeInterval(29)) == "proof")
        #expect(flow.validProof(at: now.addingTimeInterval(30)) == nil)
        #expect(flow.reauthProof == nil)
    }

    @Test
    func accountDeletionHasASeparateFinalDestructiveConfirmationStep() {
        #expect(AccountDeletionStep.allCases == [
            .scope,
            .team,
            .reauthentication,
            .nameConfirmation,
            .finalConfirmation,
        ])
        #expect(AccountDeletionStep.nameConfirmation.rawValue + 1 == AccountDeletionStep.finalConfirmation.rawValue)
    }

    @Test
    func accountDeletionServiceSendsPasswordOnlyForProofAndFinalRequestOnlyUsesProof() async throws {
        let recorder = SettingsRequestRecorder()
        SettingsURLProtocolStub.handler = { request in
            recorder.record(request)
            let body: String
            switch request.url?.path {
            case "/api/auth/reauth/password":
                body = #"{"reauthProof":"short-lived","expiresIn":300}"#
            case "/api/members/me/deletion":
                body = #"{"jobId":44,"status":"ACCEPTED"}"#
            default:
                body = #"{"code":"not_found"}"#
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(body.utf8)
            )
        }
        defer { SettingsURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SettingsURLProtocolStub.self]
        let service = SettingsService(client: APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        ))

        let proof = try await service.reauthenticateForAccountDeletion(password: "secret")
        let accepted = try await service.requestAccountDeletion(
            reauthProof: proof.reauthProof,
            transferAdminToMemberId: 9
        )

        #expect(accepted.jobId == 44)
        let requests = recorder.requests
        #expect(requests.map(\.url?.path) == [
            "/api/auth/reauth/password",
            "/api/members/me/deletion",
        ])
        let bodies = recorder.requestBodies
        let reauthBody = try #require(bodies[0])
        let reauth = try #require(Self.jsonBody(reauthBody))
        #expect(reauth["purpose"] as? String == "DELETE_ACCOUNT")
        #expect(reauth["password"] as? String == "secret")
        let deletionBody = try #require(bodies[1])
        let deletion = try #require(Self.jsonBody(deletionBody))
        #expect(deletion["confirmation"] as? String == "DELETE")
        #expect(deletion["password"] == nil)
        #expect(deletion["reauthProof"] as? String == "short-lived")
        #expect(deletion["transferAdminToMemberId"] as? Int == 9)
    }

    @Test
    func cropsAProfilePhotoToASquareJpeg() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        }

        let data = try #require(
            ProfilePhotoCropper.jpeg(
                image: image,
                viewport: 300,
                zoom: 1,
                offset: .zero
            )
        )
        let cropped = try #require(UIImage(data: data)?.cgImage)

        #expect(cropped.width == cropped.height)
    }

    @Test
    func clampsPhotoMovementInsideTheCropArea() {
        let offset = ProfilePhotoCropper.clampedOffset(
            CGSize(width: 1_000, height: -1_000),
            imageSize: CGSize(width: 200, height: 100),
            viewport: 300,
            zoom: 1
        )

        #expect(offset.width == 150)
        #expect(offset.height == 0)
    }

    private func sessionToken(
        id: Int64,
        lastUsed: String? = "2026-08-12T10:00:00Z",
        isCurrent: Bool = false
    ) -> SettingsRefreshToken {
        SettingsRefreshToken(
            memberName: "Test",
            memberId: 1,
            validUntil: "2026-09-01T10:00:00Z",
            createdDate: "2026-08-01T10:00:00Z",
            lastUsed: lastUsed,
            remoteAddr: "127.0.0.1",
            id: id,
            userAgent: .init(os: "iOS", browser: "Dutypark", device: "Apple iOS Device"),
            isCurrentLogin: isCurrent
        )
    }

    private static func jsonBody(_ body: Data) -> [String: Any]? {
        return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }
}

private final class SettingsRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []
    private var bodyStorage: [Data?] = []

    func record(_ request: URLRequest) {
        let body = Self.requestBody(request)
        lock.lock()
        storage.append(request)
        bodyStorage.append(body)
        lock.unlock()
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var requestBodies: [Data?] {
        lock.lock()
        defer { lock.unlock() }
        return bodyStorage
    }

    private static func requestBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private final class SettingsURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("SettingsURLProtocolStub.handler is not set")
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !data.isEmpty {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
