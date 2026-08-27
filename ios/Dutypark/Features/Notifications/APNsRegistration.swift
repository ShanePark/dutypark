import Combine
import Foundation
import UIKit
import UserNotifications

nonisolated protocol APNsRegistrationAPIProtocol: Sendable {
    func register(deviceToken: String) async throws
    func unregister(deviceToken: String) async throws
}

nonisolated enum EmbeddedProvisioningProfileState: Sendable {
    case absent
    case unreadable
    case loaded(Data)
}

nonisolated enum APNsEnvironmentResolutionError: Error, Equatable {
    case invalidEmbeddedProvisioningProfile
}

nonisolated enum APNsEnvironment {
    static var usesSandbox: Bool {
        get throws {
            try usesSandbox(
                profileState: embeddedProvisioningProfileState(),
                fallback: compileConfigurationUsesSandbox
            )
        }
    }

    static func usesSandbox(
        profileState: EmbeddedProvisioningProfileState,
        fallback: Bool
    ) throws -> Bool {
        switch profileState {
        case .absent:
            return fallback
        case .unreadable:
            throw APNsEnvironmentResolutionError.invalidEmbeddedProvisioningProfile
        case let .loaded(profileData):
            guard let entitlementValue = entitlementValue(profileData: profileData) else {
                throw APNsEnvironmentResolutionError.invalidEmbeddedProvisioningProfile
            }
            switch entitlementValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "production":
                return false
            case "development":
                return true
            default:
                throw APNsEnvironmentResolutionError.invalidEmbeddedProvisioningProfile
            }
        }
    }

    private static var compileConfigurationUsesSandbox: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    private static func embeddedProvisioningProfileState(
        bundle: Bundle = .main
    ) -> EmbeddedProvisioningProfileState {
        guard let profileURL = bundle.url(forResource: "embedded", withExtension: "mobileprovision") else {
            return .absent
        }
        guard let profileData = try? Data(contentsOf: profileURL) else {
            return .unreadable
        }
        return .loaded(profileData)
    }

    static func entitlementValue(profileData: Data) -> String? {
        guard let plistStart = profileData.range(of: Data("<?xml".utf8))?.lowerBound,
              let plistEndRange = profileData.range(of: Data("</plist>".utf8), options: .backwards)
        else {
            return nil
        }
        let plistEnd = plistEndRange.upperBound
        guard plistStart < plistEnd,
              let profile = try? PropertyListSerialization.propertyList(
                from: profileData[plistStart..<plistEnd],
                format: nil
              ) as? [String: Any],
              let entitlements = profile["Entitlements"] as? [String: Any]
        else {
            return nil
        }
        return entitlements["aps-environment"] as? String
    }
}

nonisolated struct APNsRegistrationAPI: APNsRegistrationAPIProtocol {
    private struct RegistrationRequest: Encodable, Sendable {
        let deviceToken: String
        let sandbox: Bool
    }

    private struct UnregistrationRequest: Encodable, Sendable {
        let deviceToken: String
    }

    private struct SuccessResponse: Decodable, Sendable {
        let success: Bool
    }

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func register(deviceToken: String) async throws {
        let sandbox = try APNsEnvironment.usesSandbox
        let _: SuccessResponse = try await client.request(
            "auth/push/apns/register",
            method: .post,
            body: RegistrationRequest(deviceToken: deviceToken, sandbox: sandbox),
            authenticationFailureHandling: .deferred
        )
    }

    func unregister(deviceToken: String) async throws {
        let _: SuccessResponse = try await client.request(
            "auth/push/apns/unregister",
            method: .post,
            body: UnregistrationRequest(deviceToken: deviceToken),
            retryingAfterUnauthorized: false
        )
    }
}

enum APNsRegistrationState: Equatable {
    case idle
    case registering
    case registered
    case failed
}

@MainActor
protocol NotificationAuthorizationCenter: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
}

