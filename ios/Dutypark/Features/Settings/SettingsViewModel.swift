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
            member = member?.replacing(calendarVisibility: visibility)
        }
    }

    func uploadProfilePhoto(_ jpegData: Data) async -> Bool {
        await workResult(success: "settings.photo.uploaded") {
            try await service.uploadProfilePhoto(jpegData: jpegData)
            member = member?.replacing(
                hasProfilePhoto: true,
                profilePhotoVersion: (member?.profilePhotoVersion ?? 0) + 1
            )
        }
    }

    func deleteProfilePhoto() async -> Bool {
        await workResult(success: "settings.photo.deleted") {
            try await service.deleteProfilePhoto()
            member = member?.replacing(
                hasProfilePhoto: false,
                profilePhotoVersion: (member?.profilePhotoVersion ?? 0) + 1
            )
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
            managers.removeAll { $0.id == memberID }
        }
    }

    func createAuxiliaryAccount(name: String) async {
        await work(success: "settings.auxiliary.created") {
            let created = try await service.createAuxiliaryAccount(name: name)
            managedMembers.append(created)
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
            sessions.removeAll { $0.id == id }
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
            sessions.removeAll(where: SettingsSessionPolicy.canRevoke)
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
            if let current = dutyPattern {
                dutyPattern = DutyPatternDTO(
                    configurable: current.configurable,
                    reason: current.reason,
                    dutyTypes: current.dutyTypes,
                    pattern: nil
                )
            }
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
        let includesHiddenDutyPattern = ProcessInfo.processInfo.arguments.contains(
            "-ui-testing-hidden-duty-pattern"
        )
        let includesLongFormPolicies = ProcessInfo.processInfo.arguments.contains(
            "-ui-testing-long-form-policies"
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
        let visibleDutyType = DutyPatternDutyTypeDTO(
            id: 1,
            name: includesHiddenDutyPattern ? "주간" : "Day",
            color: "#3B82F6"
        )
        let patternDays: [DutyPatternDayDTO] = includesHiddenDutyPattern
            ? [
                DutyPatternDayDTO(weekday: .monday, dutyType: visibleDutyType),
                DutyPatternDayDTO(
                    weekday: .sunday,
                    dutyType: DutyPatternDutyTypeDTO(id: 8, name: "야간", color: "#312E81")
                ),
            ]
            : [
                DutyPatternDayDTO(weekday: .monday, dutyType: visibleDutyType),
                DutyPatternDayDTO(weekday: .wednesday, dutyType: visibleDutyType),
                DutyPatternDayDTO(weekday: .friday, dutyType: visibleDutyType),
            ]
        dutyPattern = DutyPatternDTO(
            configurable: true,
            reason: nil,
            dutyTypes: [visibleDutyType],
            pattern: DutyPatternDetailsDTO(
                days: patternDays,
                holidayOff: true,
                effectiveFrom: DateOnly(rawValue: "2026-08-01")
            )
        )
        dutyPatternLoadFailed = false
        if includesLongFormPolicies {
            policies = CurrentPoliciesDTO(
                terms: SettingsLongFormPolicyFixture.terms,
                privacy: SettingsLongFormPolicyFixture.privacy
            )
        }
        didAttemptMemberLoad = true
        loadedSections = [.family, .friends, .managers, .managedAccounts, .sessions, .dutyPattern]
        if includesLongFormPolicies {
            loadedSections.insert(.policies)
        }
    }
#endif
}

#if DEBUG
nonisolated enum SettingsLongFormPolicyFixture {
    static let terms = PolicyDTO(
        policyType: .terms,
        version: "2026-08-14",
        content: """
        # Dutypark 이용약관

        시행일: 2026-08-14

        ## 제1조 목적과 적용 범위

        Dutypark 웹과 iOS 앱에서 제공하는 일정 및 협업 기능의 이용 조건을 안내합니다.

        1. 이용자는 정확한 계정 정보를 제공해야 합니다.
        2. 이용자는 비밀번호와 로그인 세션을 안전하게 관리해야 합니다.
        3. 선택 기능은 설정에서 언제든 해제할 수 있습니다.
        """,
        effectiveDate: DateOnly(rawValue: "2026-08-14")
    )

    static let privacy = PolicyDTO(
        policyType: .privacy,
        version: "2026-08-15",
        content: """
        # 개인정보 처리방침

        시행일: 2026-08-15

        ## 수집 정보와 이용 목적

        | 구분 | 처리 정보 | 이용 목적 |
        | --- | --- | --- |
        | 계정 | 이름, 회원 식별자와 로그인 세션 | 로그인과 계정 관리 |
        | 일정 | 날짜와 사용자가 입력한 긴 일정 내용 | 캘린더 및 공유 기능 제공 |
        """,
        effectiveDate: DateOnly(rawValue: "2026-08-15")
    )

    static let ai = PolicyDTO(
        policyType: .aiScheduleParsing,
        version: "2026-08-14",
        content: """
        # AI 일정 시간 자동 인식 선택 동의 안내

        시행일: 2026-08-14

        ## 1. 이용 목적

        Dutypark는 이용자가 선택한 경우 일정 문구에서 시작 시간과 종료 시간을 인식하기 위해 필요한 일정 날짜와 일정 내용 텍스트만 외부 AI 처리 서비스로 전송합니다.

        ## 2. 선택 동의와 철회

        1. 이 동의는 선택 사항입니다.
        2. 설정에서 언제든 동의를 철회할 수 있습니다.
        """,
        effectiveDate: DateOnly(rawValue: "2026-08-14")
    )
}
#endif

private extension MemberDTO {
    func replacing(
        calendarVisibility: Visibility? = nil,
        hasProfilePhoto: Bool? = nil,
        profilePhotoVersion: Int64? = nil
    ) -> MemberDTO {
        MemberDTO(
            id: id,
            name: name,
            email: email,
            teamId: teamId,
            team: team,
            calendarVisibility: calendarVisibility ?? self.calendarVisibility,
            kakaoId: kakaoId,
            naverId: naverId,
            appleId: appleId,
            hasPassword: hasPassword,
            hasProfilePhoto: hasProfilePhoto ?? self.hasProfilePhoto,
            profilePhotoVersion: profilePhotoVersion ?? self.profilePhotoVersion
        )
    }
}
