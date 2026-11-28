import Foundation
import Combine
import SwiftUI

enum SettingsPreference {
    static let themeKey = "dp-theme"
    static let defaultTheme = AppTheme.system.rawValue
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    /// The language iOS resolved for this app, which the whole UI follows.
    static var current: AppLanguage {
        AppLanguage(rawValue: AppLocalization.locale.identifier) ?? .english
    }

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

nonisolated enum SettingsLoadedSection: Hashable, Sendable {
    case dutyPattern
    case family
    case friends
    case managers
    case managedAccounts
    case sessions
    case policies
}

/// The account and preference screens render different sections, so each one loads
/// only the resources its own sections need. The member profile is always loaded
/// because both screens read it.
nonisolated struct SettingsLoadPlan: Equatable, Sendable {
    var familyMembers = false
    var friends = false
    var managers = false
    var managedAccounts = false
    var sessions = false
    var policies = false
    var dutyPattern = false

    static let all = SettingsLoadPlan(
        familyMembers: true,
        friends: true,
        managers: true,
        managedAccounts: true,
        sessions: true,
        policies: true,
        dutyPattern: true
    )

    var sections: Set<SettingsLoadedSection> {
        var sections: Set<SettingsLoadedSection> = []
        if familyMembers { sections.insert(.family) }
        if friends { sections.insert(.friends) }
        if managers { sections.insert(.managers) }
        if managedAccounts { sections.insert(.managedAccounts) }
        if self.sessions { sections.insert(.sessions) }
        if policies { sections.insert(.policies) }
        if dutyPattern { sections.insert(.dutyPattern) }
        return sections
    }

    /// Policies back the terms and privacy pages that deep links open from Settings.
    static let settings = SettingsLoadPlan(policies: true)

    /// Friends back the calendar visibility audience preview.
    static let myInfo = SettingsLoadPlan(
        familyMembers: true,
        friends: true,
        managers: true,
        managedAccounts: true,
        sessions: true,
        dutyPattern: true
    )
}

@MainActor
final class SettingsViewModel: ObservableObject {
    private let service: SettingsService
    private let contentFilter: ContentFilterStore
    private let hapticCenter: DPHapticCenter
    private let snapshotStore: MyInfoSnapshotStore

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
    @Published private(set) var loadingSections: Set<SettingsLoadedSection> = []
    @Published private(set) var isLoadingMember = false
    @Published var noticeKey: String?
    @Published var noticeIsError = false
    private var snapshotScopeForUpdates: MyInfoSnapshotScope?

    init(
        service: SettingsService = SettingsService(),
        contentFilter: ContentFilterStore = .shared,
        hapticCenter: DPHapticCenter = .shared,
        snapshotStore: MyInfoSnapshotStore = .shared
    ) {
        self.service = service
        self.contentFilter = contentFilter
        self.hapticCenter = hapticCenter
        self.snapshotStore = snapshotStore
    }

    var availableManagers: [MemberPreviewDTO] {
        familyMembers.filter { family in
            guard let id = family.id else { return false }
            return !managers.contains { $0.id == id }
        }
    }

    /// Each section is applied as soon as its own request finishes, so the screen can render
    /// once the member arrives instead of waiting for the slowest request. With a
    /// `snapshotScope`, the last snapshot for the same signed-in session is shown first while
    /// everything refreshes in the background.
    func load(_ plan: SettingsLoadPlan = .all, snapshotScope: MyInfoSnapshotScope? = nil) async {
        guard !isLoading else { return }
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            loadUITestingFixture()
            return
        }
#endif
        isLoading = true
        defer { isLoading = false }
        if member == nil, let snapshotScope, let snapshot = snapshotStore.snapshot(for: snapshotScope) {
            apply(snapshot)
        }

        snapshotScopeForUpdates = snapshotScope
        isLoadingMember = true
        loadingSections = plan.sections
        let service = service
        await withTaskGroup(of: SettingsLoadResult.self) { group in
            group.addTask { await SettingsLoadResult.loadMember(from: service) }
            for section in plan.sections {
                group.addTask { await SettingsLoadResult.load(section, from: service) }
            }
            for await result in group {
                apply(result)
            }
        }
        if let snapshotScope { storeSnapshot(for: snapshotScope) }
    }

