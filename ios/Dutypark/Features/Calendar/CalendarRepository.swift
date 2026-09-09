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
    func deleteSchedule(id: ScheduleID) async throws
    func untagSelf(scheduleID: ScheduleID) async throws
    func searchSchedules(memberID: MemberID, query: String, page: Int) async throws -> PageResponse<ScheduleSearchResultDTO>
    func scheduleBasic(id: ScheduleID) async throws -> ScheduleBasicInfoDTO
    func updateDuty(_ request: DutyUpdateDTO) async throws
    func uploadDutyBatch(memberID: MemberID, year: Int, month: Int, filename: String, data: Data) async throws -> DutyBatchUploadResult
    func saveDDay(_ request: DDaySaveDTO) async throws -> DDayDTO
    func deleteDDay(id: Int64) async throws
}

/// Builds the calendar duty import request while keeping its in-memory transport body
/// below the production proxy limit. The API client accepts an in-memory `Data` body, so
/// the limit has to include every multipart header and delimiter, not just the spreadsheet.
nonisolated enum CalendarDutyBatchMultipart {
    static func body(
        memberID: MemberID,
        year: Int,
        month: Int,
        filename: String,
        data: Data,
        boundary: String
    ) -> Data? {
        let safeFilename = sanitizedFilename(filename)
        var body = Data()
        appendField(name: "memberId", value: String(memberID), boundary: boundary, to: &body)
        appendField(name: "year", value: String(year), boundary: boundary, to: &body)
        appendField(name: "month", value: String(month), boundary: boundary, to: &body)
        body.append(
            Data(
                "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(safeFilename)\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8
            )
        )
        let closing = Data("\r\n--\(boundary)--\r\n".utf8)

        // Check the complete request before appending the file. In addition to avoiding an
        // oversized request, the checked additions keep a malformed/huge input from wrapping
        // the Int calculation and bypassing the limit.
        let (withFile, fileOverflow) = body.count.addingReportingOverflow(data.count)
        let (total, closingOverflow) = withFile.addingReportingOverflow(closing.count)
        guard !fileOverflow,
              !closingOverflow,
              total < AttachmentUploadPolicy.safeMaximumBytes
        else {
            return nil
        }

        body.reserveCapacity(total)
        body.append(data)
        body.append(closing)
        return body
    }

    /// Returns a filename that cannot terminate or inject the quoted multipart parameter.
    /// Quotes, backslashes, line breaks, and Unicode control characters are replaced so the
    /// header remains valid even when the local file name is user-controlled.
    static func sanitizedFilename(_ filename: String) -> String {
        let sanitized = filename.unicodeScalars.map { scalar -> String in
            if CharacterSet.controlCharacters.contains(scalar)
                || scalar.value == 0x2028
                || scalar.value == 0x2029
                || scalar.value == 0x22
                || scalar.value == 0x5C
            {
                return "_"
            }
            return String(scalar)
        }.joined()
        return sanitized.isEmpty ? "duty-batch.xlsx" : sanitized
    }

    private static func appendField(
        name: String,
        value: String,
        boundary: String,
        to body: inout Data
    ) {
        body.append(
            Data(
                "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8
            )
        )
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

    func uploadDutyBatch(memberID: MemberID, year: Int, month: Int, filename: String, data: Data) async throws -> DutyBatchUploadResult {
        // Keep the transport boundary protected even when a caller bypasses
        // CalendarViewModel's file-URL preflight.
        guard data.count < AttachmentUploadPolicy.safeMaximumBytes else {
            throw APIError.invalidResponse
        }
        let boundary = "DutyparkDuty-\(UUID().uuidString)"
        guard let body = CalendarDutyBatchMultipart.body(
            memberID: memberID,
            year: year,
            month: month,
            filename: filename,
            data: data,
            boundary: boundary
        ) else {
            // This is the final transport guard. It covers multipart overhead even when a
            // direct repository caller bypasses the URL and raw-data preflight.
            throw APIError.invalidResponse
        }
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
