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
