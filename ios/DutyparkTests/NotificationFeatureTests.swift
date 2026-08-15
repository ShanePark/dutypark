import Foundation
import Testing
import UserNotifications
@testable import Dutypark

@MainActor
struct NotificationFeatureTests {
    @Test
    func deletionConfirmationKeepsTheSelectedScopeAndLocalizationKeys() throws {
        let page: PageResponse<NotificationDTO> = try decodeNotificationFixture()
        let notification = try #require(page.content.first)

        let single = NotificationDeletionConfirmation.notification(notification)
        #expect(single.id == .notification(notification.id))
        #expect(single.titleKey == "notifications.list.deleteConfirmTitle")
        #expect(single.messageKey == "notifications.list.deleteConfirmMessage")
        #expect(single.confirmTitleKey == "notifications.common.delete")
        guard case let .notification(selectedNotification) = single else {
            Issue.record("Expected a single-notification confirmation")
            return
        }
        #expect(selectedNotification == notification)

        let allRead = NotificationDeletionConfirmation.allRead
        #expect(allRead.id == .allRead)
        #expect(allRead.titleKey == "notifications.list.deleteAllReadTitle")
        #expect(allRead.messageKey == "notifications.list.deleteAllReadConfirm")
        #expect(allRead.confirmTitleKey == "notifications.list.deleteRead")
    }

