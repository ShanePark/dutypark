import Foundation
import Testing
@testable import Dutypark

struct DPYearMonthPickerTests {
    @Test
    func monthGridIsOrderedJanuaryToDecemberForTheRequestedLocale() {
        let english = Locale(identifier: "en_US")
        let names = (1...12).map { DPYearMonthPickerLocalization.monthName($0, locale: english) }

        #expect(names.first == "January")
        #expect(names.last == "December")
        #expect(names.count == Set(names).count)
    }

    @Test
    func monthNameFollowsTheRequestedLocale() {
        #expect(DPYearMonthPickerLocalization.monthName(8, locale: Locale(identifier: "ko_KR")) == "8월")
        #expect(DPYearMonthPickerLocalization.monthName(8, locale: Locale(identifier: "en_US")) == "August")
    }

    @Test(arguments: [0, 13, -1, 99])
    func outOfRangeMonthsFallBackToTheirNumberInsteadOfCrashing(month: Int) {
        #expect(
            DPYearMonthPickerLocalization.monthName(month, locale: Locale(identifier: "en_US"))
                == String(month)
        )
    }

    @Test
    func teamAndGuestCalendarsShareTheSingleYearMonthPicker() throws {
        let features = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features")
        let team = try String(
            contentsOf: features.appending(path: "Team/TeamView.swift"),
            encoding: .utf8
        )
        let guest = try String(
            contentsOf: features.appending(path: "Guest/GuestPublicCalendarView.swift"),
            encoding: .utf8
        )

        #expect(team.contains("DPYearMonthPicker("))
        #expect(guest.contains("DPYearMonthPicker("))
        #expect(team.contains("struct TeamYearMonthPicker") == false)
        #expect(guest.contains("struct GuestYearMonthPicker") == false)
        // The guest picker is driven by identifier-based UI tests.
        #expect(guest.contains("identifierPrefix: \"guest.calendar.monthPicker\""))
    }
}