extension UNUserNotificationCenter: NotificationAuthorizationCenter {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

@MainActor
protocol RemoteNotificationRegistrar: AnyObject {
    func registerForRemoteNotifications()
}

extension UIApplication: RemoteNotificationRegistrar {}

private actor APNsRegistrationAPIOperationLock {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func perform(_ operation: @Sendable () async throws -> Void) async throws {
        await acquire()
        defer { release() }
        try await operation()
    }

    private func acquire() async {
        guard isLocked else {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }
        waiters.removeFirst().resume()
    }
}

private enum APNsRegistrationOperationError: Error {
    case unregisterFailed
}

@MainActor
final class APNsRegistrationManager: ObservableObject {
    static let shared = APNsRegistrationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var registrationState: APNsRegistrationState = .idle
    @Published private(set) var isEnabled: Bool
    @Published var showsPermissionPreprompt = false

    var isToggleOn: Bool {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return false
        }
        return isEnabled
    }

    private static let storedTokenKey = "dutypark.apns.device-token"
    private static let enabledPreferenceKey = "dp-push-enabled"
    private static let permissionPrepromptShownKey = "dp-push-permission-preprompt-shown"
    private let api: any APNsRegistrationAPIProtocol
    private let notificationCenter: any NotificationAuthorizationCenter
    private let remoteNotificationRegistrar: any RemoteNotificationRegistrar
    private let defaults: UserDefaults
    private let apiOperationLock = APNsRegistrationAPIOperationLock()
    private var hasRequestedRemoteRegistration = false
    private var hasShownPermissionPreprompt = false
    private var registrationAttempt = 0
    private var pendingDeviceToken: String?

    init(
        api: any APNsRegistrationAPIProtocol = APNsRegistrationAPI(),
        notificationCenter: any NotificationAuthorizationCenter = UNUserNotificationCenter.current(),
        remoteNotificationRegistrar: any RemoteNotificationRegistrar = UIApplication.shared,
        defaults: UserDefaults = .standard
    ) {
        self.api = api
        self.notificationCenter = notificationCenter
        self.remoteNotificationRegistrar = remoteNotificationRegistrar
        self.defaults = defaults
        hasShownPermissionPreprompt = defaults.bool(forKey: Self.permissionPrepromptShownKey)
        isEnabled = defaults.object(forKey: Self.enabledPreferenceKey) == nil
            ? true
            : defaults.bool(forKey: Self.enabledPreferenceKey)
    }

    /// Displays Dutypark's explanation before iOS presents its one-time permission prompt.
    func requestPermission() {
        setEnabled(true)
        markPermissionPrepromptAsShown()
        showsPermissionPreprompt = true
    }

    func continuePermissionRequest() async {
        showsPermissionPreprompt = false
        do {
            _ = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
            if authorizationStatus == .authorized || authorizationStatus == .provisional {
                registerWithSystemIfNeeded()
            }
        } catch {
            registrationState = .failed
        }
    }

    /// Call on foreground resume. It never asks for permission by itself.
    func resumeRegistration() async {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            return
        }
#endif
        await refreshAuthorizationStatus()
        guard isEnabled else { return }
        if authorizationStatus == .authorized || authorizationStatus == .provisional {
            registerWithSystemIfNeeded()
        }
    }

    /// Called once when the first authenticated root becomes available.
    func activateForAuthenticatedSession() async {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            return
        }