    @Test
    func mapsNotificationReferencesToNativeRoutes() throws {
        let page: PageResponse<NotificationDTO> = try decodeNotificationFixture()
        let notification = try #require(page.content.first)

        #expect(NotificationRoute(notification: notification) == .taggedSchedule(
            UUID(uuidString: "9a53c095-c8b0-4de7-91be-b2fef4134e2a")!
        ))
    }

    @Test
    func distinguishesTaggedScheduleFromOrdinaryScheduleRoute() throws {
        let scheduleID = UUID(uuidString: "9a53c095-c8b0-4de7-91be-b2fef4134e2a")!
        let notification = try decodeNotification(
            type: "SCHEDULE_TAGGED",
            referenceType: "SCHEDULE",
            referenceID: scheduleID.uuidString
        )

        #expect(NotificationRoute(notification: notification) == .taggedSchedule(scheduleID))
    }

    @Test
    func scheduleNotificationRoutesChooseTheMatchingCalendarOwner() {
        let scheduleID = UUID(uuidString: "9a53c095-c8b0-4de7-91be-b2fef4134e2a")!

        #expect(RootNavigationPolicy.scheduleMemberID(
            for: .schedule(scheduleID),
            authenticatedMemberID: 1,
            scheduleOwnerID: 9
        ) == 9)
        #expect(RootNavigationPolicy.scheduleMemberID(
            for: .taggedSchedule(scheduleID),
            authenticatedMemberID: 1,
            scheduleOwnerID: 9
        ) == 1)
    }

    @Test
    func preservesTodoReferenceIdentifierForDetailRouting() throws {
        let todoID = UUID(uuidString: "60fd4faf-ecda-48d4-a128-362791a599e7")!
        let notification = try decodeNotification(
            type: "TODO_TAGGED",
            referenceType: "TODO",
            referenceID: todoID.uuidString
        )

        #expect(NotificationRoute(notification: notification) == .todo(todoID))
    }

    @Test
    func keepsTodoRouteAvailableWhenLegacyReferenceIsMissing() throws {
        let notification = try decodeNotification(
            type: "TODO_STATUS_DONE",
            referenceType: "TODO",
            referenceID: nil
        )

        #expect(NotificationRoute(notification: notification) == .todo(nil))
    }

    @Test
    func sceneResumeRefreshesListAndBothCounts() async throws {
        let page: PageResponse<NotificationDTO> = try decodeNotificationFixture()
        let api = NotificationAPIMock(page: page)
        let store = NotificationStore(api: api)

        await store.setForeground(false)
        #expect(await api.callCounts() == .zero)

        await store.setForeground(true)

        #expect(await api.callCounts() == NotificationAPICallCounts(list: 1, count: 1, friendCount: 1))
        #expect(store.notifications.map(\.id) == page.content.map(\.id))
        #expect(store.unreadCount == 1)
        #expect(store.friendRequestCount == 2)
        #expect(store.hasFriendRequests)
        #expect(store.friendRequestCountLabel == "2")
    }

    @Test
    func pollingBackoffMatchesWebLimits() {
        #expect(NotificationStore.pollingInterval(afterFailures: 0) == 10)
        #expect(NotificationStore.pollingInterval(afterFailures: 1) == 20)
        #expect(NotificationStore.pollingInterval(afterFailures: 10) == 300)
    }

    @Test
    func versionMismatchUsesTheSelectedAppLocaleForGenericText() throws {
        let notification = try decodeNotification(
            type: "FRIEND_REQUEST_RECEIVED",
            referenceType: "FRIEND_REQUEST",
            referenceID: nil,
            payloadVersion: 2
        )

        #expect(
            NotificationPresentation.message(for: notification, locale: Locale(identifier: "ko"))
                == "새 알림이 도착했습니다."
        )
        #expect(
            NotificationPresentation.message(for: notification, locale: Locale(identifier: "en"))
                == "You have a new notification."
        )
    }

    @Test
    func formatsAbsoluteNotificationDatesInSupportedLocalesAndFallsBackToEnglish() throws {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-08-12T09:51:00Z"))
        let utc = try #require(TimeZone(secondsFromGMT: 0))

        #expect(NotificationPresentation.absoluteDate(date, locale: Locale(identifier: "en"), timeZone: utc) == "Aug 12, 2026 09:51")
        #expect(NotificationPresentation.absoluteDate(date, locale: Locale(identifier: "ko"), timeZone: utc) == "2026.08.12 09:51")
        #expect(NotificationPresentation.absoluteDate(date, locale: Locale(identifier: "fr-FR"), timeZone: utc) == "Aug 12, 2026 09:51")
    }

    @Test
    func convertsAPNsDeviceTokenToLowercaseHex() {
        #expect(APNsRegistrationManager.hexString(for: Data([0x00, 0x7F, 0xA4, 0xFF])) == "007fa4ff")
    }

    @Test
    func persistsExplicitPushPreferenceAndDefaultsToEnabled() throws {
        let suiteName = "NotificationFeatureTests.pushPreference.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let manager = APNsRegistrationManager(defaults: defaults)
        #expect(manager.isEnabled)

        manager.setEnabled(false)
        let restoredManager = APNsRegistrationManager(defaults: defaults)
        #expect(!restoredManager.isEnabled)

        restoredManager.setEnabled(true)
        #expect(APNsRegistrationManager(defaults: defaults).isEnabled)
    }

    @Test
    func authenticatedActivationDoesNotRequestUndeterminedPermission() async throws {
        let suiteName = "NotificationFeatureTests.noAutomaticPrompt.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let center = NotificationAuthorizationCenterMock(status: .notDetermined)
        let manager = APNsRegistrationManager(notificationCenter: center, defaults: defaults)

        await manager.activateForAuthenticatedSession()

        #expect(center.requestCount == 0)
        #expect(manager.authorizationStatus == .notDetermined)
        #expect(manager.registrationState == .idle)
    }

    @Test
    func disabledPreferenceStaysDisabledDuringAuthenticatedActivation() async throws {
        let suiteName = "NotificationFeatureTests.disabledActivation.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: "dp-push-enabled")
        let center = NotificationAuthorizationCenterMock(status: .notDetermined)
        let manager = APNsRegistrationManager(notificationCenter: center, defaults: defaults)

        await manager.activateForAuthenticatedSession()

        #expect(!manager.isEnabled)
        #expect(center.requestCount == 0)
    }

    @Test
    func reenablingPushRequestsRemoteRegistrationAgain() async throws {
        let suiteName = "NotificationFeatureTests.reenablePush.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let api = APNsRegistrationAPIMock()
        let center = NotificationAuthorizationCenterMock(status: .authorized)
        let registrar = RemoteNotificationRegistrarMock()
        let manager = APNsRegistrationManager(
            api: api,
            notificationCenter: center,
            remoteNotificationRegistrar: registrar,
            defaults: defaults
        )

        await manager.resumeRegistration()
        manager.setEnabled(false)
        manager.setEnabled(true)
        await manager.resumeRegistration()
        await manager.didRegisterForRemoteNotifications(deviceToken: Data([0xAA]))

        #expect(registrar.registrationRequestCount == 2)
        #expect(await api.calls().registeredTokens == ["aa"])
        #expect(defaults.string(forKey: "dutypark.apns.device-token") == "aa")
        #expect(manager.registrationState == .registered)
    }

    @Test
    func lateSystemRegistrationCallbackAfterLogoutIsIgnored() async throws {
        let suiteName = "NotificationFeatureTests.lateSystemCallbackAfterLogout.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("aa", forKey: "dutypark.apns.device-token")
        let api = APNsRegistrationAPIMock(initialBoundToken: "aa")
        let center = NotificationAuthorizationCenterMock(status: .authorized)
        let registrar = RemoteNotificationRegistrarMock()
        let manager = APNsRegistrationManager(
            api: api,
            notificationCenter: center,
            remoteNotificationRegistrar: registrar,
            defaults: defaults
        )

        await manager.activateForAuthenticatedSession()
        await manager.unregister()
        await manager.didRegisterForRemoteNotifications(deviceToken: Data([0xBB]))

        #expect(registrar.registrationRequestCount == 1)
        #expect(await api.calls() == APNsRegistrationAPICalls(
            registeredTokens: [],
            unregisteredTokens: ["aa"]
        ))
        #expect(await api.boundToken() == nil)
        #expect(defaults.string(forKey: "dutypark.apns.device-token") == nil)
        #expect(manager.registrationState == .idle)
    }

    @Test
    func failedServerRegistrationCanRetryOnForegroundResume() async throws {
        let suiteName = "NotificationFeatureTests.failedServerRegistrationRetry.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let api = APNsRegistrationAPIMock(registerFailureCount: 1)
        let center = NotificationAuthorizationCenterMock(status: .authorized)
        let registrar = RemoteNotificationRegistrarMock()
        let manager = APNsRegistrationManager(
            api: api,
            notificationCenter: center,
            remoteNotificationRegistrar: registrar,
            defaults: defaults
        )

        await manager.resumeRegistration()
        await manager.didRegisterForRemoteNotifications(deviceToken: Data([0xAA]))
        await manager.resumeRegistration()
        await manager.didRegisterForRemoteNotifications(deviceToken: Data([0xAA]))

        #expect(registrar.registrationRequestCount == 2)
        #expect(await api.calls().registeredTokens == ["aa", "aa"])
        #expect(defaults.string(forKey: "dutypark.apns.device-token") == "aa")
        #expect(manager.registrationState == .registered)
    }

    @Test
    func failedSystemRegistrationCanRetryOnForegroundResume() async throws {
        let suiteName = "NotificationFeatureTests.failedSystemRegistrationRetry.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let api = APNsRegistrationAPIMock()
        let center = NotificationAuthorizationCenterMock(status: .authorized)
        let registrar = RemoteNotificationRegistrarMock()
        let manager = APNsRegistrationManager(
            api: api,
            notificationCenter: center,
            remoteNotificationRegistrar: registrar,
            defaults: defaults
        )

        await manager.resumeRegistration()
        manager.didFailToRegisterForRemoteNotifications()
        await manager.resumeRegistration()
        await manager.didRegisterForRemoteNotifications(deviceToken: Data([0xAA]))

        #expect(registrar.registrationRequestCount == 2)
        #expect(await api.calls().registeredTokens == ["aa"])
        #expect(defaults.string(forKey: "dutypark.apns.device-token") == "aa")
        #expect(manager.registrationState == .registered)
    }

    @Test
    func newAccountRequestsRegistrationAfterPreviousAccountUnregisters() async throws {
        let suiteName = "NotificationFeatureTests.accountTransition.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let api = APNsRegistrationAPIMock()
        let center = NotificationAuthorizationCenterMock(status: .authorized)
        let registrar = RemoteNotificationRegistrarMock()
        let manager = APNsRegistrationManager(
            api: api,
            notificationCenter: center,
            remoteNotificationRegistrar: registrar,
            defaults: defaults
        )

        await manager.activateForAuthenticatedSession()
        await manager.didRegisterForRemoteNotifications(deviceToken: Data([0xAA]))
        await manager.unregister()
        await manager.activateForAuthenticatedSession()
        await manager.didRegisterForRemoteNotifications(deviceToken: Data([0xBB]))

        #expect(registrar.registrationRequestCount == 2)
        #expect(await api.calls() == APNsRegistrationAPICalls(
            registeredTokens: ["aa", "bb"],
            unregisteredTokens: ["aa"]
        ))
        #expect(await api.boundToken() == "bb")
        #expect(await api.events() == [
            .registered("aa"),
            .unregisterStarted("aa"),
            .unregisterFinished("aa"),
            .registered("bb")
        ])
        #expect(defaults.string(forKey: "dutypark.apns.device-token") == "bb")
        #expect(manager.registrationState == .registered)
    }

    @Test
    func lateUnregisterCannotRemoveAReenabledPushRegistration() async throws {
        let suiteName = "NotificationFeatureTests.lateUnregister.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("aa", forKey: "dutypark.apns.device-token")
        let api = APNsRegistrationAPIMock(
            initialBoundToken: "aa",
            delaysUnregister: true
        )
        let center = NotificationAuthorizationCenterMock(status: .authorized)
        let registrar = RemoteNotificationRegistrarMock()
        let manager = APNsRegistrationManager(
            api: api,
            notificationCenter: center,
            remoteNotificationRegistrar: registrar,
            defaults: defaults
        )

        manager.setEnabled(false)
        let unregisterTask = Task { await manager.unregister() }
        #expect(await api.waitUntilUnregisterStarts())

        manager.setEnabled(true)
        await manager.resumeRegistration()
        let registerTask = Task {
            await manager.didRegisterForRemoteNotifications(deviceToken: Data([0xAA]))
        }
        for _ in 0..<100 {
            guard manager.registrationState == .idle else { break }
            await Task.yield()
        }
        for _ in 0..<100 {
            guard manager.registrationState == .registering else { break }
            await Task.yield()
        }

        #expect(await api.calls().registeredTokens.isEmpty)
        await api.releaseUnregister()
        await unregisterTask.value
        await registerTask.value

        #expect(registrar.registrationRequestCount == 1)
        #expect(await api.events() == [
            .unregisterStarted("aa"),
            .unregisterFinished("aa"),
            .registered("aa")
        ])
        #expect(await api.boundToken() == "aa")
        #expect(defaults.string(forKey: "dutypark.apns.device-token") == "aa")
        #expect(manager.registrationState == .registered)
    }

    @Test
    func logoutUnregistersAnInFlightFirstDeviceToken() async throws {
        let suiteName = "NotificationFeatureTests.inFlightFirstRegistrationLogout.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let api = APNsRegistrationAPIMock(delaysRegister: true)
        let center = NotificationAuthorizationCenterMock(status: .authorized)
        let registrar = RemoteNotificationRegistrarMock()
        let manager = APNsRegistrationManager(
            api: api,
            notificationCenter: center,
            remoteNotificationRegistrar: registrar,
            defaults: defaults
        )
        await manager.resumeRegistration()
        let registerTask = Task {
            await manager.didRegisterForRemoteNotifications(deviceToken: Data([0xBB]))
        }
        #expect(await api.waitUntilRegisterStarts())
        var didLogout = false
        let logoutTask = Task {
            await manager.unregister()
            didLogout = true
        }
        for _ in 0..<100 { await Task.yield() }

        await api.releaseRegister()
        await registerTask.value
        await logoutTask.value

        #expect(didLogout)
        #expect(await api.events() == [
            .registered("bb"),
            .unregisterStarted("bb"),
            .unregisterFinished("bb")
        ])
        #expect(await api.boundToken() == nil)
        #expect(defaults.string(forKey: "dutypark.apns.device-token") == nil)
        #expect(manager.registrationState == .idle)
    }

    @Test
    func logoutUnregistersStoredAndInFlightReplacementTokens() async throws {
        let suiteName = "NotificationFeatureTests.inFlightReplacementLogout.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("aa", forKey: "dutypark.apns.device-token")
        let api = APNsRegistrationAPIMock(
            initialBoundToken: "aa",
            delaysRegister: true
        )
        let center = NotificationAuthorizationCenterMock(status: .authorized)
        let registrar = RemoteNotificationRegistrarMock()
        let manager = APNsRegistrationManager(
            api: api,
            notificationCenter: center,
            remoteNotificationRegistrar: registrar,
            defaults: defaults
        )
        await manager.resumeRegistration()
        let registerTask = Task {
            await manager.didRegisterForRemoteNotifications(deviceToken: Data([0xBB]))
        }
        #expect(await api.waitUntilRegisterStarts())
        var didLogout = false
        let logoutTask = Task {
            await manager.unregister()
            didLogout = true
        }
        for _ in 0..<100 { await Task.yield() }

        await api.releaseRegister()
        await registerTask.value
        await logoutTask.value

        #expect(didLogout)
        #expect(await api.events() == [
            .registered("bb"),
            .unregisterStarted("aa"),
            .unregisterFinished("aa"),
            .unregisterStarted("bb"),
            .unregisterFinished("bb")
        ])
        #expect(await api.boundToken() == nil)
        #expect(defaults.string(forKey: "dutypark.apns.device-token") == nil)
        #expect(manager.registrationState == .idle)
    }

    @Test
    func unregisterCompletesBeforeSessionCleanupContinues() async throws {
        let suiteName = "NotificationFeatureTests.rootLogout.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("abc123", forKey: "dutypark.apns.device-token")
        let api = APNsRegistrationAPIMock()
        let manager = APNsRegistrationManager(api: api, defaults: defaults)
        var logoutObservedPushUnregistration = false

        await manager.unregister()
        logoutObservedPushUnregistration = await api.calls().unregisteredTokens == ["abc123"]

        #expect(logoutObservedPushUnregistration)
    }

    @Test
    func unregisterWithoutPushTokenReturnsCleanly() async throws {
        let suiteName = "NotificationFeatureTests.rootLogoutWithoutToken.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let api = APNsRegistrationAPIMock()
        let manager = APNsRegistrationManager(api: api, defaults: defaults)
        var didLogout = false

        await manager.unregister()
        didLogout = true

        #expect(didLogout)
        #expect(await api.calls().unregisteredTokens.isEmpty)
        #expect(manager.registrationState == .idle)
    }

    @Test
    func unregisterFailureReturnsSoSessionCleanupCanContinue() async throws {
        let suiteName = "NotificationFeatureTests.rootLogoutUnregisterFailure.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("abc123", forKey: "dutypark.apns.device-token")
        let api = APNsRegistrationAPIMock(failsUnregister: true)
        let manager = APNsRegistrationManager(api: api, defaults: defaults)
        var didLogout = false

        await manager.unregister()
        didLogout = true

        #expect(didLogout)
        #expect(await api.calls().unregisteredTokens == ["abc123"])
        #expect(manager.registrationState == .failed)
    }

    @Test
    func acceptedAccountDeletionClearsStoredPushStateLocally() async throws {
        let suiteName = "NotificationFeatureTests.deletionCleanup.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("abc123", forKey: "dutypark.apns.device-token")
        let manager = APNsRegistrationManager(defaults: defaults)

        await manager.completeAccountDeletionCleanup()
        #expect(defaults.string(forKey: "dutypark.apns.device-token") == nil)
        #expect(manager.registrationState == .idle)
    }

    @Test
    func readsNotificationIdentifierFromSupportedAPNsPayloadShapes() {
        let id = UUID(uuidString: "ae71ee7d-3af9-4936-a6e8-75b9c0d37822")!

        #expect(NotificationPushCenter.notificationID(from: ["notificationId": id.uuidString]) == id)
        #expect(NotificationPushCenter.notificationID(from: [
            "data": ["notificationId": id.uuidString]
        ]) == id)
        #expect(NotificationPushCenter.notificationID(from: ["notificationId": "invalid"]) == nil)
    }

    private func decodeNotificationFixture() throws -> PageResponse<NotificationDTO> {
        let bundle = Bundle(for: NotificationFixtureBundleToken.self)
        let url = try #require(
            bundle.url(forResource: "notification-page", withExtension: "json", subdirectory: "Fixtures")
                ?? bundle.url(forResource: "notification-page", withExtension: "json")
        )
        return try JSONDecoder().decode(PageResponse<NotificationDTO>.self, from: Data(contentsOf: url))
    }

    private func decodeNotification(
        type: String,
        referenceType: String,
        referenceID: String?,
        payloadVersion: Int = 1
    ) throws -> NotificationDTO {
        let referenceJSON = referenceID.map { #", "referenceId": "\#($0)""# } ?? ""
        return try JSONDecoder().decode(
            NotificationDTO.self,
            from: Data("""
                {
                  "id": "ae71ee7d-3af9-4936-a6e8-75b9c0d37822",
                  "type": "\(type)",
                  "referenceType": "\(referenceType)"\(referenceJSON),
                  "actorId": 11,
                  "payload": {"version": \(payloadVersion), "actor": null, "todoTitle": "Task"},
                  "isRead": false,
                  "createdAt": "2026-08-12T09:51:51.163702"
                }
                """.utf8)
        )
    }
}

