import Combine
import Foundation
import UIKit
import UserNotifications

nonisolated protocol APNsRegistrationAPIProtocol: Sendable {
    func register(deviceToken: String) async throws
    func unregister(deviceToken: String) async throws
}

nonisolated struct APNsRegistrationAPI: APNsRegistrationAPIProtocol {
    private struct DeviceTokenRequest: Encodable, Sendable {
        let deviceToken: String
        let sandbox: Bool
    }

    private struct SuccessResponse: Decodable, Sendable {
        let success: Bool
    }

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func register(deviceToken: String) async throws {
        let _: SuccessResponse = try await client.request(
            "auth/push/apns/register",
            method: .post,
            body: DeviceTokenRequest(deviceToken: deviceToken, sandbox: Self.usesSandbox)
        )
    }

    func unregister(deviceToken: String) async throws {
        let _: SuccessResponse = try await client.request(
            "auth/push/apns/unregister",
            method: .post,
            body: DeviceTokenRequest(deviceToken: deviceToken, sandbox: Self.usesSandbox)
        )
    }

    private static var usesSandbox: Bool {
#if DEBUG
        true
#else
        false
#endif
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
final class APNsRegistrationManager: ObservableObject {
    static let shared = APNsRegistrationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var registrationState: APNsRegistrationState = .idle
    @Published private(set) var isEnabled: Bool
    @Published var showsPermissionPreprompt = false

    private static let storedTokenKey = "dutypark.apns.device-token"
    private static let enabledPreferenceKey = "dp-push-enabled"
    private let api: any APNsRegistrationAPIProtocol
    private let notificationCenter: any NotificationAuthorizationCenter
    private let defaults: UserDefaults
    private var hasRequestedRemoteRegistration = false

    init(
        api: any APNsRegistrationAPIProtocol = APNsRegistrationAPI(),
        notificationCenter: any NotificationAuthorizationCenter = UNUserNotificationCenter.current(),
        defaults: UserDefaults = .standard
    ) {
        self.api = api
        self.notificationCenter = notificationCenter
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Self.enabledPreferenceKey) == nil
            ? true
            : defaults.bool(forKey: Self.enabledPreferenceKey)
    }

    /// Displays Dutypark's explanation before iOS presents its one-time permission prompt.
    func requestPermission() {
        setEnabled(true)
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

    /// Call on sign-in and foreground resume. It never asks for permission by itself.
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

    /// Called from the first authenticated root without presenting the one-time system prompt.
    func activateForAuthenticatedSession() async {
        await resumeRegistration()
    }

    private func registerWithSystemIfNeeded() {
        guard !hasRequestedRemoteRegistration else { return }
        hasRequestedRemoteRegistration = true
        UIApplication.shared.registerForRemoteNotifications()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledPreferenceKey)
    }

    /// Call before logout while the authenticated cookie is still available.
    func unregister() async {
        guard let token = defaults.string(forKey: Self.storedTokenKey) else { return }
        do {
            try await api.unregister(deviceToken: token)
            defaults.removeObject(forKey: Self.storedTokenKey)
            registrationState = .idle
        } catch {
            registrationState = .failed
        }
    }

    func completeAccountDeletionCleanup() async {
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
        let token = Self.hexString(for: deviceToken)
        registrationState = .registering
        do {
            try await api.register(deviceToken: token)
            defaults.set(token, forKey: Self.storedTokenKey)
            registrationState = .registered
        } catch {
            registrationState = .failed
        }
    }

    func didFailToRegisterForRemoteNotifications() {
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
        pendingNotificationID = Self.notificationID(from: userInfo)
    }

    func receive(notificationID: NotificationID?) {
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
        completionHandler([.banner, .sound, .badge])
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
