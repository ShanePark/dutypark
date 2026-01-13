import Foundation

@MainActor
class AdminTeamListViewModel: ObservableObject {
    @Published var teams: [SimpleTeam] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentPage = 0
    @Published var totalPages = 0
    @Published var totalElements = 0

    let pageSize = 10

    func loadTeams(keyword: String = "", page: Int = 0) async {
        isLoading = true
        error = nil

        do {
            let response: PageResponse<SimpleTeam> = try await AdminAPIClient.shared.request(
                .teams(keyword: keyword, page: page, size: pageSize),
                responseType: PageResponse<SimpleTeam>.self
            )
            teams = response.content
            totalPages = response.totalPages
            totalElements = response.totalElements
            currentPage = page
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func checkTeamName(_ name: String) async -> TeamNameCheckResult? {
        do {
            let result = try await AdminAPIClient.shared.request(
                .checkTeamName(name: name),
                responseType: TeamNameCheckResult.self
            )
            return result
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func createTeam(name: String, description: String) async -> Int? {
        let request = TeamCreateDto(name: name, description: description)
        do {
            let team: TeamDto = try await AdminAPIClient.shared.request(
                .createTeam(request: request),
                responseType: TeamDto.self
            )
            await loadTeams(keyword: "", page: 0)
            return team.id
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func deleteTeam(_ teamId: Int) async -> Bool {
        do {
            try await AdminAPIClient.shared.requestVoid(.deleteTeam(id: teamId))
            teams.removeAll { $0.id == teamId }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
