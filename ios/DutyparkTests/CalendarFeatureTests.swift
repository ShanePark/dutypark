import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class CalendarFeatureTests: XCTestCase {
    func testScheduleFormStringsResolveFromCalendarTableInEveryLocale() throws {
        let keys = [
            "calendar.schedule.attachments",
            "calendar.schedule.content.placeholder",
            "calendar.schedule.description.placeholder",
            "calendar.schedule.startTime",
            "calendar.schedule.tags.search",
            "calendar.schedule.tags.selected",
            "calendar.schedule.tags.selectedOnly",
            "calendar.schedule.tags.clear",
            "calendar.schedule.tags.empty",
            "calendar.search.short",
            "calendar.compare.empty",
            "calendar.compare.reset",
            "calendar.todo.manage",
            "calendar.todo.add"
        ]

        for locale in ["en", "ko", "ja", "zh-Hans", "es"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try XCTUnwrap(Bundle(url: url))
            for key in keys {
                XCTAssertNotEqual(
                    bundle.localizedString(forKey: key, value: key, table: "Calendar"),
                    key,
                    "Missing \(key) for \(locale)"
                )
            }
        }
    }

    func testScheduleEditorDisablesInteractionsWhileAttachmentIsUploading() {
        XCTAssertTrue(
            ScheduleEditorInteractionPolicy.interactionsDisabled(
                isSaving: false,
                isUploading: true
            )
        )
        XCTAssertTrue(
            ScheduleEditorInteractionPolicy.interactionsDisabled(
                isSaving: true,
                isUploading: false
            )
        )
        XCTAssertFalse(
            ScheduleEditorInteractionPolicy.interactionsDisabled(
                isSaving: false,
                isUploading: false
            )
        )
    }

    func testLoadBuildsTheServerFortyTwoCellCalendar() async {
        let repository = CalendarRepositoryMock()
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))

        await model.load()

        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.days.count, 42)
        XCTAssertEqual(model.days.first?.cell.date.rawValue, "2026-08-01")
        XCTAssertEqual(model.days[11].schedules.first?.content, "Night duty")
    }

    func testCancelledCalendarLoadDoesNotShowAnError() async {
        let repository = CalendarRepositoryMock(cancelMemberLoad: true)
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))

        await model.load()

        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    func testMonthNavigationCrossesTheYearBoundary() async {
        let repository = CalendarRepositoryMock()
        let model = CalendarViewModel(repository: repository, now: date(2026, 12, 1))
        await model.load()

        await model.changeMonth(by: 1)
        XCTAssertEqual(model.year, 2027)
        XCTAssertEqual(model.month, 1)

        await model.changeMonth(by: -1)
        XCTAssertEqual(model.year, 2026)
        XCTAssertEqual(model.month, 12)
    }

    func testScheduleSavePreservesEveryOrderedAttachmentIdentifier() async {
        let repository = CalendarRepositoryMock()
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))
        await model.load()
        let first = UUID(uuidString: "03fd1901-043b-4e65-bf3a-655f6be0a45a")!
        let second = UUID(uuidString: "13fd1901-043b-4e65-bf3a-655f6be0a45a")!
        let session = UUID()

        let saved = await model.saveSchedule(
            existing: nil,
            content: "Dinner",
            description: "",
            visibility: .friends,
            start: date(2026, 8, 12),
            end: date(2026, 8, 12, hour: 1),
            tagFriendIDs: [],
            attachmentSessionID: session,
            orderedAttachmentIDs: [first, second]
        )

        let request = await repository.savedSchedule
        XCTAssertTrue(saved)
        XCTAssertEqual(request?.attachmentSessionId, session)
        XCTAssertEqual(request?.orderedAttachmentIds, [first, second])
        XCTAssertEqual(request?.startDateTime.rawValue, "2026-08-12T00:00:00")
    }

    func testDeepLinkInitializesTargetMemberAndHighlightedMonth() async {
        let repository = CalendarRepositoryMock()
        let model = CalendarViewModel(
            repository: repository,
            now: date(2026, 1, 1),
            memberID: 9,
            date: DateOnly(rawValue: "2027-03-15")
        )

        XCTAssertEqual(model.selectedMemberID, 9)
        XCTAssertEqual(model.year, 2027)
        XCTAssertEqual(model.month, 3)
        XCTAssertEqual(model.highlightedDate?.rawValue, "2027-03-15")
    }

    func testTaggedScheduleRouteKeepsAuthenticatedCalendarTargetWhileLoadingScheduleDate() async {
        let scheduleID = UUID(uuidString: "9a53c095-c8b0-4de7-91be-b2fef4134e2a")!
        let repository = CalendarRepositoryMock(scheduleOwnerID: 9)
        let targetMemberID = RootNavigationPolicy.scheduleMemberID(
            for: .taggedSchedule(scheduleID),
            authenticatedMemberID: 1,
            scheduleOwnerID: 9
        )
        let model = CalendarViewModel(
            repository: repository,
            now: date(2026, 1, 1),
            memberID: targetMemberID,
            scheduleID: scheduleID
        )

        await model.load()

        XCTAssertEqual(model.selectedMemberID, 1)
        XCTAssertTrue(model.isMyCalendar)
        XCTAssertEqual(model.year, 2026)
        XCTAssertEqual(model.month, 8)
        XCTAssertEqual(model.highlightedDate?.rawValue, "2026-08-12")
        let requestedPreviewMemberID = await repository.requestedPreviewMemberID
        let requestedScheduleMemberID = await repository.requestedScheduleMemberID
        let requestedDDayMemberID = await repository.requestedDDayMemberID
        XCTAssertNil(requestedPreviewMemberID)
        XCTAssertEqual(requestedScheduleMemberID, 1)
        XCTAssertEqual(requestedDDayMemberID, 1)
    }

    func testScheduleDeepLinkWithoutMemberTargetLoadsTheScheduleOwnersCalendar() async {
        let scheduleID = UUID(uuidString: "9a53c095-c8b0-4de7-91be-b2fef4134e2a")!
        let repository = CalendarRepositoryMock(scheduleOwnerID: 9)
        let model = CalendarViewModel(
            repository: repository,
            now: date(2026, 1, 1),
            scheduleID: scheduleID
        )

        await model.load()

        let requestedPreviewMemberID = await repository.requestedPreviewMemberID
        let requestedScheduleMemberID = await repository.requestedScheduleMemberID
        let requestedDDayMemberID = await repository.requestedDDayMemberID
        XCTAssertEqual(model.selectedMemberID, 9)
        XCTAssertFalse(model.isMyCalendar)
        XCTAssertEqual(requestedPreviewMemberID, 9)
        XCTAssertEqual(requestedScheduleMemberID, 9)
        XCTAssertEqual(requestedDDayMemberID, 9)
    }

    func testManagerCannotBatchReplaceAnotherMembersMonth() async {
        let repository = CalendarRepositoryMock(canManage: true)
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12), memberID: 9)
        await model.load()

        XCTAssertTrue(model.canManage)
        XCTAssertTrue(model.canEdit)
        XCTAssertFalse(model.isMyCalendar)
        await model.batchUpdateDuty(dutyTypeID: 7)

        let batchUpdateCount = await repository.batchUpdateCount
        XCTAssertEqual(batchUpdateCount, 0)
    }

    func testManagerCanUseQuickDutyInputForDelegatedCalendar() async {
        let repository = CalendarRepositoryMock(canManage: true)
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12), memberID: 9)
        await model.load()

        model.setQuickDutyEditing(true)
        await model.applyQuickDuty(dutyTypeID: 7)

        let lastDutyUpdate = await repository.lastDutyUpdate
        XCTAssertTrue(model.isQuickDutyEditing)
        XCTAssertEqual(lastDutyUpdate?.memberId, 9)
        XCTAssertEqual(lastDutyUpdate?.dutyTypeId, 7)
    }

    func testPublicNonFriendCalendarLoadsMemberPreview() async {
        let repository = CalendarRepositoryMock()
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12), memberID: 9)

        await model.load()

        XCTAssertEqual(model.targetName, "Public member")
        XCTAssertEqual(model.targetTeamName, "Public team")
        XCTAssertTrue(model.targetHasProfilePhoto)
        XCTAssertEqual(model.targetProfilePhotoVersion, 12)
        let requestedPreviewMemberID = await repository.requestedPreviewMemberID
        XCTAssertEqual(requestedPreviewMemberID, 9)
    }

    func testDirectYearMonthSelectionLoadsRequestedMonth() async {
        let repository = CalendarRepositoryMock()
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))
        await model.load()

        await model.selectYearMonth(year: 2028, month: 2)

        XCTAssertEqual(model.year, 2028)
        XCTAssertEqual(model.month, 2)
    }

    func testQuickDutyInputAdvancesToNextCurrentMonthDay() async {
        let repository = CalendarRepositoryMock()
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))
        await model.load()
        model.focusQuickDuty(on: model.days[11])

        await model.applyQuickDuty(dutyTypeID: 7)

        let lastDutyUpdate = await repository.lastDutyUpdate
        XCTAssertEqual(lastDutyUpdate?.day, 12)
        XCTAssertEqual(model.quickDutyDay?.cell.day, 13)
    }

    func testOtherCalendarCanOnlyCompareMyDuty() async {
        let repository = CalendarRepositoryMock()
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12), memberID: 9)
        await model.load()

        await model.toggleMyDutyComparison()
        XCTAssertEqual(model.comparedMemberIDs, [1])

        await model.toggleMyDutyComparison()
        XCTAssertTrue(model.comparedMemberIDs.isEmpty)
    }

    func testComparisonSelectionOnlyAcceptsKnownFriendsAndThreeMembers() async {
        let repository = CalendarRepositoryMock(friends: [
            FriendDTO(id: 2, name: "A", teamId: nil, team: nil, hasProfilePhoto: false, profilePhotoVersion: 0, isFamily: false, pinOrder: nil),
            FriendDTO(id: 3, name: "B", teamId: nil, team: nil, hasProfilePhoto: false, profilePhotoVersion: 0, isFamily: false, pinOrder: nil),
            FriendDTO(id: 4, name: "C", teamId: nil, team: nil, hasProfilePhoto: false, profilePhotoVersion: 0, isFamily: false, pinOrder: nil),
            FriendDTO(id: 5, name: "D", teamId: nil, team: nil, hasProfilePhoto: false, profilePhotoVersion: 0, isFamily: false, pinOrder: nil)
        ])
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))
        await model.load()

        await model.setFriendDutyComparisons([2, 3, 4, 5, 999])

        XCTAssertEqual(model.comparedMemberIDs.count, 3)
        XCTAssertTrue(model.comparedMemberIDs.isSubset(of: [2, 3, 4, 5]))
    }

    func testPatternWithHiddenSelectedDutyCannotBeSaved() {
        XCTAssertFalse(CalendarFeatureLogic.canSavePattern(selectedDutyTypeIDs: [10], visibleDutyTypeIDs: [11]))
        XCTAssertTrue(CalendarFeatureLogic.canSavePattern(selectedDutyTypeIDs: [11], visibleDutyTypeIDs: [11]))
        XCTAssertTrue(CalendarFeatureLogic.canSavePattern(selectedDutyTypeIDs: [], visibleDutyTypeIDs: [11]))
    }

    func testCalendarShareLinkUsesPublicDutyRoute() {
        XCTAssertEqual(
            CalendarPublicLink.url(memberID: 42).absoluteString,
            "https://dutypark.o-r.kr/duty/42"
        )
    }

    func testCalendarLocaleUsesTheAppSelectedLanguage() {
        XCTAssertEqual(CalendarLocalization.locale(languageCode: "ko").identifier, "ko")
        XCTAssertEqual(CalendarLocalization.locale(languageCode: "zh-Hans").identifier, "zh-Hans")
    }

    func testCompactCalendarModalBodyFitsContentAndCapsForSmallPhones() {
        let maximumPanelHeight: CGFloat = 780

        XCTAssertEqual(CalendarCompactModalLayout.maximumPanelHeightRatio, 0.9)
        XCTAssertEqual(
            CalendarCompactModalLayout.bodyHeight(
                contentHeight: 360,
                maximumPanelHeight: maximumPanelHeight,
                fixedChromeHeight: 140
            ),
            360
        )
        XCTAssertEqual(
            CalendarCompactModalLayout.bodyHeight(
                contentHeight: 900,
                maximumPanelHeight: maximumPanelHeight,
                fixedChromeHeight: 140
            ),
            640
        )
    }

    func testFriendDutyComparisonIsLimitedToThreeAndAllowsDeselection() {
        let selected = CalendarFeatureLogic.comparisonSelection(current: [1, 2], toggling: 3)
        XCTAssertEqual(selected, [1, 2, 3])
        XCTAssertEqual(
            CalendarFeatureLogic.comparisonSelection(current: selected, toggling: 4),
            selected
        )
        XCTAssertEqual(
            CalendarFeatureLogic.comparisonSelection(current: selected, toggling: 2),
            [1, 3]
        )
    }

    func testPatternRequestContainsOnlySelectedWeekdays() {
        let days = CalendarFeatureLogic.patternDays(
            weekdays: [.monday, .tuesday, .wednesday],
            selections: [.monday: 7, .wednesday: 9]
        )

        XCTAssertEqual(days.map(\.weekday), [.monday, .wednesday])
        XCTAssertEqual(days.map(\.dutyTypeId), [7, 9])
    }

    func testDutyBatchUsesOnlyTemplateFileExtensions() {
        XCTAssertEqual(
            CalendarFeatureLogic.normalizedFileExtensions([".XLS", "xlsx", " .xlsx ", ""]),
            [".xls", ".xlsx"]
        )
        XCTAssertTrue(
            CalendarFeatureLogic.isSupportedDutyBatchFile(
                fileName: "roster.xls",
                fileExtensions: [".xls", ".xlsx"]
            )
        )
        XCTAssertFalse(
            CalendarFeatureLogic.isSupportedDutyBatchFile(
                fileName: "roster.csv",
                fileExtensions: [".xls", ".xlsx"]
            )
        )
    }

    func testCalendarUsesTheSameCompactCellMinimumAsMobileWeb() {
        XCTAssertEqual(CalendarVisualLogic.compactCellMinimumHeight, 60)
        XCTAssertEqual(CalendarVisualLogic.regularCellMinimumHeight, 80)
        XCTAssertEqual(CalendarVisualLogic.maximumSchedulesPerCell, 3)
        XCTAssertEqual(CalendarVisualLogic.maximumTodosPerCell, 2)
    }

    func testCalendarTypographyMatchesReadableMobileWebScale() {
        XCTAssertEqual(CalendarTypography.weekday, 14)
        XCTAssertEqual(CalendarTypography.dayNumber, 12)
        XCTAssertEqual(CalendarTypography.cellContent, 10)
        XCTAssertEqual(CalendarTypography.cellMicro, 9)
        XCTAssertEqual(CalendarTypography.detailTitle, 16)
        XCTAssertEqual(CalendarTypography.detailMetadata, 14)
        XCTAssertGreaterThanOrEqual(CalendarTypography.cellContent, 10)
    }

    func testDutyBackgroundUsesAdaptiveForegroundContrast() {
        XCTAssertTrue(CalendarVisualLogic.usesLightForeground(on: "#111827"))
        XCTAssertTrue(CalendarVisualLogic.usesLightForeground(on: "3B82F6"))
        XCTAssertFalse(CalendarVisualLogic.usesLightForeground(on: "#FCD34D"))
        XCTAssertTrue(CalendarVisualLogic.usesLightForeground(on: "#7F7F7F"))
        XCTAssertFalse(CalendarVisualLogic.usesLightForeground(on: "#808080"))
        XCTAssertFalse(CalendarVisualLogic.usesLightForeground(on: nil))
    }

    func testReadOnlyFriendCalendarDoesNotOfferScheduleSearch() async {
        let readOnly = CalendarViewModel(
            repository: CalendarRepositoryMock(canManage: false),
            now: date(2026, 8, 12),
            memberID: 9
        )
        await readOnly.load()
        XCTAssertFalse(readOnly.canSearchSchedules)

        let manager = CalendarViewModel(
            repository: CalendarRepositoryMock(canManage: true),
            now: date(2026, 8, 12),
            memberID: 9
        )
        await manager.load()
        XCTAssertTrue(manager.canSearchSchedules)
    }

    func testDutyColorParserRejectsMalformedValues() {
        XCTAssertNil(CalendarVisualLogic.rgb(nil))
        XCTAssertNil(CalendarVisualLogic.rgb("#12345"))
        XCTAssertNil(CalendarVisualLogic.rgb("not-a-color"))
    }

    func testDutyColorParserAcceptsHashAndBareHex() {
        let hashed = CalendarVisualLogic.rgb("#3B82F6")
        let bare = CalendarVisualLogic.rgb("3b82f6")

        XCTAssertEqual(hashed?.red, 59)
        XCTAssertEqual(hashed?.green, 130)
        XCTAssertEqual(hashed?.blue, 246)
        XCTAssertEqual(hashed?.red, bare?.red)
        XCTAssertEqual(hashed?.green, bare?.green)
        XCTAssertEqual(hashed?.blue, bare?.blue)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        CalendarDateSupport.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}

