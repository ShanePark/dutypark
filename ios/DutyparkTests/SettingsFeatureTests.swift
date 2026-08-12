import Foundation
import Testing
import UIKit
@testable import Dutypark

@MainActor
struct SettingsFeatureTests {
    @Test
    func supportsTheSameFiveNativeLanguageChoicesAsWeb() {
        #expect(AppLanguage.allCases.map(\.rawValue) == ["ko", "en", "ja", "zh-Hans", "es"])
        #expect(AppLanguage.allCases.map(\.nativeName) == ["한국어", "English", "日本語", "简体中文", "Español"])
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
            "settings.pattern.saveConfirm",
            "settings.pattern.deleteConfirm",
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
        ]
        for language in AppLanguage.allCases {
            defaults.set(language.rawValue, forKey: SettingsPreference.languageKey)
            for key in keys {
                #expect(SettingsLocalization.string(key) != key)
            }
        }
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
        #expect(individual.message.contains("해당 기기"))

        let allOthers = SettingsSessionConfirmation.otherSessions(count: 3)
        #expect(allOthers.titleKey == "settings.sessions.revokeOthersTitle")
        #expect(allOthers.message.contains("현재 접속을 제외"))
        #expect(allOthers.message.contains("3"))
    }

    @Test(.serialized)
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
}

private final class SettingsRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []

    func record(_ request: URLRequest) {
        lock.lock()
        storage.append(request)
        lock.unlock()
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storage
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
