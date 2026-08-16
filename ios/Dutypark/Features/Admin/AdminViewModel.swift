import Combine
import Foundation

@MainActor
final class AdminMemberListViewModel: ObservableObject {
    static let pageSize = 10

    @Published private(set) var members: [AdminMemberDTO] = []
    @Published private(set) var sessions: [SettingsRefreshToken] = []
    @Published private(set) var totalElements: Int64 = 0
    @Published private(set) var totalPages = 0
    @Published private(set) var page = 0
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false

    private let repository: any AdminRepositoryProtocol
    private var keyword = ""
    private var loadGeneration = 0

    init(repository: any AdminRepositoryProtocol = AdminRepository()) {
        self.repository = repository
    }

    func load() async {
        await load(keyword: keyword, page: page)
    }

    func search(_ value: String) async {
        keyword = value.trimmingCharacters(in: .whitespacesAndNewlines)
        await load(keyword: keyword, page: 0)
    }

    func movePage(by offset: Int) async {
        let nextPage = page + offset
        guard nextPage >= 0, nextPage < totalPages else { return }
        await load(keyword: keyword, page: nextPage)
    }

    func memberDetail(id: MemberID) async throws -> AdminMemberDetailDTO {
        try await repository.memberDetail(id: id)
    }

    func revokeSession(id: Int64) async throws {
        try await repository.revokeSession(id: id)
        sessions.removeAll { $0.id == id }
        members = members.map { member in
            guard member.tokens.contains(where: { $0.id == id }) else { return member }
            return AdminMemberDTO(
                id: member.id,
                name: member.name,
                email: member.email,
                teamId: member.teamId,
                teamName: member.teamName,
                tokens: member.tokens.filter { $0.id != id },
                hasProfilePhoto: member.hasProfilePhoto,
                profilePhotoVersion: member.profilePhotoVersion
            )
        }
    }

    func changePassword(memberID: MemberID, newPassword: String) async throws {
        try await repository.changePassword(memberID: memberID, newPassword: newPassword)
    }

    private func load(keyword: String, page: Int) async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }
        do {
            async let memberPage = repository.members(
                keyword: keyword,
                page: page,
                size: Self.pageSize
            )
            async let allSessions = repository.sessions()
            let (loadedPage, loadedSessions) = try await (memberPage, allSessions)
            guard generation == loadGeneration else { return }
            members = loadedPage.content
            sessions = loadedSessions
            totalElements = loadedPage.totalElements
            totalPages = loadedPage.totalPages
            self.page = loadedPage.number
            loadFailed = false
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            loadFailed = true
        }
    }
}

@MainActor
final class AdminTeamListViewModel: ObservableObject {
    static let pageSize = 10

    @Published private(set) var teams: [SimpleTeamDTO] = []
    @Published private(set) var totalElements: Int64 = 0
    @Published private(set) var totalPages = 0
    @Published private(set) var page = 0
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false
    @Published private(set) var nameCheckResult: AdminTeamNameCheckResult?
    @Published private(set) var searchKeyword = ""

    private let repository: any AdminRepositoryProtocol
    private var loadGeneration = 0
    private var nameCheckGeneration = 0

    init(repository: any AdminRepositoryProtocol = AdminRepository()) {
        self.repository = repository
    }

    func load() async {
        await load(keyword: searchKeyword, page: page)
    }

    func search(_ value: String) async {
        searchKeyword = value.trimmingCharacters(in: .whitespacesAndNewlines)
        await load(keyword: searchKeyword, page: 0)
    }

    func movePage(by offset: Int) async {
        await movePage(to: page + offset)
    }

    func movePage(to nextPage: Int) async {
        guard nextPage >= 0, nextPage < totalPages else { return }
        await load(keyword: searchKeyword, page: nextPage)
    }

    func checkName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        nameCheckGeneration += 1
        let generation = nameCheckGeneration
        nameCheckResult = nil

        guard (2...20).contains(trimmed.count) else {
            nameCheckResult = trimmed.count < 2 ? .tooShort : .tooLong
            return
        }

        do {
            let result = try await repository.checkTeamName(trimmed)
            guard generation == nameCheckGeneration else { return }
            nameCheckResult = result
        } catch is CancellationError {
            return
        } catch {
            guard generation == nameCheckGeneration else { return }
            nameCheckResult = nil
        }
    }

    func resetNameCheck() {
        nameCheckGeneration += 1
        nameCheckResult = nil
    }

    func create(name: String, description: String) async throws -> TeamDTO {
        let created = try await repository.createTeam(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        insertCreatedTeam(created)
        return created
    }

    func delete(_ team: SimpleTeamDTO) async throws {
        try await repository.deleteTeam(id: team.id)
        guard teams.contains(where: { $0.id == team.id }) else { return }
        teams.removeAll { $0.id == team.id }
        totalElements = max(0, totalElements - 1)
        totalPages = Self.pageCount(for: totalElements)
        page = min(page, max(0, totalPages - 1))
    }

    private func insertCreatedTeam(_ team: TeamDTO) {
        let matchesKeyword = searchKeyword.isEmpty
            || team.name.localizedCaseInsensitiveContains(searchKeyword)
            || team.description?.localizedCaseInsensitiveContains(searchKeyword) == true
        guard matchesKeyword else { return }

        let created = SimpleTeamDTO(
            id: team.id,
            name: team.name,
            description: team.description,
            memberCount: Int64(team.members.count)
        )
        if let existingIndex = teams.firstIndex(where: { $0.id == created.id }) {
            teams[existingIndex] = created
            return
        }

        totalElements += 1
        totalPages = Self.pageCount(for: totalElements)
        guard page == 0 else { return }
        teams.insert(created, at: 0)
        if teams.count > Self.pageSize {
            teams.removeLast(teams.count - Self.pageSize)
        }
    }

    private static func pageCount(for totalElements: Int64) -> Int {
        guard totalElements > 0 else { return 0 }
        return Int((totalElements + Int64(pageSize) - 1) / Int64(pageSize))
    }

    private func load(keyword: String, page: Int) async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }
        do {
            let loaded = try await repository.teams(
                keyword: keyword,
                page: page,
                size: Self.pageSize
            )
            guard generation == loadGeneration else { return }
            teams = loaded.content
            totalElements = loaded.totalElements
            totalPages = loaded.totalPages
            self.page = loaded.number
            loadFailed = false
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            loadFailed = true
        }
    }
}
