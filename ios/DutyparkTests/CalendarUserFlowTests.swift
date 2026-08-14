import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class CalendarUserFlowTests: XCTestCase {
    func testScheduleCreateEditDeleteRefreshesTheOpenDay() async throws {
        let repository = CalendarUserFlowRepository()
        let model = CalendarViewModel(
            repository: repository,
            now: date(2026, 8, 12)
        )
        await model.load()
        model.selectedDay = try XCTUnwrap(model.days.first { $0.cell.date.rawValue == "2026-08-12" })

        let created = await model.saveSchedule(
            existing: nil,
            content: "  Shared dinner  ",
            description: "Bring dessert",
            visibility: .friends,
            start: date(2026, 8, 12, hour: 18),
            end: date(2026, 8, 12, hour: 20),
            tagFriendIDs: [3, 2],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )

        XCTAssertTrue(created)
        let createdSchedule = try XCTUnwrap(model.selectedDay?.schedules.first)
        XCTAssertEqual(createdSchedule.content, "Shared dinner")
        XCTAssertEqual(model.selectedDay?.id, "2026-08-12", "Reloading must keep an open day modal bound to fresh data")
        let createRequests = await repository.savedRequests
        let createRequest = try XCTUnwrap(createRequests.last)
        XCTAssertNil(createRequest.id)
        XCTAssertEqual(createRequest.memberId, 1)
        XCTAssertEqual(createRequest.tagFriendIds, [3, 2])

        let updated = await model.saveSchedule(
            existing: createdSchedule,
            content: "Shared brunch",
            description: "Updated",
            visibility: .family,
            start: date(2026, 8, 12, hour: 10),
            end: date(2026, 8, 12, hour: 12),
            tagFriendIDs: [2],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: true
        )

        XCTAssertTrue(updated)
        let updatedSchedule = try XCTUnwrap(model.selectedDay?.schedules.first)
        XCTAssertEqual(updatedSchedule.id, createdSchedule.id)
        XCTAssertEqual(updatedSchedule.content, "Shared brunch")
        let updateRequests = await repository.savedRequests
        let updateRequest = try XCTUnwrap(updateRequests.last)
        XCTAssertEqual(updateRequest.id, createdSchedule.id)
        XCTAssertEqual(updateRequest.tagFriendIds, [2])
        XCTAssertTrue(updateRequest.aiTimeParsingRequested)

        let deleted = await model.deleteSchedule(updatedSchedule)
        XCTAssertTrue(deleted)
        XCTAssertEqual(model.selectedDay?.id, "2026-08-12")
        XCTAssertTrue(model.selectedDay?.schedules.isEmpty == true)
        let deletedScheduleIDs = await repository.deletedScheduleIDs
        XCTAssertEqual(deletedScheduleIDs, [createdSchedule.id])
    }

    func testDelegatedCalendarScheduleEditUsesTargetAndDoesNotForwardSharingTags() async throws {
        let existing = CalendarUserFlowRepository.schedule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            memberID: 9,
            content: "Delegated shift",
            isTagged: false
        )
        let repository = CalendarUserFlowRepository(schedule: existing, canManage: true)
        let model = CalendarViewModel(
            repository: repository,
            now: date(2026, 8, 12),
            memberID: 9
        )
        await model.load()

        let saved = await model.saveSchedule(
            existing: existing,
            content: "Delegated shift updated",
            description: "",
            visibility: .friends,
            start: date(2026, 8, 12),
            end: date(2026, 8, 12, hour: 1),
            tagFriendIDs: [2, 3],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )

        XCTAssertTrue(saved)
        let requests = await repository.savedRequests
        let request = try XCTUnwrap(requests.last)
        XCTAssertEqual(request.memberId, 9)
        XCTAssertNil(request.tagFriendIds, "Only a member's own calendar may modify friend sharing tags")
    }

    func testTaggedScheduleDeepLinkCanRemoveMyTagAndRefreshHighlightedDay() async throws {
        let scheduleID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        let tagged = CalendarUserFlowRepository.schedule(
            id: scheduleID,
            memberID: 9,
            content: "Shared shift",
            isTagged: true
        )
        let repository = CalendarUserFlowRepository(
            schedule: tagged,
            scheduleOwnerID: 9
        )
        let model = CalendarViewModel(
            repository: repository,
            now: date(2026, 1, 1),
            memberID: 1,
            scheduleID: scheduleID
        )

        await model.load()

        XCTAssertTrue(model.isMyCalendar)
        XCTAssertEqual(model.highlightedDate?.rawValue, "2026-08-12")
        model.selectedDay = try XCTUnwrap(model.days.first { $0.cell.date == model.highlightedDate })
        let linkedSchedule = try XCTUnwrap(model.selectedDay?.schedules.first)
        XCTAssertTrue(linkedSchedule.isTagged)

        let untagged = await model.untagSelf(linkedSchedule)
        XCTAssertTrue(untagged)
        XCTAssertTrue(model.selectedDay?.schedules.isEmpty == true)
        let untaggedScheduleIDs = await repository.untaggedScheduleIDs
        XCTAssertEqual(untaggedScheduleIDs, [scheduleID])
    }

    func testDDayCreateEditDeleteLifecycleRefreshesCalendarAndList() async throws {
        let repository = CalendarUserFlowRepository()
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))
        await model.load()

        let createdSuccessfully = await model.saveDDay(
            existing: nil,
            title: "  Anniversary  ",
            date: date(2026, 8, 12),
            isPrivate: false
        )
        XCTAssertTrue(createdSuccessfully)
        let created = try XCTUnwrap(model.dDays.first)
        XCTAssertEqual(created.title, "Anniversary")
        XCTAssertEqual(model.days.first { $0.cell.date.rawValue == "2026-08-12" }?.dDays, [created])

        let updatedSuccessfully = await model.saveDDay(
            existing: created,
            title: "Private anniversary",
            date: date(2026, 8, 13),
            isPrivate: true
        )
        XCTAssertTrue(updatedSuccessfully)
        let updated = try XCTUnwrap(model.dDays.first)
        XCTAssertEqual(updated.id, created.id)
        XCTAssertEqual(updated.date.rawValue, "2026-08-13")
        XCTAssertTrue(updated.isPrivate)
        XCTAssertTrue(model.days.first { $0.cell.date.rawValue == "2026-08-12" }?.dDays.isEmpty == true)
        XCTAssertEqual(model.days.first { $0.cell.date.rawValue == "2026-08-13" }?.dDays, [updated])

        let deletedSuccessfully = await model.deleteDDay(updated)
        XCTAssertTrue(deletedSuccessfully)
        XCTAssertTrue(model.dDays.isEmpty)
        XCTAssertTrue(model.days.flatMap(\.dDays).isEmpty)
        let deletedDDayIDs = await repository.deletedDDayIDs
        XCTAssertEqual(deletedDDayIDs, [created.id])
    }

    func testEmptyScheduleTitleDoesNotMutateOrDismissTheEditorFlow() async {
        let repository = CalendarUserFlowRepository()
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))
        await model.load()

        let saved = await model.saveSchedule(
            existing: nil,
            content: "   ",
            description: "",
            visibility: .privateAccess,
            start: date(2026, 8, 12, hour: 1),
            end: date(2026, 8, 12, hour: 2),
            tagFriendIDs: [],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )

        XCTAssertFalse(saved)
        let savedRequests = await repository.savedRequests
        XCTAssertTrue(savedRequests.isEmpty)
        XCTAssertNil(model.errorMessage)
    }

    func testScheduleEndBeforeStartDoesNotMutateOrDismissTheEditorFlow() async {
        let repository = CalendarUserFlowRepository()
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))
        await model.load()

        let saved = await model.saveSchedule(
            existing: nil,
            content: "Valid title",
            description: "",
            visibility: .privateAccess,
            start: date(2026, 8, 12, hour: 2),
            end: date(2026, 8, 12, hour: 1),
            tagFriendIDs: [],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )

        XCTAssertFalse(saved)
        let savedRequests = await repository.savedRequests
        XCTAssertTrue(savedRequests.isEmpty)
        XCTAssertNil(model.errorMessage)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        CalendarDateSupport.calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        )!
    }
}

