import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class GuestCalendarMonthPickerTests: XCTestCase {
    func testYearMonthFormattingDoesNotGroupTheCalendarYear() {
        XCTAssertEqual(
            GuestCalendarLocalization.yearMonth(
                year: 2028,
                month: 2,
                template: "%1$lld년 %2$lld월"
            ),
            "2028년 2월"
        )
        XCTAssertEqual(
            GuestCalendarLocalization.yearMonth(
                year: 2028,
                month: 2,
                template: "%1$lld/%2$02lld"
            ),
            "2028/02"
        )
    }

    func testSelectYearMonthLoadsTheRequestedDistantMonth() async {
        let model = GuestPublicCalendarViewModel(
            memberID: 42,
            api: GuestCalendarMonthPickerAPIMock(),
            now: date(2026, 8, 12)
        )
        await model.load()

        await model.selectYearMonth(year: 2028, month: 2)

        XCTAssertEqual(model.year, 2028)
        XCTAssertEqual(model.month, 2)
        XCTAssertEqual(model.days.count, 42)
        XCTAssertTrue(model.days.filter(\.cell.isCurrentMonth).allSatisfy {
            $0.cell.year == 2028 && $0.cell.month == 2
        })
    }

    func testMonthNavigationEmitsRoutineFeedbackOnlyForAnActualChange() async {
        let haptics = DPHapticCenter()
        let model = GuestPublicCalendarViewModel(
            memberID: 42,
            api: GuestCalendarMonthPickerAPIMock(),
            now: date(2026, 8, 12),
            haptics: haptics
        )

        await model.load()
        XCTAssertNil(haptics.event)

        await model.changeMonth(by: 1)

        XCTAssertEqual(haptics.event?.kind, .routine)
        let eventID = haptics.event?.id

        await model.changeMonth(by: 0)

        XCTAssertEqual(haptics.event?.id, eventID)
    }

    func testMonthPickerStringsResolveInEverySupportedLocale() throws {
        let keys = [
            "guest.calendar.month.choose",
            "guest.calendar.month.previousYear",
            "guest.calendar.month.nextYear",
            "guest.calendar.month.current"
        ]

        for locale in ["en", "ko"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try XCTUnwrap(Bundle(url: url))
            for key in keys {
                XCTAssertNotEqual(
                    bundle.localizedString(forKey: key, value: key, table: "Guest"),
                    key,
                    "Missing \(key) for \(locale)"
                )
            }
        }
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        CalendarDateSupport.calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        )!
    }
}

private actor GuestCalendarMonthPickerAPIMock: GuestAPIProtocol {
    func member(id: MemberID) async throws -> MemberPreviewDTO {
        MemberPreviewDTO(
            id: id,
            name: "Public member",
            teamId: nil,
            team: nil,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
    }

    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO] {
        (1...42).map { TeamDayDTO(year: year, month: month, day: $0) }
    }

    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO] { [] }
    func schedules(memberID: MemberID, year: Int, month: Int) async throws -> [[ScheduleDTO]] {
        Array(repeating: [], count: 42)
    }
    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]] {
        Array(repeating: [], count: 42)
    }
    func dDays(memberID: MemberID) async throws -> [DDayDTO] { [] }
    func policy(_ type: PolicyType) async throws -> PolicyDTO { throw URLError(.unsupportedURL) }
}