    private func apply(_ result: SettingsLoadResult) {
        switch result {
        case .member(let value):
            isLoadingMember = false
            didAttemptMemberLoad = true
            if let value {
                member = value
            } else if member != nil {
                showError("settings.error.load")
                hapticCenter.emit(.error)
            }
        case .family(let value):
            if let value { familyMembers = value }
            finish(.family, loaded: value != nil)
        case .friends(let value):
            if let value { friends = value }
            finish(.friends, loaded: value != nil)
        case .managers(let value):
            if let value { managers = value }
            finish(.managers, loaded: value != nil)
        case .managedAccounts(let value):
            if let value { managedMembers = value }
            finish(.managedAccounts, loaded: value != nil)
        case .sessions(let value):
            if let value { sessions = value }
            finish(.sessions, loaded: value != nil)
        case .policies(let value):
            if let value { policies = value }
            policyLoadFailed = value == nil
            finish(.policies, loaded: value != nil)
        case .dutyPattern(let value):
            if let value { dutyPattern = value }
            dutyPatternLoadFailed = value == nil
            finish(.dutyPattern, loaded: value != nil)
        }
    }

    private func finish(_ section: SettingsLoadedSection, loaded: Bool) {
        loadingSections.remove(section)
        if loaded { loadedSections.insert(section) }
    }

    private func apply(_ snapshot: MyInfoSnapshot) {
        member = snapshot.member
        familyMembers = snapshot.familyMembers
        friends = snapshot.friends
        managers = snapshot.managers
        managedMembers = snapshot.managedMembers
        sessions = snapshot.sessions
        dutyPattern = snapshot.dutyPattern
        loadedSections.formUnion(snapshot.loadedSections)
        didAttemptMemberLoad = true
    }

    /// Only a member that matches the scope is stored, so a response that raced an account
    /// switch can never be shown to a different member.
    private func storeSnapshot(for scope: MyInfoSnapshotScope) {
        guard let member, member.id == scope.memberID else { return }
        snapshotStore.store(
            MyInfoSnapshot(
                member: member,
                familyMembers: familyMembers,
                friends: friends,
                managers: managers,
                managedMembers: managedMembers,
                sessions: sessions,
                dutyPattern: dutyPattern,
                loadedSections: loadedSections.subtracting([.policies])
            ),
            for: scope
        )
    }

    private func refreshSnapshot() {
        guard let snapshotScopeForUpdates else { return }
        storeSnapshot(for: snapshotScopeForUpdates)
    }

    func profilePhotoData() async -> Data? {
        guard let memberID = member?.id else { return nil }
        return try? await service.profilePhotoData(memberID: memberID)
    }

    func reloadMember() async {
        do {
            member = try await service.member()
            refreshSnapshot()
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
        await workResult(
            success: "settings.photo.deleted",
            failure: "settings.photo.deleteFailed"
        ) {
            try await service.deleteProfilePhoto()
            member = member?.replacing(
                hasProfilePhoto: false,
                profilePhotoVersion: (member?.profilePhotoVersion ?? 0) + 1
            )
        }
    }

    func assignManager(_ memberID: Int64) async {
        let assigned = await workResult(success: "settings.manager.assigned") {
            try await service.assignManager(memberID)
        }
        guard assigned else { return }
        if let refreshedManagers = try? await service.managers() {
            managers = refreshedManagers
            refreshSnapshot()
        }
    }

    func unassignManager(_ memberID: Int64) async {
        await work(success: "settings.manager.unassigned") {
            try await service.unassignManager(memberID)
            managers.removeAll { $0.id == memberID }
        }
    }

    /// Returns true only after the server saved the name; an unchanged name is a silent no-op.
    func updateName(_ rawName: String) async -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, SsoSignupNamePolicy.fits(name) else {
            showError("settings.name.invalid")
            hapticCenter.emit(.warning)
            return false
        }
        guard !contentFilter.isBlocked(name) else {
            showError("settings.error.contentFilter")
            hapticCenter.emit(.warning)
            return false
        }
        guard name != member?.name else { return false }
        return await workResult(success: "settings.name.updated", failure: "settings.name.failed") {
            member = try await service.updateName(name)
        }
    }

