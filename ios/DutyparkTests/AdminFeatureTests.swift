import Foundation
import Testing
@testable import Dutypark

@Suite("Admin feature")
struct AdminFeatureTests {
    @Test("Admin menu destinations are completely hidden from non-admin members")
    func adminMenuVisibility() {
        #expect(AdminMenuDestination.visibleDestinations(isAdmin: false).isEmpty)
        #expect(AdminMenuDestination.visibleDestinations(isAdmin: true) == AdminMenuDestination.allCases)
    }

    @Test("Selecting Home always resets its navigation path")
    func homeNavigationResetPolicy() {
        #expect(RootNavigationPolicy.resetsHomePath(for: .home))
        #expect(!RootNavigationPolicy.resetsHomePath(for: .calendar))
        #expect(!RootNavigationPolicy.resetsHomePath(for: .settings))
    }

    @Test("Admin member contract decodes without exposing the raw refresh token")
    func memberContract() throws {
        let json = #"""
        {
          "content":[{
            "id":7,"name":"Shane","email":"test@duty.park","teamId":2,"teamName":"Dutypark",
            "tokens":[{
              "memberName":"Shane","memberId":7,"validUntil":"2026-09-01T00:00:00",
              "createdDate":"2026-08-01T00:00:00","lastUsed":null,"remoteAddr":"127.0.0.1",
              "id":99,"token":"server-secret","userAgent":{"os":"iOS","browser":"Dutypark","device":"iPhone"}
            }],
            "hasProfilePhoto":true,"profilePhotoVersion":3
          }],
          "totalPages":1,"totalElements":1,"last":true,"first":true,"size":10,"number":0,
          "numberOfElements":1,"empty":false
        }
        """#
        let page = try JSONDecoder().decode(PageResponse<AdminMemberDTO>.self, from: Data(json.utf8))

        #expect(page.content.first?.id == 7)
        #expect(page.content.first?.tokens.first?.userAgent?.device == "iPhone")
    }

    @Test("Team name validation catches lengths before calling the server") @MainActor
    func teamNameValidation() async {
        let repository = AdminRepositorySpy()
        let model = AdminTeamListViewModel(repository: repository)

        await model.checkName("A")
        #expect(model.nameCheckResult == .tooShort)
        await model.checkName(String(repeating: "A", count: 21))
        #expect(model.nameCheckResult == .tooLong)
        #expect(await repository.nameCheckCalls == 0)
    }

    @Test("A stale team-name response cannot overwrite the latest check") @MainActor
    func staleTeamNameResponseIsIgnored() async {
        let repository = AdminNameCheckRaceRepository()
        let model = AdminTeamListViewModel(repository: repository)

        let firstCheck = Task { await model.checkName("Alpha") }
        await repository.waitUntilRequested("Alpha")

        let secondCheck = Task { await model.checkName("Bravo") }
        await repository.waitUntilRequested("Bravo")
        await repository.complete("Bravo", with: .ok)
        await secondCheck.value
        #expect(model.nameCheckResult == .ok)

        await repository.complete("Alpha", with: .duplicated)
        await firstCheck.value
        #expect(model.nameCheckResult == .ok)

        model.resetNameCheck()
        #expect(model.nameCheckResult == nil)
    }

    @Test("Admin edit modals use one dirty-form dismissal policy for every request source")
    func modalDismissPolicy() {
        let pristine = AdminModalInteractionState()
        #expect(pristine.allowsDismiss)
        #expect(pristine.dismissDecision == .dismiss)

        let dirty = AdminModalInteractionState(isDirty: true)
        #expect(dirty.allowsDismiss)
        #expect(dirty.dismissDecision == .confirmDiscard)

        let saving = AdminModalInteractionState(isDirty: true, isSaving: true)
        #expect(!saving.allowsDismiss)
        #expect(saving.dismissDecision == .blocked)

        let checking = AdminModalInteractionState(isDirty: true, isChecking: true)
        #expect(!checking.allowsDismiss)
        #expect(checking.dismissDecision == .blocked)
    }

    @Test("Admin form dirtiness is an exact comparison with its initial values")
    func modalDirtyBaseline() {
        #expect(!AdminModalInteractionState.passwordIsDirty(password: "", confirmation: ""))
        #expect(AdminModalInteractionState.passwordIsDirty(password: " ", confirmation: ""))
        #expect(!AdminModalInteractionState.passwordIsDirty(
            password: "original",
            confirmation: "original",
            baselinePassword: "original",
            baselineConfirmation: "original"
        ))

        #expect(!AdminModalInteractionState.teamIsDirty(name: "", description: ""))
        #expect(AdminModalInteractionState.teamIsDirty(name: " ", description: ""))
        #expect(!AdminModalInteractionState.teamIsDirty(
            name: "Dutypark",
            description: "Team",
            baselineName: "Dutypark",
            baselineDescription: "Team"
        ))
    }
}

private actor AdminNameCheckRaceRepository: AdminRepositoryProtocol {
    private var pending: [String: CheckedContinuation<AdminTeamNameCheckResult, any Error>] = [:]
    private var requestWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    func members(keyword: String, page: Int, size: Int) async throws -> PageResponse<AdminMemberDTO> {
        try emptyPage()
    }

    func memberDetail(id: MemberID) async throws -> AdminMemberDetailDTO { throw APIError.invalidResponse }
    func sessions() async throws -> [SettingsRefreshToken] { [] }
    func revokeSession(id: Int64) async throws {}
    func changePassword(memberID: MemberID, newPassword: String) async throws {}

    func teams(keyword: String, page: Int, size: Int) async throws -> PageResponse<SimpleTeamDTO> {
        try emptyPage()
    }

    func checkTeamName(_ name: String) async throws -> AdminTeamNameCheckResult {
        try await withCheckedThrowingContinuation { continuation in
            pending[name] = continuation
            requestWaiters.removeValue(forKey: name)?.forEach { $0.resume() }
        }
    }

    func createTeam(name: String, description: String) async throws -> TeamDTO {
        throw APIError.invalidResponse
    }

    func deleteTeam(id: TeamID) async throws {}

    func waitUntilRequested(_ name: String) async {
        guard pending[name] == nil else { return }
        await withCheckedContinuation { continuation in
            requestWaiters[name, default: []].append(continuation)
        }
    }

    func complete(_ name: String, with result: AdminTeamNameCheckResult) {
        pending.removeValue(forKey: name)?.resume(returning: result)
    }

    private func emptyPage<Element: Codable & Equatable & Sendable>() throws -> PageResponse<Element> {
        try JSONDecoder().decode(
            PageResponse<Element>.self,
            from: Data(#"{"content":[],"totalPages":0,"totalElements":0,"last":true,"first":true,"size":10,"number":0,"numberOfElements":0,"empty":true}"#.utf8)
        )
    }
}

private actor AdminRepositorySpy: AdminRepositoryProtocol {
    private(set) var nameCheckCalls = 0

    func members(keyword: String, page: Int, size: Int) async throws -> PageResponse<AdminMemberDTO> {
        try emptyPage()
    }

    func memberDetail(id: MemberID) async throws -> AdminMemberDetailDTO { throw APIError.invalidResponse }
    func sessions() async throws -> [SettingsRefreshToken] { [] }
    func revokeSession(id: Int64) async throws {}
    func changePassword(memberID: MemberID, newPassword: String) async throws {}

    func teams(keyword: String, page: Int, size: Int) async throws -> PageResponse<SimpleTeamDTO> {
        try emptyPage()
    }

    func checkTeamName(_ name: String) async throws -> AdminTeamNameCheckResult {
        nameCheckCalls += 1
        return .ok
    }

    func createTeam(name: String, description: String) async throws -> TeamDTO { throw APIError.invalidResponse }
    func deleteTeam(id: TeamID) async throws {}

    private func emptyPage<Element: Codable & Equatable & Sendable>() throws -> PageResponse<Element> {
        try JSONDecoder().decode(
            PageResponse<Element>.self,
            from: Data(#"{"content":[],"totalPages":0,"totalElements":0,"last":true,"first":true,"size":10,"number":0,"numberOfElements":0,"empty":true}"#.utf8)
        )
    }
}
