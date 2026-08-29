import Foundation

nonisolated struct TeamRepository: Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func summary(year: Int, month: Int) async throws -> MyTeamSummaryDTO {
        try await client.request(
            "teams/my",
            queryItems: yearMonthQuery(year: year, month: month)
        )
    }

    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO] {
        try await client.request(
            "calendar",
            queryItems: yearMonthQuery(year: year, month: month)
        )
    }

    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO] {
        try await client.request(
            "duty",
            queryItems: yearMonthQuery(year: year, month: month) + [
                URLQueryItem(name: "memberId", value: String(memberID))
            ]
        )
    }

    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]] {
        try await client.request(
            "holidays",
            queryItems: yearMonthQuery(year: year, month: month)
        )
    }

    func schedules(teamID: TeamID, year: Int, month: Int) async throws -> [[TeamScheduleDTO]] {
        try await client.request(
            "teams/schedules",
            queryItems: yearMonthQuery(year: year, month: month) + [
                URLQueryItem(name: "teamId", value: String(teamID))
            ]
        )
    }

    func shifts(year: Int, month: Int, day: Int) async throws -> [DutyByShiftDTO] {
        try await client.request(
            "teams/shift",
            queryItems: [
                URLQueryItem(name: "year", value: String(year)),
                URLQueryItem(name: "month", value: String(month)),
                URLQueryItem(name: "day", value: String(day))
            ]
        )
    }

    @discardableResult
    func saveSchedule(_ request: TeamScheduleSaveDTO) async throws -> TeamScheduleDTO {
        try await client.request("teams/schedules", method: .post, body: request)
    }

    func deleteSchedule(id: UUID) async throws {
        try await client.data("teams/schedules/\(id.uuidString)", method: .delete)
    }

    func teamForManagement(teamID: TeamID) async throws -> TeamDTO {
        try await client.request("teams/manage/\(teamID)")
    }

    func batchTemplates() async throws -> [DutyBatchTemplateDTO] {
        try await client.request("duty_batch/templates")
    }

    func changeAdmin(teamID: TeamID, memberID: MemberID?) async throws {
        let query = memberID.map { [URLQueryItem(name: "memberId", value: String($0))] } ?? []
        try await client.data("teams/manage/\(teamID)/admin", method: .put, queryItems: query)
    }

    func updateBatchTemplate(teamID: TeamID, name: String?) async throws {
        let query = name.map { [URLQueryItem(name: "templateName", value: $0)] } ?? []
        try await client.data("teams/manage/\(teamID)/batch-template", method: .patch, queryItems: query)
    }

    func updateDefaultDuty(teamID: TeamID, name: String, color: String) async throws {
        try await client.data(
            "teams/manage/\(teamID)/default-duty",
            method: .patch,
            queryItems: [
                URLQueryItem(name: "name", value: name),
                URLQueryItem(name: "color", value: color)
            ]
        )
    }

    func searchMembers(
        teamID: TeamID,
        keyword: String,
        page: Int,
        size: Int = 5
    ) async throws -> PageResponse<MemberInviteCandidateDTO> {
        try await client.request(
            "teams/manage/members",
            queryItems: [
                URLQueryItem(name: "teamId", value: String(teamID)),
                URLQueryItem(name: "keyword", value: keyword),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
        )
    }

    func addMember(teamID: TeamID, memberID: MemberID) async throws {
        try await memberAction(teamID: teamID, memberID: memberID, path: "members", method: .post)
    }

    func removeMember(teamID: TeamID, memberID: MemberID) async throws {
        try await memberAction(teamID: teamID, memberID: memberID, path: "members", method: .delete)
    }

    func addManager(teamID: TeamID, memberID: MemberID) async throws {
        try await memberAction(teamID: teamID, memberID: memberID, path: "manager", method: .post)
    }

    func removeManager(teamID: TeamID, memberID: MemberID) async throws {
        try await memberAction(teamID: teamID, memberID: memberID, path: "manager", method: .delete)
    }

    func addDutyType(teamID: TeamID, name: String, color: String) async throws {
        try await sendJSON(
            "teams/manage/\(teamID)/duty-types",
            method: .post,
            body: DutyTypeCreateDTO(teamId: teamID, name: name, color: color)
        )
    }

    func updateDutyType(id: DutyTypeID, teamID: TeamID, name: String, color: String) async throws {
        try await sendJSON(
            "teams/manage/\(teamID)/duty-types",
            method: .patch,
            body: DutyTypeUpdateDTO(id: id, name: name, color: color)
        )
    }

    func swapDutyTypes(teamID: TeamID, first: DutyTypeID, second: DutyTypeID) async throws {
        try await client.data(
            "teams/manage/\(teamID)/duty-types/swap-position",
            method: .patch,
            queryItems: [
                URLQueryItem(name: "id1", value: String(first)),
                URLQueryItem(name: "id2", value: String(second))
            ]
        )
    }

    func setDutyTypeVisibility(teamID: TeamID, dutyTypeID: DutyTypeID, hidden: Bool) async throws {
        try await sendJSON(
            "teams/manage/\(teamID)/duty-types/\(dutyTypeID)/visibility",
            method: .patch,
            body: DutyTypeVisibilityDTO(hidden: hidden)
        )
    }

    func uploadDutyBatch(
        teamID: TeamID,
        fileName: String,
        fileData: Data,
        year: Int,
        month: Int
    ) async throws -> TeamBatchResultDTO {
        let form = TeamMultipartForm(boundary: "Dutypark-\(UUID().uuidString)")
        guard TeamFeatureLogic.isValidDutyBatchFileSize(
            fileData.count,
            fileName: fileName,
            year: year,
            month: month
        ) else {
            throw TeamBatchUploadError.requestBodyTooLarge
        }
        let body = form.makeBody(
            fileName: fileName,
            fileData: fileData,
            year: year,
            month: month
        )
        guard body.count < TeamFeatureLogic.maximumDutyBatchRequestBodySize else {
            throw TeamBatchUploadError.requestBodyTooLarge
        }
        let data = try await client.data(
            "teams/manage/\(teamID)/duty",
            method: .post,
            body: body,
            headers: ["Content-Type": form.contentType]
        )
        do {
            return try JSONDecoder().decode(TeamBatchResultDTO.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func memberAction(
        teamID: TeamID,
        memberID: MemberID,
        path: String,
        method: HTTPMethod
    ) async throws {
        try await client.data(
            "teams/manage/\(teamID)/\(path)",
            method: method,
            queryItems: [URLQueryItem(name: "memberId", value: String(memberID))]
        )
    }

    private func sendJSON<Body: Encodable>(
        _ path: String,
        method: HTTPMethod,
        body: Body
    ) async throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(body)
        } catch {
            throw APIError.decoding
        }
        try await client.data(path, method: method, body: data)
    }

    private func yearMonthQuery(year: Int, month: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "month", value: String(month))
        ]
    }
}
