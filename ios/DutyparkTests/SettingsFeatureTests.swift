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

        // The settings row only mirrors the language iOS resolved for the app.
        #expect(AppLanguage.current.rawValue == AppLocalization.locale.identifier)
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
        let expectedByLanguage: [Locale: [String: String]] = [
            .korean: [
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
            .english: [
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

        for (locale, expectedCopy) in expectedByLanguage {
            for (key, expected) in expectedCopy {
                #expect(SettingsLocalization.string(key, locale: locale) == expected)
            }
        }
    }

    @Test
    func webParitySettingsCopyExistsInEverySupportedLanguage() {
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
            "settings.photo.actions",
            "settings.photo.take",
            "settings.photo.library",
            "settings.manager.removeMessage",
            "settings.managed.switchMessage",
            "settings.accessibility.on",
            "settings.accessibility.off",
            "settings.sessions.empty",
            "settings.sessions.justNow",
            "settings.sessions.ipLabel",
            "settings.sessions.deviceLabel",
            "settings.sessions.browserLabel",
            "settings.sessions.appLabel",
            "settings.sessions.client.iosApp",
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
        for locale in [Locale.korean, .english] {
            for key in keys {
                #expect(SettingsLocalization.string(key, locale: locale) != key)
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
    func managedAccountSwitchKeepsTheConfirmationOpenOnFailure() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appending(path: "Dutypark/Features/Settings/MyInfoView.swift"),
            encoding: .utf8
        )
        let switchCase = try #require(
            source.range(of: "case .switchManagedAccount(let id, _):")
        )
        let switchSource = source[switchCase.lowerBound...]

        #expect(switchSource.contains("try await session.impersonate(memberId: id)"))
        #expect(switchSource.contains("DPHapticCenter.shared.emit(.error)"))
        #expect(!switchSource.contains("model.noticeKey = \"settings.error.generic\""))
        #expect(!switchSource.contains("try? await session.impersonate(memberId: id)"))
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
    func localizationHelpersResolveEverySupportedLanguage() {
        #expect(SettingsLocalization.string("settings.guide", locale: .korean) == "사용 가이드")
        #expect(SettingsLocalization.string("settings.guide", locale: .english) == "Guide")
        #expect(GuestLocalization.text("guest.retry", locale: .korean) == "다시 시도")
        #expect(GuestLocalization.text("guest.retry", locale: .english) == "Try again")
        #expect(
            SettingsLocalization.string("settings.guide.loadError.title", locale: .korean)
                == "페이지를 불러올 수 없습니다"
        )
        #expect(
            SettingsLocalization.string("settings.guide.loadError.title", locale: .english)
                == "Unable to load the page"
        )
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
    func decodesNativeAppSessionMarkerAndTreatsAnythingElseAsBrowser() throws {
        func session(_ clientTypeField: String) throws -> SettingsRefreshToken {
            let json = #"""
            {"memberName":"Test","memberId":1,"validUntil":"2026-09-01T10:00:00",\#
            "createdDate":"2026-08-01T10:00:00","lastUsed":null,"remoteAddr":"127.0.0.1","id":9,\#
            "userAgent":{"os":"iOS","browser":"Dutypark","device":"iPhone"},"isCurrentLogin":true\#
            \#(clientTypeField)}
            """#
            return try JSONDecoder().decode(SettingsRefreshToken.self, from: Data(json.utf8))
        }

        #expect(try session(#","clientType":"IOS_APP""#).resolvedClientType == .iosApp)
        #expect(try session(#","clientType":"BROWSER""#).resolvedClientType == .browser)
        #expect(try session("").resolvedClientType == .browser)
        #expect(try session(#","clientType":null"#).resolvedClientType == .browser)
        #expect(try session(#","clientType":"ANDROID_APP""#).resolvedClientType == .browser)
        #expect(try session(#","clientType":7"#).resolvedClientType == .browser)
    }

    @Test
    func nativeAppSessionsAreLabelledAsTheAppInsteadOfABrowserName() {
        let appSession = SettingsSessionClientPresentation(
            token: sessionToken(id: 9, clientType: .iosApp)
        )
        #expect(appSession.clientLabelKey == "settings.sessions.appLabel")
        #expect(SettingsLocalization.string(appSession.clientLabelKey, locale: .korean) == "앱")
        #expect(SettingsLocalization.string(appSession.clientLabelKey, locale: .english) == "App")
        #expect(SettingsLocalization.string("settings.sessions.client.iosApp", locale: .korean) == "iOS 앱")
        #expect(SettingsLocalization.string("settings.sessions.client.iosApp", locale: .english) == "iOS App")
        #expect(appSession.clientValue == SettingsLocalization.string("settings.sessions.client.iosApp"))
        #expect(appSession.clientIcon != "globe")
        #expect(appSession.deviceIcon == "iphone")

        let browserSession = SettingsSessionClientPresentation(token: sessionToken(id: 10))
        #expect(browserSession.clientLabelKey == "settings.sessions.browserLabel")
        #expect(browserSession.clientValue == "Dutypark")
        #expect(browserSession.clientIcon == "globe")

        let confirmation = SettingsSessionConfirmation.session(
            sessionToken(id: 9, clientType: .iosApp)
        )
        #expect(confirmation.message.contains(appSession.clientValue))
        #expect(!confirmation.message.contains("Dutypark"))
        #expect(confirmation.message.contains("Apple iOS Device"))
    }

    @Test
    func formatsSessionDatesWithoutExposingRawISOValues() throws {
        #expect(SettingsLocalization.string("settings.sessions.justNow", locale: .korean) == "방금 전")
        #expect(SettingsLocalization.string("settings.sessions.justNow", locale: .english) == "Just now")

        let now = try #require(SettingsSessionFormatter.date(from: "2026-08-12T12:00:00Z"))
        #expect(
            SettingsSessionFormatter.relativeTime("2026-08-12T11:59:30Z", now: now)
                == SettingsLocalization.string("settings.sessions.justNow")
        )
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
        let individual = SettingsSessionConfirmation.session(sessionToken(id: 9))
        #expect(individual.titleKey == "settings.sessions.revokeTitle")
        #expect(individual.message.contains("Apple iOS Device"))
        #expect(individual.message.contains("Dutypark"))
        #expect(individual.message.contains("127.0.0.1"))
        #expect(!individual.message.contains("{device}"))

        let allOthers = SettingsSessionConfirmation.otherSessions(count: 3)
        #expect(allOthers.titleKey == "settings.sessions.revokeOthersTitle")
        #expect(allOthers.message.contains("3"))
        #expect(!allOthers.message.contains("{count}"))
        #expect(
            SettingsLocalization.string("settings.sessions.revokeOthersMessage", locale: .korean)
                .contains("현재 접속을 제외")
        )
        #expect(
            SettingsLocalization.string("settings.sessions.revokeOthersMessage", locale: .english)
                .contains("keeping your current session")
        )
    }

    @Test
    func individualSessionRevokeCopyMatchesResponsiveWeb() {
        let expectedCopy: [(locale: Locale, title: String, action: String)] = [
            (.korean, "접속 세션 종료", "접속 종료"),
            (.english, "End session", "End session"),
        ]

        for expected in expectedCopy {
            #expect(
                SettingsLocalization.string("settings.sessions.revokeTitle", locale: expected.locale)
                    == expected.title
            )
            #expect(
                SettingsLocalization.string("settings.sessions.revoke", locale: expected.locale)
                    == expected.action
            )
        }
    }

    @Test
    func consequentialSettingsActionsUseCentralConfirmationContent() {
        let photo = SettingsConfirmation.deleteProfilePhoto
        #expect(photo.titleKey == "settings.photo.delete")
        #expect(photo.message == SettingsLocalization.string("settings.photo.deleteConfirm"))
        #expect(
            SettingsLocalization.string("settings.photo.delete", locale: .korean)
                == "기본 이미지로 변경"
        )
        #expect(
            SettingsLocalization.string("settings.photo.delete", locale: .english)
                == "Use default image"
        )
        #expect(photo.confirmTitleKey == "settings.photo.delete")
        #expect(photo.isDestructive)
        #expect(
            SettingsLocalization.string("settings.photo.deleteConfirm", locale: .korean)
                == "프로필 사진을 기본 이미지로 변경하시겠습니까?"
        )
        #expect(
            SettingsLocalization.string("settings.photo.deleteConfirm", locale: .english)
                == "Change your profile photo to the default image?"
        )
        #expect(
            SettingsLocalization.string("settings.photo.deleted", locale: .korean)
                == "프로필 사진이 기본 이미지로 변경되었습니다."
        )
        #expect(
            SettingsLocalization.string("settings.photo.deleted", locale: .english)
                == "Your profile photo is now set to the default image."
        )
        #expect(
            SettingsLocalization.string("settings.photo.deleteFailed", locale: .korean)
                == "프로필 사진을 기본 이미지로 변경하지 못했습니다."
        )
        #expect(
            SettingsLocalization.string("settings.photo.deleteFailed", locale: .english)
                == "Failed to change your profile photo to the default image."
        )

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
    func successfulSettingsMutationsPatchLoadedStateWithoutFollowUpGets() async throws {
        let recorder = SettingsRequestRecorder()
        defer { SettingsURLProtocolStub.handler = nil }
        let model = try await loadedSettingsModel(recorder: recorder)
        let originalMember = try #require(model.member)
        let originalDutyTypes = try #require(model.dutyPattern).dutyTypes
        recorder.reset()

        await model.updateVisibility(.privateAccess)
        #expect(model.member?.calendarVisibility == .privateAccess)
        #expect(model.member?.name == originalMember.name)
        #expect(model.member?.email == originalMember.email)

        #expect(await model.uploadProfilePhoto(Data([0x01, 0x02])))
        #expect(model.member?.hasProfilePhoto == true)
        #expect(model.member?.profilePhotoVersion == originalMember.profilePhotoVersion + 1)

        #expect(await model.deleteProfilePhoto())
        #expect(model.member?.hasProfilePhoto == false)
        #expect(model.member?.profilePhotoVersion == originalMember.profilePhotoVersion + 2)

        await model.unassignManager(2)
        #expect(model.managers.map(\.id) == [3])

        await model.createAuxiliaryAccount(name: "New child")
        #expect(model.managedMembers.map(\.id) == [10, 11, 12])

        #expect(await model.revokeSession(id: 102))
        #expect(model.sessions.map(\.id) == [101, 103])
        #expect(await model.revokeOtherSessions())
        #expect(model.sessions.map(\.id) == [101])

        #expect(await model.deleteDutyPattern())
        #expect(model.dutyPattern?.pattern == nil)
        #expect(model.dutyPattern?.dutyTypes == originalDutyTypes)
        #expect(model.dutyPattern?.configurable == true)

        let requests = recorder.requests
        #expect(requests.map(\.httpMethod) == [
            "PUT", "PUT", "DELETE", "DELETE", "POST", "DELETE", "DELETE", "DELETE",
        ])
        #expect(requests.compactMap { $0.url?.path } == [
            "/api/members/1/visibility",
            "/api/members/profile-photo",
            "/api/members/profile-photo",
            "/api/members/manager/2",
            "/api/members/auxiliary",
            "/api/auth/refresh-tokens/102",
            "/api/auth/refresh-tokens/others",
            "/api/duty/pattern/me",
        ])
        #expect(!requests.contains { $0.httpMethod == "GET" })
    }

    @Test
    func failedSettingsMutationsPreserveAllLoadedStateWithoutFollowUpGets() async throws {
        let recorder = SettingsRequestRecorder()
        defer { SettingsURLProtocolStub.handler = nil }
        let model = try await loadedSettingsModel(recorder: recorder)
        let originalMember = model.member
        let originalManagers = model.managers
        let originalManagedMembers = model.managedMembers
        let originalSessions = model.sessions
        let originalPattern = model.dutyPattern
        recorder.reset()
        SettingsURLProtocolStub.handler = { request in
            recorder.record(request)
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Data(#"{"code":"test.error"}"#.utf8)
            )
        }

        await model.updateVisibility(.publicAccess)
        #expect(!(await model.uploadProfilePhoto(Data([0x01]))))
        #expect(!(await model.deleteProfilePhoto()))
        #expect(model.noticeKey == "settings.photo.deleteFailed")
        #expect(model.noticeIsError)
        await model.unassignManager(2)
        await model.createAuxiliaryAccount(name: "Not created")
        #expect(!(await model.revokeSession(id: 102)))
        #expect(!(await model.revokeOtherSessions()))
        #expect(!(await model.deleteDutyPattern()))

        #expect(model.member == originalMember)
        #expect(model.managers == originalManagers)
        #expect(model.managedMembers == originalManagedMembers)
        #expect(model.sessions == originalSessions)
        #expect(model.dutyPattern == originalPattern)
        #expect(!recorder.requests.contains { $0.httpMethod == "GET" })
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

        let koreanMessage = SettingsSocialUnlinkPolicy.confirmationMessage(for: .kakao, locale: .korean)
        #expect(koreanMessage.contains("Dutypark 내부 연결만 해제"))
        #expect(koreanMessage.contains("Kakao 계정"))
        #expect(koreanMessage.contains("권한은 삭제되지 않습니다"))
        let koreanLastProviderReason = SettingsLocalization.string(
            "settings.social.unlinkLastAuthenticationMethod",
            locale: .korean
        )
        #expect(koreanLastProviderReason.contains("다른 소셜 계정을 먼저 연결"))
        #expect(!koreanLastProviderReason.contains("비밀번호"))

        for locale in [Locale.korean, .english] {
            let message = SettingsSocialUnlinkPolicy.confirmationMessage(for: .kakao, locale: locale)
            #expect(message.contains("Kakao"))
            #expect(message != "settings.social.unlinkConfirmMessage")
            let lastProviderReason = SettingsLocalization.string(
                "settings.social.unlinkLastAuthenticationMethod",
                locale: locale
            )
            #expect(!lastProviderReason.contains("{count}"))
            #expect(lastProviderReason != "settings.social.unlinkLastAuthenticationMethod")
        }

        let appleMessage = SettingsSocialUnlinkPolicy.confirmationMessage(for: .apple, locale: .english)
        #expect(appleMessage.contains("Apple"))
    }

    @Test
    func appleUnlinkCopyExplainsProviderRevocationWhileOtherProvidersStayLocalOnly() {
        let kakaoDescription = SettingsSocialUnlinkPolicy.managementDescription(for: .kakao, locale: .korean)
        let naverDescription = SettingsSocialUnlinkPolicy.managementDescription(for: .naver, locale: .korean)
        let appleDescription = SettingsSocialUnlinkPolicy.managementDescription(for: .apple, locale: .korean)
        let appleConfirmation = SettingsSocialUnlinkPolicy.confirmationMessage(for: .apple, locale: .korean)

        #expect(kakaoDescription.contains("권한은 삭제되지 않습니다"))
        #expect(naverDescription.contains("Naver 계정"))
        #expect(naverDescription.contains("권한은 삭제되지 않습니다"))
        #expect(appleDescription.contains("먼저 Apple 인증 권한을 철회한 뒤"))
        #expect(appleDescription.contains("철회에 실패하면"))
        #expect(appleConfirmation.contains("Apple 인증 권한을 철회하고"))
        #expect(appleConfirmation.contains("이후 이 Apple 계정으로 Dutypark에 로그인할 수 없습니다"))
        #expect(!appleDescription.contains("권한은 삭제되지 않습니다"))
        #expect(!appleConfirmation.contains("권한은 삭제되지 않습니다"))

        #expect(
            SettingsSocialUnlinkPolicy.managementDescription(for: .apple, locale: .english)
                .contains("first revokes its Apple authorization")
        )
        #expect(
            SettingsSocialUnlinkPolicy.confirmationMessage(for: .apple, locale: .english)
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

        #expect(
            SettingsLocalization.string(
                DutyPatternUnavailableCopy.key(reason: "TEAM_REQUIRED"),
                locale: .korean
            ).contains("팀에 소속")
        )
        #expect(
            SettingsLocalization.string(
                DutyPatternUnavailableCopy.key(reason: "TEAM_REQUIRED"),
                locale: .english
            ).contains("assigned to a team")
        )
        #expect(
            SettingsLocalization.string(
                DutyPatternUnavailableCopy.key(reason: "DUTY_TYPE_REQUIRED"),
                locale: .korean
            ).contains("근무 유형")
        )
        #expect(
            SettingsLocalization.string(
                DutyPatternUnavailableCopy.key(reason: "DUTY_TYPE_REQUIRED"),
                locale: .english
            ).contains("duty type")
        )
        #expect(
            SettingsLocalization.string(
                DutyPatternUnavailableCopy.key(reason: "UNKNOWN"),
                locale: .korean
            ).contains("설정")
        )
        #expect(
            SettingsLocalization.string(
                DutyPatternUnavailableCopy.key(reason: "UNKNOWN"),
                locale: .english
            ).contains("settings")
        )
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
                body = #"{"jobId":44,"status":"ACCEPTED","receiptToken":"receipt-token","estimatedCompletionAt":"2026-08-29T12:05:00Z"}"#
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
            receiptToken: "receipt-token",
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
        #expect(deletion["receiptToken"] as? String == "receipt-token")
        #expect(deletion["transferAdminToMemberId"] as? Int == 9)
    }

    @Test
    func accountDeletionStatusUsesTheUnauthenticatedReceiptEndpoint() async throws {
        let recorder = SettingsRequestRecorder()
        SettingsURLProtocolStub.handler = { request in
            recorder.record(request)
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"status":"COMPLETED","estimatedCompletionAt":"2026-08-29T12:05:00Z","completedAt":"2026-08-29T12:04:00Z","receiptExpiresAt":"2026-09-28T12:05:00Z"}"#.utf8)
            )
        }
        defer { SettingsURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SettingsURLProtocolStub.self]
        let service = SettingsService(client: APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        ))

        let response = try await service.accountDeletionStatus(receiptToken: "opaque-receipt")

        #expect(response.status == "COMPLETED")
        #expect(response.completedAt == "2026-08-29T12:04:00Z")
        #expect(recorder.requests.count == 1)
        #expect(recorder.requests.first?.httpMethod == "POST")
        #expect(recorder.requests.first?.url?.path == "/api/account-deletions/status")
        let requestBody = try #require(recorder.requestBodies.first.flatMap { $0 })
        let body = try #require(Self.jsonBody(requestBody))
        #expect(body["receiptToken"] as? String == "opaque-receipt")
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
    func downsamplesProfilePhotoBeforeItReachesTheCropView() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 3_000, height: 2_000)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3_000, height: 2_000))
        }
        let url = FileManager.default.temporaryDirectory
            .appending(path: "dutypark-profile-photo-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        try #require(source.jpegData(compressionQuality: 0.9)).write(to: url)

        let downsampled = try #require(ProfilePhotoCropper.downsampledImage(at: url))
        let largestDimension = max(downsampled.cgImage?.width ?? 0, downsampled.cgImage?.height ?? 0)

        #expect(largestDimension <= ProfilePhotoProcessingPolicy.maxInputPixelDimension)
        #expect(largestDimension < 3_000)
    }

    @Test
    func rejectsProfilePhotoWhenInputSizeMetadataIsMissing() {
        do {
            try ProfilePhotoCropper.validateInputFileSize(nil)
            Issue.record("A photo without a verifiable file size must be rejected")
        } catch let error as ProfilePhotoProcessingError {
            #expect(error == .inputSizeUnavailable)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func rejectsProfilePhotoWhenInputSizeMetadataCannotBeRead() {
        let url = URL(string: "dutypark-profile-photo://unavailable-size")!

        do {
            _ = try ProfilePhotoCropper.loadDownsampledImage(at: url)
            Issue.record("A photo whose file size cannot be read must be rejected")
        } catch let error as ProfilePhotoProcessingError {
            #expect(error == .inputSizeUnavailable)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func capsProfilePhotoCropPixelsAndUploadBytes() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3_000, height: 2_000)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3_000, height: 2_000))
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

        #expect(cropped.width <= ProfilePhotoProcessingPolicy.maxOutputPixelDimension)
        #expect(data.count <= ProfilePhotoProcessingPolicy.maxUploadBytes)
    }

    @Test
    func rejectsOversizedProfilePhotoBeforeCreatingARequest() async throws {
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
        let oversizedData = Data(
            repeating: 0,
            count: ProfilePhotoProcessingPolicy.maxUploadBytes + 1
        )

        do {
            try await service.uploadProfilePhoto(jpegData: oversizedData)
            Issue.record("An oversized profile photo must be rejected before a request is sent")
        } catch let error as ProfilePhotoUploadError {
            #expect(error == .tooLarge(maxBytes: ProfilePhotoProcessingPolicy.maxUploadBytes))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(recorder.requests.isEmpty)
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
        isCurrent: Bool = false,
        clientType: SessionClientType? = nil
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
            isCurrentLogin: isCurrent,
            clientType: clientType
        )
    }

    private func loadedSettingsModel(
        recorder: SettingsRequestRecorder
    ) async throws -> SettingsViewModel {
        SettingsURLProtocolStub.handler = { request in
            recorder.record(request)
            let path = request.url?.path
            let body: String
            let status: Int
            switch (request.httpMethod, path) {
            case ("GET", "/api/members/me"):
                body = #"{"id":1,"name":"Owner","email":"owner@example.com","teamId":7,"team":"Team","calendarVisibility":"FRIENDS","kakaoId":"kakao","naverId":"naver","appleId":null,"hasPassword":true,"hasProfilePhoto":false,"profilePhotoVersion":4}"#
                status = 200
            case ("GET", "/api/members/family"):
                body = "[]"
                status = 200
            case ("GET", "/api/friends"):
                body = "[]"
                status = 200
            case ("GET", "/api/members/managers"):
                body = #"[{"id":2,"name":"Manager A","email":null,"teamId":7,"team":"Team","calendarVisibility":"FRIENDS","kakaoId":null,"naverId":null,"appleId":null,"hasPassword":true,"hasProfilePhoto":false,"profilePhotoVersion":0},{"id":3,"name":"Manager B","email":null,"teamId":7,"team":"Team","calendarVisibility":"FRIENDS","kakaoId":null,"naverId":null,"appleId":null,"hasPassword":true,"hasProfilePhoto":false,"profilePhotoVersion":0}]"#
                status = 200
            case ("GET", "/api/members/managed"):
                body = #"[{"id":10,"name":"Child A","email":null,"teamId":null,"team":null,"calendarVisibility":"FRIENDS","kakaoId":null,"naverId":null,"appleId":null,"hasPassword":false,"hasProfilePhoto":false,"profilePhotoVersion":0},{"id":11,"name":"Child B","email":null,"teamId":null,"team":null,"calendarVisibility":"FRIENDS","kakaoId":null,"naverId":null,"appleId":null,"hasPassword":false,"hasProfilePhoto":false,"profilePhotoVersion":0}]"#
                status = 200
            case ("GET", "/api/auth/refresh-tokens"):
                body = #"[{"memberName":"Owner","memberId":1,"validUntil":"2026-09-01T10:00:00Z","createdDate":"2026-08-01T10:00:00Z","lastUsed":"2026-08-15T10:00:00Z","remoteAddr":"127.0.0.1","id":101,"userAgent":null,"isCurrentLogin":true},{"memberName":"Owner","memberId":1,"validUntil":"2026-09-01T10:00:00Z","createdDate":"2026-08-01T10:00:00Z","lastUsed":"2026-08-14T10:00:00Z","remoteAddr":"127.0.0.2","id":102,"userAgent":null,"isCurrentLogin":false},{"memberName":"Owner","memberId":1,"validUntil":"2026-09-01T10:00:00Z","createdDate":"2026-08-01T10:00:00Z","lastUsed":"2026-08-13T10:00:00Z","remoteAddr":"127.0.0.3","id":103,"userAgent":null,"isCurrentLogin":false}]"#
                status = 200
            case ("GET", "/api/policies/current"):
                body = #"{"terms":null,"privacy":null}"#
                status = 200
            case ("GET", "/api/duty/pattern/me"):
                body = ##"{"configurable":true,"reason":null,"dutyTypes":[{"id":4,"name":"Day","color":"#3B82F6"}],"pattern":{"days":[{"weekday":"MONDAY","dutyType":{"id":4,"name":"Day","color":"#3B82F6"}}],"holidayOff":true,"effectiveFrom":"2026-08-01"}}"##
                status = 200
            case ("POST", "/api/members/auxiliary"):
                body = #"{"id":12,"name":"New child","email":null,"teamId":null,"team":null,"calendarVisibility":"FRIENDS","kakaoId":null,"naverId":null,"appleId":null,"hasPassword":false,"hasProfilePhoto":false,"profilePhotoVersion":0}"#
                status = 200
            case ("DELETE", "/api/auth/refresh-tokens/others"):
                body = #"{"deletedCount":1}"#
                status = 200
            default:
                body = ""
                status = 204
            }
            return (
                HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
                Data(body.utf8)
            )
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SettingsURLProtocolStub.self]
        let service = SettingsService(client: APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        ))
        let model = SettingsViewModel(service: service)
        await model.load()
        _ = try #require(model.member)
        return model
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

    func reset() {
        lock.lock()
        storage.removeAll()
        bodyStorage.removeAll()
        lock.unlock()
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
