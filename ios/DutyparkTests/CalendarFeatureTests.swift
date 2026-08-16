import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class CalendarFeatureTests: XCTestCase {
    func testCalendarTodoAddUsesTheQuickCreateModalAndTodoOnlyRefresh() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Calendar/CalendarView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("TodoCreateModal("))
        XCTAssertTrue(source.contains("initialStatus: .inProgress"))
        XCTAssertTrue(source.contains("refreshBoardAfterCreate: false"))
        XCTAssertTrue(source.contains("onCreated: { await model.refreshTodoBoard() }"))
        XCTAssertTrue(source.contains("TodoDetailModal("))
        XCTAssertTrue(source.contains("Button { openTodo(todo) }"))
        XCTAssertTrue(source.contains("calendar.day.todo.\\(todo.id)"))
        XCTAssertFalse(source.contains("todoDetailModel.load()"))
        XCTAssertFalse(source.contains("TodoView("), "Calendar Todo bubbles must not present the full board")
        XCTAssertFalse(source.contains("private func openTodoBoard()"), "Calendar keeps only the quick-add entry")
    }

    func testCalendarHeaderAllocatesEqualSidesAroundMonthNavigation() {
        XCTAssertEqual(
            CalendarMainLayout.headerSideWidth(
                containerWidth: 359,
                monthControlsWidth: 176,
                interColumnSpacing: 2
            ),
            89.5
        )
        XCTAssertEqual(
            CalendarMainLayout.headerSideWidth(
                containerWidth: 160,
                monthControlsWidth: 176,
                interColumnSpacing: 2
            ),
            0
        )
    }

    func testComparedDutyRetainsProfileMetadataForCalendarAvatar() async throws {
        let response = OtherDutyResponse(
            memberId: 2,
            name: "Profile friend",
            hasProfilePhoto: true,
            profilePhotoVersion: 17,
            duties: [DutyDTO(
                year: 2026,
                month: 8,
                day: 12,
                dutyType: "Day",
                dutyColor: "#3B82F6",
                isOff: false,
                dutyTypeId: 7,
                source: .override
            )]
        )
        let repository = CalendarRepositoryMock(otherDuties: [response])
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))
        model.comparedMemberIDs = [response.memberId]

        await model.load()

        let item = try XCTUnwrap(
            model.days.first { $0.cell.day == 12 }?.comparedDuties.first
        )
        XCTAssertEqual(item.memberID, response.memberId)
        XCTAssertEqual(item.name, response.name)
        XCTAssertTrue(item.hasProfilePhoto)
        XCTAssertEqual(item.profilePhotoVersion, response.profilePhotoVersion)
    }

    func testSharedFriendTagSelectorMergesCurrentAndSelectedStaleItems() {
        let current = tagItem(id: 1, name: "Current name", team: "New team", isFamily: true, pinOrder: 2)
        let staleDuplicate = tagItem(id: 1, name: "Old name", team: "Old team")
        let selectedStale = tagItem(id: 2, name: "Former friend", team: "Previous team")
        let unselectedStale = tagItem(id: 3, name: "Hidden", team: nil)

        let merged = DPFriendTagSelectionLogic.mergedItems(
            items: [current],
            preservedItems: [staleDuplicate, selectedStale, unselectedStale],
            selection: [1, 2]
        )

        XCTAssertEqual(merged.map(\.id), [1, 2])
        XCTAssertEqual(merged.first, current, "The current friend record must win over a stale summary")
    }

    func testSharedFriendTagSelectorUsesPinFamilyNameAndIDOrder() {
        let items = [
            tagItem(id: 9, name: "Zed", team: nil),
            tagItem(id: 8, name: "Amy", team: nil, isFamily: false),
            tagItem(id: 7, name: "Zed", team: nil, isFamily: true),
            tagItem(id: 6, name: "Amy", team: nil, isFamily: true),
            tagItem(id: 5, name: "Same", team: nil, pinOrder: 2),
            tagItem(id: 4, name: "Same", team: nil, pinOrder: 2),
            tagItem(id: 3, name: "Pinned", team: nil, pinOrder: 1)
        ]

        let merged = DPFriendTagSelectionLogic.mergedItems(
            items: items,
            preservedItems: [],
            selection: []
        )

        XCTAssertEqual(merged.map(\.id), [3, 4, 5, 6, 7, 8, 9])
    }

    func testSharedFriendTagSelectorFiltersNameAndTeamAndIntersectsSelectedOnly() {
        let items = [
            tagItem(id: 1, name: "Alice", team: "Emergency"),
            tagItem(id: 2, name: "Bob", team: "Emergency"),
            tagItem(id: 3, name: "Carol", team: "Ward")
        ]

        XCTAssertEqual(
            DPFriendTagSelectionLogic.visibleItems(
                items: items,
                query: "emerg",
                selectedOnly: false,
                selection: [2]
            ).map(\.id),
            [1, 2]
        )
        XCTAssertEqual(
            DPFriendTagSelectionLogic.visibleItems(
                items: items,
                query: "emerg",
                selectedOnly: true,
                selection: [2, 3]
            ).map(\.id),
            [2]
        )
        XCTAssertEqual(
            DPFriendTagSelectionLogic.visibleItems(
                items: items,
                query: "alice",
                selectedOnly: false,
                selection: []
            ).map(\.id),
            [1]
        )
    }

    func testFriendTagAdaptersSkipNilMemberIDs() {
        let member = MemberDTO(
            id: nil, name: "No ID", email: nil, teamId: nil, team: nil,
            calendarVisibility: .friends, kakaoId: nil, naverId: nil,
            hasPassword: false, hasProfilePhoto: false, profilePhotoVersion: 0
        )
        let preview = MemberPreviewDTO(
            id: nil, name: "No ID", teamId: nil, team: nil,
            hasProfilePhoto: false, profilePhotoVersion: 0
        )

        XCTAssertNil(DPFriendTagAdapter.item(member))
        XCTAssertNil(DPFriendTagAdapter.item(preview))
        XCTAssertNil(TodoFriendTagAdapter.item(preview))
    }

    func testSharedFriendTagSelectionMapsPayloadInStableOrder() {
        XCTAssertEqual(DPFriendTagSelectionLogic.sortedIDs([30, 10, 20]), [10, 20, 30])
    }

    func testScheduleFriendTagSelectorRemainsVisibleForSelectedStaleTags() {
        XCTAssertTrue(ScheduleFriendTagSelectorPolicy.shouldShow(
            isMyCalendar: true,
            currentFriendCount: 0,
            selectedIDs: [42],
            preservedValidIDCount: 1
        ))
        XCTAssertTrue(ScheduleFriendTagSelectorPolicy.shouldShow(
            isMyCalendar: true,
            currentFriendCount: 0,
            selectedIDs: [],
            preservedValidIDCount: 1
        ))
        XCTAssertFalse(ScheduleFriendTagSelectorPolicy.shouldShow(
            isMyCalendar: true,
            currentFriendCount: 0,
            selectedIDs: [],
            preservedValidIDCount: 0
        ))
        XCTAssertFalse(ScheduleFriendTagSelectorPolicy.shouldShow(
            isMyCalendar: false,
            currentFriendCount: 1,
            selectedIDs: [42],
            preservedValidIDCount: 1
        ))
    }

    func testSharedFriendTagStringsResolveInEveryLocale() throws {
        let keys = [
            "friendTag.clear", "friendTag.clearSearch", "friendTag.empty", "friendTag.expand",
            "friendTag.noneSelected", "friendTag.notSelectedState", "friendTag.search",
            "friendTag.selected", "friendTag.selectedOnly", "friendTag.selectedState", "friendTag.title"
        ]

        for locale in ["en", "ko"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try XCTUnwrap(Bundle(url: url))
            for key in keys {
                XCTAssertNotEqual(
                    bundle.localizedString(forKey: key, value: key, table: "Localizable"),
                    key,
                    "Missing \(key) for \(locale)"
                )
            }
        }
    }

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
            "calendar.todo.add",
            "calendar.search.hint",
            "calendar.search.empty",
            "calendar.search.summary",
            "calendar.schedule.delete.confirm.title",
            "calendar.schedule.delete.confirm.message",
            "calendar.schedule.untag.confirm.title",
            "calendar.schedule.untag.confirm.message",
            "calendar.dday.detail.title",
            "calendar.dday.edit.action",
            "calendar.dday.pin.enabled",
            "calendar.dday.pin.disabled",
            "calendar.dday.pin.action",
            "calendar.dday.delete.confirm.title",
            "calendar.dday.delete.confirm.message",
            "calendar.duty.batch.description.month",
            "calendar.duty.batch.description.selection",
            "calendar.month.current",
            "calendar.discard.title",
            "calendar.discard.message",
            "calendar.discard.action"
        ]

        for locale in ["en", "ko"] {
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

    func testDDayDetailMutationsAreOnlyAvailableOnMyCalendar() {
        XCTAssertTrue(CalendarDDayDetailPolicy.canManage(isMyCalendar: true))
        XCTAssertFalse(CalendarDDayDetailPolicy.canManage(isMyCalendar: false))
    }

    func testDestructiveModalRejectsDuplicateConfirmationWhileWorking() {
        XCTAssertTrue(CalendarDestructiveActionPolicy.canBegin(isWorking: false))
        XCTAssertFalse(CalendarDestructiveActionPolicy.canBegin(isWorking: true))
    }

    func testDDayEditorDeleteUsesOnlyTheCentralConfirmationRoute() {
        XCTAssertEqual(
            CalendarDDayEditorDeleteRoutingPolicy.route(
                hasExistingDDay: true,
                hasCentralConfirmationHandler: true
            ),
            .centralConfirmation
        )
        XCTAssertEqual(
            CalendarDDayEditorDeleteRoutingPolicy.route(
                hasExistingDDay: true,
                hasCentralConfirmationHandler: false
            ),
            .unavailable
        )
        XCTAssertEqual(
            CalendarDDayEditorDeleteRoutingPolicy.route(
                hasExistingDDay: false,
                hasCentralConfirmationHandler: true
            ),
            .unavailable
        )
    }

    func testDDayDeleteSuccessEnablesDismissalBeforeYieldingToPresenter() async {
        var events: [String] = []

        await CalendarDDayDeleteSuccessDismissalPolicy.prepareForDismiss(
            authorizeDismiss: {
                events.append("enabled")
            },
            yieldTurn: {
                events.append("yielded")
            }
        )
        events.append("dismissed")

        XCTAssertEqual(events, ["enabled", "yielded", "dismissed"])
    }

    func testCalendarModalDismissabilityBlocksEditorsAndWorkingMutations() {
        XCTAssertTrue(CalendarModalDismissabilityPolicy.dayCanDismiss(
            isEditorWorking: false,
            hasDestructiveAction: false,
            isPerformingDestructiveAction: false
        ))
        XCTAssertFalse(CalendarModalDismissabilityPolicy.dayCanDismiss(
            isEditorWorking: true,
            hasDestructiveAction: false,
            isPerformingDestructiveAction: false
        ))
        XCTAssertFalse(CalendarModalDismissabilityPolicy.dayCanDismiss(
            isEditorWorking: false,
            hasDestructiveAction: true,
            isPerformingDestructiveAction: false
        ))
        XCTAssertFalse(CalendarModalDismissabilityPolicy.dayCanDismiss(
            isEditorWorking: false,
            hasDestructiveAction: false,
            isPerformingDestructiveAction: true
        ))
        XCTAssertTrue(CalendarModalDismissabilityPolicy.dDayCanDismiss(
            isWorking: false,
            isConfirmingDelete: false
        ))
        XCTAssertFalse(CalendarModalDismissabilityPolicy.dDayCanDismiss(
            isWorking: true,
            isConfirmingDelete: false
        ))
        XCTAssertFalse(CalendarModalDismissabilityPolicy.dDayCanDismiss(
            isWorking: false,
            isConfirmingDelete: true
        ))
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
        XCTAssertTrue(
            ScheduleEditorInteractionPolicy.interactionsDisabled(
                isSaving: false,
                isUploading: false,
                isDiscarding: true
            )
        )
    }

    func testScheduleEditorDismissalDetectsFieldAndAttachmentChanges() {
        let initialDate = Date(timeIntervalSince1970: 100)
        let attachmentID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let unchanged = ScheduleEditorDismissalPolicy.isDirty(
            initialContent: "Shift", content: "Shift",
            initialDescription: "Notes", description: "Notes",
            initialVisibility: .family, visibility: .family,
            initialStart: initialDate, start: initialDate,
            initialEnd: initialDate, end: initialDate,
            initialTagIDs: [1], tagIDs: [1],
            initialAttachmentIDs: [attachmentID], attachmentIDs: [attachmentID],
            hasAttachmentSession: false
        )
        XCTAssertFalse(unchanged)

        XCTAssertTrue(ScheduleEditorDismissalPolicy.isDirty(
            initialContent: "Shift", content: "Changed",
            initialDescription: "Notes", description: "Notes",
            initialVisibility: .family, visibility: .family,
            initialStart: initialDate, start: initialDate,
            initialEnd: initialDate, end: initialDate,
            initialTagIDs: [1], tagIDs: [1],
            initialAttachmentIDs: [attachmentID], attachmentIDs: [attachmentID],
            hasAttachmentSession: false
        ))
        XCTAssertTrue(ScheduleEditorDismissalPolicy.isDirty(
            initialContent: "Shift", content: "Shift",
            initialDescription: "Notes", description: "Notes",
            initialVisibility: .family, visibility: .family,
            initialStart: initialDate, start: initialDate,
            initialEnd: initialDate, end: initialDate,
            initialTagIDs: [1], tagIDs: [1],
            initialAttachmentIDs: [attachmentID], attachmentIDs: [attachmentID],
            hasAttachmentSession: true
        ))
    }

    func testDDayEditorDismissalDetectsChanges() {
        let initialDate = Date(timeIntervalSince1970: 100)
        XCTAssertFalse(DDayEditorDismissalPolicy.isDirty(
            initialTitle: "Anniversary", title: "Anniversary",
            initialDate: initialDate, date: initialDate,
            initialIsPrivate: false, isPrivate: false
        ))
        XCTAssertTrue(DDayEditorDismissalPolicy.isDirty(
            initialTitle: "Anniversary", title: "Changed",
            initialDate: initialDate, date: initialDate,
            initialIsPrivate: false, isPrivate: false
        ))
    }

    func testFailedScheduleDeleteReturnsFalseAndCallsAPIOnce() async {
        let repository = CalendarRepositoryMock(failDestructiveMutations: true)
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))
        await model.load()

        let succeeded = await model.deleteSchedule(model.days[11].schedules[0])

        XCTAssertFalse(succeeded)
        XCTAssertNotNil(model.errorMessage)
        let deleteCount = await repository.deleteScheduleCount
        XCTAssertEqual(deleteCount, 1)
    }

    func testFailedScheduleUntagReturnsFalseAndCallsAPIOnce() async {
        let repository = CalendarRepositoryMock(
            failDestructiveMutations: true,
            returnsTaggedSchedule: true
        )
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))
        await model.load()

        let succeeded = await model.untagSelf(model.days[11].schedules[0])

        XCTAssertFalse(succeeded)
        XCTAssertNotNil(model.errorMessage)
        let untagCount = await repository.untagCount
        XCTAssertEqual(untagCount, 1)
    }

    func testFailedDDayDeleteReturnsFalseAndCallsAPIOnce() async {
        let repository = CalendarRepositoryMock(failDestructiveMutations: true)
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))
        await model.load()
        let dDay = DDayDTO(
            id: 3,
            title: "Important day",
            date: DateOnly(rawValue: "2026-08-12"),
            isPrivate: false,
            calc: 0,
            daysLeft: 0
        )

        let succeeded = await model.deleteDDay(dDay)

        XCTAssertFalse(succeeded)
        XCTAssertNotNil(model.errorMessage)
        let deleteCount = await repository.deleteDDayCount
        XCTAssertEqual(deleteCount, 1)
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
            orderedAttachmentIDs: [first, second],
            aiTimeParsingRequested: false
        )

        let request = await repository.savedSchedule
        XCTAssertTrue(saved)
        XCTAssertEqual(request?.attachmentSessionId, session)
        XCTAssertEqual(request?.orderedAttachmentIds, [first, second])
        XCTAssertEqual(request?.startDateTime.rawValue, "2026-08-12T00:00:00")
        XCTAssertEqual(request?.aiTimeParsingRequested, false)
        let encoded = try? JSONEncoder().encode(request)
        let json = encoded.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }
        XCTAssertEqual(json?["aiTimeParsingRequested"] as? Bool, false)
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

    func testCalendarLocaleUsesTheAppSelectedLanguage() {
        XCTAssertEqual(CalendarLocalization.locale(languageCode: "ko").identifier, "ko")
        XCTAssertEqual(CalendarLocalization.locale(languageCode: "en").identifier, "en")
        XCTAssertEqual(CalendarLocalization.locale(languageCode: "fr-FR").identifier, "en")
    }

    func testKoreanDutyBatchMonthDescriptionDoesNotGroupTheYear() {
        let defaults = UserDefaults.standard
        let previousLanguage = defaults.string(forKey: SettingsPreference.languageKey)
        defaults.set("ko", forKey: SettingsPreference.languageKey)
        defer {
            if let previousLanguage {
                defaults.set(previousLanguage, forKey: SettingsPreference.languageKey)
            } else {
                defaults.removeObject(forKey: SettingsPreference.languageKey)
            }
        }

        XCTAssertEqual(
            CalendarLocalization.format("calendar.duty.batch.description.month", 2026, 8),
            "2026년 8월 전체에 적용할 근무를 선택하세요."
        )
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
        XCTAssertEqual(CalendarVisualLogic.maximumSchedulesPerCell, 3)
        XCTAssertEqual(CalendarVisualLogic.maximumTodosPerCell, 2)
    }

    func testCalendarOmitsEmptyDutyToolbarAboveMonthGrid() {
        XCTAssertFalse(CalendarMainLayout.shouldShowDutyToolbar(
            hasDutySummary: false,
            hasComparisonAction: false,
            hasQuickEditAction: false,
            hasImportAction: false,
            isQuickDutyEditing: false
        ))
        XCTAssertTrue(CalendarMainLayout.shouldShowDutyToolbar(
            hasDutySummary: true,
            hasComparisonAction: false,
            hasQuickEditAction: false,
            hasImportAction: false,
            isQuickDutyEditing: false
        ))
        XCTAssertTrue(CalendarMainLayout.shouldShowDutyToolbar(
            hasDutySummary: false,
            hasComparisonAction: false,
            hasQuickEditAction: false,
            hasImportAction: false,
            isQuickDutyEditing: true
        ))
        XCTAssertTrue(CalendarMainLayout.shouldShowDutyToolbar(
            hasDutySummary: false,
            hasComparisonAction: true,
            hasQuickEditAction: false,
            hasImportAction: false,
            isQuickDutyEditing: false
        ))
        XCTAssertTrue(CalendarMainLayout.shouldShowDutyToolbar(
            hasDutySummary: false,
            hasComparisonAction: false,
            hasQuickEditAction: true,
            hasImportAction: false,
            isQuickDutyEditing: false
        ))
        XCTAssertTrue(CalendarMainLayout.shouldShowDutyToolbar(
            hasDutySummary: false,
            hasComparisonAction: false,
            hasQuickEditAction: false,
            hasImportAction: true,
            isQuickDutyEditing: false
        ))
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

private func tagItem(
    id: MemberID,
    name: String,
    team: String?,
    isFamily: Bool = false,
    pinOrder: Int64? = nil
) -> DPFriendTagItem {
    DPFriendTagItem(
        id: id,
        name: name,
        team: team,
        hasProfilePhoto: false,
        profilePhotoVersion: 0,
        isFamily: isFamily,
        pinOrder: pinOrder
    )
}

private actor CalendarRepositoryMock: CalendarRepositoryProtocol {
    var savedSchedule: ScheduleSaveDTO?
    var batchUpdateCount = 0
    var requestedPreviewMemberID: MemberID?
    var requestedScheduleMemberID: MemberID?
    var requestedDDayMemberID: MemberID?
    var lastDutyUpdate: DutyUpdateDTO?
    var deleteScheduleCount = 0
    var untagCount = 0
    var deleteDDayCount = 0
    let canManageValue: Bool
    let cancelMemberLoad: Bool
    let friendValues: [FriendDTO]
    let scheduleOwnerID: MemberID
    let failDestructiveMutations: Bool
    let returnsTaggedSchedule: Bool
    let otherDutyValues: [OtherDutyResponse]

    init(
        canManage: Bool = false,
        cancelMemberLoad: Bool = false,
        friends: [FriendDTO] = [],
        scheduleOwnerID: MemberID = 1,
        failDestructiveMutations: Bool = false,
        returnsTaggedSchedule: Bool = false,
        otherDuties: [OtherDutyResponse] = []
    ) {
        canManageValue = canManage
        self.cancelMemberLoad = cancelMemberLoad
        friendValues = friends
        self.scheduleOwnerID = scheduleOwnerID
        self.failDestructiveMutations = failDestructiveMutations
        self.returnsTaggedSchedule = returnsTaggedSchedule
        otherDutyValues = otherDuties
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
    func otherDuties(memberIDs: [MemberID], year: Int, month: Int) async throws -> [OtherDutyResponse] {
        otherDutyValues
    }
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
    func deleteSchedule(id: ScheduleID) async throws {
        deleteScheduleCount += 1
        if failDestructiveMutations { throw APIError.invalidResponse }
    }
    func untagSelf(scheduleID: ScheduleID) async throws {
        untagCount += 1
        if failDestructiveMutations { throw APIError.invalidResponse }
    }
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
    func saveDDay(_ request: DDaySaveDTO) async throws -> DDayDTO { DDayDTO(id: 1, title: request.title, date: request.date, isPrivate: request.isPrivate, calc: 0, daysLeft: 0) }
    func deleteDDay(id: Int64) async throws {
        deleteDDayCount += 1
        if failDestructiveMutations { throw APIError.invalidResponse }
    }

    private func schedule(year: Int, month: Int) -> ScheduleDTO {
        ScheduleDTO(
            id: UUID(), content: "Night duty", description: "", position: 0,
            year: year, month: month, dayOfMonth: 12,
            startDateTime: LocalDateTimeValue(rawValue: String(format: "%04d-%02d-12T00:00:00", year, month)),
            endDateTime: LocalDateTimeValue(rawValue: String(format: "%04d-%02d-12T01:00:00", year, month)),
            isTagged: returnsTaggedSchedule, owner: "Tester", taggedByMember: nil, tags: [], visibility: .friends,
            dateToCompare: DateOnly(rawValue: String(format: "%04d-%02d-12", year, month)), attachments: [],
            startDate: DateOnly(rawValue: String(format: "%04d-%02d-12", year, month)), daysFromStart: 1,
            endDate: DateOnly(rawValue: String(format: "%04d-%02d-12", year, month)),
            curDate: DateOnly(rawValue: String(format: "%04d-%02d-12", year, month)), totalDays: 1
        )
    }
}