private actor CalendarRepositoryMock: CalendarRepositoryProtocol {
    var savedSchedule: ScheduleSaveDTO?
    var batchUpdateCount = 0
    var requestedPreviewMemberID: MemberID?
    var requestedScheduleMemberID: MemberID?
    var requestedDDayMemberID: MemberID?
    var lastDutyUpdate: DutyUpdateDTO?
    let canManageValue: Bool
    let cancelMemberLoad: Bool
    let friendValues: [FriendDTO]
    let scheduleOwnerID: MemberID

    init(
        canManage: Bool = false,
        cancelMemberLoad: Bool = false,
        friends: [FriendDTO] = [],
        scheduleOwnerID: MemberID = 1
    ) {
        canManageValue = canManage
        self.cancelMemberLoad = cancelMemberLoad
        friendValues = friends
        self.scheduleOwnerID = scheduleOwnerID
    }

    func member() async throws -> MemberDTO {
        if cancelMemberLoad { throw CancellationError() }
        return MemberDTO(
            id: 1, name: "Tester", email: "test@duty.park", teamId: nil, team: nil,
            calendarVisibility: .friends, kakaoId: nil, naverId: nil, hasPassword: true,
            hasProfilePhoto: false, profilePhotoVersion: 0
        )
    }
    func member(id: MemberID) async throws -> MemberPreviewDTO {
        requestedPreviewMemberID = id
        return MemberPreviewDTO(id: id, name: "Public member", teamId: nil, team: "Public team", hasProfilePhoto: true, profilePhotoVersion: 12)
    }
    func friends() async throws -> [FriendDTO] { friendValues }
    func team(id: TeamID) async throws -> TeamDTO { throw APIError.invalidResponse }
    func canManage(memberID: MemberID) async throws -> Bool { canManageValue }
    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO] {
        (1...42).map { TeamDayDTO(year: year, month: month, day: $0) }
    }
    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO] { [] }
    func otherDuties(memberIDs: [MemberID], year: Int, month: Int) async throws -> [OtherDutyResponse] { [] }
    func schedules(memberID: MemberID, year: Int, month: Int) async throws -> [[ScheduleDTO]] {
        requestedScheduleMemberID = memberID
        var result = Array(repeating: [ScheduleDTO](), count: 42)
        result[11] = [schedule(year: year, month: month)]
        return result
    }
    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]] { Array(repeating: [], count: 42) }
    func dDays(memberID: MemberID, isMine: Bool) async throws -> [DDayDTO] {
        requestedDDayMemberID = memberID
        return []
    }
    func todoBoard() async throws -> TodoBoardDTO {
        TodoBoardDTO(todo: [], inProgress: [], done: [], counts: TodoCountsDTO(todo: 0, inProgress: 0, done: 0, total: 0))
    }
    func saveSchedule(_ request: ScheduleSaveDTO) async throws -> ScheduleSaveResponse {
        savedSchedule = request
        return ScheduleSaveResponse(id: UUID())
    }
    func deleteSchedule(id: ScheduleID) async throws {}
    func reorderSchedules(ids: [ScheduleID]) async throws {}
    func untagSelf(scheduleID: ScheduleID) async throws {}
    func searchSchedules(memberID: MemberID, query: String, page: Int) async throws -> PageResponse<ScheduleSearchResultDTO> {
        try JSONDecoder().decode(PageResponse<ScheduleSearchResultDTO>.self, from: Data(#"{"content":[],"totalPages":0,"totalElements":0,"last":true,"first":true,"size":10,"number":0,"numberOfElements":0,"empty":true}"#.utf8))
    }
    func scheduleBasic(id: ScheduleID) async throws -> ScheduleBasicInfoDTO {
        ScheduleBasicInfoDTO(id: id, memberId: scheduleOwnerID, memberName: "Tester", startDateTime: LocalDateTimeValue(rawValue: "2026-08-12T00:00:00"), content: "Night duty")
    }
    func updateDuty(_ request: DutyUpdateDTO) async throws { lastDutyUpdate = request }
    func batchUpdateDuty(_ request: DutyBatchUpdateDTO) async throws { batchUpdateCount += 1 }
    func uploadDutyBatch(memberID: MemberID, year: Int, month: Int, filename: String, data: Data) async throws -> DutyBatchUploadResult {
        DutyBatchUploadResult(result: true, errorCode: nil, errorDetails: nil, startDate: nil, endDate: nil, workingDays: 20, offDays: 10)
    }
    func dutyPattern() async throws -> DutyPatternDTO { DutyPatternDTO(configurable: false, reason: nil, dutyTypes: [], pattern: nil) }
    func updateDutyPattern(_ request: DutyPatternUpdateDTO) async throws -> DutyPatternDTO { try await dutyPattern() }
    func deleteDutyPattern() async throws {}
    func saveDDay(_ request: DDaySaveDTO) async throws -> DDayDTO { DDayDTO(id: 1, title: request.title, date: request.date, isPrivate: request.isPrivate, calc: 0, daysLeft: 0) }
    func deleteDDay(id: Int64) async throws {}

    private func schedule(year: Int, month: Int) -> ScheduleDTO {
        ScheduleDTO(
            id: UUID(), content: "Night duty", description: "", position: 0,
            year: year, month: month, dayOfMonth: 12,
            startDateTime: LocalDateTimeValue(rawValue: String(format: "%04d-%02d-12T00:00:00", year, month)),
            endDateTime: LocalDateTimeValue(rawValue: String(format: "%04d-%02d-12T01:00:00", year, month)),
            isTagged: false, owner: "Tester", taggedByMember: nil, tags: [], visibility: .friends,
            dateToCompare: DateOnly(rawValue: String(format: "%04d-%02d-12", year, month)), attachments: [],
            startDate: DateOnly(rawValue: String(format: "%04d-%02d-12", year, month)), daysFromStart: 1,
            endDate: DateOnly(rawValue: String(format: "%04d-%02d-12", year, month)),
            curDate: DateOnly(rawValue: String(format: "%04d-%02d-12", year, month)), totalDays: 1
        )
    }
}
