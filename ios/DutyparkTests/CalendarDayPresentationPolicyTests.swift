import XCTest
@testable import Dutypark

/// The two value rules the calendar's month grid and day detail lean on: whether a day
/// is worth opening at all, and who a schedule names once the tags are merged.
final class CalendarDayPresentationPolicyTests: XCTestCase {

    // MARK: - Opening a day

    func testADayWithoutAScheduleShowsNothingInTheDetail() {
        XCTAssertTrue(CalendarDayOpenPolicy.showsNothing(day()))
        XCTAssertFalse(CalendarDayOpenPolicy.showsNothing(day(schedules: [schedule()])))
    }

    /// The detail lists schedules and nothing else, so everything else the cell draws
    /// leaves it empty: the sheet would open with nothing in it.
    func testTheDetailIgnoresEverythingTheCellDrawsBesideSchedules() {
        XCTAssertTrue(CalendarDayOpenPolicy.showsNothing(day(duty: duty())))
        XCTAssertTrue(CalendarDayOpenPolicy.showsNothing(day(todos: [todo()])))
        XCTAssertTrue(CalendarDayOpenPolicy.showsNothing(day(dDays: [dDay()])))
        XCTAssertTrue(CalendarDayOpenPolicy.showsNothing(day(holidays: [holiday()])))
    }

    func testADayWithNothingToShowDoesNotOpenForAReaderWhoCannotWrite() {
        XCTAssertFalse(CalendarDayOpenPolicy.opensDetail(day(), canEdit: false))
        // A duty of somebody else's colours the cell and says nothing more in the sheet.
        XCTAssertFalse(CalendarDayOpenPolicy.opensDetail(day(duty: duty()), canEdit: false))
    }

    /// Edit rights are what make an empty day the way a schedule gets written.
    func testAnEmptyDayTheReaderCanWriteToStillOpens() {
        XCTAssertTrue(CalendarDayOpenPolicy.opensDetail(day(), canEdit: true))
        XCTAssertTrue(CalendarDayOpenPolicy.opensDetail(day(duty: duty()), canEdit: true))
    }

    func testADayHoldingAScheduleOpensWithOrWithoutEditRights() {
        let filled = day(schedules: [schedule()])
        XCTAssertTrue(CalendarDayOpenPolicy.opensDetail(filled, canEdit: false))
        XCTAssertTrue(CalendarDayOpenPolicy.opensDetail(filled, canEdit: true))
    }

    // MARK: - Who a schedule names

    func testTagsLeaveOutTheMemberWhoseCalendarIsBeingRead() {
        let tags = ScheduleTagDisplayPolicy.displayTags(
            for: schedule(tags: [member(id: 1, name: "Owner"), member(id: 2, name: "Friend")]),
            calendarMemberID: 1
        )

        XCTAssertEqual(tags.map(\.name), ["Friend"])
        XCTAssertEqual(tags.map(\.memberID), [2])
    }

    func testANamelessTagIsDropped() {
        let tags = ScheduleTagDisplayPolicy.displayTags(
            for: schedule(tags: [member(id: 2, name: ""), member(id: 3, name: "Friend")]),
            calendarMemberID: 1
        )

        XCTAssertEqual(tags.map(\.name), ["Friend"])
    }

    func testWhoeverDidTheTaggingComesFirst() {
        let tags = ScheduleTagDisplayPolicy.displayTags(
            for: schedule(
                isTagged: true,
                taggedByMember: preview(id: 9, name: "Tagger", hasProfilePhoto: true, version: 4),
                tags: [member(id: 2, name: "Friend")]
            ),
            calendarMemberID: 1
        )

        XCTAssertEqual(tags.map(\.name), ["Tagger", "Friend"])
        XCTAssertTrue(tags[0].hasProfilePhoto)
        XCTAssertEqual(tags[0].profilePhotoVersion, 4)
    }

    func testATaggerAlreadyAmongTheTagsIsNotNamedTwice() {
        let tags = ScheduleTagDisplayPolicy.displayTags(
            for: schedule(
                isTagged: true,
                taggedByMember: preview(id: 9, name: "Tagger"),
                tags: [member(id: 9, name: "Tagger"), member(id: 2, name: "Friend")]
            ),
            calendarMemberID: 1
        )

        XCTAssertEqual(tags.map(\.name), ["Tagger", "Friend"])
    }