private actor CalendarUserFlowRepository: CalendarRepositoryProtocol {
    private var storedSchedule: ScheduleDTO?
    private var storedDDays: [DDayDTO] = []
    private let canManageValue: Bool
    private let scheduleOwnerID: MemberID

    private(set) var savedRequests: [ScheduleSaveDTO] = []
    private(set) var deletedScheduleIDs: [ScheduleID] = []
    private(set) var untaggedScheduleIDs: [ScheduleID] = []
    private(set) var deletedDDayIDs: [Int64] = []

    init(
        schedule: ScheduleDTO? = nil,
        canManage: Bool = false,
        scheduleOwnerID: MemberID = 1
    ) {
        storedSchedule = schedule
        canManageValue = canManage
        self.scheduleOwnerID = scheduleOwnerID
    }

    func member() async throws -> MemberDTO {
        MemberDTO(
            id: 1,
            name: "Tester",
            email: "test@duty.park",
            teamId: nil,
            team: nil,
            calendarVisibility: .friends,
            kakaoId: nil,
            naverId: nil,
            hasPassword: true,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
    }

    func member(id: MemberID) async throws -> MemberPreviewDTO {
        MemberPreviewDTO(
            id: id,
            name: "Member \(id)",
            teamId: nil,
            team: nil,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
    }

    func friends() async throws -> [FriendDTO] { [] }
    func team(id: TeamID) async throws -> TeamDTO { throw APIError.invalidResponse }
    func canManage(memberID: MemberID) async throws -> Bool { canManageValue }

    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO] {
        Self.gridDays(year: year, month: month)
    }

    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO] { [] }
    func otherDuties(memberIDs: [MemberID], year: Int, month: Int) async throws -> [OtherDutyResponse] { [] }

    func schedules(memberID: MemberID, year: Int, month: Int) async throws -> [[ScheduleDTO]] {
        var result = Array(repeating: [ScheduleDTO](), count: 42)
        let cells = Self.gridDays(year: year, month: month)
        if let storedSchedule,
           let index = cells.firstIndex(where: {
               $0.year == storedSchedule.year
                   && $0.month == storedSchedule.month
                   && $0.day == storedSchedule.dayOfMonth
           }) {
            result[index] = [storedSchedule]
        }
        return result
    }

    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]] {
        Array(repeating: [], count: 42)
    }

    func dDays(memberID: MemberID, isMine: Bool) async throws -> [DDayDTO] { storedDDays }

    func todoBoard() async throws -> TodoBoardDTO {
        TodoBoardDTO(
            todo: [],
            inProgress: [],
            done: [],
            counts: TodoCountsDTO(todo: 0, inProgress: 0, done: 0, total: 0)
        )
    }

    func saveSchedule(_ request: ScheduleSaveDTO) async throws -> ScheduleSaveResponse {
        savedRequests.append(request)
        let id = request.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let date = Self.dateParts(request.startDateTime)
        storedSchedule = Self.schedule(
            id: id,
            memberID: request.memberId,
            content: request.content,
            isTagged: false,
            year: date.year,
            month: date.month,
            day: date.day,
            description: request.description,
            visibility: request.visibility
        )
        return ScheduleSaveResponse(id: id)
    }

    func deleteSchedule(id: ScheduleID) async throws {
        deletedScheduleIDs.append(id)
        if storedSchedule?.id == id { storedSchedule = nil }
    }

    func untagSelf(scheduleID: ScheduleID) async throws {
        untaggedScheduleIDs.append(scheduleID)
        if storedSchedule?.id == scheduleID { storedSchedule = nil }
    }

    func searchSchedules(
        memberID: MemberID,
        query: String,
        page: Int
    ) async throws -> PageResponse<ScheduleSearchResultDTO> {
        try JSONDecoder().decode(
            PageResponse<ScheduleSearchResultDTO>.self,
            from: Data(#"{"content":[],"totalPages":0,"totalElements":0,"last":true,"first":true,"size":10,"number":0,"numberOfElements":0,"empty":true}"#.utf8)
        )
    }

    func scheduleBasic(id: ScheduleID) async throws -> ScheduleBasicInfoDTO {
        ScheduleBasicInfoDTO(
            id: id,
            memberId: scheduleOwnerID,
            memberName: "Owner",
            startDateTime: LocalDateTimeValue(rawValue: "2026-08-12T00:00:00"),
            content: "Shared shift"
        )
    }

    func updateDuty(_ request: DutyUpdateDTO) async throws {}
    func batchUpdateDuty(_ request: DutyBatchUpdateDTO) async throws {}

    func uploadDutyBatch(
        memberID: MemberID,
        year: Int,
        month: Int,
        filename: String,
        data: Data
    ) async throws -> DutyBatchUploadResult {
        DutyBatchUploadResult(
            result: true,
            errorCode: nil,
            errorDetails: nil,
            startDate: nil,
            endDate: nil,
            workingDays: 0,
            offDays: 0
        )
    }

    func saveDDay(_ request: DDaySaveDTO) async throws -> DDayDTO {
        let item = DDayDTO(
            id: request.id ?? 100,
            title: request.title,
            date: request.date,
            isPrivate: request.isPrivate,
            calc: 0,
            daysLeft: 0
        )
        storedDDays = [item]
        return item
    }

    func deleteDDay(id: Int64) async throws {
        deletedDDayIDs.append(id)
        storedDDays.removeAll { $0.id == id }
    }

    nonisolated private static func gridDays(year: Int, month: Int) -> [TeamDayDTO] {
        let calendar = CalendarDateSupport.calendar
        guard let firstOfMonth = calendar.date(
            from: DateComponents(year: year, month: month, day: 1)
        ) else { return [] }
        let weekdayOffset = (
            calendar.component(.weekday, from: firstOfMonth)
                - calendar.firstWeekday
                + 7
        ) % 7
        guard let gridStart = calendar.date(
            byAdding: .day,
            value: -weekdayOffset,
            to: firstOfMonth
        ) else { return [] }

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else {
                return nil
            }
            let parts = calendar.dateComponents([.year, .month, .day], from: date)
            guard let cellYear = parts.year,
                  let cellMonth = parts.month,
                  let cellDay = parts.day
            else { return nil }
            return TeamDayDTO(year: cellYear, month: cellMonth, day: cellDay)
        }
    }

    nonisolated static func schedule(
        id: ScheduleID,
        memberID: MemberID,
        content: String,
        isTagged: Bool,
        year: Int = 2026,
        month: Int = 8,
        day: Int = 12,
        description: String = "",
        visibility: Visibility = .friends
    ) -> ScheduleDTO {
        let date = String(format: "%04d-%02d-%02d", year, month, day)
        return ScheduleDTO(
            id: id,
            content: content,
            description: description,
            position: 0,
            year: year,
            month: month,
            dayOfMonth: day,
            startDateTime: LocalDateTimeValue(rawValue: "\(date)T00:00:00"),
            endDateTime: LocalDateTimeValue(rawValue: "\(date)T01:00:00"),
            isTagged: isTagged,
            owner: "Member \(memberID)",
            taggedByMember: nil,
            tags: [],
            visibility: visibility,
            dateToCompare: DateOnly(rawValue: date),
            attachments: [],
            startDate: DateOnly(rawValue: date),
            daysFromStart: 1,
            endDate: DateOnly(rawValue: date),
            curDate: DateOnly(rawValue: date),
            totalDays: 1
        )
    }

    nonisolated private static func dateParts(
        _ value: LocalDateTimeValue
    ) -> (year: Int, month: Int, day: Int) {
        let values = value.rawValue.prefix(10).split(separator: "-").compactMap { Int($0) }
        return (values[0], values[1], values[2])
    }
}