private final class NotificationFixtureBundleToken {}

@MainActor
private final class NotificationAuthorizationCenterMock: NotificationAuthorizationCenter {
    private let status: UNAuthorizationStatus
    private(set) var requestCount = 0

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestCount += 1
        return true
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }
}

@MainActor
private final class RemoteNotificationRegistrarMock: RemoteNotificationRegistrar {
    private(set) var registrationRequestCount = 0

    func registerForRemoteNotifications() {
        registrationRequestCount += 1
    }
}

private struct APNsRegistrationAPICalls: Equatable, Sendable {
    let registeredTokens: [String]
    let unregisteredTokens: [String]
}

private enum APNsRegistrationAPIEvent: Equatable, Sendable {
    case registerFailed(String)
    case registered(String)
    case unregisterStarted(String)
    case unregisterFinished(String)
    case unregisterFailed(String)
}

private enum APNsRegistrationAPIMockError: Error {
    case registerFailed
    case unregisterFailed
}

private actor APNsRegistrationAPIMock: APNsRegistrationAPIProtocol {
    private var registeredTokens: [String] = []
    private var unregisteredTokens: [String] = []
    private var recordedEvents: [APNsRegistrationAPIEvent] = []
    private var currentBoundToken: String?
    private let delaysRegister: Bool
    private let delaysUnregister: Bool
    private var registerFailuresRemaining: Int
    private let failsUnregister: Bool
    private var registerStarted = false
    private var registerReleaseRequested = false
    private var registerReleaseContinuation: CheckedContinuation<Void, Never>?
    private var unregisterStarted = false
    private var unregisterReleaseRequested = false
    private var unregisterReleaseContinuation: CheckedContinuation<Void, Never>?

    init(
        initialBoundToken: String? = nil,
        delaysRegister: Bool = false,
        delaysUnregister: Bool = false,
        registerFailureCount: Int = 0,
        failsUnregister: Bool = false
    ) {
        currentBoundToken = initialBoundToken
        self.delaysRegister = delaysRegister
        self.delaysUnregister = delaysUnregister
        registerFailuresRemaining = registerFailureCount
        self.failsUnregister = failsUnregister
    }

    func register(deviceToken: String) async throws {
        registeredTokens.append(deviceToken)
        registerStarted = true
        if delaysRegister, !registerReleaseRequested {
            await withCheckedContinuation { continuation in
                registerReleaseContinuation = continuation
            }
        }
        if registerFailuresRemaining > 0 {
            registerFailuresRemaining -= 1
            recordedEvents.append(.registerFailed(deviceToken))
            throw APNsRegistrationAPIMockError.registerFailed
        }
        recordedEvents.append(.registered(deviceToken))
        currentBoundToken = deviceToken
    }

    func unregister(deviceToken: String) async throws {
        unregisteredTokens.append(deviceToken)
        recordedEvents.append(.unregisterStarted(deviceToken))
        unregisterStarted = true
        if delaysUnregister, !unregisterReleaseRequested {
            await withCheckedContinuation { continuation in
                unregisterReleaseContinuation = continuation
            }
        }
        if failsUnregister {
            recordedEvents.append(.unregisterFailed(deviceToken))
            throw APNsRegistrationAPIMockError.unregisterFailed
        }
        if currentBoundToken == deviceToken {
            currentBoundToken = nil
        }
        recordedEvents.append(.unregisterFinished(deviceToken))
    }

    func calls() -> APNsRegistrationAPICalls {
        APNsRegistrationAPICalls(
            registeredTokens: registeredTokens,
            unregisteredTokens: unregisteredTokens
        )
    }

    func events() -> [APNsRegistrationAPIEvent] {
        recordedEvents
    }

    func boundToken() -> String? {
        currentBoundToken
    }

    func waitUntilRegisterStarts() async -> Bool {
        for _ in 0..<200 {
            if registerStarted { return true }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return registerStarted
    }

    func releaseRegister() {
        registerReleaseRequested = true
        registerReleaseContinuation?.resume()
        registerReleaseContinuation = nil
    }

    func waitUntilUnregisterStarts() async -> Bool {
        for _ in 0..<200 {
            if unregisterStarted { return true }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return unregisterStarted
    }

    func releaseUnregister() {
        unregisterReleaseRequested = true
        unregisterReleaseContinuation?.resume()
        unregisterReleaseContinuation = nil
    }
}

private struct NotificationAPICallCounts: Equatable, Sendable {
    let list: Int
    let count: Int
    let friendCount: Int

    static let zero = NotificationAPICallCounts(list: 0, count: 0, friendCount: 0)
}

private actor NotificationAPIMock: NotificationAPIProtocol {
    private let page: PageResponse<NotificationDTO>
    private var listCalls = 0
    private var countCalls = 0
    private var friendCountCalls = 0

    init(page: PageResponse<NotificationDTO>) {
        self.page = page
    }

    func notifications(page: Int, size: Int) async throws -> PageResponse<NotificationDTO> {
        listCalls += 1
        return self.page
    }

    func unreadNotifications() async throws -> [NotificationDTO] {
        self.page.content.filter { !$0.isRead }
    }

    func count() async throws -> NotificationCountDTO {
        countCalls += 1
        return NotificationCountDTO(unreadCount: 1, totalCount: 1)
    }

    func friendRequestCount() async throws -> Int {
        friendCountCalls += 1
        return 2
    }

    func markAsRead(id: NotificationID) async throws -> NotificationDTO {
        try #require(page.content.first)
    }

    func markAllAsRead() async throws -> Int { 0 }

    func delete(id: NotificationID) async throws {}

    func deleteAllRead() async throws -> Int { 0 }

    func callCounts() -> NotificationAPICallCounts {
        NotificationAPICallCounts(
            list: listCalls,
            count: countCalls,
            friendCount: friendCountCalls
        )
    }
}
