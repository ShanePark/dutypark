import Foundation
import Combine

enum SettingsPreference {
    static let languageKey = "dp-language"
    static let themeKey = "dp-theme"
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"
    case japanese = "ja"
    case chinese = "zh-Hans"
    case spanish = "es"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        case .japanese: "日本語"
        case .chinese: "简体中文"
        case .spanish: "Español"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: String {
        rawValue
    }
}

enum SettingsLoadedSection: Hashable {
    case family
    case friends
    case managers
    case managedAccounts
    case sessions
    case policies
}

@MainActor
final class SettingsViewModel: ObservableObject {
    private let service: SettingsService

    @Published private(set) var member: MemberDTO?
    @Published private(set) var familyMembers: [MemberPreviewDTO] = []
    @Published private(set) var friends: [FriendDTO] = []
    @Published private(set) var managers: [MemberDTO] = []
    @Published private(set) var managedMembers: [MemberDTO] = []
    @Published private(set) var sessions: [SettingsRefreshToken] = []
    @Published private(set) var policies: CurrentPoliciesDTO?
    @Published private(set) var policyLoadFailed = false
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false
    @Published private(set) var didAttemptMemberLoad = false
    @Published private(set) var loadedSections: Set<SettingsLoadedSection> = []
    @Published var noticeKey: String?
    @Published var noticeIsError = false

    init(service: SettingsService = SettingsService()) {
        self.service = service
    }

    var availableManagers: [MemberPreviewDTO] {
        familyMembers.filter { family in
            guard let id = family.id else { return false }
            return !managers.contains { $0.id == id }
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        async let loadedMember = try? service.member()
        async let loadedFamily = try? service.familyMembers()
        async let loadedFriends = try? service.friends()
        async let loadedManagers = try? service.managers()
        async let loadedManaged = try? service.managedMembers()
        async let loadedSessions = try? service.sessions()
        async let loadedPolicies = try? service.policies()
        let values = await (
            loadedMember,
            loadedFamily,
            loadedFriends,
            loadedManagers,
            loadedManaged,
            loadedSessions,
            loadedPolicies
        )
        didAttemptMemberLoad = true
        if let value = values.0 { member = value }
        if let value = values.1 {
            familyMembers = value
            loadedSections.insert(.family)
        }
        if let value = values.2 {
            friends = value
            loadedSections.insert(.friends)
        }
        if let value = values.3 {
            managers = value
            loadedSections.insert(.managers)
        }
        if let value = values.4 {
            managedMembers = value
            loadedSections.insert(.managedAccounts)
        }
        if let value = values.5 {
            sessions = value
            loadedSections.insert(.sessions)
        }
        if let value = values.6 {
            policies = value
            loadedSections.insert(.policies)
            policyLoadFailed = false
        } else {
            policyLoadFailed = true
        }
        if values.0 == nil, member != nil {
            showError("settings.error.load")
        }
    }

    func profilePhotoData() async -> Data? {
        guard let memberID = member?.id else { return nil }
        return try? await service.profilePhotoData(memberID: memberID)
    }

    func reloadMember() async {
        do {
            member = try await service.member()
        } catch {
            showError("settings.error.load")
        }
    }

    func reloadPolicies() async {
        do {
            policies = try await service.policies()
            loadedSections.insert(.policies)
            policyLoadFailed = false
        } catch {
            policyLoadFailed = true
        }
    }

    func updateVisibility(_ visibility: Visibility) async {
        guard let memberID = member?.id else { return }
        await work(success: "settings.visibility.updated") {
            try await service.updateVisibility(memberID: memberID, visibility: visibility)
            member = try await service.member()
        }
    }

    func uploadProfilePhoto(_ jpegData: Data) async -> Bool {
        await workResult(success: "settings.photo.uploaded") {
            try await service.uploadProfilePhoto(jpegData: jpegData)
            member = try await service.member()
        }
    }

    func deleteProfilePhoto() async -> Bool {
        await workResult(success: "settings.photo.deleted") {
            try await service.deleteProfilePhoto()
            member = try await service.member()
        }
    }

    func assignManager(_ memberID: Int64) async {
        await work(success: "settings.manager.assigned") {
            try await service.assignManager(memberID)
            managers = try await service.managers()
        }
    }

    func unassignManager(_ memberID: Int64) async {
        await work(success: "settings.manager.unassigned") {
            try await service.unassignManager(memberID)
            managers = try await service.managers()
        }
    }

    func createAuxiliaryAccount(name: String) async {
        await work(success: "settings.auxiliary.created") {
            _ = try await service.createAuxiliaryAccount(name: name)
            managedMembers = try await service.managedMembers()
        }
    }

    func impersonate(memberID: Int64) async throws {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await service.impersonate(memberID: memberID)
        } catch {
            showError("settings.error.generic")
            throw error
        }
    }

    func restoreImpersonation() async throws {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await service.restoreImpersonation()
        } catch {
            showError("settings.error.generic")
            throw error
        }
    }

    func changePassword(
        memberID: Int64,
        currentPassword: String,
        newPassword: String
    ) async throws {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await service.changePassword(
                PasswordChangeRequest(
                    memberId: memberID,
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
            )
        } catch {
            showError("settings.password.failed")
            throw error
        }
    }

    func revokeSession(id: Int64) async {
        guard sessions.first(where: { $0.id == id })?.isCurrentLogin != true else {
            return
        }
        await work(success: "settings.sessions.revoked") {
            try await service.revokeSession(id: id)
            sessions = try await service.sessions()
        }
    }

    func revokeOtherSessions() async {
        guard sessions.contains(where: { $0.isCurrentLogin != true }) else {
            showNotice("settings.sessions.noOthers")
            return
        }
        await work(success: "settings.sessions.othersRevoked") {
            _ = try await service.revokeOtherSessions()
            sessions = try await service.sessions()
        }
    }

    func profilePhotoURL() -> URL? {
        guard let member, let id = member.id, member.hasProfilePhoto else { return nil }
        return service.profilePhotoURL(memberID: id, version: member.profilePhotoVersion)
    }

    private func work(
        success: String,
        operation: () async throws -> Void
    ) async {
        _ = await workResult(success: success, operation: operation)
    }

    private func workResult(
        success: String,
        operation: () async throws -> Void
    ) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try await operation()
            showNotice(success)
            return true
        } catch {
            showError("settings.error.generic")
            return false
        }
    }

    private func showNotice(_ key: String) {
        noticeIsError = false
        noticeKey = key
    }

    private func showError(_ key: String) {
        noticeIsError = true
        noticeKey = key
    }
}
