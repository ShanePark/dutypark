import Foundation

nonisolated protocol GuestAPIProtocol: Sendable {
    func member(id: MemberID) async throws -> MemberPreviewDTO
    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO]
    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO]
    func schedules(memberID: MemberID, year: Int, month: Int) async throws -> [[ScheduleDTO]]
    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]]
    func dDays(memberID: MemberID) async throws -> [DDayDTO]
    func policy(_ type: PolicyType) async throws -> PolicyDTO
}

nonisolated final class GuestAPI: GuestAPIProtocol, Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func member(id: MemberID) async throws -> MemberPreviewDTO {
        try await get("members/\(id)")
    }

    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO] {
        try await get("calendar", queryItems: monthQuery(year: year, month: month))
    }

    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO] {
        try await get(
            "duty",
            queryItems: memberMonthQuery(memberID: memberID, year: year, month: month)
        )
    }

    func schedules(memberID: MemberID, year: Int, month: Int) async throws -> [[ScheduleDTO]] {
        try await get(
            "schedules",
            queryItems: memberMonthQuery(memberID: memberID, year: year, month: month)
        )
    }

    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]] {
        try await get("holidays", queryItems: monthQuery(year: year, month: month))
    }

    func dDays(memberID: MemberID) async throws -> [DDayDTO] {
        try await get("dday/\(memberID)")
    }

    func policy(_ type: PolicyType) async throws -> PolicyDTO {
        let path = switch type {
        case .terms: "terms"
        case .privacy: "privacy"
        case .aiScheduleParsing: "ai-schedule-parsing"
        case .unknown(let value): value.lowercased()
        }
        return try await get("policies/\(path)")
    }

    private func get<Response: Decodable & Sendable>(
        _ path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        let data = try await client.data(
            path,
            queryItems: queryItems,
            retryingAfterUnauthorized: false
        )
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func monthQuery(year: Int, month: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "month", value: String(month))
        ]
    }

    private func memberMonthQuery(memberID: MemberID, year: Int, month: Int) -> [URLQueryItem] {
        [URLQueryItem(name: "memberId", value: String(memberID))]
            + monthQuery(year: year, month: month)
    }
}
