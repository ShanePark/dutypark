import Foundation

nonisolated protocol CalendarRepositoryProtocol: Sendable {
    func member() async throws -> MemberDTO
    func member(id: MemberID) async throws -> MemberPreviewDTO
    func friends() async throws -> [FriendDTO]
    func team(id: TeamID) async throws -> TeamDTO
    func canManage(memberID: MemberID) async throws -> Bool
    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO]
    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO]
    func otherDuties(memberIDs: [MemberID], year: Int, month: Int) async throws -> [OtherDutyResponse]
    func schedules(memberID: MemberID, year: Int, month: Int) async throws -> [[ScheduleDTO]]
    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]]
    func dDays(memberID: MemberID, isMine: Bool) async throws -> [DDayDTO]
    func todoBoard() async throws -> TodoBoardDTO
    func saveSchedule(_ request: ScheduleSaveDTO) async throws -> ScheduleSaveResponse
    func saveSchedule(
        _ request: ScheduleSaveDTO,
        operationID: UUID
    ) async throws -> ScheduleSaveResponse
    func deleteSchedule(id: ScheduleID) async throws
    func untagSelf(scheduleID: ScheduleID) async throws
    func searchSchedules(memberID: MemberID, query: String, page: Int) async throws -> PageResponse<ScheduleSearchResultDTO>
    func scheduleBasic(id: ScheduleID) async throws -> ScheduleBasicInfoDTO
    func updateDuty(_ request: DutyUpdateDTO) async throws
    func batchUpdateDuty(_ request: DutyBatchUpdateDTO) async throws
    func uploadDutyBatch(memberID: MemberID, year: Int, month: Int, filename: String, data: Data) async throws -> DutyBatchUploadResult
    func saveDDay(_ request: DDaySaveDTO) async throws -> DDayDTO
    func deleteDDay(id: Int64) async throws
}

extension CalendarRepositoryProtocol {
    /// Keep existing repository fakes and update call sites source-compatible;
    /// the production repository overrides this overload to send the key.
    func saveSchedule(
        _ request: ScheduleSaveDTO,
        operationID: UUID
    ) async throws -> ScheduleSaveResponse {
        try await saveSchedule(request)
    }
}

nonisolated final class CalendarRepository: CalendarRepositoryProtocol, Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func member() async throws -> MemberDTO { try await client.request("members/me") }
    func member(id: MemberID) async throws -> MemberPreviewDTO { try await client.request("members/\(id)") }
    func friends() async throws -> [FriendDTO] { try await client.request("friends") }
    func team(id: TeamID) async throws -> TeamDTO { try await client.request("teams/\(id)") }
    func canManage(memberID: MemberID) async throws -> Bool { try await client.request("members/\(memberID)/canManage") }

    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO] {
        try await client.request("calendar", queryItems: monthQuery(year: year, month: month))
    }

    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO] {
        try await client.request(
            "duty",
            queryItems: memberMonthQuery(memberID: memberID, year: year, month: month)
        )
    }

    func otherDuties(memberIDs: [MemberID], year: Int, month: Int) async throws -> [OtherDutyResponse] {
        guard !memberIDs.isEmpty else { return [] }
        return try await client.request(
            "duty/others",
            queryItems: [
                URLQueryItem(name: "memberIds", value: memberIDs.map(String.init).joined(separator: ",")),
                URLQueryItem(name: "year", value: String(year)),
                URLQueryItem(name: "month", value: String(month))
            ]
        )
    }

    func schedules(memberID: MemberID, year: Int, month: Int) async throws -> [[ScheduleDTO]] {
        try await client.request(
            "schedules",
            queryItems: memberMonthQuery(memberID: memberID, year: year, month: month)
        )
    }

    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]] {
        try await client.request("holidays", queryItems: monthQuery(year: year, month: month))
    }

    func dDays(memberID: MemberID, isMine: Bool) async throws -> [DDayDTO] {
        try await client.request(isMine ? "dday" : "dday/\(memberID)")
    }

    func todoBoard() async throws -> TodoBoardDTO { try await client.request("todos/board") }

    func saveSchedule(_ request: ScheduleSaveDTO) async throws -> ScheduleSaveResponse {
        try await client.request("schedules", method: .post, body: request)
    }

    func saveSchedule(
        _ request: ScheduleSaveDTO,
        operationID: UUID
    ) async throws -> ScheduleSaveResponse {
        try await client.request(
            "schedules",
            method: .post,
            body: request,
            headers: ["Idempotency-Key": operationID.uuidString]
        )
    }

    func deleteSchedule(id: ScheduleID) async throws {
        try await voidRequest("schedules/\(id.uuidString)", method: .delete)
    }

    func untagSelf(scheduleID: ScheduleID) async throws {
        try await voidRequest("schedules/\(scheduleID.uuidString)/tags", method: .delete)
    }

    func searchSchedules(memberID: MemberID, query: String, page: Int) async throws -> PageResponse<ScheduleSearchResultDTO> {
        try await client.request(
            "schedules/\(memberID)/search",
            queryItems: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: "10")
            ]
        )
    }

    func scheduleBasic(id: ScheduleID) async throws -> ScheduleBasicInfoDTO {
        try await client.request("schedules/\(id.uuidString)")
    }

    func updateDuty(_ request: DutyUpdateDTO) async throws {
        let _: Bool = try await client.request("duty/change", method: .put, body: request)
    }

    func batchUpdateDuty(_ request: DutyBatchUpdateDTO) async throws {
        let _: Bool = try await client.request("duty/batch", method: .put, body: request)
    }

    func uploadDutyBatch(memberID: MemberID, year: Int, month: Int, filename: String, data: Data) async throws -> DutyBatchUploadResult {
        let boundary = "DutyparkDuty-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("memberId", String(memberID))
        field("year", String(year))
        field("month", String(month))
        let safeFilename = filename.replacingOccurrences(of: "\"", with: "_").replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "")
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(safeFilename)\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        let response = try await client.data(
            "duty_batch", method: .post, body: body,
            headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
        )
        do { return try JSONDecoder().decode(DutyBatchUploadResult.self, from: response) }
        catch { throw APIError.decoding }
    }

    func saveDDay(_ request: DDaySaveDTO) async throws -> DDayDTO {
        try await client.request("dday", method: .post, body: request)
    }

    func deleteDDay(id: Int64) async throws {
        try await voidRequest("dday/\(id)", method: .delete)
    }

    private func monthQuery(year: Int, month: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "year", value: String(year)), URLQueryItem(name: "month", value: String(month))]
    }

    private func memberMonthQuery(memberID: MemberID, year: Int, month: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "memberId", value: String(memberID))] + monthQuery(year: year, month: month)
    }

    private func voidRequest(_ path: String, method: HTTPMethod) async throws {
        _ = try await client.data(path, method: method)
    }

    private func voidRequest<Body: Encodable & Sendable>(
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
        _ = try await client.data(path, method: method, body: data)
    }
}

nonisolated struct DutyBatchUploadResult: Codable, Equatable, Sendable {
    let result: Bool
    let errorCode: String?
    let errorDetails: [String: JSONValue]?
    let startDate: DateOnly?
    let endDate: DateOnly?
    let workingDays: Int
    let offDays: Int
}
