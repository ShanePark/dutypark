import Foundation
import Combine
import SwiftUI

enum SettingsPreference {
    static let languageKey = "dp-language"
    static let themeKey = "dp-theme"
    static let defaultTheme = AppTheme.system.rawValue
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var titleKey: String {
        "settings.theme.\(rawValue)"
    }

    var currentDescriptionKey: String {
        "settings.theme.current.\(rawValue)"
    }
}

enum SettingsLoadedSection: Hashable {
    case dutyPattern
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
    @Published private(set) var dutyPattern: DutyPatternDTO?
    @Published private(set) var dutyPatternLoadFailed = false
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
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            loadUITestingFixture()
            return
        }
#endif
        isLoading = true
        defer { isLoading = false }

        async let loadedMember = try? service.member()
        async let loadedFamily = try? service.familyMembers()
        async let loadedFriends = try? service.friends()
        async let loadedManagers = try? service.managers()
        async let loadedManaged = try? service.managedMembers()
        async let loadedSessions = try? service.sessions()
        async let loadedPolicies = try? service.policies()
        async let loadedPattern = try? service.dutyPattern()
        let values = await (
            loadedMember,
            loadedFamily,
            loadedFriends,
            loadedManagers,
            loadedManaged,
            loadedSessions,
            loadedPolicies,
            loadedPattern
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
        if let value = values.7 {
            dutyPattern = value
            dutyPatternLoadFailed = false
            loadedSections.insert(.dutyPattern)
        } else {
            dutyPatternLoadFailed = true
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

    @discardableResult
    func revokeSession(id: Int64) async -> Bool {
        guard let token = sessions.first(where: { $0.id == id }),
              SettingsSessionPolicy.canRevoke(token)
        else {
            return false
        }
        return await workResult(success: "settings.sessions.revoked") {
            try await service.revokeSession(id: id)
            sessions = try await service.sessions()
        }
    }

    @discardableResult
    func revokeOtherSessions() async -> Bool {
        guard sessions.contains(where: SettingsSessionPolicy.canRevoke) else {
            showNotice("settings.sessions.noOthers")
            return false
        }
        return await workResult(success: "settings.sessions.othersRevoked") {
            _ = try await service.revokeOtherSessions()
            sessions = try await service.sessions()
        }
    }

    func reloadDutyPattern() async {
        dutyPatternLoadFailed = false
        do {
            dutyPattern = try await service.dutyPattern()
            loadedSections.insert(.dutyPattern)
        } catch {
            dutyPatternLoadFailed = true
            showError("settings.pattern.loadFailed")
        }
    }

    func saveDutyPattern(days: [DutyPatternDayUpdateDTO], holidayOff: Bool) async -> Bool {
        await workResult(success: "settings.pattern.saved") {
            dutyPattern = try await service.updateDutyPattern(
                DutyPatternUpdateDTO(days: days, holidayOff: holidayOff)
            )
            loadedSections.insert(.dutyPattern)
        }
    }

    func deleteDutyPattern() async -> Bool {
        await workResult(success: "settings.pattern.deleted") {
            try await service.deleteDutyPattern()
            dutyPattern = try await service.dutyPattern()
            loadedSections.insert(.dutyPattern)
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

    func showNotice(_ key: String) {
        noticeIsError = false
        noticeKey = key
    }

    private func showError(_ key: String) {
        noticeIsError = true
        noticeKey = key
    }

#if DEBUG
    private func loadUITestingFixture() {
        let includesSocialConnections = ProcessInfo.processInfo.arguments.contains(
            "-ui-testing-social-connections"
        )
        let includesAppleSocialConnection = ProcessInfo.processInfo.arguments.contains(
            "-ui-testing-apple-social-connection"
        )
        member = MemberDTO(
            id: 1,
            name: "Test",
            email: "test@duty.park",
            teamId: 1,
            team: "Dutypark",
            calendarVisibility: .friends,
            kakaoId: "connected",
            naverId: includesSocialConnections ? "connected" : nil,
            appleId: includesAppleSocialConnection ? "connected" : nil,
            hasPassword: true,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
        familyMembers = []
        friends = [
            FriendDTO(
                id: 2,
                name: "Alex",
                teamId: 1,
                team: "Dutypark",
                hasProfilePhoto: false,
                profilePhotoVersion: 0,
                isFamily: true,
                pinOrder: 1
            )
        ]
        managers = []
        managedMembers = []
        sessions = [
            SettingsRefreshToken(
                memberName: "Test",
                memberId: 1,
                validUntil: "2026-09-12",
                createdDate: "2026-08-01",
                lastUsed: "2026-08-12",
                remoteAddr: "127.0.0.1",
                id: 1,
                userAgent: .init(os: "iOS", browser: "Dutypark", device: "iPhone"),
                isCurrentLogin: true
            )
        ]
        dutyPattern = DutyPatternDTO(
            configurable: true,
            reason: nil,
            dutyTypes: [DutyPatternDutyTypeDTO(id: 1, name: "Day", color: "#3B82F6")],
            pattern: DutyPatternDetailsDTO(
                days: [
                    DutyPatternDayDTO(
                        weekday: .monday,
                        dutyType: DutyPatternDutyTypeDTO(id: 1, name: "Day", color: "#3B82F6")
                    ),
                    DutyPatternDayDTO(
                        weekday: .wednesday,
                        dutyType: DutyPatternDutyTypeDTO(id: 1, name: "Day", color: "#3B82F6")
                    ),
                    DutyPatternDayDTO(
                        weekday: .friday,
                        dutyType: DutyPatternDutyTypeDTO(id: 1, name: "Day", color: "#3B82F6")
                    ),
                ],
                holidayOff: true,
                effectiveFrom: DateOnly(rawValue: "2026-08-01")
            )
        )
        dutyPatternLoadFailed = false
        didAttemptMemberLoad = true
        loadedSections = [.family, .friends, .managers, .managedAccounts, .sessions, .dutyPattern]
    }
#endif
}
