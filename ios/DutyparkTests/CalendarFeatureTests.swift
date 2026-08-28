import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class CalendarFeatureTests: XCTestCase {
    func testCalendarHapticPolicyLeavesNoOpTransitionsSilent() {
        XCTAssertNil(CalendarHapticPolicy.monthNavigation(fromYear: 2026, fromMonth: 8, toYear: 2026, toMonth: 8))
        XCTAssertEqual(
            CalendarHapticPolicy.monthNavigation(fromYear: 2026, fromMonth: 8, toYear: 2026, toMonth: 9),
            .routine
        )
        XCTAssertNil(
            CalendarHapticPolicy.selectionChanged(
                from: DateOnly(rawValue: "2026-08-12"),
                to: DateOnly(rawValue: "2026-08-12")
            )
        )
        XCTAssertEqual(
            CalendarHapticPolicy.mutationResult(succeeded: true),
            .success
        )
        XCTAssertEqual(
            CalendarHapticPolicy.mutationResult(succeeded: false),
            .error
        )
        XCTAssertEqual(CalendarHapticPolicy.validationFailure(), .warning)
        XCTAssertNil(CalendarHapticPolicy.validationFailure(isActionable: false))
    }

    func testSearchResultDateOmitsMidnightPlaceholderButKeepsExplicitTime() {
        XCTAssertEqual(
            CalendarVisualLogic.searchResultDateText(
                LocalDateTimeValue(rawValue: "2026-08-22T00:00:00")
            ),
            "2026-08-22"
        )
        XCTAssertEqual(
            CalendarVisualLogic.searchResultDateText(
                LocalDateTimeValue(rawValue: "2026-08-22T09:30:00")
            ),
            "2026-08-22 09:30:00"
        )
    }

    /// The pinned D-day shares the day-number row, so only the counter fits. Adding the
    /// title pushed the number out of the single line, which is the one part the pin is
    /// for; the title already appears as a bubble on the D-day's own date.
    func testThePinnedDDayCellShowsTheCounterWithoutTheTitle() throws {
        let target = DateOnly(rawValue: "2026-08-19")

        XCTAssertEqual(
            CalendarVisualLogic.pinnedDDayLabel(cell: DateOnly(rawValue: "2026-08-19"), target: target),
            "D-Day"
        )
        XCTAssertEqual(
            CalendarVisualLogic.pinnedDDayLabel(cell: DateOnly(rawValue: "2026-08-16"), target: target),
            "D-3"
        )
        XCTAssertEqual(
            CalendarVisualLogic.pinnedDDayLabel(cell: DateOnly(rawValue: "2026-08-20"), target: target),
            "D+1"
        )
        XCTAssertNil(CalendarVisualLogic.pinnedDDayLabel(cell: DateOnly(rawValue: "2026-08"), target: target))

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Calendar/CalendarView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("CalendarVisualLogic.pinnedDDayLabel("))
        XCTAssertFalse(
            source.contains("item.title) \\(label)"),
            "The pinned counter must not be prefixed with the D-day title"
        )
    }

    /// The callout is the only one-tap way back from a distant month, so it has to appear for
    /// every month but the one the clock is in — the same month of another year included.
    func testTheThisMonthCalloutAppearsForEveryMonthButTheCurrentOne() throws {
        let today = try XCTUnwrap(CalendarDateSupport.date(from: DateOnly(rawValue: "2026-08-20")))

        XCTAssertFalse(CalendarVisualLogic.showsThisMonthCallout(year: 2026, month: 8, today: today))
        XCTAssertTrue(CalendarVisualLogic.showsThisMonthCallout(year: 2026, month: 7, today: today))
        XCTAssertTrue(CalendarVisualLogic.showsThisMonthCallout(year: 2025, month: 8, today: today))
    }

    /// Moving the month header into the navigation bar left the return to today as a bare
    /// arrow among the bar buttons, where nothing says what it does. It goes back to the
    /// labelled speech bubble the web calendar draws, fixed at the top of the calendar body
    /// so it remains reachable after the navigation bar returns to its native height.
    func testTheThisMonthAffordanceIsALabelledCalloutFixedAtTheCalendarBodyTop() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Calendar/CalendarView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("private var thisMonthCallout: some View"))
        XCTAssertTrue(
            source.contains("Text(CalendarLocalization.text(\"calendar.month.goToThisMonth\"))"),
            "The callout carries its label, not just the return arrow"
        )
        XCTAssertFalse(
            source.contains("thisMonthControl"),
            "The bare trailing bar icon gives way to the callout"
        )
        let content = try Self.declaration(named: "private var calendarContent: some View", in: source)
        XCTAssertTrue(content.contains("ZStack(alignment: .top) {"))
        XCTAssertTrue(
            content.contains("thisMonthCalloutLayer"),
            "The callout is a fixed sibling of the scrolling content"
        )
        XCTAssertTrue(
            !content.contains(".padding(.top, Self.calloutReach * 2)"),
            "The fixed callout must not push the calendar content down"
        )
        XCTAssertTrue(
            content.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)"),
            "The callout host covers the full calendar body for hit testing"
        )

        let controls = try XCTUnwrap(source.range(of: "private var monthControls: some View"))
        let body = source[controls.upperBound...]
        let end = try XCTUnwrap(body.range(of: "\n    private var"))
        XCTAssertTrue(
            !body[..<end.lowerBound].contains("thisMonthCalloutLayer"),
            "The 44pt month controls do not expand to host the callout"
        )
        XCTAssertTrue(
            !body[..<end.lowerBound].contains(".padding(.vertical, Self.calloutReach)"),
            "The callout reserve belongs to the calendar content, not the navigation bar"
        )
    }

    func testTheThisMonthCalloutAddsATallerVerticalTouchArea() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Calendar/CalendarView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("private static let calloutHitInsetY: CGFloat = 6"))
        XCTAssertTrue(source.contains(".padding(.vertical, Self.calloutHitInsetY)"))
    }

    func testTheThisMonthCalloutIsLiftedTwentyPointsWithinTheCalendarBody() throws {
        let source = try Self.calendarViewSource()
        let content = try Self.declaration(named: "private var calendarContent: some View", in: source)

        XCTAssertTrue(
            source.contains("private static let calloutVerticalOffset: CGFloat = -20"),
            "The body-hosted callout needs an explicit 20pt upward offset"
        )
        XCTAssertTrue(
            content.contains("thisMonthCalloutLayer\n                .offset(y: Self.calloutVerticalOffset)"),
            "The upward offset must apply to the fixed body callout layer"
        )
    }

    /// iOS 26's top edge effect must remain available for contrast when calendar content moves
    /// under the fixed navigation controls. The calendar owns the effect policy, but only for
    /// the top edge and only on OS versions that provide the API; the bottom edge is unchanged.
    func testCalendarUsesASoftTopScrollEdgeEffectOnIOS26() throws {
        let source = try Self.calendarViewSource()
        let content = try Self.declaration(named: "private var calendarContent: some View", in: source)
        let modifier = try Self.declaration(
            named: "private struct CalendarTopScrollEdgeEffectModifier: ViewModifier",
            in: source
        )

        XCTAssertTrue(content.contains("ScrollView {"), "The policy belongs to the outer vertical calendar scroll view")
        XCTAssertTrue(content.contains("CalendarTopScrollEdgeEffectModifier()"))
        XCTAssertTrue(modifier.contains("if #available(iOS 26.0, *)"))
        XCTAssertTrue(modifier.contains(".scrollEdgeEffectStyle(.soft, for: .top)"))
        XCTAssertFalse(modifier.contains("scrollEdgeEffectHidden"))
        XCTAssertFalse(modifier.contains(".bottom"), "The bottom edge effect remains automatic")
        XCTAssertFalse(modifier.contains(".all"), "Only the top edge effect is disabled")
        XCTAssertTrue(modifier.contains("else"), "iOS 17 must keep the unmodified fallback")
    }

    /// The callout grows from its current upper-left corner so its layout anchor and the month
    /// header's centre do not move. Scaling the Button itself keeps the existing action and
    /// accessibility label attached to the enlarged hit target.
    func testTheThisMonthCalloutScalesTheWholeButtonByTenPercentFromTopLeading() throws {
        let source = try Self.calendarViewSource()
        let callout = try Self.declaration(named: "private var thisMonthCallout: some View", in: source)

        XCTAssertTrue(source.contains("private static let calloutScale: CGFloat = 1.1"))
        XCTAssertTrue(callout.contains(".scaleEffect(Self.calloutScale, anchor: .topLeading)"))
        XCTAssertTrue(callout.contains("Button { Task { await model.goToToday() } } label:"))
        XCTAssertTrue(callout.contains(".accessibilityLabel(CalendarLocalization.text(\"calendar.month.goToThisMonth\"))"))
    }

    /// The strip above the calendar is gone: due-date bubbles inside the day cells are the
    /// only Todo surface the calendar keeps, and they open the detail modal in place.
    func testCalendarTodosLiveOnlyInDayCellsAndOpenTheDetailModal() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Calendar/CalendarView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("TodoDetailModal("))
        XCTAssertTrue(source.contains("onTodoChanged: { await model.refreshTodoBoard() }"))
        XCTAssertTrue(source.contains("Button { openTodo(todo) }"))
        XCTAssertTrue(source.contains("calendar.day.todo.\\(todo.id)"))
        XCTAssertFalse(source.contains("todoDetailModel.load()"))
        XCTAssertFalse(source.contains("dutyTodoRow"), "The Todo strip above the calendar is removed")
        XCTAssertFalse(source.contains("calendar.todo.item."), "The Todo strip above the calendar is removed")
        XCTAssertFalse(source.contains("TodoCreateModal("), "Calendar no longer creates Todos")
        XCTAssertFalse(source.contains("TodoView("), "Calendar Todo bubbles must not present the full board")
        XCTAssertFalse(source.contains("private func openTodoBoard()"), "Calendar never opens the Todo board")
    }

    func testCalendarDayCellExposesOneFullCellAccessibilityTarget() throws {
        let dayCell = try Self.declaration(
            named: "private struct CalendarDayCell: View",
            in: Self.calendarViewSource()
        )

        XCTAssertTrue(
            dayCell.contains(".accessibilityElement(children: .ignore)"),
            "Nested schedule/comparison/todo views must not duplicate the day label"
        )
        XCTAssertTrue(
            dayCell.contains(".accessibilityActions"),
            "Collapsing the cell must retain direct VoiceOver actions for visible Todos"
        )
        XCTAssertTrue(
            dayCell.contains(".accessibilityIdentifier(\"calendar.day.\\(day.cell.date.rawValue)\")"),
            "Every day needs a stable, unique accessibility target for VoiceOver and UI automation"
        )
    }

    func testAMemberCalendarIsPushedOntoTheStackOfTheTabItWasOpenedFrom() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let calendarSource = try String(
            contentsOf: projectRoot.appending(path: "Dutypark/Features/Calendar/CalendarView.swift"),
            encoding: .utf8
        )
        // The identity chip is the back control of a pushed member calendar, and the
        // screen is genuinely pushed, so the back action is a pop and the system edge
        // gesture is restored instead of being re-implemented.
        for wiring in [
            "private let isPushedMemberCalendar: Bool",
            "isPushed: Bool = false",
            "@Environment(\\.dismiss) private var dismiss",
            "private var memberBackAction: (() -> Void)?",
            "guard isPushedMemberCalendar else { return nil }",
            "DPHapticCenter.shared.emit(.routine)",
            "dismiss()",
            "Button(action: memberBackAction)",
            ".navigationBarBackButtonHidden(isPushedMemberCalendar)",
            ".dpInteractivePopGestureEnabled()",
            "calendar.member.back",
            "chevron.left",
        ] {
            XCTAssertTrue(calendarSource.contains(wiring), "CalendarView is missing: \(wiring)")
        }
        // Whose calendar it is no longer decides whether there is a way back: opening
        // your own calendar from a team shift grid or from Admin pushes it too.
        XCTAssertFalse(calendarSource.contains("if let onBack, !model.isMyCalendar"))
        XCTAssertFalse(calendarSource.contains("onBack"))
        XCTAssertFalse(
            calendarSource.contains("dpSwipeBackGesture"),
            "The stopgap swipe recognizer is replaced by the real interactive pop"
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: projectRoot.appending(path: "Dutypark/Components/DPSwipeBackGesture.swift").path
            )
        )

        let rootSource = try String(
            contentsOf: projectRoot.appending(path: "Dutypark/App/RootTabView.swift"),
            encoding: .utf8
        )
        for wiring in [
            // Every tab that can open a member calendar owns a navigation stack for it.
            "@State private var homePath: [HomeDestination] = []",
            "@State private var calendarPath: [MemberCalendarRoute] = []",
            "@State private var teamPath: [MemberCalendarRoute] = []",
            "@State private var morePath: [MoreDestination] = []",
            "NavigationStack(path: path)",
            ".navigationDestination(for: MemberCalendarRoute.self)",
            ".navigationDestination(for: MoreDestination.self)",
            "case .memberCalendar(let route):",
            "isPushed: true",
            // The calendar is pushed onto the stack of the tab it was opened from.
            "homePath.append(.memberCalendar(route))",
            "teamPath.append(route)",
            "morePath.append(.memberCalendar(route))",
            "calendarPath.append(route)",
            "selectedTab = host",
            // Routed entries have nothing behind them, so they push onto the calendar
            // tab whose root is the authenticated member's own calendar.
            "private func routeToMemberCalendar(_ memberID: MemberID)",
            "routeToMemberCalendar(memberID)",
            "calendarPath = [route]",
        ] {
            XCTAssertTrue(rootSource.contains(wiring), "RootTabView is missing: \(wiring)")
        }
        // The origin machinery only existed to fake a back destination for a screen
        // that replaced the calendar tab root.
        for removed in [
            "calendarOrigin",
            "CalendarOrigin",
            "closeMemberCalendar",
            "calendarBackTab",
            "CalendarTarget",
            "navigationDestination(item: $moreDestination)",
        ] {
            XCTAssertFalse(rootSource.contains(removed), "RootTabView still carries: \(removed)")
        }

        let catalog = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: Data(contentsOf: projectRoot.appending(path: "Dutypark/Features/Calendar/Calendar.xcstrings"))
            ) as? [String: Any]
        )
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        let entry = try XCTUnwrap(strings["calendar.member.back"] as? [String: Any])
        let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
        for language in ["en", "ko"] {
            let localization = try XCTUnwrap(localizations[language] as? [String: Any])
            let stringUnit = try XCTUnwrap(localization["stringUnit"] as? [String: Any])
            XCTAssertEqual(stringUnit["state"] as? String, "translated")
            XCTAssertFalse((stringUnit["value"] as? String ?? "").isEmpty)
        }
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

    func testSharedFriendTagSelectorFiltersNameAndTeamIndependentlyOfSelection() {
        let items = [
            tagItem(id: 1, name: "Alice", team: "Emergency"),
            tagItem(id: 2, name: "Bob", team: "Emergency"),
            tagItem(id: 3, name: "Carol", team: "Ward")
        ]

        XCTAssertEqual(
            DPFriendTagSelectionLogic.visibleItems(items: items, query: "emerg").map(\.id),
            [1, 2]
        )
        XCTAssertEqual(
            DPFriendTagSelectionLogic.visibleItems(items: items, query: "alice").map(\.id),
            [1]
        )
        XCTAssertEqual(
            DPFriendTagSelectionLogic.visibleItems(items: items, query: "   ").map(\.id),
            [1, 2, 3],
            "A blank query keeps the whole rail browsable"
        )
    }

    func testSharedFriendTagRailKeepsThreePortraitsVisibleAtAnyFormWidth() {
        let spacing: CGFloat = 8

        // The labelled schedule editor column on the smallest supported phone is the tightest rail.
        let narrow = DPFriendTagSelectionLogic.cardWidth(
            availableWidth: 217, spacing: spacing, minimum: 60, maximum: 88
        )
        XCTAssertLessThanOrEqual(
            narrow * 3 + spacing * 2, 217,
            "Three portraits must fit the narrowest form without clipping the third"
        )

        XCTAssertEqual(
            DPFriendTagSelectionLogic.cardWidth(
                availableWidth: 900, spacing: spacing, minimum: 60, maximum: 88
            ),
            88,
            "A roomy container must not stretch portraits past the comfortable maximum"
        )
        XCTAssertEqual(
            DPFriendTagSelectionLogic.cardWidth(
                availableWidth: 40, spacing: spacing, minimum: 60, maximum: 88
            ),
            60,
            "A collapsed container must not shrink portraits below the legible minimum"
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
            "friendTag.clear", "friendTag.clearSearch", "friendTag.clearShort", "friendTag.empty",
            "friendTag.expand", "friendTag.noneSelected", "friendTag.notSelectedState",
            "friendTag.remove", "friendTag.search", "friendTag.selected", "friendTag.selectedState",
            "friendTag.title"
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
            "calendar.schedule.start",
            "calendar.schedule.end",
            "calendar.schedule.time.add",
            "calendar.schedule.time.remove",
            "calendar.schedule.tags.search",
            "calendar.schedule.tags.selected",
            "calendar.schedule.tags.selectedOnly",
            "calendar.schedule.tags.clear",
            "calendar.schedule.tags.empty",
            "calendar.search.short",
            "calendar.compare.empty",
            "calendar.compare.reset",
            "calendar.todo.manage",
            "calendar.search.hint",
            "calendar.search.empty",
            "calendar.search.summary",
            "calendar.schedule.delete.confirm.title",
            "calendar.schedule.delete.confirm.message",
            "calendar.schedule.untag.confirm.title",
            "calendar.schedule.untag.confirm.message",
            "calendar.dday.detail.title",
            "calendar.dday.edit.action",
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

    func testScheduleEditorTreatsMidnightAsNoTime() {
        let calendar = CalendarDateSupport.calendar
        let midnight = Self.moment(2026, 8, 19, 0, 0)
        let morning = Self.moment(2026, 8, 19, 9, 30)

        XCTAssertNil(ScheduleEditorTimePolicy.time(of: midnight, calendar: calendar))
        XCTAssertEqual(ScheduleEditorTimePolicy.time(of: morning, calendar: calendar), morning)
    }

    func testScheduleEditorCombinesADateWithItsOptionalTime() {
        let calendar = CalendarDateSupport.calendar
        let day = Self.moment(2026, 8, 19, 0, 0)
        let timeOnAnotherDay = Self.moment(2026, 1, 2, 14, 45)

        XCTAssertEqual(
            ScheduleEditorTimePolicy.combine(date: day, time: nil, calendar: calendar),
            Self.moment(2026, 8, 19, 0, 0)
        )
        XCTAssertEqual(
            ScheduleEditorTimePolicy.combine(date: day, time: timeOnAnotherDay, calendar: calendar),
            Self.moment(2026, 8, 19, 14, 45)
        )
    }

    /// Splitting a stored value and folding it straight back must reproduce it exactly,
    /// otherwise merely opening an untouched editor would look dirty and warn on close.
    func testScheduleEditorRoundTripsAStoredValueUnchanged() {
        let calendar = CalendarDateSupport.calendar
        for stored in [Self.moment(2026, 8, 19, 0, 0), Self.moment(2026, 8, 19, 21, 5)] {
            XCTAssertEqual(
                ScheduleEditorTimePolicy.combine(
                    date: stored,
                    time: ScheduleEditorTimePolicy.time(of: stored, calendar: calendar),
                    calendar: calendar
                ),
                stored
            )
        }
    }

    /// The model rejects an end before the start, so "start at 22:00, no end time" has to be
    /// stored as an end equal to the start — otherwise the editor could not save it at all.
    func testScheduleEditorCollapsesASameDayEndWithoutATimeOntoTheStart() {
        let calendar = CalendarDateSupport.calendar
        let start = Self.moment(2026, 8, 19, 22, 0)

        XCTAssertEqual(
            ScheduleEditorTimePolicy.effectiveEnd(
                start: start,
                endDate: Self.moment(2026, 8, 19, 0, 0),
                endTime: nil,
                calendar: calendar
            ),
            start
        )
        XCTAssertEqual(
            ScheduleEditorTimePolicy.effectiveEnd(
                start: start,
                endDate: Self.moment(2026, 8, 21, 0, 0),
                endTime: nil,
                calendar: calendar
            ),
            Self.moment(2026, 8, 21, 0, 0)
        )
        XCTAssertEqual(
            ScheduleEditorTimePolicy.effectiveEnd(
                start: start,
                endDate: Self.moment(2026, 8, 19, 0, 0),
                endTime: Self.moment(2026, 1, 2, 23, 30),
                calendar: calendar
            ),
            Self.moment(2026, 8, 19, 23, 30)
        )
        // An end date before the start stays invalid instead of being quietly bumped.
        XCTAssertEqual(
            ScheduleEditorTimePolicy.effectiveEnd(
                start: start,
                endDate: Self.moment(2026, 8, 18, 0, 0),
                endTime: nil,
                calendar: calendar
            ),
            Self.moment(2026, 8, 18, 0, 0)
        )
    }

    /// A stored end that equals the start carries no end time of its own, so the editor
    /// leaves that field empty and folds it back to the same value on save.
    func testScheduleEditorReadsAnEndEqualToTheStartAsNoEndTime() {
        let calendar = CalendarDateSupport.calendar
        let start = Self.moment(2026, 8, 19, 9, 0)

        XCTAssertNil(ScheduleEditorTimePolicy.endTime(of: start, start: start, calendar: calendar))
        XCTAssertEqual(
            ScheduleEditorTimePolicy.endTime(
                of: Self.moment(2026, 8, 19, 18, 0),
                start: start,
                calendar: calendar
            ),
            Self.moment(2026, 8, 19, 18, 0)
        )
        XCTAssertEqual(
            ScheduleEditorTimePolicy.effectiveEnd(
                start: start,
                endDate: start,
                endTime: nil,
                calendar: calendar
            ),
            start
        )
    }

    func testScheduleEditorDefaultStartTimeTakesTheNextHourAndAvoidsMidnight() {
        let calendar = CalendarDateSupport.calendar
        let day = Self.moment(2026, 8, 19, 0, 0)

        XCTAssertEqual(
            ScheduleEditorTimePolicy.defaultStartTime(
                on: day,
                now: Self.moment(2026, 1, 2, 9, 15),
                calendar: calendar
            ),
            Self.moment(2026, 8, 19, 10, 0)
        )
        // 23:xx would roll over to midnight, which the model reads back as "no time".
        XCTAssertEqual(
            ScheduleEditorTimePolicy.defaultStartTime(
                on: day,
                now: Self.moment(2026, 1, 2, 23, 40),
                calendar: calendar
            ),
            Self.moment(2026, 8, 19, 9, 0)
        )
    }

    func testScheduleEditorDefaultEndIsAlwaysAVisibleTimeAfterTheStart() {
        let calendar = CalendarDateSupport.calendar
        let sameDay = Self.moment(2026, 8, 19, 0, 0)

        XCTAssertEqual(
            ScheduleEditorTimePolicy.defaultEnd(
                start: Self.moment(2026, 8, 19, 10, 0),
                endDate: sameDay,
                calendar: calendar
            ),
            Self.moment(2026, 8, 19, 11, 0)
        )
        // An hour later would cross midnight, which reads back as no time at all.
        XCTAssertEqual(
            ScheduleEditorTimePolicy.defaultEnd(
                start: Self.moment(2026, 8, 19, 23, 0),
                endDate: sameDay,
                calendar: calendar
            ),
            Self.moment(2026, 8, 19, 23, 59)
        )
        XCTAssertEqual(
            ScheduleEditorTimePolicy.defaultEnd(
                start: Self.moment(2026, 8, 19, 23, 30),
                endDate: Self.moment(2026, 8, 20, 0, 0),
                calendar: calendar
            ),
            Self.moment(2026, 8, 20, 23, 59)
        )
        // Nothing later is left on the start's own day, so the end rolls over.
        XCTAssertEqual(
            ScheduleEditorTimePolicy.defaultEnd(
                start: Self.moment(2026, 8, 31, 23, 59),
                endDate: Self.moment(2026, 8, 31, 0, 0),
                calendar: calendar
            ),
            Self.moment(2026, 9, 1, 0, 59)
        )
    }

    /// An end time only makes sense once a start time exists, and a control the user cannot
    /// use reads as broken — so the end offers no button at all until then.
    /// Korean form labels are all two-character words ("공개 범위", "첨부파일"), so a two-character
    /// column wraps the four-character ones into an even block and leaves the date and time
    /// controls beside them the room a phone cannot spare. Latin labels have no such break point
    /// inside a word, so they keep a column wide enough for the longest of them.
    func testFormLabelColumnIsTwoCharactersWideInKorean() {
        let korean = CalendarVisualLogic.formLabelWidth(locale: Locale(identifier: "ko_KR"))
        let english = CalendarVisualLogic.formLabelWidth(locale: Locale(identifier: "en_US"))

        XCTAssertEqual(korean, 28)
        XCTAssertLessThan(korean, english)
    }

    /// Every row of the editor hangs its label off the one shared width token, and the date
    /// bounds are no exception: they go through the very row builder the rest of the form uses,
    /// so a start or end label cannot drift away from the fields above and below it.
    func testScheduleEditorRowLabelsShareOneWidthToken() throws {
        let source = try Self.calendarViewSource()
        let section = try Self.declaration(
            named: "private var scheduleDateSection: some View",
            in: try Self.scheduleEditorSource()
        )

        XCTAssertTrue(source.contains(".frame(width: rowLabelWidth, alignment: .leading)"))
        XCTAssertFalse(
            source.contains(".frame(width: 64, alignment: .leading)"),
            "Every row label takes its width from the shared token"
        )
        XCTAssertTrue(section.contains(#"formRow("calendar.schedule.start", alignment: .top)"#))
        XCTAssertTrue(section.contains(#"formRow("calendar.schedule.end", alignment: .top)"#))
    }

    /// A new schedule's start cannot be changed and the end is picked as a range, but the two
    /// rows still draw one control through one builder: the same box, the same reserved height,
    /// the same language. Only the state handed to it differs.
    func testScheduleEditorStartAndEndDatesDrawTheSameControl() throws {
        let editor = try Self.scheduleEditorSource()
        let builder = try Self.declaration(named: "private func dateControl", in: editor)

        XCTAssertEqual(
            editor.components(separatedBy: "DPDateField(").count - 1,
            1,
            "Both date rows go through the one builder"
        )
        XCTAssertTrue(builder.contains("DPDateField("))
        XCTAssertTrue(builder.contains("isReadOnly: isReadOnly"), "The locked look is a state of the shared field")
        XCTAssertTrue(editor.contains("isReadOnly: existing == nil"))
        XCTAssertTrue(editor.contains("mode: .range(anchor: startDay)"))
        XCTAssertFalse(
            editor.contains("displayedComponents: .date"),
            "A date is picked through the shared field, not a native date picker"
        )
        XCTAssertFalse(
            editor.contains("ScheduleEditorTimePolicy.dateText"),
            "The fixed start date is the shared date control, not a text stand-in styled to match it"
        )
    }

    /// The time is optional, so its cell draws either a button that adds one or a time picker.
    /// Sized to whichever it holds, the cell grew the moment a time was added and shifted every
    /// field below it, so it reserves the taller control's height in every state. The date field
    /// is handed the same budget as its own row height rather than being wrapped in it: a fixed
    /// frame around the field would cut off the calendar it opens.
    func testScheduleDateRowsReserveOneHeightWhetherOrNotATimeIsSet() throws {
        let editor = try Self.scheduleEditorSource()
        let builder = try Self.declaration(named: "private func dateControl", in: editor)

        XCTAssertEqual(CalendarVisualLogic.scheduleDateRowHeight, 36)
        XCTAssertTrue(
            builder.contains("rowHeight: dateRowHeight"),
            "The date field holds the reserved row height"
        )
        XCTAssertFalse(
            builder.contains(".frame(height:"),
            "Wrapping the date field in a fixed height would clip the calendar it opens"
        )
        XCTAssertTrue(
            editor.contains(".frame(height: dateRowHeight, alignment: .leading)"),
            "The time cell holds the reserved row height in both of its states"
        )
        XCTAssertFalse(
            editor.contains(".frame(minHeight: dateRowHeight"),
            "A floor still lets a picker grow the row past it; the height is fixed"
        )
    }

    func testScheduleEditorHidesTheEndTimeButtonUntilAStartTimeExists() throws {
        let editor = try Self.scheduleEditorSource()

        XCTAssertTrue(editor.contains("} else if canAdd {"))
        XCTAssertTrue(editor.contains("canAdd: startTime != nil"))
        XCTAssertFalse(
            editor.contains(".disabled(!canAdd)"),
            "The end time button is hidden, not shown disabled"
        )
        // The empty cell keeps its height all the same: otherwise adding a start time would
        // reveal the end's button and push every field below the end date down by a row.
        XCTAssertTrue(editor.contains(".frame(height: dateRowHeight, alignment: .leading)"))
    }

    /// The time sits *beside* its date, not under it. Stacked, the end's hidden button left a
    /// reserved-but-empty band under the end date — a 36-point hole between the row and the
    /// next field — and the reserve itself cannot be dropped: it is what keeps adding a time
    /// from pushing every field below it down. Beside the date the same reserve is invisible,
    /// exactly as the web keeps the two controls on one line.
    func testTheDateAndItsTimeShareOneRow() throws {
        let editor = try Self.scheduleEditorSource()
        let builder = try Self.declaration(named: "private func dateControl", in: editor)
        let start = try Self.declaration(named: "private var startDateControl: some View", in: editor)
        let end = try Self.declaration(named: "private var endDateControl: some View", in: editor)

        XCTAssertTrue(
            builder.contains("accessory: accessory"),
            "The time is handed to the date field as the accessory of its own row"
        )
        for (name, row) in [("start", start), ("end", end)] {
            XCTAssertTrue(row.contains("timeControl("), "The \(name) row still owns its time control")
            XCTAssertFalse(
                row.contains("VStack"),
                "The \(name) row no longer stacks its time under its date"
            )
        }
    }

    /// The label column narrows the row's content, and a calendar confined to it is cramped —
    /// 29 points a cell in English. The expanded calendar owes the label nothing, so it bleeds
    /// back across the column and takes the whole row in both languages.
    func testTheExpandedCalendarSpansTheRowRatherThanTheLabelledColumn() throws {
        let editor = try Self.scheduleEditorSource()
        let builder = try Self.declaration(named: "private func dateControl", in: editor)

        XCTAssertTrue(
            builder.contains(
                "calendarLeadingBleed: CalendarVisualLogic.formRowContentInset(labelWidth: rowLabelWidth)"
            ),
            "The calendar bleeds back across exactly the label column the row hangs off"
        )
        XCTAssertEqual(CalendarVisualLogic.formRowContentInset(labelWidth: 28), 36)
        XCTAssertEqual(CalendarVisualLogic.formRowContentInset(labelWidth: 88), 96)
    }

    /// Expanding a calendar grows the form well past the fold, so the calendar's own confirm
    /// lands under the modal's footer where only a scroll the user has no reason to try reaches
    /// it. The panel already scrolls to whatever the body names as its target, so an open
    /// calendar becomes that target — outranking a focused text field, whose keyboard the
    /// calendar has just taken the room from.
    func testExpandingADateCalendarScrollsItsConfirmIntoView() throws {
        let editor = try Self.scheduleEditorSource()
        let target = try Self.declaration(named: "private var scrollTarget: AnyHashable?", in: editor)
        let expanded = try XCTUnwrap(target.range(of: "expandedDateField"))
        let focused = try XCTUnwrap(target.range(of: "focusedField"))

        XCTAssertLessThan(
            expanded.lowerBound,
            focused.lowerBound,
            "An open calendar outranks the focused field the panel would otherwise reveal"
        )
        XCTAssertTrue(editor.contains("scrollTarget: scrollTarget"))
        XCTAssertTrue(editor.contains(".id(ScheduleDateField.start)"))
        XCTAssertTrue(editor.contains(".id(ScheduleDateField.end)"))
    }

    func testExpandingFriendTagsScrollsToTheReservedSelectionSummary() throws {
        let editor = try Self.scheduleEditorSource()
        let target = try Self.declaration(named: "private var scrollTarget: AnyHashable?", in: editor)

        XCTAssertTrue(
            target.contains("isTagSelectorExpanded")
                && target.contains("DPFriendTagSelectorScrollAnchor.selectionSummary"),
            "Once friend tagging expands, the panel must target the reserved selection summary below the rail"
        )
        XCTAssertTrue(
            editor.contains("focusedField = nil")
                && editor.contains("isTagSelectorExpanded = true"),
            "Expansion must release any focused field before requesting the selector summary"
        )
    }

    /// A tap outside the expanded calendar closed the whole editor — and offered to discard the
    /// form on the way out — because the backdrop request reached the editor's own dismissal.
    /// It closes the innermost thing that is open instead: the calendar first, the editor only
    /// once no calendar is left. The close button is untouched: pressing it is an explicit
    /// intent to leave.
    func testATapOutsideAnOpenDateCalendarClosesTheCalendarAndNotTheEditor() throws {
        let editor = try Self.scheduleEditorSource()

        XCTAssertEqual(
            ScheduleEditorDismissalPolicy.outsideRequest(hasOpenDateCalendar: true),
            .closeDateCalendar
        )
        XCTAssertEqual(
            ScheduleEditorDismissalPolicy.outsideRequest(hasOpenDateCalendar: false),
            .requestEditorDismissal
        )
        XCTAssertTrue(editor.contains(".onChange(of: dismissRequest) { _, _ in handleOutsideDismissRequest() }"))
        let handler = try Self.declaration(named: "private func handleOutsideDismissRequest()", in: editor)
        XCTAssertTrue(handler.contains("ScheduleEditorDismissalPolicy.outsideRequest("))
        let actions = try Self.declaration(named: "private var editorActions: some View", in: editor)
        XCTAssertTrue(actions.contains("requestDismissal()"), "The close button still leaves the editor")
    }

    /// "종료 날짜 선정할 때, 시작 날짜보다 이전은 절대 눌리면 안되지." The end date control is
    /// bounded at the start's own day, so an earlier date cannot be tapped at all. The bound is
    /// the start of that day: the start's own date stays reachable whatever time it carries.
    func testEndDateIsBoundedAtTheStartsOwnDay() {
        let calendar = CalendarDateSupport.calendar

        XCTAssertEqual(
            ScheduleEditorTimePolicy.endDateLowerBound(
                start: Self.moment(2026, 8, 19, 22, 30),
                calendar: calendar
            ),
            Self.moment(2026, 8, 19, 0, 0)
        )
    }

    /// No bound on the end control can stop the start from moving past it, which edit mode
    /// allows — so the end follows the start instead of being left in a range only the save
    /// button would reject.
    func testEndFollowsTheStartWhenTheStartMovesPastIt() {
        let calendar = CalendarDateSupport.calendar

        // The start jumps beyond an end that carries no time: the end date rises with it.
        var aligned = ScheduleEditorTimePolicy.endFollowingStart(
            start: Self.moment(2026, 8, 21, 10, 0),
            endDate: Self.moment(2026, 8, 19, 0, 0),
            endTime: nil,
            calendar: calendar
        )
        XCTAssertEqual(aligned.date, Self.moment(2026, 8, 21, 0, 0))
        XCTAssertNil(aligned.time)

        // An end already after the start is left exactly as the user set it.
        aligned = ScheduleEditorTimePolicy.endFollowingStart(
            start: Self.moment(2026, 8, 19, 10, 0),
            endDate: Self.moment(2026, 8, 21, 0, 0),
            endTime: nil,
            calendar: calendar
        )
        XCTAssertEqual(aligned.date, Self.moment(2026, 8, 21, 0, 0))
        XCTAssertNil(aligned.time)

        // A same-day end time the start has overtaken is re-proposed by the rule that first
        // offered one, so it stays a visible time after the start.
        aligned = ScheduleEditorTimePolicy.endFollowingStart(
            start: Self.moment(2026, 8, 19, 14, 0),
            endDate: Self.moment(2026, 8, 19, 0, 0),
            endTime: Self.moment(2026, 8, 19, 9, 0),
            calendar: calendar
        )
        XCTAssertEqual(aligned.date, Self.moment(2026, 8, 19, 15, 0))
        XCTAssertEqual(aligned.time, Self.moment(2026, 8, 19, 15, 0))

        // An end time still after the start survives untouched.
        aligned = ScheduleEditorTimePolicy.endFollowingStart(
            start: Self.moment(2026, 8, 19, 14, 0),
            endDate: Self.moment(2026, 8, 19, 0, 0),
            endTime: Self.moment(2026, 8, 19, 18, 0),
            calendar: calendar
        )
        XCTAssertEqual(aligned.time, Self.moment(2026, 8, 19, 18, 0))

        // The end's clock is re-anchored onto the day the end is shown on, which is what lets
        // the bound on the end time control weigh it against the right day.
        aligned = ScheduleEditorTimePolicy.endFollowingStart(
            start: Self.moment(2026, 8, 19, 9, 0),
            endDate: Self.moment(2026, 8, 20, 0, 0),
            endTime: Self.moment(2026, 8, 19, 18, 0),
            calendar: calendar
        )
        XCTAssertEqual(aligned.time, Self.moment(2026, 8, 20, 18, 0))
    }

    /// Whatever the start is moved to, the end that follows it has to be a range the editor
    /// can actually save — never an end before its own start.
    func testEndFollowingTheStartIsNeverBeforeIt() {
        let calendar = CalendarDateSupport.calendar
        let endDate = Self.moment(2026, 8, 19, 0, 0)

        for hour in 0..<24 {
            for endHour in [0, 9, 23] {
                let start = Self.moment(2026, 8, 19, hour, 30)
                let endTime = endHour == 0 ? nil : Self.moment(2026, 8, 19, endHour, 0)
                let aligned = ScheduleEditorTimePolicy.endFollowingStart(
                    start: start,
                    endDate: endDate,
                    endTime: endTime,
                    calendar: calendar
                )
                let end = ScheduleEditorTimePolicy.effectiveEnd(
                    start: start,
                    endDate: aligned.date,
                    endTime: aligned.time,
                    calendar: calendar
                )
                XCTAssertGreaterThanOrEqual(
                    end,
                    start,
                    "start \(hour):30 with end hour \(endHour) left an end before its start"
                )
            }
        }
    }

    /// The end date is barred from going before the start by the control itself, not by a check
    /// that only fires once the user has already picked an impossible date: a day before the
    /// start cannot be tapped at all.
    func testEndDateControlIsBoundedRatherThanValidatedAfterwards() throws {
        let start = DateOnly(rawValue: "2026-08-19")
        let mode = DPDateFieldMode.range(anchor: start)

        XCTAssertEqual(
            DPDateFieldPolicy.lowerBound(mode: mode, minimum: start),
            start,
            "The end calendar's floor is the start's own day"
        )
        for earlier in ["2026-08-18", "2026-07-31", "2025-12-31"] {
            XCTAssertEqual(
                DPDateFieldPolicy.tap(DateOnly(rawValue: earlier), mode: mode, minimum: start, maximum: nil),
                .ignored,
                "\(earlier) sits before the start and must not be selectable"
            )
        }
        XCTAssertFalse(
            DPDateFieldPolicy.canGoToPreviousMonth(
                from: DatePickerMonth(year: 2026, month: 8),
                mode: mode,
                minimum: start
            ),
            "Paging back to a month of dead days is closed too"
        )
        XCTAssertEqual(
            DPDateFieldPolicy.tap(start, mode: mode, minimum: start, maximum: nil),
            .staged(start),
            "A same-day end is still a legal end"
        )

        let editor = try Self.scheduleEditorSource()
        XCTAssertTrue(
            editor.contains("mode: .range(anchor: startDay)"),
            "The end date is bounded at the start's own day"
        )
        XCTAssertTrue(editor.contains("minimum: startDay"))
        XCTAssertTrue(
            editor.contains("in: (lowerBound ?? .distantPast)..."),
            "The end time keeps the same bounded initialiser"
        )
        XCTAssertTrue(
            editor.contains("notEarlierThan: start,"),
            "The end time is bounded at the start instant"
        )
        XCTAssertTrue(
            editor.contains(".onChange(of: startDate) { _, _ in alignEndWithStart() }"),
            "Edit mode lets the start move, so the end follows it"
        )
        XCTAssertTrue(editor.contains(".onChange(of: startTime) { _, _ in alignEndWithStart() }"))
        XCTAssertTrue(editor.contains(".onChange(of: endDate) { _, _ in alignEndWithStart() }"))
    }

    /// A tap in the end calendar paints the span it would produce; it does not write it. Only
    /// the confirm button commits, which is what keeps the editor clean — and its discard alert
    /// disarmed — while the user is still deciding.
    func testTappingAnEndDayStagesItRatherThanCommittingIt() {
        let start = DateOnly(rawValue: "2026-08-19")
        let mode = DPDateFieldMode.range(anchor: start)

        for day in ["2026-08-19", "2026-08-20", "2026-09-04"] {
            XCTAssertEqual(
                DPDateFieldPolicy.tap(DateOnly(rawValue: day), mode: mode, minimum: start, maximum: nil),
                .staged(DateOnly(rawValue: day)),
                "\(day) must be staged, never written straight through"
            )
        }
        // The span is painted from the anchor, so the user sees the schedule's length forming.
        XCTAssertEqual(
            DPDateFieldPolicy.rangeState(
                DateOnly(rawValue: "2026-08-20"),
                mode: mode,
                stagedDay: DateOnly(rawValue: "2026-08-21")
            ),
            .middle
        )

        // The start row is deliberately not a range: it commits on the tap, exactly as the web's
        // single-select start input does.
        XCTAssertEqual(
            DPDateFieldPolicy.tap(DateOnly(rawValue: "2026-08-20"), mode: .single, minimum: nil, maximum: nil),
            .committed(DateOnly(rawValue: "2026-08-20"))
        )
    }

    /// A staged day is unwritten, so the editor cannot see it. Dirtiness keys off the committed
    /// dates alone, which is what leaves the discard alert disarmed until confirm.
    func testAStagedEndDayLeavesTheEditorClean() {
        let start = Self.moment(2026, 8, 19, 9, 30)
        let end = Self.moment(2026, 8, 19, 10, 30)
        let confirmed = Self.moment(2026, 8, 21, 10, 30)

        func isDirty(end current: Date) -> Bool {
            ScheduleEditorDismissalPolicy.isDirty(
                initialContent: "Shift", content: "Shift",
                initialDescription: "Notes", description: "Notes",
                initialVisibility: .family, visibility: .family,
                initialStart: start, start: start,
                initialEnd: end, end: current,
                initialTagIDs: [], tagIDs: [],
                initialAttachmentIDs: [], attachmentIDs: [],
                hasAttachmentSession: false
            )
        }

        XCTAssertFalse(isDirty(end: end), "Staging cannot reach the editor, so nothing is dirty yet")
        XCTAssertTrue(isDirty(end: confirmed), "Confirming writes the day through and arms the alert")
    }

    /// The editor stores instants; the date field speaks calendar days. The bridge has to move
    /// the day without shifting it across a time-zone boundary and without dropping the clock
    /// the editor still needs.
    func testMovingAScheduleDateKeepsItsClockAndItsDay() {
        let calendar = CalendarDateSupport.calendar

        for hour in [0, 9, 12, 23] {
            let original = Self.moment(2026, 8, 19, hour, 30)
            XCTAssertEqual(
                ScheduleEditorTimePolicy.day(of: original),
                DateOnly(rawValue: "2026-08-19"),
                "\(hour):30 must read as the day it is shown on"
            )

            for target in ["2026-08-19", "2026-08-20", "2026-09-01", "2027-03-01"] {
                let moved = ScheduleEditorTimePolicy.date(
                    original,
                    movedTo: DateOnly(rawValue: target),
                    calendar: calendar
                )
                XCTAssertEqual(
                    ScheduleEditorTimePolicy.day(of: moved),
                    DateOnly(rawValue: target),
                    "moving \(hour):30 to \(target) landed on another day"
                )
                XCTAssertEqual(
                    calendar.dateComponents([.hour, .minute], from: moved),
                    calendar.dateComponents([.hour, .minute], from: original),
                    "moving \(hour):30 to \(target) lost the clock the editor still needs"
                )
            }
        }

        // A value that names no real day leaves the stored instant alone rather than collapsing
        // it to some fallback.
        let untouched = Self.moment(2026, 8, 19, 9, 30)
        for broken in ["", "2026-02-30", "not-a-day"] {
            XCTAssertEqual(
                ScheduleEditorTimePolicy.date(untouched, movedTo: DateOnly(rawValue: broken), calendar: calendar),
                untouched,
                "\(broken) is not a day and must not move the schedule"
            )
        }
    }

    /// The date field defaults to `AppLocalization.locale` while the editor formats through
    /// `CalendarLocalization.selectedLocale`. They are the same locale; the editor passes it
    /// explicitly so a future divergence shows up here rather than as a half-translated row.
    func testTheDateFieldFollowsTheEditorsOwnLocale() throws {
        XCTAssertEqual(CalendarLocalization.selectedLocale, AppLocalization.locale)

        let editor = try Self.scheduleEditorSource()
        let builder = try Self.declaration(named: "private func dateControl", in: editor)
        XCTAssertTrue(builder.contains("locale: CalendarLocalization.selectedLocale"))
    }

    /// The start and end controls were asked to look identical, so the locked start may differ
    /// only in *state*: it is the same field with `isReadOnly` set, and the lock, the drained
    /// colour and the one static VoiceOver reading all come from that state rather than from
    /// decoration the editor bolts on beside the control.
    func testLockedStartDiffersFromTheEndOnlyInState() throws {
        let editor = try Self.scheduleEditorSource()

        XCTAssertTrue(
            editor.contains("isReadOnly: existing == nil"),
            "A new schedule's start is locked; an existing schedule's start is editable"
        )
        XCTAssertFalse(
            editor.contains(#"Image(systemName: "lock.fill")"#),
            "The lock is the field's own read-only state, not a badge bolted on beside it"
        )
        XCTAssertFalse(
            editor.contains(".grayscale(1)"),
            "Draining the control's colour was decoration standing in for a state it now has"
        )
        XCTAssertFalse(
            editor.contains(".allowsHitTesting(false)"),
            "Read-only is a state of the field, not a touch barrier laid over an editable one"
        )
        XCTAssertFalse(
            editor.contains(".datePickerStyle(.wheel)"),
            "The locked start is the same field the end row draws"
        )

        // VoiceOver meets the locked row as one static reading: the date it shows plus why it
        // will not move, in the language the row is drawn in.
        let day = DateOnly(rawValue: "2026-08-19")
        for identifier in ["ko_KR", "en_US"] {
            let locale = Locale(identifier: identifier)
            let spoken = DPDateFieldLocalization.lockedAccessibilityValue(day, locale: locale)
            let reason = CalendarLocalization.text("calendar.schedule.start.locked", locale: locale)

            XCTAssertFalse(reason.isEmpty, "\(identifier) has no reason string for the locked start")
            XCTAssertTrue(spoken.hasSuffix(", \(reason)"), "\(identifier) spoke \(spoken)")
            XCTAssertTrue(spoken.contains("2026"), "\(identifier) spoke \(spoken)")
            XCTAssertTrue(spoken.contains("19"), "\(identifier) spoke \(spoken)")
        }
    }

    /// The schedule editor alone. `CalendarView.swift` also holds the D-day editor, which
    /// legitimately draws its own lock badge and its own date picker, so a check meant for the
    /// schedule editor has to be asked of the schedule editor.
    private static func scheduleEditorSource() throws -> String {
        try declaration(
            named: "private struct ScheduleEditorView<Header: View>: View",
            in: calendarViewSource()
        )
    }

    /// Reads one declaration out of the view's source so a check meant for the shared date
    /// builder cannot be satisfied by an unrelated line elsewhere in a 4,000-line file.
    private static func declaration(named signature: String, in source: String) throws -> String {
        let start = try XCTUnwrap(
            source.range(of: signature),
            "\(signature) is no longer declared in CalendarView.swift"
        ).lowerBound
        var depth = 0
        var opened = false
        var index = start
        while index < source.endIndex {
            let character = source[index]
            if character == "{" {
                depth += 1
                opened = true
            } else if character == "}" {
                depth -= 1
                if opened, depth == 0 { return String(source[start...index]) }
            }
            index = source.index(after: index)
        }
        return String(source[start...])
    }

    private static func calendarViewSource() throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Calendar/CalendarView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    /// The end chip only appears for an end that differs from the start and is not midnight,
    /// so adding an end right after a start has to produce one at every hour of the day.
    func testScheduleEditorAddingAnEndAfterAStartAlwaysYieldsAnEndTime() {
        let calendar = CalendarDateSupport.calendar
        let day = Self.moment(2026, 8, 19, 0, 0)

        for hour in 0..<24 {
            let now = Self.moment(2026, 8, 19, hour, 15)
            let startTime = ScheduleEditorTimePolicy.defaultStartTime(on: day, now: now, calendar: calendar)
            let start = ScheduleEditorTimePolicy.combine(date: day, time: startTime, calendar: calendar)
            let end = ScheduleEditorTimePolicy.defaultEnd(start: start, endDate: day, calendar: calendar)

            XCTAssertNotNil(
                ScheduleEditorTimePolicy.endTime(of: end, start: start, calendar: calendar),
                "no end time offered for a start added at \(hour):15"
            )
        }
    }

    private static func moment(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        CalendarDateSupport.calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
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

    func testCalendarMonthNavigationAndPickerUseRoutineFeedback() async {
        let repository = CalendarRepositoryMock()
        let haptics = DPHapticCenter()
        let model = CalendarViewModel(
            repository: repository,
            now: date(2026, 8, 12),
            hapticCenter: haptics
        )
        await model.load()
        XCTAssertNil(haptics.event)

        await model.changeMonth(by: 1)
        guard let navigationEvent = haptics.event else {
            XCTFail("Changing the month should emit a routine event")
            return
        }
        XCTAssertEqual(navigationEvent.kind, .routine)
        let navigationEventID = navigationEvent.id

        await model.changeMonth(by: 0)
        XCTAssertEqual(haptics.event?.id, navigationEventID, "A no-op month change stays silent")

        await model.selectYearMonth(year: 2028, month: 2)
        XCTAssertEqual(haptics.event?.kind, .routine)
    }

    func testSelectingDayOnMyCalendarOpensTheDayWithoutCreatingAHighlight() async throws {
        let haptics = DPHapticCenter()
        let model = CalendarViewModel(
            repository: CalendarRepositoryMock(),
            now: date(2026, 8, 12),
            hapticCenter: haptics
        )
        await model.load()
        let day = try XCTUnwrap(model.days.first { $0.cell.date.rawValue == "2026-08-12" })

        model.selectDay(day)

        XCTAssertEqual(model.selectedDay?.cell.date, day.cell.date)
        XCTAssertNil(model.highlightedDate)
        XCTAssertEqual(haptics.event?.kind, .selection)
    }

    func testSelectingDayOnManagedCalendarPreservesExistingHighlight() async throws {
        let haptics = DPHapticCenter()
        let highlightedDate = DateOnly(rawValue: "2026-08-12")
        let model = CalendarViewModel(
            repository: CalendarRepositoryMock(canManage: true),
            now: date(2026, 8, 12),
            memberID: 9,
            date: highlightedDate,
            hapticCenter: haptics
        )
        await model.load()
        let day = try XCTUnwrap(model.days.first { $0.cell.date.rawValue == "2026-08-13" })

        model.selectDay(day)

        XCTAssertTrue(model.canManage)
        XCTAssertEqual(model.selectedDay?.cell.date, day.cell.date)
        XCTAssertEqual(model.highlightedDate, highlightedDate)
        XCTAssertEqual(haptics.event?.kind, .selection)
    }

    func testScheduleMutationEmitsSuccessOnlyAfterTheSaveCompletes() async {
        let repository = CalendarRepositoryMock()
        let haptics = DPHapticCenter()
        let model = CalendarViewModel(
            repository: repository,
            now: date(2026, 8, 12),
            hapticCenter: haptics
        )
        await model.load()

        let saved = await model.saveSchedule(
            existing: nil,
            content: "Dinner",
            description: "",
            visibility: .friends,
            start: date(2026, 8, 12),
            end: date(2026, 8, 12, hour: 1),
            tagFriendIDs: [],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )

        XCTAssertTrue(saved)
        XCTAssertEqual(haptics.event?.kind, .success)
    }

    func testNewScheduleUsesThePlainRepositoryCreate() async {
        let repository = CalendarRepositoryMock()
        let model = CalendarViewModel(repository: repository, now: date(2026, 8, 12))
        await model.load()

        let saved = await model.saveSchedule(
            existing: nil,
            content: "Dinner",
            description: "",
            visibility: .friends,
            start: date(2026, 8, 12),
            end: date(2026, 8, 12, hour: 1),
            tagFriendIDs: [],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )

        XCTAssertTrue(saved)
        let savedSchedule = await repository.savedSchedule
        XCTAssertNotNil(savedSchedule)
    }

    func testScheduleValidationUsesWarningFeedbackWithoutCallingTheRepository() async {
        let repository = CalendarRepositoryMock()
        let haptics = DPHapticCenter()
        let model = CalendarViewModel(
            repository: repository,
            now: date(2026, 8, 12),
            hapticCenter: haptics
        )
        await model.load()

        let saved = await model.saveSchedule(
            existing: nil,
            content: "   ",
            description: "",
            visibility: .friends,
            start: date(2026, 8, 12),
            end: date(2026, 8, 12),
            tagFriendIDs: [],
            attachmentSessionID: nil,
            orderedAttachmentIDs: [],
            aiTimeParsingRequested: false
        )

        XCTAssertFalse(saved)
        XCTAssertEqual(haptics.event?.kind, .warning)
        let request = await repository.savedSchedule
        XCTAssertNil(request)
    }

    func testFailedScheduleDeleteUsesErrorFeedback() async {
        let repository = CalendarRepositoryMock(failDestructiveMutations: true)
        let haptics = DPHapticCenter()
        let model = CalendarViewModel(
            repository: repository,
            now: date(2026, 8, 12),
            hapticCenter: haptics
        )
        await model.load()

        let succeeded = await model.deleteSchedule(model.days[11].schedules[0])

        XCTAssertFalse(succeeded)
        XCTAssertEqual(haptics.event?.kind, .error)
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

    func testSlowerPreviousMonthResponseCannotOverwriteLatestMonth() async {
        let gate = CalendarMonthRaceGate()
        let repository = CalendarRepositoryMock(monthGate: gate)
        let model = CalendarViewModel(
            repository: repository,
            now: date(2026, 8, 12),
            outbox: CalendarMonthRaceOutboxStub()
        )

        let augustLoad = Task { await model.load() }
        await gate.waitForRequest(OfflineMonthKey(year: 2026, month: 8))

        let septemberLoad = Task {
            await model.selectYearMonth(year: 2026, month: 9, emitFeedback: false)
        }
        await gate.waitForRequest(OfflineMonthKey(year: 2026, month: 9))

        await gate.release(OfflineMonthKey(year: 2026, month: 9))
        await septemberLoad.value

        XCTAssertEqual(model.year, 2026)
        XCTAssertEqual(model.month, 9)
        XCTAssertEqual(
            model.days.first(where: { $0.cell.date.rawValue == "2026-09-12" })?.schedules.first?.startDateTime.rawValue,
            "2026-09-12T00:00:00"
        )

        await gate.release(OfflineMonthKey(year: 2026, month: 8))
        await augustLoad.value

        XCTAssertEqual(model.year, 2026)
        XCTAssertEqual(model.month, 9)
        XCTAssertEqual(
            model.days.first(where: { $0.cell.date.rawValue == "2026-09-12" })?.schedules.first?.startDateTime.rawValue,
            "2026-09-12T00:00:00"
        )
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
        XCTAssertEqual(
            CalendarLocalization.format(
                "calendar.duty.batch.description.month",
                2026,
                8,
                locale: .korean
            ),
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

    func testDutyBatchFileSizePolicyRejectsTheProxyBoundaryAndUnknownMetadata() {
        let maximum = AttachmentUploadPolicy.safeMaximumBytes

        XCTAssertEqual(
            CalendarFeatureLogic.dutyBatchFileSizeValidation(maximum - 1),
            .allowed
        )
        XCTAssertEqual(
            CalendarFeatureLogic.dutyBatchFileSizeValidation(maximum),
            .tooLarge
        )
        XCTAssertEqual(
            CalendarFeatureLogic.dutyBatchFileSizeValidation(maximum + 1),
            .tooLarge
        )
        XCTAssertEqual(
            CalendarFeatureLogic.dutyBatchFileSizeValidation(nil),
            .unavailable
        )
        XCTAssertEqual(
            CalendarFeatureLogic.dutyBatchFileSizeValidation(-1),
            .unavailable
        )
    }

    func testDutyBatchDataSizePolicyKeepsTheRequestBoundaryAfterReading() {
        let maximum = AttachmentUploadPolicy.safeMaximumBytes

        XCTAssertEqual(
            CalendarFeatureLogic.dutyBatchDataSizeValidation(maximum - 1),
            .allowed
        )
        XCTAssertEqual(
            CalendarFeatureLogic.dutyBatchDataSizeValidation(maximum),
            .tooLarge
        )
        XCTAssertEqual(
            CalendarFeatureLogic.dutyBatchDataSizeValidation(maximum + 1),
            .tooLarge
        )
    }

    func testDutyBatchMultipartBodyCountsItsHeadersAndBoundaryAgainstTheLimit() throws {
        let maximum = AttachmentUploadPolicy.safeMaximumBytes
        let boundary = "DutyparkDuty-fixed"
        let emptyBody = try XCTUnwrap(
            CalendarDutyBatchMultipart.body(
                memberID: 42,
                year: 2026,
                month: 8,
                filename: "roster.xlsx",
                data: Data(),
                boundary: boundary
            )
        )
        let overhead = emptyBody.count

        let bodyBelowLimit = try XCTUnwrap(
            CalendarDutyBatchMultipart.body(
                memberID: 42,
                year: 2026,
                month: 8,
                filename: "roster.xlsx",
                data: Data(repeating: 0x41, count: maximum - overhead - 1),
                boundary: boundary
            )
        )
        XCTAssertEqual(bodyBelowLimit.count, maximum - 1)

        let bodyAtLimit = CalendarDutyBatchMultipart.body(
            memberID: 42,
            year: 2026,
            month: 8,
            filename: "roster.xlsx",
            data: Data(repeating: 0x41, count: maximum - overhead),
            boundary: boundary
        )
        XCTAssertNil(bodyAtLimit, "The complete multipart request must remain strictly below 10 MiB")
    }

    func testDutyBatchMultipartBodyRejectsOversizedDataBeforeBuildingTheBody() throws {
        let maximum = AttachmentUploadPolicy.safeMaximumBytes
        let boundary = "DutyparkDuty-fixed"
        let emptyBody = try XCTUnwrap(
            CalendarDutyBatchMultipart.body(
                memberID: 42,
                year: 2026,
                month: 8,
                filename: "roster.xlsx",
                data: Data(),
                boundary: boundary
            )
        )

        XCTAssertNil(
            CalendarDutyBatchMultipart.body(
                memberID: 42,
                year: 2026,
                month: 8,
                filename: "roster.xlsx",
                data: Data(repeating: 0x41, count: maximum - emptyBody.count + 1),
                boundary: boundary
            )
        )
    }

    func testDutyBatchRepositoryRejectsMultipartOverflowBeforeSendingARequest() async {
        CalendarURLProtocolStub.requestCount = 0
        CalendarURLProtocolStub.handler = { request in
            CalendarURLProtocolStub.requestCount += 1
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"result":true,"workingDays":0,"offDays":0}"#.utf8)
            )
        }
        defer {
            CalendarURLProtocolStub.handler = nil
            CalendarURLProtocolStub.requestCount = 0
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CalendarURLProtocolStub.self]
        let repository = CalendarRepository(
            client: APIClient(
                baseURL: URL(string: "https://dutypark.test/api/")!,
                session: URLSession(configuration: configuration)
            )
        )

        do {
            _ = try await repository.uploadDutyBatch(
                memberID: 42,
                year: 2026,
                month: 8,
                filename: "roster.xlsx",
                data: Data(repeating: 0x41, count: AttachmentUploadPolicy.safeMaximumBytes - 1)
            )
            XCTFail("Multipart overhead should make this request exceed the proxy limit")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected upload error: \(error)")
        }

        XCTAssertEqual(CalendarURLProtocolStub.requestCount, 0)
    }

    func testDutyBatchMultipartFilenameSanitizesQuotedEscapedAndControlCharacters() throws {
        let rawFilename = "roster\"\\night\r\n\u{0000}\u{001F}\u{007F}\u{0085}.xlsx"
        let sanitized = CalendarDutyBatchMultipart.sanitizedFilename(rawFilename)

        XCTAssertFalse(sanitized.contains("\""))
        XCTAssertFalse(sanitized.contains("\\"))
        XCTAssertFalse(
            sanitized.unicodeScalars.contains {
                $0.value <= 0x1F || $0.value == 0x7F || (0x80...0x9F).contains($0.value)
            }
        )
        XCTAssertTrue(sanitized.hasSuffix(".xlsx"))

        let body = try XCTUnwrap(
            CalendarDutyBatchMultipart.body(
                memberID: 42,
                year: 2026,
                month: 8,
                filename: rawFilename,
                data: Data(),
                boundary: "DutyparkDuty-fixed"
            )
        )
        let bodyText = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(bodyText.contains("filename=\"\(sanitized)\""))
    }

    func testDutyBatchUploadPreflightsResourceMetadataBeforeMaterializingData() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Calendar/CalendarViewModel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let upload = try Self.declaration(named: "func uploadDutyBatch(url: URL) async", in: source)
        let metadata = try XCTUnwrap(upload.range(of: "url.resourceValues(forKeys: [.fileSizeKey])"))
        let dataRead = try XCTUnwrap(upload.range(of: "Data(contentsOf: url)"))

        XCTAssertLessThan(
            metadata.lowerBound,
            dataRead.lowerBound,
            "The file URL metadata must be checked before Data(contentsOf:)"
        )
        XCTAssertTrue(upload.contains("dutyBatchFileSizeValidation"))
        XCTAssertTrue(upload.contains("dutyBatchDataSizeValidation"))

        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Calendar/CalendarRepository.swift")
        let repository = try String(contentsOf: repositoryURL, encoding: .utf8)
        XCTAssertTrue(
            repository.contains("guard data.count < AttachmentUploadPolicy.safeMaximumBytes"),
            "The multipart request boundary must reject oversized Data even if a caller bypasses the ViewModel"
        )
        XCTAssertTrue(
            repository.contains("CalendarDutyBatchMultipart.body("),
            "The repository must build multipart data through the guarded builder"
        )
        XCTAssertTrue(
            repository.contains("guard let body = CalendarDutyBatchMultipart.body("),
            "The final request boundary must reject multipart overhead overflow"
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
    let monthGate: CalendarMonthRaceGate?

    init(
        canManage: Bool = false,
        cancelMemberLoad: Bool = false,
        friends: [FriendDTO] = [],
        scheduleOwnerID: MemberID = 1,
        failDestructiveMutations: Bool = false,
        returnsTaggedSchedule: Bool = false,
        otherDuties: [OtherDutyResponse] = [],
        monthGate: CalendarMonthRaceGate? = nil
    ) {
        canManageValue = canManage
        self.cancelMemberLoad = cancelMemberLoad
        friendValues = friends
        self.scheduleOwnerID = scheduleOwnerID
        self.failDestructiveMutations = failDestructiveMutations
        self.returnsTaggedSchedule = returnsTaggedSchedule
        otherDutyValues = otherDuties
        self.monthGate = monthGate
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
        await monthGate?.wait(year: year, month: month)
        return (1...42).map { TeamDayDTO(year: year, month: month, day: $0) }
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

private actor CalendarMonthRaceGate {
    private var requested: Set<OfflineMonthKey> = []
    private var requestWaiters: [OfflineMonthKey: [CheckedContinuation<Void, Never>]] = [:]
    private var releaseWaiters: [OfflineMonthKey: [CheckedContinuation<Void, Never>]] = [:]

    func wait(year: Int, month: Int) async {
        let key = OfflineMonthKey(year: year, month: month)
        requested.insert(key)
        requestWaiters.removeValue(forKey: key)?.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            releaseWaiters[key, default: []].append(continuation)
        }
    }

    func waitForRequest(_ key: OfflineMonthKey) async {
        guard !requested.contains(key) else { return }
        await withCheckedContinuation { continuation in
            requestWaiters[key, default: []].append(continuation)
        }
    }

    func release(_ key: OfflineMonthKey) {
        releaseWaiters.removeValue(forKey: key)?.forEach { $0.resume() }
    }
}

private actor CalendarMonthRaceOutboxStub: OfflineOutboxProviding {
    func enqueueScheduleCreate(
        accountID: MemberID,
        request: ScheduleSaveDTO,
        operationID: UUID,
        now: Date
    ) async throws -> OfflineOutboxEntry {
        fatalError("Not used by the calendar month race test")
    }

    func enqueueTodoCreate(
        accountID: MemberID,
        request: TodoRequest,
        operationID: UUID,
        now: Date
    ) async throws -> OfflineOutboxEntry {
        fatalError("Not used by the calendar month race test")
    }

    func entries(accountID: MemberID) async -> [OfflineOutboxEntry] { [] }
    func pendingEntries(accountID: MemberID, now: Date) async -> [OfflineOutboxEntry] { [] }

    func recordRetry(
        accountID: MemberID,
        operationID: UUID,
        error: OfflineOutboxFailure,
        nextAttemptAt: Date?
    ) async throws {}

    func markPermanentFailure(
        accountID: MemberID,
        operationID: UUID,
        error: OfflineOutboxFailure
    ) async throws {}

    func retryPermanentFailure(
        accountID: MemberID,
        operationID: UUID,
        now: Date
    ) async throws {}

    func markSucceeded(accountID: MemberID, operationID: UUID) async throws {}
    func purge(accountID: MemberID) async throws {}
}

private final class CalendarURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("CalendarURLProtocolStub handler is not set")
        }
        Self.requestCount += 1
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
