import Foundation

@MainActor
class TeamManageViewModel: ObservableObject {
    @Published var team: TeamDto?
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchResults: [MemberDto] = []
    @Published var isSearching = false
    @Published var currentPage = 0
    @Published var totalPages = 1
    @Published var totalElements = 0

    let teamId: Int
    private let pageSize = 10

    init(teamId: Int) {
        self.teamId = teamId
    }

    func loadTeam() async {
        isLoading = true
        error = nil

        do {
            team = try await APIClient.shared.request(
                .teamForManage(id: teamId),
                responseType: TeamDto.self
            )
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func searchMembers(keyword: String) async {
        isSearching = true
        currentPage = 0

        do {
            let response: PageResponse<MemberDto> = try await APIClient.shared.request(
                .searchMembersToInvite(keyword: keyword, page: currentPage, size: pageSize),
                responseType: PageResponse<MemberDto>.self
            )
            searchResults = response.content
            totalPages = response.totalPages
            totalElements = response.totalElements
        } catch {
            self.error = error.localizedDescription
        }

        isSearching = false
    }

    func loadMoreSearchResults(keyword: String) async {
        guard currentPage < totalPages - 1 else { return }

        currentPage += 1

        do {
            let response: PageResponse<MemberDto> = try await APIClient.shared.request(
                .searchMembersToInvite(keyword: keyword, page: currentPage, size: pageSize),
                responseType: PageResponse<MemberDto>.self
            )
            searchResults.append(contentsOf: response.content)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addMember(_ memberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.addTeamMember(teamId: teamId, memberId: memberId))
            await loadTeam()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func removeMember(_ memberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.removeTeamMember(teamId: teamId, memberId: memberId))
            await loadTeam()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func grantManagerRole(_ memberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.addTeamManager(teamId: teamId, memberId: memberId))
            await loadTeam()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func revokeManagerRole(_ memberId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.removeTeamManager(teamId: teamId, memberId: memberId))
            await loadTeam()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func isCurrentUserManager() -> Bool {
        guard let team = team,
              let currentUserId = AuthManager.shared.currentUser?.id else {
            return false
        }
        return team.adminId == currentUserId ||
               team.members.contains { $0.id == currentUserId && $0.isManager }
    }
}
