import Foundation
import Combine

nonisolated struct GuestCalendarDay: Identifiable, Equatable, Sendable {
    let cell: CalendarCell
    let duty: DutyDTO?
    let schedules: [ScheduleDTO]
    let holidays: [HolidayDTO]
    let dDays: [DDayDTO]

    var id: String { cell.id }
}

@MainActor
final class GuestPublicCalendarViewModel: ObservableObject {
    private let memberID: MemberID
    private let api: GuestAPIProtocol

    @Published private(set) var member: MemberPreviewDTO?
    @Published private(set) var days: [GuestCalendarDay] = []
    @Published private(set) var dDays: [DDayDTO] = []
    @Published private(set) var isLoading = false
    @Published var hasError = false
    @Published var selectedDay: GuestCalendarDay?
    @Published var year: Int
    @Published var month: Int

    init(
        memberID: MemberID,
        api: GuestAPIProtocol = GuestAPI(),
        now: Date = Date()
    ) {
        self.memberID = memberID
        self.api = api
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month], from: now)
        year = parts.year ?? 2026
        month = parts.month ?? 1
    }

    func load() async {
        isLoading = true
        hasError = false
        do {
            if member == nil {
                member = try await api.member(id: memberID)
            }
            try await loadMonth()
        } catch {
            hasError = true
        }
        isLoading = false
    }

    func changeMonth(by offset: Int) async {
        guard let date = CalendarDateSupport.calendar.date(
            from: DateComponents(year: year, month: month, day: 1)
        ), let changed = CalendarDateSupport.calendar.date(
            byAdding: .month,
            value: offset,
            to: date
        ) else {
            return
        }
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month], from: changed)
        year = parts.year ?? year
        month = parts.month ?? month
        await load()
    }

    func goToToday() async {
        let parts = CalendarDateSupport.calendar.dateComponents([.year, .month], from: Date())
        year = parts.year ?? year
        month = parts.month ?? month
        await load()
    }

    private func loadMonth() async throws {
        async let calendarResult = api.calendar(year: year, month: month)
        async let dutiesResult = api.duties(memberID: memberID, year: year, month: month)
        async let schedulesResult = api.schedules(memberID: memberID, year: year, month: month)
        async let holidaysResult = api.holidays(year: year, month: month)
        async let dDaysResult = api.dDays(memberID: memberID)

        let cells = CalendarDateSupport.cells(
            year: year,
            month: month,
            serverDays: try await calendarResult
        )
        guard cells.count == 42 else { throw APIError.invalidResponse }
        let duties = try await dutiesResult
        let schedules = try await schedulesResult
        let holidays = try await holidaysResult
        let loadedDDays = try await dDaysResult.sorted { $0.date.rawValue < $1.date.rawValue }

        dDays = loadedDDays
        days = cells.enumerated().map { index, cell in
            GuestCalendarDay(
                cell: cell,
                duty: duties.first {
                    $0.year == cell.year && $0.month == cell.month && $0.day == cell.day
                },
                schedules: index < schedules.count ? schedules[index] : [],
                holidays: index < holidays.count ? holidays[index] : [],
                dDays: loadedDDays.filter { $0.date == cell.date }
            )
        }
        selectedDay = selectedDay.flatMap { selection in
            days.first { $0.id == selection.id }
        }
    }
}