#endif
        await refreshAuthorizationStatus()
        guard isEnabled else { return }

        if authorizationStatus == .notDetermined {
            guard !hasShownPermissionPreprompt else { return }
            markPermissionPrepromptAsShown()
            showsPermissionPreprompt = true
            return
        }

        if authorizationStatus == .authorized || authorizationStatus == .provisional {
            registerWithSystemIfNeeded()
        }
    }

    private func markPermissionPrepromptAsShown() {
        hasShownPermissionPreprompt = true
        defaults.set(true, forKey: Self.permissionPrepromptShownKey)
    }

    private func registerWithSystemIfNeeded() {
        guard !hasRequestedRemoteRegistration else { return }
        hasRequestedRemoteRegistration = true
        remoteNotificationRegistrar.registerForRemoteNotifications()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledPreferenceKey)
        if !enabled {
            hasRequestedRemoteRegistration = false
        }
    }

    /// Call before logout while the authenticated cookie is still available.
    func unregister() async {
        hasRequestedRemoteRegistration = false
        registrationAttempt &+= 1
        let currentUnregisterAttempt = registrationAttempt
        let storedToken = defaults.string(forKey: Self.storedTokenKey)
        let pendingToken = pendingDeviceToken
        let tokens = [storedToken, pendingToken]
            .compactMap { $0 }
            .reduce(into: [String]()) { tokens, token in
                if !tokens.contains(token) {
                    tokens.append(token)
                }
            }
        guard !tokens.isEmpty else {
            registrationState = .idle
            return
        }
        do {
            let api = api
            try await apiOperationLock.perform {
                var unregisterFailed = false
                for token in tokens {
                    do {
                        try await api.unregister(deviceToken: token)
                    } catch {
                        unregisterFailed = true
                    }
                }
                if unregisterFailed {
                    throw APNsRegistrationOperationError.unregisterFailed
                }
            }
            guard registrationAttempt == currentUnregisterAttempt else { return }
            defaults.removeObject(forKey: Self.storedTokenKey)
            if pendingDeviceToken == pendingToken {
                pendingDeviceToken = nil
            }
            registrationState = .idle
        } catch {
            guard registrationAttempt == currentUnregisterAttempt else { return }
            registrationState = .failed
        }
    }

    func completeAccountDeletionCleanup() async {
        registrationAttempt &+= 1
        pendingDeviceToken = nil
        defaults.removeObject(forKey: Self.storedTokenKey)
        hasRequestedRemoteRegistration = false
        registrationState = .idle
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        try? await center.setBadgeCount(0)
        NotificationPushCenter.shared.resetForAccountDeletion()
    }

    func didRegisterForRemoteNotifications(deviceToken: Data) async {
        guard isEnabled else {
            registrationState = .idle
            return
        }
        guard hasRequestedRemoteRegistration else { return }
        let token = Self.hexString(for: deviceToken)
        registrationAttempt &+= 1
        let currentRegistrationAttempt = registrationAttempt
        pendingDeviceToken = token
        registrationState = .registering
        do {
            let api = api
            try await apiOperationLock.perform {
                try await api.register(deviceToken: token)
            }
            guard registrationAttempt == currentRegistrationAttempt else { return }
            pendingDeviceToken = nil
            defaults.set(token, forKey: Self.storedTokenKey)
            registrationState = .registered
        } catch {
            guard registrationAttempt == currentRegistrationAttempt else { return }
            pendingDeviceToken = nil
            hasRequestedRemoteRegistration = false
            registrationState = .failed
        }
    }

    func didFailToRegisterForRemoteNotifications() {
        hasRequestedRemoteRegistration = false
        registrationState = .failed
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await notificationCenter.authorizationStatus()
    }

    nonisolated static func hexString(for data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class NotificationPushCenter: ObservableObject {
    static let shared = NotificationPushCenter()

    @Published private(set) var pendingNotificationID: NotificationID?

    func receive(userInfo: [AnyHashable: Any]) {
        guard let notificationID = Self.notificationID(from: userInfo) else { return }
        pendingNotificationID = notificationID
    }

    func receive(notificationID: NotificationID?) {
        guard let notificationID else { return }
        pendingNotificationID = notificationID
    }

    func consumePendingNotificationID() -> NotificationID? {
        defer { pendingNotificationID = nil }
        return pendingNotificationID
    }

    func resetForAccountDeletion() {
        pendingNotificationID = nil
    }

    nonisolated static func notificationID(from userInfo: [AnyHashable: Any]) -> NotificationID? {
        if let raw = userInfo["notificationId"] as? String {
            return UUID(uuidString: raw)
        }
        if let data = userInfo["data"] as? [String: Any],
           let raw = data["notificationId"] as? String {
            return UUID(uuidString: raw)
        }
        return nil
    }
}

/// Add with `@UIApplicationDelegateAdaptor` in `DutyparkApp` to bridge APNs callbacks.
final class NotificationAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    nonisolated static let foregroundPresentationOptions: UNNotificationPresentationOptions = [
        .banner,
        .list,
        .sound,
        .badge
    ]

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            Task { @MainActor in
                NotificationPushCenter.shared.receive(userInfo: userInfo)
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            await APNsRegistrationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            APNsRegistrationManager.shared.didFailToRegisterForRemoteNotifications()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(Self.foregroundPresentationOptions)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let notificationID = NotificationPushCenter.notificationID(
            from: response.notification.request.content.userInfo
        )
        completionHandler()
        Task { @MainActor in
            NotificationPushCenter.shared.receive(notificationID: notificationID)
        }
    }
}