    /// A tagger whose account is gone is remembered by name alone.
    func testATaggerWithoutAMemberFallsBackToTheOwnersName() {
        let tags = ScheduleTagDisplayPolicy.displayTags(
            for: schedule(isTagged: true, owner: "Gone", taggedByMember: nil),
            calendarMemberID: 1
        )

        XCTAssertEqual(tags.map(\.name), ["Gone"])
        XCTAssertNil(tags[0].memberID)
        XCTAssertFalse(tags[0].hasProfilePhoto)
    }

    func testAnUntaggedScheduleNeverNamesItsOwner() {
        let tags = ScheduleTagDisplayPolicy.displayTags(
            for: schedule(isTagged: false, owner: "Owner", tags: [member(id: 2, name: "Friend")]),
            calendarMemberID: 1
        )

        XCTAssertEqual(tags.map(\.name), ["Friend"])
    }

    func testAScheduleWithNothingToNameYieldsNoTags() {
        XCTAssertTrue(
            ScheduleTagDisplayPolicy.displayTags(for: schedule(), calendarMemberID: 1).isEmpty
        )
    }

    // MARK: - Fixtures

    private func day(
        duty: DutyDTO? = nil,
        schedules: [ScheduleDTO] = [],
        holidays: [HolidayDTO] = [],
        todos: [TodoDTO] = [],
        dDays: [DDayDTO] = []
    ) -> CalendarDayContent {
        CalendarDayContent(
            cell: CalendarCell(
                date: DateOnly(rawValue: "2026-08-20"),
                year: 2026,
                month: 8,
                day: 20,
                isCurrentMonth: true
            ),
            duty: duty,
            schedules: schedules,
            holidays: holidays,
            todos: todos,
            dDays: dDays,
            comparedDuties: []
        )
    }

    private func duty() -> DutyDTO {
        DutyDTO(
            year: 2026,
            month: 8,
            day: 20,
            dutyType: "Night",
            dutyColor: "#111827",
            isOff: false,
            dutyTypeId: 3,
            source: .override
        )
    }

    private func holiday() -> HolidayDTO {
        HolidayDTO(dateName: "Liberation Day", isHoliday: true, localDate: DateOnly(rawValue: "2026-08-20"))
    }

    private func dDay() -> DDayDTO {
        DDayDTO(id: 1, title: "Anniversary", date: DateOnly(rawValue: "2026-08-20"), isPrivate: false, calc: 0, daysLeft: 0)
    }

    private func todo() -> TodoDTO {
        TodoDTO(
            id: "todo-1",
            title: "Pack",
            content: "",
            position: 0,
            status: .todo,
            createdDate: LocalDateTimeValue(rawValue: "2026-08-19T09:00:00"),
            completedDate: nil,
            dueDate: DateOnly(rawValue: "2026-08-20"),
            isOverdue: false,
            isTagged: false,
            owner: "Tester",
            taggedByMember: nil,
            tags: [],
            hasAttachments: false
        )
    }

    private func schedule(
        isTagged: Bool = false,
        owner: String = "Owner",
        taggedByMember: MemberPreviewDTO? = nil,
        tags: [MemberDTO] = []
    ) -> ScheduleDTO {
        ScheduleDTO(
            id: UUID(),
            content: "Dinner",
            description: "",
            position: 0,
            year: 2026,
            month: 8,
            dayOfMonth: 20,
            startDateTime: LocalDateTimeValue(rawValue: "2026-08-20T18:00:00"),
            endDateTime: LocalDateTimeValue(rawValue: "2026-08-20T19:00:00"),
            isTagged: isTagged,
            owner: owner,
            taggedByMember: taggedByMember,
            tags: tags,
            visibility: .friends,
            dateToCompare: DateOnly(rawValue: "2026-08-20"),
            attachments: [],
            startDate: DateOnly(rawValue: "2026-08-20"),
            daysFromStart: 1,
            endDate: DateOnly(rawValue: "2026-08-20"),
            curDate: DateOnly(rawValue: "2026-08-20"),
            totalDays: 1
        )
    }

    private func member(id: MemberID?, name: String) -> MemberDTO {
        MemberDTO(
            id: id,
            name: name,
            email: nil,
            teamId: nil,
            team: nil,
            calendarVisibility: .friends,
            kakaoId: nil,
            naverId: nil,
            hasPassword: false,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
    }

    private func preview(
        id: MemberID?,
        name: String,
        hasProfilePhoto: Bool = false,
        version: Int64 = 0
    ) -> MemberPreviewDTO {
        MemberPreviewDTO(
            id: id,
            name: name,
            teamId: nil,
            team: nil,
            hasProfilePhoto: hasProfilePhoto,
            profilePhotoVersion: version
        )
    }
}
