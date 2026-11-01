import Testing
@testable import Dutypark

/// A team calendar cell lists multi-day schedules before single-day ones.
struct TeamCalendarCellOrderTests {
    private func schedule(_ name: String, daysFromStart: Int?, totalDays: Int?) -> TeamScheduleDTO {
        TeamScheduleDTO(
            id: ScheduleID(),
            teamId: 1,
            content: name,
            description: "",
            position: 0,
            year: 2026,
            month: 11,
            dayOfMonth: 10,
            daysFromStart: daysFromStart,
            totalDays: totalDays,
            startDateTime: LocalDateTimeValue(rawValue: "2026-11-10T00:00:00"),
            endDateTime: LocalDateTimeValue(rawValue: "2026-11-10T00:00:00"),
            createMember: "",
            updateMember: "",
            curDate: DateOnly(rawValue: "2026-11-10")
        )
    }

    @Test
    func multiDaySchedulesComeFirstStartedEarlierThenEndingLater() {
        let schedules = [
            schedule("s1", daysFromStart: 1, totalDays: 1),
            schedule("s2", daysFromStart: 1, totalDays: 2),
            schedule("s3", daysFromStart: nil, totalDays: nil),
            schedule("s4", daysFromStart: 3, totalDays: 4),
            schedule("s5", daysFromStart: 1, totalDays: 5),
        ]

        let ordered = TeamCalendarCellSchedules.ordered(schedules).map(\.content)

        #expect(ordered == ["s4", "s5", "s2", "s1", "s3"])
    }
}
