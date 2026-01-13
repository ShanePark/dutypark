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
    @Published var dutyBatchTemplates: [DutyBatchTemplateDto] = []
    @Published var isUploadingBatch = false
    @Published var lastBatchResult: DutyBatchTeamResult?

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
            await loadDutyBatchTemplates()
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
              let currentUser = AuthManager.shared.currentUser else {
            return false
        }
        if currentUser.isAdmin {
            return true
        }
        return team.adminId == currentUser.id ||
               team.members.contains { $0.id == currentUser.id && $0.isManager }
    }

    func loadDutyBatchTemplates() async {
        do {
            dutyBatchTemplates = try await APIClient.shared.request(
                .dutyBatchTemplates,
                responseType: [DutyBatchTemplateDto].self
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateBatchTemplate(templateName: String?) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.updateBatchTemplate(teamId: teamId, templateName: templateName))
            await loadTeam()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func updateWorkType(_ workType: String) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.updateWorkType(teamId: teamId, workType: workType))
            await loadTeam()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func changeAdmin(memberId: Int?) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.updateTeamAdmin(teamId: teamId, memberId: memberId))
            await loadTeam()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func uploadDutyBatch(fileURL: URL, year: Int, month: Int) async -> DutyBatchTeamResult? {
        isUploadingBatch = true
        defer { isUploadingBatch = false }

        do {
            let result = try await uploadDutyBatchRequest(fileURL: fileURL, year: year, month: month)
            lastBatchResult = result
            await loadTeam()
            return result
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    func addDutyType(name: String, color: String) async -> Bool {
        let request = DutyTypeCreateDto(teamId: teamId, name: name, color: color)
        do {
            try await APIClient.shared.requestVoid(.addDutyType(teamId: teamId, request: request))
            await loadTeam()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func updateDutyType(id: Int, name: String, color: String) async -> Bool {
        let request = DutyTypeUpdateDto(id: id, name: name, color: color)
        do {
            try await APIClient.shared.requestVoid(.updateDutyType(teamId: teamId, request: request))
            await loadTeam()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func updateDefaultDuty(name: String, color: String) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.updateDefaultDuty(teamId: teamId, name: name, color: color))
            await loadTeam()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func swapDutyTypePosition(id1: Int, id2: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.swapDutyTypePosition(teamId: teamId, id1: id1, id2: id2))
            await loadTeam()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteDutyType(_ dutyTypeId: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.deleteDutyType(teamId: teamId, dutyTypeId: dutyTypeId))
            await loadTeam()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func uploadDutyBatchRequest(fileURL: URL, year: Int, month: Int) async throws -> DutyBatchTeamResult {
        let boundary = UUID().uuidString
        let baseURL: URL
        #if DEBUG
        baseURL = URL(string: "http://localhost:8080/api")!
        #else
        baseURL = URL(string: "https://duty.park/api")!
        #endif

        guard let url = URL(string: "teams/manage/\(teamId)/duty", relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = AuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var data = Data()

        func appendField(name: String, value: String) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            data.append("\(value)\r\n".data(using: .utf8)!)
        }

        var fileData = Data()
        let isAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent

        appendField(name: "year", value: "\(year)")
        appendField(name: "month", value: "\(month)")

        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(DutyBatchTeamResult.self, from: responseData)
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 400...499:
            throw APIError.clientError(statusCode: httpResponse.statusCode, data: responseData)
        case 500...599:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw APIError.unknown(statusCode: httpResponse.statusCode)
        }
    }
}