    func createAuxiliaryAccount(name: String) async {
        guard !contentFilter.isBlocked(name) else {
            showError("settings.error.contentFilter")
            hapticCenter.emit(.warning)
            return
        }
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
            hapticCenter.emit(.success)
        } catch {
            showError("settings.error.generic")
            hapticCenter.emit(.error)
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
            hapticCenter.emit(.success)
        } catch {
            showError("settings.password.failed")
            hapticCenter.emit(.error)
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
            refreshSnapshot()
        } catch {
            dutyPatternLoadFailed = true
            showError("settings.pattern.loadFailed")
            hapticCenter.emit(.error)
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
        guard let member, let id = member.id else { return nil }
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
        failure: String = "settings.error.generic",
        operation: () async throws -> Void
    ) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try await operation()
            refreshSnapshot()
            showNotice(success)
            hapticCenter.emit(.success)
            return true
        } catch {
            showError(failure)
            hapticCenter.emit(.error)
            return false
        }
    }

    func clearNotice() {
        noticeKey = nil
        noticeIsError = false
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
                displayOrder: 1
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

/// Identifies one signed-in session. Every login, account switch and impersonation change
/// starts a new session generation, so a snapshot can never outlive the session it came from.
nonisolated struct MyInfoSnapshotScope: Hashable, Sendable {
    let memberID: MemberID
    let sessionGeneration: UInt64
}

nonisolated struct MyInfoSnapshot: Equatable, Sendable {
    var member: MemberDTO
    var familyMembers: [MemberPreviewDTO]
    var friends: [FriendDTO]
    var managers: [MemberDTO]
    var managedMembers: [MemberDTO]
    var sessions: [SettingsRefreshToken]
    var dutyPattern: DutyPatternDTO?
    var loadedSections: Set<SettingsLoadedSection>
}

/// Keeps only the latest My Info snapshot in memory for instant re-entry.
final class MyInfoSnapshotStore {
    static let shared = MyInfoSnapshotStore()

    private var entry: (scope: MyInfoSnapshotScope, snapshot: MyInfoSnapshot)?

    func snapshot(for scope: MyInfoSnapshotScope) -> MyInfoSnapshot? {
        guard let entry else { return nil }
        guard entry.scope == scope else {
            // Another session or member must never see this data, so drop it.
            self.entry = nil
            return nil
        }
        return entry.snapshot
    }

    func store(_ snapshot: MyInfoSnapshot, for scope: MyInfoSnapshotScope) {
        entry = (scope, snapshot)
    }
}

/// Fetches one My Info resource off the main actor. Sessions are sorted here, once, so the
/// view never sorts or parses dates while rendering.
nonisolated enum SettingsLoadResult: Sendable {
    case member(MemberDTO?)
    case family([MemberPreviewDTO]?)
    case friends([FriendDTO]?)
    case managers([MemberDTO]?)
    case managedAccounts([MemberDTO]?)
    case sessions([SettingsRefreshToken]?)
    case policies(CurrentPoliciesDTO?)
    case dutyPattern(DutyPatternDTO?)

    static func loadMember(from service: SettingsService) async -> Self {
        .member(try? await service.member())
    }

    static func load(_ section: SettingsLoadedSection, from service: SettingsService) async -> Self {
        switch section {
        case .family: .family(try? await service.familyMembers())
        case .friends: .friends(try? await service.friends())
        case .managers: .managers(try? await service.managers())
        case .managedAccounts: .managedAccounts(try? await service.managedMembers())
        case .sessions: .sessions((try? await service.sessions()).map(SettingsSessionFormatter.sorted))
        case .policies: .policies(try? await service.policies())
        case .dutyPattern: .dutyPattern(try? await service.dutyPattern())
        }
    }
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
