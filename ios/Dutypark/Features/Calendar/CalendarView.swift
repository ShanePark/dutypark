import SwiftUI
import UniformTypeIdentifiers

enum DDayModalSelection: Identifiable, Equatable {
    case create
    case detail(DDayDTO)

    var id: String {
        switch self {
        case .create: "create"
        case .detail(let item): "detail-\(item.id)"
        }
    }
}

private struct CalendarTodoSelection: Identifiable {
    let todo: TodoDTO
    var id: String { todo.id }
}

nonisolated enum CalendarMainLayout {
    static func shouldShowDutyToolbar(
        hasDutySummary: Bool,
        hasComparisonAction: Bool,
        hasQuickEditAction: Bool,
        hasImportAction: Bool,
        isQuickDutyEditing: Bool
    ) -> Bool {
        isQuickDutyEditing
            || hasDutySummary
            || hasComparisonAction
            || hasQuickEditAction
            || hasImportAction
    }
}

nonisolated enum CalendarReportPolicy {
    static func canReport(
        isSignedIn: Bool,
        isMyCalendar: Bool,
        isTagged: Bool,
        scheduleOwnerID: MemberID?,
        reporterID: MemberID?
    ) -> Bool {
        guard isSignedIn, let reporterID else { return false }
        return (!isMyCalendar || isTagged) && scheduleOwnerID != reporterID
    }
}

/// Whether tapping a day is worth anything.
///
/// The day detail lists schedules and nothing else: the duty is already told by the
/// colour of the cell, and holidays, D-Days and to-dos are drawn in the cell itself.
/// So a reader who cannot write opens a sheet with nothing in it on a day that holds
/// no schedule — a tap that answers with silence — and the day stays shut instead.
/// Where the reader can write, on their own calendar or one they manage, an empty day
/// is the way a schedule gets added and always opens.
nonisolated enum CalendarDayOpenPolicy {
    static func showsNothing(_ day: CalendarDayContent) -> Bool {
        day.schedules.isEmpty
    }

    static func opensDetail(_ day: CalendarDayContent, canEdit: Bool) -> Bool {
        canEdit || !showsNothing(day)
    }
}

/// Who a schedule names, in the order the web names them.
///
/// A schedule's tags leave out the member whose calendar is being read — their own
/// name beside their own day says nothing — and whoever did the tagging comes first,
/// because on a tagged schedule they are the one the reader does not already know.
nonisolated enum ScheduleTagDisplayPolicy {
    static func displayTags(for schedule: ScheduleDTO, calendarMemberID: MemberID?) -> [DPMemberTagItem] {
        var items = schedule.tags
            .filter { !$0.name.isEmpty && $0.id != calendarMemberID }
            .map(DPMemberTagItem.init)

        guard schedule.isTagged else { return items }

        if let taggedBy = schedule.taggedByMember, !taggedBy.name.isEmpty {
            let owner = DPMemberTagItem(taggedBy)
            let alreadyListed = owner.memberID != nil && items.contains { $0.memberID == owner.memberID }
            if !alreadyListed { items.insert(owner, at: 0) }
        } else if !schedule.owner.isEmpty {
            // A tagger whose account is gone is remembered by name alone, so the tag
            // carries the name without a photo rather than disappearing.
            items.insert(DPMemberTagItem(memberID: nil, name: schedule.owner), at: 0)
        }

        return items
    }
}

/// The tail of the "this month" callout: a slender pointer that climbs from the capsule to
/// the month label sitting in the navigation bar above it.
private struct CalloutTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct CalendarTopScrollEdgeEffectModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Keep the top boundary readable when the calendar rows scroll under the
            // fixed navigation controls, while leaving the iOS 17 behaviour untouched.
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

struct CalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @StateObject private var offlineNetworkMonitor = OfflineNetworkMonitor.shared
    @StateObject private var model: CalendarViewModel
    @StateObject private var todoDetailModel = TodoViewModel()
    @State private var showsSearch = false
    @State private var dDayModalSelection: DDayModalSelection?
    @State private var showsBatchUpdate = false
    @State private var showsMonthPicker = false
    @State private var showsDutyComparison = false
    @State private var importsDutyBatch = false
    @State private var todoSelection: CalendarTodoSelection?
    @State private var todoDetailCanDismiss = true
    @State private var todoDetailDismissRequest = 0
    @State private var dayModalCanDismiss = true
    @State private var dDayModalCanDismiss = true
    @State private var monthPickerCanDismiss = true
    @State private var searchModalCanDismiss = true
    @State private var dayDismissRequest = 0
    @State private var dDayDismissRequest = 0
    @State private var reportTarget: ReportTarget?
    @State private var reportCanDismiss = true
    @State private var showsBlockConfirmation = false
    @State private var monthSlideOffset: CGFloat = 0
    @State private var calendarGridWidth: CGFloat = 0
    @State private var isSlidingMonth = false
    @State private var isSwipingMonth = false
    @State private var leavesAfterBlock = false
    @State private var refreshesAfterReportedBlock = false
    @StateObject private var blockModel = MemberBlockViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let isPushedMemberCalendar: Bool
    private let currentMonthRequestID: Int

    init(
        memberID: MemberID? = nil,
        date: DateOnly? = nil,
        scheduleID: ScheduleID? = nil,
        isPushed: Bool = false,
        currentMonthRequestID: Int = 0
    ) {
        _model = StateObject(wrappedValue: CalendarViewModel(memberID: memberID, date: date, scheduleID: scheduleID))
        isPushedMemberCalendar = isPushed
        self.currentMonthRequestID = currentMonthRequestID
    }

    var body: some View {
        Group {
            if model.isLoading && model.days.isEmpty {
                DPLoadingState(label: LocalizedStringKey(CalendarLocalization.text("calendar.loading")))
            } else if let error = model.errorMessage, model.days.isEmpty {
                DPErrorState(
                    title: LocalizedStringKey(CalendarLocalization.text("calendar.error.title")),
                    message: LocalizedStringKey(error),
                    retryTitle: LocalizedStringKey(CalendarLocalization.text("calendar.retry")),
                    retryAction: { Task { await model.load(emitErrorFeedback: true) } }
                )
            } else {
                calendarContent
            }
        }
        .dpKeyboardDismissToolbar()
        .background(DPColor.backgroundPrimary)
        .navigationBarBackButtonHidden(isPushedMemberCalendar)
        // The identity chip stands in for the system back button, so the pushed screen
        // restores UIKit's edge pop itself; at the calendar tab root there is nothing to
        // pop and the gesture policy declines it.
        .dpInteractivePopGestureEnabled()
        .toolbar { calendarToolbar }
        .task {
            configureFromSession()
            if model.days.isEmpty {
                await model.load()
            } else {
                model.resumeServerRecoveryIfNeeded()
            }
        }
        .onChange(of: currentMonthRequestID) { _, _ in
            Task { await model.goToToday(emitFeedback: false) }
        }
        .onDisappear { model.cancelBackgroundTasks() }
        .onChange(of: session.availability) { _, availability in
            configureFromSession()
            Task {
                if availability == .online || model.days.isEmpty {
                    await model.load()
                }
            }
        }
        .onChange(of: session.state) { _, _ in
            // The Calendar can stay mounted while the authenticated account
            // changes. Rebind the detail-only Todo model before a cached item
            // can issue a mutation with the previous account's context.
            todoSelection = nil
            configureFromSession()
        }
        .onChange(of: offlineNetworkMonitor.status) { _, status in
            guard status == .satisfied, session.availability == .online else { return }
            Task { await model.handleNetworkBecameReachable() }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: Notification.Name("offlineSyncDidComplete")
        )) { notification in
            guard case .authenticated(let member) = session.state,
                  offlineSyncAccountID(from: notification) == member.id
            else { return }
            Task { await model.handleOfflineSyncCompleted() }
        }
        .fullScreenCover(item: $model.selectedDay) { day in
            DPModalOverlay(
                onDismiss: {
                    model.selectedDay = nil
                    dayModalCanDismiss = true
                    finishDayDismissal()
                },
                canDismiss: dayModalCanDismiss,
                onDismissRequest: { _ in dayDismissRequest += 1 }
            ) { availableSize, dismiss in
                DayDetailView(
                    model: model,
                    initialDay: day,
                    maximumHeight: availableSize.height,
                    onDismissabilityChange: { dayModalCanDismiss = $0 },
                    onBlockedScheduleOwner: { leavesCalendar in
                        refreshesAfterReportedBlock = true
                        leavesAfterBlock = leavesCalendar
                    },
                    dismissRequest: dayDismissRequest
                ) {
                    dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $showsSearch) {
            DPModalOverlay(
                onDismiss: {
                    showsSearch = false
                    searchModalCanDismiss = true
                },
                canDismiss: searchModalCanDismiss
            ) { availableSize, dismiss in
                ScheduleSearchView(
                    model: model,
                    maximumHeight: availableSize.height,
                    onDismissabilityChange: { searchModalCanDismiss = $0 },
                    dismiss: dismiss
                )
            }
        }
        .fullScreenCover(item: $dDayModalSelection) { selection in
            DPModalOverlay(
                onDismiss: {
                    dDayModalSelection = nil
                    dDayModalCanDismiss = true
                },
                canDismiss: dDayModalCanDismiss,
                onDismissRequest: { _ in dDayDismissRequest += 1 }
            ) { availableSize, dismiss in
                DDayModalView(
                    model: model,
                    selection: selection,
                    maximumHeight: availableSize.height,
                    onDismissabilityChange: { dDayModalCanDismiss = $0 },
                    dismissRequest: dDayDismissRequest,
                    dismiss: dismiss
                )
            }
        }
        .fullScreenCover(isPresented: $showsMonthPicker) {
            DPModalOverlay(
                onDismiss: {
                    showsMonthPicker = false
                    monthPickerCanDismiss = true
                },
                canDismiss: monthPickerCanDismiss
            ) { availableSize, dismiss in
                YearMonthPickerView(
                    model: model,
                    maximumHeight: availableSize.height,
                    onDismissabilityChange: { monthPickerCanDismiss = $0 },
                    dismiss: dismiss
                )
            }
        }
        .fullScreenCover(isPresented: $showsDutyComparison) {
            DPModalOverlay(onDismiss: { showsDutyComparison = false }) { availableSize, dismiss in
                DutyComparisonView(model: model, maximumHeight: availableSize.height) {
                    dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $showsBatchUpdate) {
            DPModalOverlay(
                maximumContentWidth: CalendarBatchDutySelectionModal.maximumWidth,
                onDismiss: { showsBatchUpdate = false }
            ) { availableSize, dismiss in
                CalendarBatchDutySelectionModal(
                    dutyTypes: batchDutyTypes,
                    year: model.year,
                    month: model.month,
                    maximumHeight: availableSize.height,
                    cancel: dismiss,
                    select: { dutyTypeID in
                        dismiss()
                        Task { await model.batchUpdateDuty(dutyTypeID: dutyTypeID) }
                    }
                )
            }
        }
        .fullScreenCover(item: $todoSelection) { selection in
            DPModalOverlay(
                onDismiss: {
                    todoSelection = nil
                    todoDetailCanDismiss = true
                },
                canDismiss: todoDetailCanDismiss && !todoDetailModel.isSaving,
                onDismissRequest: { _ in todoDetailDismissRequest += 1 }
            ) { availableSize, dismiss in
                TodoDetailModal(
                    model: todoDetailModel,
                    todo: selection.todo,
                    maximumHeight: availableSize.height,
                    accountID: authenticatedAccountID,
                    sessionGeneration: session.authenticationSessionGenerationForCurrentAccount,
                    onTodoChanged: { await model.refreshTodoBoard() },
                    onDismissabilityChange: { todoDetailCanDismiss = $0 },
                    dismissRequest: todoDetailDismissRequest,
                    dismiss: dismiss
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("calendar.todo.detail")
            }
        }
        .fullScreenCover(item: $reportTarget) { target in
            DPModalOverlay(
                onDismiss: { finishReportDismissal() },
                canDismiss: reportCanDismiss
            ) { availableSize, dismiss in
                ReportSheet(
                    target: target,
                    maximumHeight: availableSize.height,
                    onDismissabilityChange: { reportCanDismiss = $0 },
                    // The menu that opens this sheet only exists on somebody else's
                    // calendar, so the blocked member is this calendar's own.
                    onBlocked: { leavesAfterBlock = true },
                    dismiss: dismiss
                )
            }
        }
        .fullScreenCover(isPresented: $showsBlockConfirmation) {
            DPModalOverlay(
                maximumContentWidth: DPConfirmationPanel.maximumWidth,
                onDismiss: { finishBlockConfirmationDismissal() },
                canDismiss: !blockModel.isBlocking,
                dismissHaptic: nil
            ) { availableSize, dismiss in
                DPConfirmationPanel(
                    title: CalendarLocalization.text("calendar.block.confirm.title"),
                    message: CalendarLocalization.text("calendar.block.confirm.message"),
                    confirmTitle: CalendarLocalization.text("calendar.block.confirm.action"),
                    cancelTitle: CalendarLocalization.text("calendar.cancel"),
                    isDestructive: true,
                    isWorking: blockModel.isBlocking,
                    maximumHeight: availableSize.height,
                    cancel: dismiss,
                    confirm: { confirmBlock(dismissConfirmation: dismiss) }
                )
            }
        }
        .alert(CalendarLocalization.text("calendar.error.title"), isPresented: Binding(
            get: { blockModel.errorMessage != nil },
            set: { if !$0 { blockModel.errorMessage = nil } }
        )) {
            Button(CalendarLocalization.text("calendar.ok"), role: .cancel) { blockModel.errorMessage = nil }
        } message: {
            Text(blockModel.errorMessage ?? "")
        }
        .alert(CalendarLocalization.text("calendar.error.title"), isPresented: Binding(
            get: { model.errorMessage != nil && !model.days.isEmpty },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button(CalendarLocalization.text("calendar.ok"), role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .fileImporter(isPresented: $importsDutyBatch, allowedContentTypes: dutyBatchContentTypes) { result in
            if case .success(let url) = result { Task { await model.uploadDutyBatch(url: url) } }
        }
        .alert(CalendarLocalization.text("calendar.duty.excel.title"), isPresented: Binding(
            get: { model.dutyBatchMessage != nil }, set: { if !$0 { model.dutyBatchMessage = nil } }
        )) { Button(CalendarLocalization.text("calendar.ok"), role: .cancel) { model.dutyBatchMessage = nil } } message: { Text(model.dutyBatchMessage ?? "") }
    }

    private var calendarContent: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVStack(spacing: DPSpacing.small) {
                    if model.isShowingCachedData || model.pendingScheduleCount > 0 {
                        offlineStateBanner
                    }
                    if showsDutyToolbar {
                        dutyToolbar
                    }
                    swipeableCalendarGrid
                    if !model.isQuickDutyEditing {
                        dDaySection
                    }
                }
                .padding(.horizontal, DPSpacing.small)
                .padding(.top, DPSpacing.extraSmall)
                .padding(.bottom, DPSpacing.large)
            }

            thisMonthCalloutLayer
                .offset(y: Self.calloutVerticalOffset)
                .alignmentGuide(HorizontalAlignment.center) { _ in Self.calloutTailCenter }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: showsThisMonthCallout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .modifier(CalendarTopScrollEdgeEffectModifier())
        .refreshable { await model.load() }
    }

    private var offlineStateBanner: some View {
        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
            if model.isShowingCachedData {
                Label {
                    Text(CalendarLocalization.text("calendar.offline.cached"))
                } icon: {
                    Image(systemName: "wifi.slash")
                }
                if let storedAt = model.cacheStoredAt {
                    Text(CalendarLocalization.format(
                        "calendar.offline.cachedAt",
                        DateFormatter.localizedString(from: storedAt, dateStyle: .short, timeStyle: .short)
                    ))
                    .font(.caption)
                    .foregroundStyle(DPColor.textSecondary)
                }
            }
            if model.pendingScheduleCount > 0 {
                Text(CalendarLocalization.format(
                    "calendar.offline.pending",
                    model.pendingScheduleCount
                ))
                .font(.caption)
                .foregroundStyle(DPColor.textSecondary)
            }
        }
        .font(.caption)
        .foregroundStyle(DPColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DPSpacing.small)
        .padding(.vertical, DPSpacing.extraSmall)
        .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("calendar.offline.banner")
    }

    private func configureFromSession() {
        guard case .authenticated(let member) = session.state else {
            todoDetailModel.configureSession(accountID: nil, availability: .offline)
            return
        }
        model.configure(accountID: member.id, isOffline: session.availability.isOffline)
        todoDetailModel.configureSession(
            accountID: member.id,
            availability: session.availability,
            sessionGeneration: session.authenticationSessionGenerationForCurrentAccount
        )
    }

    private var authenticatedAccountID: MemberID? {
        guard case .authenticated(let member) = session.state else { return nil }
        return member.id
    }

    private func offlineSyncAccountID(from notification: Notification) -> MemberID? {
        if let accountID = notification.object as? MemberID { return accountID }
        if let accountID = notification.object as? NSNumber { return accountID.int64Value }
        if let accountID = notification.userInfo?["accountID"] as? MemberID { return accountID }
        if let accountID = notification.userInfo?["accountID"] as? NSNumber { return accountID.int64Value }
        return nil
    }

    @ToolbarContentBuilder
    private var calendarToolbar: some ToolbarContent {
        DPDashboardHeaderToolbarItem(placement: .topBarLeading) {
            memberIdentityBar
                .frame(width: Self.barSideWidth, alignment: .leading)
        }
        DPDashboardHeaderToolbarItem(placement: .principal) {
            monthControls
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("calendar.month.controls")
        }
        DPDashboardHeaderToolbarItem(placement: .topBarTrailing) {
            Group {
                if model.canSearchSchedules {
                    searchControl
                }
            }
            .frame(width: Self.barSideWidth, alignment: .trailing)
        }
    }

    // Report and block belong to someone else's calendar opened from another screen.
    private var showsMemberActions: Bool {
        isPushedMemberCalendar && !model.isMyCalendar && model.me != nil
    }

    // The avatar and the name are the menu label, the way a social app opens member
    // actions from the identity itself instead of a separate overflow button.
    private var memberActionsMenu: some View {
        Menu {
            // The same siren in the same red as every other report in the app.
            Button(role: .destructive) {
                guard let memberID = model.targetMemberID else { return }
                DPHapticCenter.shared.emit(.routine)
                withoutPresentationAnimation {
                    reportTarget = ReportTarget(
                        type: .member,
                        targetID: String(memberID),
                        name: model.targetName
                    )
                }
            } label: {
                Label {
                    Text(CalendarLocalization.text("calendar.report.member"))
                } icon: {
                    DPReportBeaconIcon()
                }
            }
            .accessibilityIdentifier("calendar.member.report")

            Button(role: .destructive) {
                withoutPresentationAnimation { showsBlockConfirmation = true }
            } label: {
                Label(CalendarLocalization.text("calendar.block.member"), systemImage: "hand.raised")
            }
            .accessibilityIdentifier("calendar.member.block")
        } label: {
            memberIdentity
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(CalendarLocalization.text("calendar.more"))
        .accessibilityValue(model.targetName)
        .accessibilityIdentifier("calendar.member.menu")
    }

    // A member calendar is pushed onto the stack of the tab it was opened from, so back
    // is a plain pop. Whose calendar it is does not matter: a team shift grid and Admin
    // can both open your own calendar, and that push needs a way back too. The calendar
    // tab root is not pushed and keeps the bare identity.
    private var memberBackAction: (() -> Void)? {
        guard isPushedMemberCalendar else { return nil }
        return {
            DPHapticCenter.shared.emit(.routine)
            dismiss()
        }
    }

    // Back is a control of its own so the avatar and the name stay free to open the
    // member actions. The leading bar slot cannot fit two 44pt-wide controls, so the
    // chevron claims only its own width and the identity takes the rest.
    private var memberIdentityBar: some View {
        HStack(spacing: 0) {
            if let memberBackAction {
                Button(action: memberBackAction) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DPColor.accent)
                        .frame(width: Self.barBackWidth, height: DPSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CalendarLocalization.text("calendar.member.back"))
                .accessibilityValue(model.targetName)
                .accessibilityIdentifier("calendar.member.back")
            }
            if showsMemberActions {
                memberActionsMenu
            } else {
                memberIdentity
            }
        }
        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget, alignment: .leading)
    }

    private var memberIdentity: some View {
        HStack(spacing: 6) {
            CalendarMemberAvatar(
                memberID: model.targetMemberID,
                hasProfilePhoto: model.targetHasProfilePhoto,
                profilePhotoVersion: model.targetProfilePhotoVersion,
                size: 32
            )
            Text(model.targetName)
                .font(DPFont.bold(size: 12, relativeTo: .caption))
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minHeight: DPSize.minimumTouchTarget)
        .accessibilityElement(children: .combine)
    }

    private var showsThisMonthCallout: Bool {
        CalendarVisualLogic.showsThisMonthCallout(year: model.year, month: model.month, today: Date())
    }

    private var monthLabel: some View {
        Button {
            DPHapticCenter.shared.emit(.routine)
            withoutPresentationAnimation { showsMonthPicker = true }
        } label: {
            Text(String(format: "%04d-%02d", model.year, model.month))
                .font(DPFont.bold(size: 16, relativeTo: .headline))
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
        }
        .accessibilityLabel(CalendarLocalization.text("calendar.month.choose"))
        .accessibilityValue(String(format: "%04d-%02d", model.year, model.month))
        .accessibilityIdentifier("calendar.month.display")
    }

    // The trailing search control is narrower than `DPSize.minimumTouchTarget`; the 44pt-tall
    // navigation bar cannot fit the leading identity, the month navigation and the trailing
    // action otherwise. Height stays at the full touch target.
    private static let barControlWidth: CGFloat = 36

    // Back sits inside the leading slot next to the identity, so it claims barely
    // more than the chevron itself and leaves the name its room. Height still spans
    // the full touch target.
    private static let barBackWidth: CGFloat = 16

    // The leading and trailing bar items claim the same width so the month
    // navigation in the principal slot stays centred on the screen.
    private static let barSideWidth: CGFloat = 88

    // The web calendar draws the tail near the leading edge of the bubble; these place that
    // tail on the horizontal centre, so it points at the month label whatever the label reads.
    private static let calloutCapsuleHeight: CGFloat = 20
    private nonisolated static let calloutTailInset: CGFloat = 8
    private nonisolated static let calloutTailWidth: CGFloat = 12
    private static let calloutTailHeight: CGFloat = 6
    // Overlap that keeps the tail and the capsule reading as one shape.
    private static let calloutTailOverlap: CGFloat = 2
    // The capsule is shorter than a touch target, so it takes what room the bar leaves
    // around itself; a taller hit area would only reach past the bar, which passes on
    // nothing it does not draw.
    private nonisolated static let calloutHitInsetX: CGFloat = 6
    private static let calloutHitInsetY: CGFloat = 6
    private nonisolated static let calloutTailCenter: CGFloat =
        calloutHitInsetX + calloutTailInset + calloutTailWidth / 2

    // Keep the callout's existing upper-left corner fixed while giving its label and hit area
    // ten percent more room toward the lower-right. A transform leaves the month controls'
    // layout footprint unchanged, so the month header remains centred.
    private static let calloutScale: CGFloat = 1.1

    // The callout is hosted below the 44pt navigation bar; lift its body anchor so the bubble
    // sits close to the month controls without changing the scroll content's position.
    private static let calloutVerticalOffset: CGFloat = -20

    // The callout is hosted by the full calendar body rather than the navigation-bar item.
    // That keeps the item at its native 44pt height while the body still owns the callout's
    // scaled hit area.
    @ViewBuilder
    private var thisMonthCalloutLayer: some View {
        if showsThisMonthCallout {
            thisMonthCallout
                .transition(.offset(y: -4).combined(with: .opacity))
        }
    }

    private var thisMonthCallout: some View {
        Button { Task { await model.goToToday() } } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .bold))
                Text(CalendarLocalization.text("calendar.month.goToThisMonth"))
                    .font(DPFont.bold(size: 11, relativeTo: .caption2))
                    .lineLimit(1)
            }
            .foregroundStyle(DPColor.textOnDark)
            .padding(.horizontal, 8)
            .frame(height: Self.calloutCapsuleHeight)
            .background(DPColor.accent, in: Capsule())
            .background(alignment: .topLeading) {
                CalloutTail()
                    .fill(DPColor.accent)
                    .frame(width: Self.calloutTailWidth, height: Self.calloutTailHeight)
                    .offset(
                        x: Self.calloutTailInset,
                        y: Self.calloutTailOverlap - Self.calloutTailHeight
                    )
            }
            .compositingGroup()
            .shadow(color: DPColor.accent.opacity(0.35), radius: 4, x: 0, y: 2)
            .padding(.horizontal, Self.calloutHitInsetX)
            .padding(.vertical, Self.calloutHitInsetY)
            .contentShape(Rectangle())
        }
        .scaleEffect(Self.calloutScale, anchor: .topLeading)
        .accessibilityLabel(CalendarLocalization.text("calendar.month.goToThisMonth"))
    }

    private var monthCenterControls: some View {
        monthLabel
            .frame(width: 78)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.compact))
    }

    private var monthControls: some View {
        HStack(spacing: 0) {
            DPMonthArrowButton(direction: .previous, label: CalendarLocalization.text("calendar.month.previous"), identifier: "calendar.month.previous") {
                Task { await model.changeMonth(by: -1) }
            }
            monthCenterControls
            DPMonthArrowButton(direction: .next, label: CalendarLocalization.text("calendar.month.next"), identifier: "calendar.month.next") {
                Task { await model.changeMonth(by: 1) }
            }
        }
    }

    // The navigation bar has no room for the inline query field; tapping opens the
    // search modal, which already carries its own field and the full placeholder.
    private var searchControl: some View {
        Button(action: performSearch) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DPColor.accentHover)
                .frame(width: Self.barControlWidth, height: DPSize.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(CalendarLocalization.text("calendar.search"))
    }

    private func confirmBlock(dismissConfirmation: @escaping () -> Void) {
        guard let memberID = model.targetMemberID, !blockModel.isBlocking else { return }
        Task {
            leavesAfterBlock = await blockModel.block(memberID: memberID)
            await Task.yield()
            dismissConfirmation()
        }
    }

    private func finishBlockConfirmationDismissal() {
        showsBlockConfirmation = false
        leaveBlockedMemberCalendar()
    }

    private func finishReportDismissal() {
        reportTarget = nil
        reportCanDismiss = true
        leaveBlockedMemberCalendar()
    }

    private func finishDayDismissal() {
        let shouldRefresh = refreshesAfterReportedBlock && !leavesAfterBlock
        refreshesAfterReportedBlock = false
        if shouldRefresh {
            Task { await model.load() }
        }
        leaveBlockedMemberCalendar()
    }

    // A blocked member's calendar stops loading immediately, so the screen this one was
    // pushed from is the only place left to land. Every caller is a cover's dismissal
    // callback: SwiftUI drops navigation requested while a cover is still on screen.
    private func leaveBlockedMemberCalendar() {
        guard leavesAfterBlock else { return }
        leavesAfterBlock = false
        Task {
            await Task.yield()
            memberBackAction?()
        }
    }

    private func performSearch() {
        guard model.canSearchSchedules else { return }
        DPHapticCenter.shared.emit(.routine)
        withoutPresentationAnimation { showsSearch = true }
        if !model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task { await model.search() }
        }
    }

    private var dutyToolbar: some View {
        Group {
            if model.isQuickDutyEditing {
                quickDutyPanel
            } else {
                HStack(spacing: DPSpacing.small) {
                    dutySummary
                        .frame(maxWidth: .infinity, alignment: .leading)
                    normalDutyActions
                }
            }
        }
    }

    private var showsDutyToolbar: Bool {
        CalendarMainLayout.shouldShowDutyToolbar(
            hasDutySummary: model.days.contains { $0.duty?.month == model.month },
            hasComparisonAction: (model.isMyCalendar && !model.friends.isEmpty)
                || (!model.isMyCalendar && model.me?.id != nil),
            hasQuickEditAction: model.canEdit && !batchDutyTypes.isEmpty,
            hasImportAction: model.isMyCalendar && model.team?.dutyBatchTemplate != nil,
            isQuickDutyEditing: model.isQuickDutyEditing
        )
    }

    private var normalDutyActions: some View {
        HStack(spacing: 0) {
            if model.isMyCalendar && !model.friends.isEmpty {
                Button {
                    DPHapticCenter.shared.emit(.routine)
                    withoutPresentationAnimation { showsDutyComparison = true }
                } label: {
                    Image(systemName: "person.2")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(CalendarLocalization.text("calendar.compare"))
            } else if !model.isMyCalendar, model.me?.id != nil {
                Button { Task { await model.toggleMyDutyComparison() } } label: {
                    Image(systemName: model.comparedMemberIDs.isEmpty ? "person.2" : "person.2.fill")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(CalendarLocalization.text("calendar.compare.mine"))
            }
            if model.canEdit && !batchDutyTypes.isEmpty {
                Button { model.setQuickDutyEditing(true) } label: {
                    Image(systemName: "pencil.line")
                        .foregroundStyle(DPColor.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(CalendarLocalization.text("calendar.duty.quick.start"))
                .accessibilityIdentifier("calendar.duty.quick.start")
            }
            if model.isMyCalendar, model.team?.dutyBatchTemplate != nil {
                Button {
                    DPHapticCenter.shared.emit(.routine)
                    importsDutyBatch = true
                } label: {
                    Image(systemName: "doc.badge.arrow.up")
                        .foregroundStyle(DPColor.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(CalendarLocalization.text("calendar.duty.excel"))
            }
        }
        .foregroundStyle(DPColor.textSecondary)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderSecondary))
    }

    // Edit mode used to be a notice card with a full-width exit button stacked on top of
    // a loose row of controls, which read as two unrelated blocks and pushed the calendar
    // itself off the first screen. One panel says the mode once and keeps its controls
    // inside it.
    private var quickDutyPanel: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            editModeHeader
            Divider().overlay(DPColor.warningBorder)
            quickDutyBar
        }
        .padding(DPSpacing.small)
        .background(DPColor.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay(RoundedRectangle(cornerRadius: DPRadius.large).stroke(DPColor.warningBorder))
    }

    private var editModeHeader: some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: "pencil.line")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DPColor.warningHover)
                .frame(width: 28, height: 28)
                .background(DPColor.backgroundCard, in: RoundedRectangle(cornerRadius: DPRadius.compact))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.compact)
                        .stroke(DPColor.warningBorder, lineWidth: DPChrome.borderWidth)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(CalendarLocalization.text("calendar.duty.quick.start"))
                    .font(DPFont.bold(size: 13, relativeTo: .subheadline))
                    .foregroundStyle(DPColor.textPrimary)
                Text("calendar.duty.quick.description", tableName: "Calendar")
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DPIconActionButton(
                systemImage: "xmark",
                label: CalendarLocalization.text("calendar.duty.quick.exit"),
                showsLabel: true,
                tone: .warning
            ) {
                model.setQuickDutyEditing(false, emitFeedback: false)
            }
            .padding(.trailing, -DPIconActionMetrics.touchPadding)
            .accessibilityIdentifier("calendar.duty.quick.exit")
        }
    }

    private func openTodo(_ todo: TodoDTO) {
        guard TodoID(uuidString: todo.id) != nil else { return }
        DPHapticCenter.shared.emit(.routine)
        todoSelection = CalendarTodoSelection(todo: todo)
    }

    private var dutyBatchContentTypes: [UTType] {
        let extensions = CalendarFeatureLogic.normalizedFileExtensions(
            model.team?.dutyBatchTemplate?.fileExtensions ?? []
        )
        let types = extensions.compactMap {
            UTType(filenameExtension: String($0.dropFirst()))
        }
        return types.isEmpty ? [.spreadsheet] : types
    }

    private var dutySummary: some View {
        let counts = Dictionary(grouping: model.days.compactMap(\.duty).filter { $0.month == model.month }, by: { $0.dutyType ?? CalendarLocalization.text("calendar.off") })
        return AnyView(ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DPSpacing.small) {
                ForEach(counts.keys.sorted(), id: \.self) { name in
                    HStack(spacing: DPSpacing.extraSmall) {
                        RoundedRectangle(cornerRadius: 2).fill(color(hex: counts[name]?.first?.dutyColor)).frame(width: 16, height: 16)
                        Text(name).foregroundStyle(DPColor.textSecondary)
                        Text("\(counts[name]?.count ?? 0)").bold().foregroundStyle(DPColor.textPrimary)
                    }
                    .font(DPTypography.caption)
                }
            }
            .frame(minHeight: DPSize.minimumTouchTarget)
        })
    }

    // Every control on this row is a card-coloured chip of the same height and corner
    // radius, so the day stepper, the duty types and the batch action read as one set
    // instead of a stepper, some tiles and a stray capsule.
    private var quickDutyBar: some View {
        CalendarFlowLayout(spacing: DPSpacing.small) {
            HStack(spacing: 0) {
                Button { model.moveQuickDutyFocus(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: Self.quickDutyStepWidth, height: DPSize.minimumTouchTarget)
                }
                Text(CalendarLocalization.format("calendar.duty.quick.day", model.quickDutyDay?.cell.day ?? 1))
                    .font(DPFont.bold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DPColor.warningHover)
                    .frame(minWidth: 38)
                Button { model.moveQuickDutyFocus(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: Self.quickDutyStepWidth, height: DPSize.minimumTouchTarget)
                }
            }
            .background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderSecondary))

            ForEach(batchDutyTypes, id: \.id) { type in
                quickDutyButton(
                    id: type.id,
                    name: type.name,
                    color: color(hex: type.color),
                    foreground: CalendarVisualLogic.usesLightForeground(on: type.color)
                        ? DPColor.textOnDark
                        : DPColor.textOnLight
                )
            }

            if model.isMyCalendar {
                Button {
                    DPHapticCenter.shared.emit(.routine)
                    showsBatchUpdate = true
                } label: {
                    Label(CalendarLocalization.text("calendar.duty.batch"), systemImage: "calendar")
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textSecondary)
                        .padding(.horizontal, DPSpacing.compact)
                        .frame(minHeight: DPSize.minimumTouchTarget)
                        .background(DPColor.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                        .overlay {
                            RoundedRectangle(cornerRadius: DPRadius.standard)
                                .stroke(DPColor.borderSecondary, lineWidth: DPChrome.borderWidth)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("calendar.duty.batch.open")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quickDutyButton(
        id: DutyTypeID?,
        name: String,
        color: Color,
        foreground: Color
    ) -> some View {
        let selected = model.quickDutyDay?.duty?.dutyTypeId == id
        return Button { Task { await model.applyQuickDuty(dutyTypeID: id) } } label: {
            Text(name)
                .font(DPTypography.label)
                .foregroundStyle(foreground)
                .padding(.horizontal, DPSpacing.compact)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                // The selected type keeps a ring rather than a 3pt slab: at that weight the
                // stroke ate into the duty colour it is meant to point at.
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.standard)
                        .stroke(
                            selected ? DPColor.warningHover : DPColor.borderPrimary,
                            lineWidth: selected ? 2 : DPChrome.borderWidth
                        )
                }
                .shadow(
                    color: DPColor.warningHover.opacity(selected ? 0.35 : 0),
                    radius: 3,
                    y: 1
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // The stepper's chevrons stay narrower than a full touch target so the day readout
    // between them keeps its room; the group is still 44pt tall.
    private static let quickDutyStepWidth: CGFloat = 36

    private var calendarGrid: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(["sun", "mon", "tue", "wed", "thu", "fri", "sat"], id: \.self) { weekday in
                    Text(CalendarLocalization.text("calendar.weekday.\(weekday)"))
                        .font(DPFont.bold(size: CalendarTypography.weekday, relativeTo: .subheadline))
                        .foregroundStyle(weekday == "sun" ? DPColor.dangerHover : weekday == "sat" ? DPColor.accentHover : DPColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(DPColor.backgroundHover)
                        .overlay(alignment: .trailing) { Rectangle().fill(DPColor.borderSecondary).frame(width: 0.5) }
                        .overlay(alignment: .bottom) { Rectangle().fill(DPColor.borderSecondary).frame(height: 2) }
                }
                ForEach(Array(model.days.enumerated()), id: \.element.id) { index, day in
                    let opensDetail = CalendarDayOpenPolicy.opensDetail(day, canEdit: model.canEdit)
                    let cell = CalendarDayCell(
                        day: day,
                        weekday: index % 7,
                        highlighted: model.highlightedDate == day.cell.date,
                        pinnedDDay: model.pinnedDDay,
                        hidesDetails: model.isQuickDutyEditing,
                        calendarMemberID: model.targetMemberID,
                        opensDetail: opensDetail,
                        openTodo: openTodo
                    )
                    if opensDetail {
                        cell.onTapGesture {
                            // A finger that pulled the grid sideways was swiping, not
                            // tapping, even when it gave up short of the next month.
                            guard !isSwipingMonth, !isSlidingMonth else { return }
                            if model.isQuickDutyEditing { model.focusQuickDuty(on: day) }
                            else {
                                withoutPresentationAnimation { model.selectDay(day) }
                            }
                        }
                    } else {
                        cell
                    }
                }
            }
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderSecondary))
        .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
    }

    // Swiping the grid sideways is the quick way through the months; the chevrons in
    // the navigation bar stay for taps and for VoiceOver, which never sees this drag.
    private var swipeableCalendarGrid: some View {
        calendarGrid
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { calendarGridWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { _, width in calendarGridWidth = width }
                }
            }
            .offset(x: monthSlideOffset)
            // A plain DragGesture claimed every drag that passed its minimum distance,
            // so a scroll that set off with the slightest sideways lean never reached
            // the page underneath. This one takes sideways drags and nothing else.
            .dpHorizontalPan(onChanged: followMonthSwipe, onEnded: finishMonthSwipe)
    }

    private func followMonthSwipe(translation: CGSize) {
        guard !isSlidingMonth else { return }
        monthSlideOffset = CalendarMonthSwipe.followOffset(translation: translation)
        if monthSlideOffset != 0 { isSwipingMonth = true }
    }

    private func finishMonthSwipe(translation: CGSize) {
        guard !isSlidingMonth else { return }
        // The cell's own tap lands around the same moment, so the swipe flag
        // outlives the drag just long enough for that tap to be turned away.
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            isSwipingMonth = false
        }
        let offset = CalendarMonthSwipe.monthOffset(translation: translation)
        guard offset != 0 else {
            withAnimation(.easeOut(duration: CalendarMonthSwipe.slideInDuration)) {
                monthSlideOffset = 0
            }
            return
        }
        slideMonth(by: offset)
    }

    private func slideMonth(by offset: Int) {
        isSlidingMonth = true
        // The month itself changes now and its days arrive later, so the grid slides
        // out, reappears on the far side and slides back in without waiting for the
        // response; a slow month lands its cells into a calendar that is already home.
        let travel = calendarGridWidth > 0 ? calendarGridWidth : CalendarMonthSwipe.maximumFollowDistance
        withAnimation(.easeIn(duration: CalendarMonthSwipe.slideOutDuration)) {
            monthSlideOffset = offset > 0 ? -travel : travel
        }
        Task { await model.changeMonth(by: offset) }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(CalendarMonthSwipe.slideOutDuration * 1_000_000_000))
            monthSlideOffset = offset > 0 ? travel : -travel
            withAnimation(.easeOut(duration: CalendarMonthSwipe.slideInDuration)) {
                monthSlideOffset = 0
            }
            isSlidingMonth = false
        }
    }

    private var dDaySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DPSpacing.small) {
            ForEach(model.dDays, id: \.id) { item in
                DDayCard(item: item, model: model) {
                    DPHapticCenter.shared.emit(.routine)
                    withoutPresentationAnimation { dDayModalSelection = .detail(item) }
                }
            }
            if model.isMyCalendar {
                Button {
                    DPHapticCenter.shared.emit(.routine)
                    withoutPresentationAnimation { dDayModalSelection = .create }
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(DPColor.backgroundTertiary)
                            .frame(width: 40, height: 40)
                            .overlay(Image(systemName: "plus").foregroundStyle(DPColor.textMuted))
                        Text("calendar.dday.add", tableName: "Calendar")
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 108)
                    .background(DPColor.backgroundCard)
                    .overlay {
                        RoundedRectangle(cornerRadius: DPRadius.large)
                            .stroke(DPColor.borderSecondary, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func color(hex: String?) -> Color {
        guard let hex else { return DPColor.textMuted }
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x6B7280
        return Color(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255)
    }

    private var batchDutyTypes: [DutyTypeDTO] {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-calendar-batch") {
            return [
                DutyTypeDTO(
                    id: 101,
                    teamId: 1,
                    name: "주간",
                    position: 0,
                    color: "#3B82F6",
                    hidden: false
                ),
                DutyTypeDTO(
                    id: 102,
                    teamId: 1,
                    name: "야간",
                    position: 1,
                    color: "#4338CA",
                    hidden: false
                ),
            ]
        }
#endif
        return model.visibleDutyTypes
    }
}

private struct CalendarBatchDutySelectionModal: View {
    static let maximumWidth: CGFloat = 420

    let dutyTypes: [DutyTypeDTO]
    let year: Int
    let month: Int
    let maximumHeight: CGFloat
    let cancel: () -> Void
    let select: (DutyTypeID?) -> Void

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            Text(CalendarLocalization.text("calendar.duty.batch.title"))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, DPSpacing.large)
                .background(DPColor.backgroundTertiary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("calendar.duty.batch.title")
        } content: {
            VStack(spacing: DPSpacing.medium) {
                VStack(spacing: DPSpacing.extraSmall) {
                    Text(CalendarLocalization.format("calendar.duty.batch.description.month", year, month))
                    Text(CalendarLocalization.text("calendar.duty.batch.description.selection"))
                }
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                Label {
                    Text(CalendarLocalization.text("calendar.duty.batch.warning"))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.warning)
                .padding(DPSpacing.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DPColor.warningSoft)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.standard)
                        .stroke(DPColor.warningBorder)
                }

                CalendarFlowLayout(spacing: DPSpacing.small) {
                    ForEach(dutyTypes, id: \.id) { type in
                        Button { select(type.id) } label: {
                            Text(type.name)
                                .font(DPTypography.label)
                                .foregroundStyle(
                                    CalendarVisualLogic.usesLightForeground(on: type.color)
                                        ? DPColor.textOnDark
                                        : DPColor.textOnLight
                                )
                                .padding(.horizontal, DPSpacing.medium)
                                .frame(minHeight: DPSize.minimumTouchTarget)
                                .background(dutyColor(type.color))
                                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                                .overlay {
                                    RoundedRectangle(cornerRadius: DPRadius.standard)
                                        .stroke(DPColor.borderPrimary)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("calendar.duty.batch.option.\(type.id.map(String.init) ?? "none")")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DPSpacing.large)
        } footer: {
            Button(action: cancel) {
                Text(CalendarLocalization.text("calendar.cancel"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())
            .padding(.horizontal, DPSpacing.large)
            .padding(.vertical, DPSpacing.medium)
            .accessibilityIdentifier("calendar.duty.batch.cancel")
        }
    }

    private func dutyColor(_ hex: String?) -> Color {
        guard let components = CalendarVisualLogic.rgb(hex) else { return DPColor.textMuted }
        return Color(
            red: Double(components.red) / 255,
            green: Double(components.green) / 255,
            blue: Double(components.blue) / 255
        )
    }
}

private struct CalendarFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, points: [CGPoint]) {
        let availableWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > availableWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (CGSize(width: availableWidth, height: y + rowHeight), points)
    }
}

enum CalendarCompactModalLayout {
    static let maximumPanelHeightRatio: CGFloat = 0.9
    static let minimumBodyHeight: CGFloat = 1

    static func bodyHeight(
        contentHeight: CGFloat,
        maximumPanelHeight: CGFloat,
        fixedChromeHeight: CGFloat
    ) -> CGFloat {
        let availableHeight = max(minimumBodyHeight, maximumPanelHeight - fixedChromeHeight)
        return min(max(contentHeight, minimumBodyHeight), availableHeight)
    }
}

private struct YearMonthPickerView: View {
    @ObservedObject var model: CalendarViewModel
    let maximumHeight: CGFloat
    let onDismissabilityChange: (Bool) -> Void
    let dismiss: () -> Void
    @State private var pickerYear: Int
    @State private var isSelecting = false

    init(
        model: CalendarViewModel,
        maximumHeight: CGFloat,
        onDismissabilityChange: @escaping (Bool) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.model = model
        self.maximumHeight = maximumHeight
        self.onDismissabilityChange = onDismissabilityChange
        self.dismiss = dismiss
        _pickerYear = State(initialValue: model.year)
    }

    var body: some View {
        DPModalPanel(
            maximumPanelHeight: maximumHeight * CalendarCompactModalLayout.maximumPanelHeightRatio
        ) {
            header
        } content: {
            pickerBody
        } footer: {
            footerActions
        }
        .opacity(isSelecting ? DPChrome.disabledOpacity : 1)
        .onAppear { onDismissabilityChange(!isSelecting) }
        .onChange(of: isSelecting) { _, value in onDismissabilityChange(!value) }
        .onDisappear { onDismissabilityChange(true) }
        .accessibilityIdentifier("calendar.monthPicker")
    }

    private var header: some View {
        HStack(spacing: DPSpacing.small) {
            Text(CalendarLocalization.text("calendar.month.choose"))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Spacer(minLength: 0)
            Button(action: guardedDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isSelecting)
            .accessibilityLabel(CalendarLocalization.text("calendar.close"))
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.compact)
    }

    private var pickerBody: some View {
        VStack(spacing: DPSpacing.medium) {
            HStack(spacing: DPSpacing.small) {
                Button {
                    pickerYear -= 1
                    DPHapticCenter.shared.emit(.selection)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CalendarLocalization.format("calendar.month.format", pickerYear - 1, model.month))

                Spacer(minLength: 0)

                Text(String(pickerYear))
                    .font(DPTypography.sectionTitle)
                    .foregroundStyle(DPColor.textPrimary)

                Spacer(minLength: 0)

                Button {
                    pickerYear += 1
                    DPHapticCenter.shared.emit(.selection)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CalendarLocalization.format("calendar.month.format", pickerYear + 1, model.month))
            }
            .foregroundStyle(DPColor.accent)
            .disabled(isSelecting)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DPSpacing.small), count: 4),
                spacing: DPSpacing.small
            ) {
                ForEach(1...12, id: \.self) { month in
                    let isSelected = pickerYear == model.year && month == model.month
                    Button {
                        select(month: month)
                    } label: {
                        Text(CalendarLocalization.format("calendar.month.short", month))
                            .font(DPTypography.label)
                            .foregroundStyle(isSelected ? DPColor.textOnDark : DPColor.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                            .background(isSelected ? DPColor.accent : DPColor.backgroundTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                            .overlay {
                                RoundedRectangle(cornerRadius: DPRadius.standard)
                                    .stroke(isSelected ? DPColor.accent : DPColor.borderPrimary)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSelecting)
                    .accessibilityIdentifier("calendar.monthPicker.month.\(month)")
                }
            }
        }
        .padding(DPSpacing.medium)
    }

    private var footerActions: some View {
        HStack(spacing: DPSpacing.small) {
            Button(action: guardedDismiss) {
                Text(CalendarLocalization.text("calendar.close"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())
            .disabled(isSelecting)

            Button {
                selectCurrentMonth()
            } label: {
                HStack(spacing: DPSpacing.extraSmall) {
                    if isSelecting { ProgressView().controlSize(.small) }
                    Text(CalendarLocalization.text("calendar.month.current"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(isSelecting)
        }
        .padding(DPSpacing.compact)
    }

    private func guardedDismiss() {
        guard !isSelecting else { return }
        dismiss()
    }

    private func select(month: Int) {
        guard !isSelecting else { return }
        isSelecting = true
        Task {
            await model.selectYearMonth(year: pickerYear, month: month, emitFeedback: false)
            dismiss()
        }
    }

    private func selectCurrentMonth() {
        guard !isSelecting else { return }
        isSelecting = true
        Task {
            await model.goToToday(emitFeedback: false)
            dismiss()
        }
    }
}

private struct DutyComparisonView: View {
    @ObservedObject var model: CalendarViewModel
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    @State private var selection: Set<MemberID>
    @State private var isApplying = false

    init(model: CalendarViewModel, maximumHeight: CGFloat, dismiss: @escaping () -> Void) {
        self.model = model
        self.maximumHeight = maximumHeight
        self.dismiss = dismiss
        _selection = State(initialValue: model.comparedMemberIDs)
    }

    var body: some View {
        DPModalPanel(
            maximumPanelHeight: maximumHeight * CalendarCompactModalLayout.maximumPanelHeightRatio
        ) {
            header
        } content: {
            friendGrid
        } footer: {
            footerActions
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: DPSpacing.small) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(DPColor.accent)
                Text(CalendarLocalization.text("calendar.compare"))
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DPColor.textPrimary)
                .disabled(isApplying)
                .accessibilityLabel(CalendarLocalization.text("calendar.close"))
            }
            .padding(.leading, DPSpacing.medium)
            .padding(.trailing, DPSpacing.extraSmall)
            .padding(.vertical, DPSpacing.extraSmall)
            .background(DPColor.backgroundTertiary)

            Text(CalendarLocalization.format("calendar.compare.description", 3))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.accentHover)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DPSpacing.medium)
                .padding(.vertical, DPSpacing.small)
                .background(DPColor.accentSoft)
        }
    }

    private var friendGrid: some View {
        Group {
            if model.friends.isEmpty {
                Text(CalendarLocalization.text("calendar.compare.empty"))
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 88)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: DPSpacing.small), GridItem(.flexible())],
                    spacing: DPSpacing.small
                ) {
                    ForEach(model.friends, id: \.id) { friend in
                        friendButton(friend)
                    }
                }
            }
        }
        .padding(DPSpacing.medium)
    }

    private var footerActions: some View {
        VStack(spacing: DPSpacing.small) {
            Text(CalendarLocalization.format("calendar.compare.count", selection.count, 3))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DPSpacing.small) {
                Button {
                    selection.removeAll()
                } label: {
                    Text(CalendarLocalization.text("calendar.compare.reset"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPOutlineButtonStyle())
                .disabled(selection.isEmpty || isApplying)

                Button(action: dismiss) {
                    Text(CalendarLocalization.text("calendar.cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(isApplying)

                Button {
                    isApplying = true
                    Task {
                        await model.setFriendDutyComparisons(selection)
                        dismiss()
                    }
                } label: {
                    Group {
                        if isApplying {
                            ProgressView()
                        } else {
                            Text(CalendarLocalization.text("calendar.ok"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(isApplying)
            }
        }
        .padding(DPSpacing.medium)
    }

    private func friendButton(_ friend: FriendDTO) -> some View {
        let selected = selection.contains(friend.id)
        let disabled = !selected && selection.count >= 3
        return Button {
            if selected {
                selection.remove(friend.id)
            } else if selection.count < 3 {
                selection.insert(friend.id)
            }
        } label: {
            HStack(spacing: DPSpacing.small) {
                CalendarMemberAvatar(
                    memberID: friend.id,
                    hasProfilePhoto: friend.hasProfilePhoto,
                    profilePhotoVersion: friend.profilePhotoVersion,
                    size: 34
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(friend.name)
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textPrimary)
                        .lineLimit(1)
                    if let team = friend.team, !team.isEmpty {
                        Text(team)
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? DPColor.accent : DPColor.textMuted)
            }
            .padding(.horizontal, DPSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(selected ? DPColor.accentSoft : DPColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(selected ? DPColor.accent : DPColor.borderPrimary, lineWidth: selected ? 2 : 1)
            }
            .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled || isApplying)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct CalendarMemberAvatar: View {
    let memberID: MemberID?
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
    let size: CGFloat

    var body: some View {
        DPProfileAvatar(
            memberID: memberID,
            hasProfilePhoto: hasProfilePhoto,
            profilePhotoVersion: profilePhotoVersion,
            size: size
        )
        .accessibilityHidden(true)
    }
}

private struct CalendarDayCell: View {
    let day: CalendarDayContent
    let weekday: Int
    let highlighted: Bool
    let pinnedDDay: DDayDTO?
    let hidesDetails: Bool
    let calendarMemberID: MemberID?
    let opensDetail: Bool
    let openTodo: (TodoDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 1) {
                Text("\(day.cell.day)")
                    .font(DPFont.bold(size: CalendarTypography.dayNumber, relativeTo: .caption))
                    .foregroundStyle(dayNumberColor)
                Spacer(minLength: 0)
                if let pinnedDDay, !hidesDetails, let label = relativeLabel(pinnedDDay) {
                    Text(label)
                        .font(DPFont.light(size: CalendarTypography.cellMicro, relativeTo: .caption2))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(secondaryForeground)
                }
            }
            if !hidesDetails {
                if let holiday = day.holidays.first {
                    Text(holiday.dateName)
                        .font(DPFont.light(size: CalendarTypography.cellContent, relativeTo: .caption2))
                        .lineLimit(1)
                        .foregroundStyle(holiday.isHoliday ? DPColor.dangerHover : secondaryForeground)
                }
                ForEach(Array(day.comparedDuties.prefix(3).enumerated()), id: \.offset) { _, item in
                    comparedDutyChip(item)
                }
                ForEach(day.dDays.prefix(1), id: \.id) { item in
                    statusBubble(item.title, image: "calendar.badge.checkmark", background: DPColor.successSoft, border: DPColor.successBorder, foreground: DPColor.successHover)
                }
                ForEach(day.schedules.prefix(CalendarVisualLogic.maximumSchedulesPerCell), id: \.id) { schedule in
                    scheduleText(schedule)
                }
                if day.schedules.count > CalendarVisualLogic.maximumSchedulesPerCell {
                    Text("+\(day.schedules.count - CalendarVisualLogic.maximumSchedulesPerCell)")
                        .font(DPFont.bold(size: CalendarTypography.cellContent, relativeTo: .caption2))
                        .foregroundStyle(secondaryForeground)
                }
                ForEach(day.todos.prefix(CalendarVisualLogic.maximumTodosPerCell), id: \.id) { todo in
                    Button { openTodo(todo) } label: {
                        statusBubble(
                            todo.title,
                            image: "checkmark.square",
                            background: todo.status == .inProgress ? DPColor.warningSoft : DPColor.accentSoft,
                            border: todo.status == .inProgress ? DPColor.warningBorder : DPColor.accentBorder,
                            foreground: todo.status == .inProgress ? DPColor.warningHover : DPColor.accentHover
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("calendar.day.todo.\(todo.id)")
                }
                if day.todos.count > CalendarVisualLogic.maximumTodosPerCell {
                    Text("+\(day.todos.count - CalendarVisualLogic.maximumTodosPerCell)")
                        .font(DPFont.bold(size: CalendarTypography.cellContent, relativeTo: .caption2))
                        .foregroundStyle(secondaryForeground)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(2)
        .frame(maxWidth: .infinity, minHeight: CalendarVisualLogic.compactCellMinimumHeight, alignment: .topLeading)
        .background(cellBackground)
        .opacity(day.cell.isCurrentMonth ? 1 : 0.45)
        .overlay(alignment: .trailing) { Rectangle().fill(cellBorder).frame(width: 0.5) }
        .overlay(alignment: .bottom) { Rectangle().fill(cellBorder).frame(height: 0.5) }
        .overlay(Rectangle().stroke(focusBorder, lineWidth: highlighted || isToday ? 2 : 0))
        .contentShape(Rectangle())
        // The day gesture belongs to the whole cell. Without an explicit accessibility
        // boundary, SwiftUI propagates this label and button trait to every nested schedule,
        // comparison chip and Todo button, producing duplicate date targets whose small
        // subframes are often reported as non-hittable by VoiceOver and UI automation.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.cell.date.rawValue)
        .accessibilityIdentifier("calendar.day.\(day.cell.date.rawValue)")
        // A day that opens nothing carries no tap gesture, so it must not offer itself
        // as a button either.
        .accessibilityAddTraits(opensDetail ? .isButton : [])
        // The visual Todo buttons remain nested in the cell. Re-expose them as custom
        // actions after collapsing the cell so VoiceOver keeps both the day action and
        // direct Todo access without recreating duplicate date elements.
        .accessibilityActions {
            if !hidesDetails {
                ForEach(day.todos.prefix(CalendarVisualLogic.maximumTodosPerCell), id: \.id) { todo in
                    Button(todo.title) { openTodo(todo) }
                }
            }
        }
    }

    private var cellBackground: Color {
        guard let components = CalendarVisualLogic.rgb(day.duty?.dutyColor) else {
            return day.cell.isCurrentMonth ? DPColor.backgroundCard : DPColor.backgroundSecondary
        }
        return Color(
            red: Double(components.red) / 255,
            green: Double(components.green) / 255,
            blue: Double(components.blue) / 255
        )
    }

    private var primaryForeground: Color {
        guard day.duty?.dutyColor != nil else { return DPColor.textPrimary }
        return CalendarVisualLogic.usesLightForeground(on: day.duty?.dutyColor) ? DPColor.textOnDark : DPColor.textOnLight
    }

    private var secondaryForeground: Color {
        guard day.duty?.dutyColor != nil else { return DPColor.textMuted }
        return CalendarVisualLogic.usesLightForeground(on: day.duty?.dutyColor) ? DPColor.textOnDarkMuted : DPColor.textMuted
    }

    private var dayNumberColor: Color {
        if weekday == 0 || (!hidesDetails && !day.holidays.isEmpty) { return DPColor.dangerHover }
        if weekday == 6 { return DPColor.accentHover }
        return primaryForeground
    }

    private var cellBorder: Color {
        guard day.duty?.dutyColor != nil else { return DPColor.borderSecondary }
        return CalendarVisualLogic.usesLightForeground(on: day.duty?.dutyColor)
            ? DPColor.textOnDark.opacity(0.30)
            : DPColor.textOnLight.opacity(0.15)
    }

    private var focusBorder: Color {
        if highlighted { return DPColor.accent }
        return isToday ? DPColor.danger : .clear
    }

    private var isToday: Bool {
        let today = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: Date())
        return day.cell.year == today.year && day.cell.month == today.month && day.cell.day == today.day
    }

    private func scheduleText(_ schedule: ScheduleDTO) -> some View {
        let tags = ScheduleTagDisplayPolicy.displayTags(for: schedule, calendarMemberID: calendarMemberID)
        return VStack(alignment: .leading, spacing: 1) {
            scheduleTitleLine(schedule)
                .font(DPFont.light(size: CalendarTypography.cellContent, relativeTo: .caption2))
                .foregroundStyle(primaryForeground)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !tags.isEmpty {
                // Two tags already outgrow a 47pt cell, so they wrap and settle against
                // the trailing edge, as they do in the same cell on the web.
                DPMemberTagChips(
                    items: tags,
                    size: .micro,
                    limit: CalendarVisualLogic.maximumTagsPerCellSchedule,
                    alignment: .trailing
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.top, 1)
        .overlay(alignment: .top) {
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 0.75, dash: [2, 2]))
                .foregroundStyle(cellBorder)
                .frame(height: 0.75)
        }
    }

    /// The title and everything that qualifies it run as one flow of text, so the counter
    /// and the details mark stay with the last word instead of claiming a line of their own.
    private func scheduleTitleLine(_ schedule: ScheduleDTO) -> Text {
        var line = Text(verbatim: schedule.content)
        if let time = CalendarVisualLogic.calendarScheduleTimeText(
            start: schedule.startDateTime,
            end: schedule.endDateTime,
            daysFromStart: schedule.daysFromStart,
            totalDays: schedule.totalDays
        ) {
            line = line + Text(verbatim: time)
        }
        if schedule.totalDays > 1 {
            line = line + Text(verbatim: "(\(schedule.daysFromStart)/\(schedule.totalDays))")
        }
        if !schedule.description.isEmpty || !schedule.attachments.isEmpty {
            line = line + Text(verbatim: " ") + Text(Image(systemName: "text.bubble"))
        }
        return line
    }

    private func statusBubble(_ text: String, image: String, background: Color, border: Color, foreground: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: image).font(.system(size: CalendarTypography.cellMicro, weight: .semibold))
            Text(text).lineLimit(1)
        }
        .font(DPFont.light(size: CalendarTypography.cellContent, relativeTo: .caption2))
        .foregroundStyle(foreground)
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(border, lineWidth: 0.5))
    }

    private func comparedDutyChip(_ item: ComparedDuty) -> some View {
        HStack(spacing: 2) {
            CalendarMemberAvatar(
                memberID: item.memberID,
                hasProfilePhoto: item.hasProfilePhoto,
                profilePhotoVersion: item.profilePhotoVersion,
                size: 12
            )
            Text(item.duty.dutyType ?? CalendarLocalization.text("calendar.off"))
                .lineLimit(1)
        }
        .font(DPFont.bold(size: CalendarTypography.cellContent, relativeTo: .caption2))
        .foregroundStyle(primaryForeground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name), \(item.duty.dutyType ?? CalendarLocalization.text("calendar.off"))")
        .accessibilityIdentifier("calendar.compared-duty.\(item.memberID)")
    }

    private func relativeLabel(_ item: DDayDTO) -> String? {
        CalendarVisualLogic.pinnedDDayLabel(cell: day.cell.date, target: item.date)
    }
}

enum CalendarScheduleDestructiveAction: Identifiable {
    case delete(ScheduleDTO)
    case untag(ScheduleDTO)

    var id: String {
        switch self {
        case .delete(let schedule): "delete-\(schedule.id)"
        case .untag(let schedule): "untag-\(schedule.id)"
        }
    }

    var titleKey: String {
        switch self {
        case .delete: "calendar.schedule.delete.confirm.title"
        case .untag: "calendar.schedule.untag.confirm.title"
        }
    }

    var actionKey: String {
        switch self {
        case .delete: "calendar.delete"
        case .untag: "calendar.schedule.untag"
        }
    }

    var message: String {
        switch self {
        case .delete(let schedule):
            CalendarLocalization.format("calendar.schedule.delete.confirm.message", schedule.content)
        case .untag(let schedule):
            CalendarLocalization.format("calendar.schedule.untag.confirm.message", schedule.content)
        }
    }
}

enum CalendarDestructiveActionPolicy {
    static func canBegin(isWorking: Bool) -> Bool { !isWorking }
}

nonisolated enum CalendarDDayEditorDeleteRoute: Equatable, Sendable {
    case centralConfirmation
    case unavailable
}

nonisolated enum CalendarDDayEditorDeleteRoutingPolicy {
    static func route(
        hasExistingDDay: Bool,
        hasCentralConfirmationHandler: Bool
    ) -> CalendarDDayEditorDeleteRoute {
        hasExistingDDay && hasCentralConfirmationHandler
            ? .centralConfirmation
            : .unavailable
    }
}

enum CalendarDDayDeleteSuccessDismissalPolicy {
    static func prepareForDismiss(
        authorizeDismiss: () -> Void,
        yieldTurn: () async -> Void = { await Task.yield() }
    ) async {
        authorizeDismiss()
        await yieldTurn()
    }
}

enum CalendarModalDismissabilityPolicy {
    static func dayCanDismiss(
        isEditorWorking: Bool,
        hasDestructiveAction: Bool,
        isPerformingDestructiveAction: Bool
    ) -> Bool {
        !isEditorWorking && !hasDestructiveAction && !isPerformingDestructiveAction
    }

    static func dDayCanDismiss(isWorking: Bool, isConfirmingDelete: Bool) -> Bool {
        !isWorking && !isConfirmingDelete
    }
}

private struct CalendarDestructiveConfirmationModal: View {
    let action: CalendarScheduleDestructiveAction
    let isWorking: Bool
    let cancel: () -> Void
    let confirm: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(CalendarLocalization.text(action.titleKey))
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DPSpacing.large)
                .frame(minHeight: 56)
                .background(DPColor.backgroundTertiary)

            Text(action.message)
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DPSpacing.large)
                .padding(.vertical, DPSpacing.large)
                .frame(maxWidth: .infinity)

            HStack(spacing: DPSpacing.compact) {
                Button(action: cancel) {
                    Text(CalendarLocalization.text("calendar.cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPOutlineButtonStyle())
                .disabled(isWorking)

                Button {
                    Task { await confirm() }
                } label: {
                    Group {
                        if isWorking {
                            ProgressView().tint(DPColor.textOnDark)
                        } else {
                            Text(CalendarLocalization.text(action.actionKey))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPDestructiveButtonStyle())
                .disabled(isWorking)
            }
            .padding(.horizontal, DPSpacing.large)
            .padding(.bottom, DPSpacing.large)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DayDetailView: View {
    @ObservedObject var model: CalendarViewModel
    let initialDay: CalendarDayContent
    let maximumHeight: CGFloat
    let onDismissabilityChange: (Bool) -> Void
    /// Raised after a report blocks the schedule owner. The argument says whether that
    /// owner is also the calendar owner, whose block ends access to this screen.
    let onBlockedScheduleOwner: (Bool) -> Void
    let dismissRequest: Int
    let dismiss: () -> Void
    @State private var editorSchedule: ScheduleDTO?
    @State private var createsSchedule = false
    @State private var destructiveAction: CalendarScheduleDestructiveAction?
    @State private var isPerformingDestructiveAction = false
    @State private var isEditorWorking = false
    @State private var editorDismissRequest = 0
    @State private var reportTarget: ReportTarget?
    @State private var reportCanDismiss = true
    @State private var reportBlockEndsCalendarAccess = false
    @State private var dismissesAfterReportedBlock = false

    private var day: CalendarDayContent {
        model.selectedDay ?? initialDay
    }

    private var showsEditor: Bool {
        createsSchedule || editorSchedule != nil
    }

    var body: some View {
        Group {
            if let destructiveAction {
                CalendarDestructiveConfirmationModal(
                    action: destructiveAction,
                    isWorking: isPerformingDestructiveAction,
                    cancel: { self.destructiveAction = nil },
                    confirm: performDestructiveAction
                )
            } else if showsEditor {
                ScheduleEditorView(
                    model: model,
                    day: day,
                    existing: editorSchedule,
                    maximumPanelHeight: maximumHeight,
                    onCancel: closeEditor,
                    onSaved: closeEditor,
                    dismissRequest: editorDismissRequest,
                    onWorkingChange: updateEditorWorking
                ) {
                    modalHeader
                }
                .id(editorSchedule?.id.uuidString ?? "new-\(day.id)")
            } else {
                DPModalPanel(
                    maximumPanelHeight: maximumHeight * CalendarCompactModalLayout.maximumPanelHeightRatio
                ) {
                    modalHeader
                } content: {
                    scheduleList
                } footer: {
                    modalFooter
                }
            }
        }
        .onAppear(perform: reportDismissability)
        .onChange(of: showsEditor) { _, _ in reportDismissability() }
        .onChange(of: destructiveAction != nil) { _, _ in reportDismissability() }
        .onChange(of: isPerformingDestructiveAction) { _, _ in reportDismissability() }
        .onChange(of: dismissRequest) { _, _ in requestDismissal() }
        .onDisappear { onDismissabilityChange(true) }
        .fullScreenCover(item: $reportTarget) { target in
            DPModalOverlay(
                onDismiss: { finishReportDismissal() },
                canDismiss: reportCanDismiss
            ) { availableSize, dismissReport in
                ReportSheet(
                    target: target,
                    maximumHeight: availableSize.height,
                    onDismissabilityChange: { reportCanDismiss = $0 },
                    onBlocked: { dismissesAfterReportedBlock = true },
                    dismiss: dismissReport
                )
            }
        }
        .alert(
            CalendarLocalization.text("calendar.error.title"),
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button(CalendarLocalization.text("calendar.ok"), role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var modalHeader: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack(spacing: DPSpacing.small) {
                if createsSchedule {
                    modeBadge("calendar.schedule.add", color: DPColor.success)
                } else if editorSchedule != nil {
                    modeBadge("calendar.schedule.edit", color: DPColor.accent)
                }

                Text(formattedDate)
                    .font(DPFont.bold(size: CalendarTypography.detailTitle, relativeTo: .headline))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)

                Spacer()

                Button {
                    requestDismissal()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DPColor.textPrimary)
                .opacity(dayModalCanRequestDismissal ? 1 : 0.35)
                .disabled(!dayModalCanRequestDismissal)
                .accessibilityLabel(CalendarLocalization.text("calendar.close"))
            }

            // Somebody else's duty is already told by the colour of the day in the grid
            // behind this sheet, so the sheet does not repeat it.
            if model.canEdit, !showsEditor, !model.visibleDutyTypes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.visibleDutyTypes, id: \.id) { type in
                            dutyButton(id: type.id, name: type.name, color: calendarColor(type.color))
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, DPSpacing.extraSmall)
        .padding(.vertical, DPSpacing.small)
        .background(DPColor.backgroundTertiary)
    }

    private var scheduleList: some View {
        VStack(alignment: .leading, spacing: DPSpacing.compact) {
            if day.schedules.isEmpty {
                Text("calendar.schedule.empty", tableName: "Calendar")
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 56)
            } else {
                ForEach(day.schedules, id: \.id) { schedule in
                    scheduleCard(schedule)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var modalFooter: some View {
        HStack {
            if model.canEdit {
                Button {
                    createsSchedule = true
                } label: {
                    Label(CalendarLocalization.text("calendar.schedule.add"), systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSuccessButtonStyle())
            } else {
                Button(action: dismiss) {
                    Text(CalendarLocalization.text("calendar.close"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPOutlineButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func scheduleCard(_ schedule: ScheduleDTO) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack(alignment: .top, spacing: DPSpacing.small) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: DPSpacing.extraSmall) {
                        Text(schedule.content)
                            .font(DPFont.light(size: CalendarTypography.detailTitle, relativeTo: .body))
                            .foregroundStyle(DPColor.textPrimary)
                        if schedule.totalDays > 1 {
                            Text("(\(schedule.daysFromStart)/\(schedule.totalDays))")
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.accent)
                        }
                    }
                    if let time = scheduleTime(schedule) {
                        Text(time)
                            .font(DPFont.light(size: CalendarTypography.detailMetadata, relativeTo: .subheadline))
                            .foregroundStyle(DPColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 0) {
                    if model.canEdit, !canUntag(schedule) {
                        DPIconActionButton(
                            systemImage: "pencil",
                            label: CalendarLocalization.text("calendar.schedule.edit"),
                            tone: .accent
                        ) {
                            editorSchedule = schedule
                        }

                        DPIconActionButton(
                            systemImage: "trash",
                            label: CalendarLocalization.text("calendar.schedule.delete"),
                            tone: .danger
                        ) {
                            destructiveAction = .delete(schedule)
                        }
                    }

                    // Untag and report both act on somebody else's doing rather than on
                    // the schedule's content, and a schedule you were tagged into offers
                    // the two at once. One overflow keeps them from competing with edit
                    // and delete for the same corner of the row.
                    if canUntag(schedule) || canReport(schedule) {
                        scheduleOverflowMenu(schedule)
                    }
                }
                // The chips carry their own touch padding, so the row lines them up with
                // the title instead of adding another gap on top of it.
                .padding(.top, -DPIconActionMetrics.touchPadding)
                .padding(.trailing, -DPIconActionMetrics.touchPadding)
            }

            scheduleMetadata(schedule)

            if !schedule.description.isEmpty {
                Divider().overlay(DPColor.borderPrimary)
                Text(schedule.description)
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textSecondary)
                    .textSelection(.enabled)
            }

            if !schedule.attachments.isEmpty {
                Divider().overlay(DPColor.borderPrimary)
                ScheduleAttachmentGallery(
                    schedule: schedule,
                    canEdit: model.canEdit && !schedule.isTagged
                )
            }
        }
        .padding(DPSpacing.compact)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary, lineWidth: 1)
        }
    }

    private func scheduleOverflowMenu(_ schedule: ScheduleDTO) -> some View {
        Menu {
            if canUntag(schedule) {
                Button {
                    destructiveAction = .untag(schedule)
                } label: {
                    Label(CalendarLocalization.text("calendar.schedule.untag"), systemImage: "tag.slash")
                }
                .accessibilityIdentifier("calendar.schedule.untag")
            }

            if canReport(schedule) {
                // Reporting is the one action here that reaches another member, so it
                // carries the siren the rest of the app reports with, in danger red.
                Button(role: .destructive) {
                    withoutPresentationAnimation {
                        reportBlockEndsCalendarAccess = blockEndsCalendarAccess(schedule)
                        reportTarget = ReportTarget(
                            type: .schedule,
                            targetID: schedule.id.uuidString,
                            name: schedule.content
                        )
                    }
                } label: {
                    Label {
                        Text(CalendarLocalization.text("calendar.report.schedule"))
                    } icon: {
                        DPReportBeaconIcon()
                    }
                }
                .accessibilityIdentifier("calendar.schedule.report")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: DPIconActionMetrics.iconSize, weight: .semibold))
                .foregroundStyle(DPIconActionTone.neutral.foreground)
                .frame(
                    minWidth: DPIconActionMetrics.controlSize,
                    minHeight: DPIconActionMetrics.controlSize
                )
                .background(
                    RoundedRectangle(cornerRadius: DPRadius.standard)
                        .fill(DPIconActionTone.neutral.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DPRadius.standard)
                        .stroke(DPIconActionTone.neutral.border, lineWidth: DPChrome.borderWidth)
                )
                .padding(DPIconActionMetrics.touchPadding)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(CalendarLocalization.text("calendar.schedule.more"))
        .accessibilityIdentifier("calendar.schedule.menu")
    }

    // Only the tagged member can shed a tag, and only from their own calendar, where
    // the schedule is somebody else's doing.
    private func canUntag(_ schedule: ScheduleDTO) -> Bool {
        schedule.isTagged && model.isMyCalendar
    }

    // Only a signed-in member can report, and only content that is not their own:
    // another member's calendar, or a schedule someone else tagged them into.
    private func canReport(_ schedule: ScheduleDTO) -> Bool {
        CalendarReportPolicy.canReport(
            isSignedIn: model.me != nil,
            isMyCalendar: model.isMyCalendar,
            isTagged: schedule.isTagged,
            scheduleOwnerID: schedule.taggedByMember?.id ?? model.targetMemberID,
            reporterID: model.me?.id
        )
    }

    // Reporting with "also block" blocks whoever owns the reported schedule, and only
    // the calendar's own member owning it revokes access to this screen. A schedule a
    // third party tagged this member into belongs to somebody else, whose block leaves
    // the calendar perfectly readable.
    private func blockEndsCalendarAccess(_ schedule: ScheduleDTO) -> Bool {
        !model.isMyCalendar && !schedule.isTagged
    }

    @ViewBuilder
    private func scheduleMetadata(_ schedule: ScheduleDTO) -> some View {
        let tags = ScheduleTagDisplayPolicy.displayTags(
            for: schedule,
            calendarMemberID: model.targetMemberID
        )
        let showsVisibility = schedule.visibility != nil && model.isMyCalendar

        if !tags.isEmpty || showsVisibility {
            HStack(spacing: DPSpacing.small) {
                if !tags.isEmpty {
                    DPMemberTagChips(items: tags, size: .regular)
                }
                if let visibility = schedule.visibility, model.isMyCalendar {
                    Label(
                        CalendarLocalization.text("calendar.visibility.\(visibilityKey(visibility))"),
                        systemImage: "eye"
                    )
                    .font(DPFont.light(size: CalendarTypography.detailMetadata, relativeTo: .subheadline))
                    .foregroundStyle(DPColor.textMuted)
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func dutyButton(id: DutyTypeID?, name: String, color: Color) -> some View {
        let selected = day.duty?.dutyTypeId == id
        return Button {
            Task { await model.updateDuty(day: day, dutyTypeID: id) }
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3).stroke(DPColor.borderSecondary)
                    }
                Text(name)
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textPrimary)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(selected ? color.opacity(0.20) : DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.compact))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.compact)
                    .stroke(selected ? DPColor.accent : DPColor.borderPrimary, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func modeBadge(_ key: String, color: Color) -> some View {
        Text(CalendarLocalization.text(key))
            .font(DPTypography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, DPSpacing.small)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.small))
    }

    private func closeEditor() {
        createsSchedule = false
        editorSchedule = nil
        isEditorWorking = false
        reportDismissability()
    }

    // Blocking removes this schedule from every board or calendar where it was tagged,
    // so the detail closes and lets the calendar refresh or leave once the cover is gone.
    private func finishReportDismissal() {
        reportTarget = nil
        reportCanDismiss = true
        guard dismissesAfterReportedBlock else { return }
        dismissesAfterReportedBlock = false
        onBlockedScheduleOwner(reportBlockEndsCalendarAccess)
        Task {
            await Task.yield()
            dismiss()
        }
    }

    private var dayModalCanRequestDismissal: Bool {
        !isEditorWorking && destructiveAction == nil && !isPerformingDestructiveAction
    }

    private func requestDismissal() {
        guard dayModalCanRequestDismissal else { return }
        if showsEditor {
            editorDismissRequest += 1
        } else {
            dismiss()
        }
    }

    private func updateEditorWorking(_ isWorking: Bool) {
        isEditorWorking = isWorking
        reportDismissability()
    }

    private func performDestructiveAction() async {
        guard let destructiveAction,
              CalendarDestructiveActionPolicy.canBegin(isWorking: isPerformingDestructiveAction)
        else { return }
        isPerformingDestructiveAction = true
        switch destructiveAction {
        case .delete(let schedule):
            let succeeded = await model.deleteSchedule(schedule)
            isPerformingDestructiveAction = false
            if succeeded { self.destructiveAction = nil }
        case .untag(let schedule):
            let succeeded = await model.untagSelf(schedule)
            isPerformingDestructiveAction = false
            if succeeded { self.destructiveAction = nil }
        }
    }

    private func reportDismissability() {
        onDismissabilityChange(
            CalendarModalDismissabilityPolicy.dayCanDismiss(
                isEditorWorking: isEditorWorking,
                hasDestructiveAction: destructiveAction != nil,
                isPerformingDestructiveAction: isPerformingDestructiveAction
            )
        )
    }

    private var formattedDate: String {
        guard let date = CalendarDateSupport.date(from: day.cell.date) else {
            return day.cell.date.rawValue
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = CalendarLocalization.selectedLocale
        dateFormatter.calendar = CalendarDateSupport.calendar
        dateFormatter.setLocalizedDateFormatFromTemplate("yyyyMMMMd")
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = CalendarLocalization.selectedLocale
        weekdayFormatter.calendar = CalendarDateSupport.calendar
        weekdayFormatter.setLocalizedDateFormatFromTemplate("EEE")
        return "\(dateFormatter.string(from: date)) (\(weekdayFormatter.string(from: date)))"
    }

    private func scheduleTime(_ schedule: ScheduleDTO) -> String? {
        CalendarVisualLogic.scheduleListTimeText(
            start: schedule.startDateTime,
            end: schedule.endDateTime
        )
    }

    private func visibilityKey(_ visibility: Visibility) -> String {
        switch visibility {
        case .publicAccess: "public"
        case .friends: "friends"
        case .family: "family"
        case .privateAccess, .unknown: "private"
        }
    }

    private func calendarColor(_ hex: String?) -> Color {
        guard let hex else { return DPColor.backgroundCard }
        let value = UInt64(
            hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted),
            radix: 16
        ) ?? 0x6B7280
        return Color(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}

private struct ScheduleEditorView<Header: View>: View {
    @ObservedObject var model: CalendarViewModel
    let day: CalendarDayContent
    let existing: ScheduleDTO?
    let maximumPanelHeight: CGFloat
    let onCancel: () -> Void
    let onSaved: () -> Void
    let dismissRequest: Int
    let onWorkingChange: (Bool) -> Void
    let header: Header
    /// The dismissal baseline is pinned to the same snapshot that seeded the editable state.
    /// Recomputing it per render lets an unrelated re-render redefine "unchanged" — the
    /// `?? base` fallbacks resolve to a fresh `Date()` — and marks an untouched editor dirty.
    @State private var initialContent: String
    @State private var initialDescription: String
    @State private var initialVisibility: Visibility
    @State private var initialStart: Date
    @State private var initialEnd: Date
    @State private var initialTagIDs: Set<MemberID>
    @State private var initialAttachmentIDs: [AttachmentID]
    @State private var content: String
    @State private var description: String
    @State private var visibility: Visibility
    /// The schedule model stores "no time" as midnight, so the editor keeps each date and
    /// its optional time apart and only recombines them for saving and dirty checks.
    @State private var startDate: Date
    @State private var startTime: Date?
    @State private var endDate: Date
    @State private var endTime: Date?
    @State private var tagIDs: Set<MemberID>
    @State private var isSaving = false
    @State private var isDiscarding = false
    @State private var showsDiscardConfirmation = false
    @State private var pendingAIConsentPolicy: PolicyDTO?
    @StateObject private var attachmentModel: AttachmentPickerModel
    @StateObject private var aiConsent = AIScheduleParsingConsentStore.shared
    @FocusState private var focusedField: Field?
    @State private var isTagSearchFocused = false
    @State private var isTagSelectorExpanded = false
    @ScaledMetric(relativeTo: .subheadline) private var rowLabelWidth: CGFloat =
        CalendarVisualLogic.formLabelWidth(locale: CalendarLocalization.selectedLocale)
    /// Reserved on every date and time cell so a row keeps its height in each of the time's
    /// states. It follows the body text style because the pickers it has to fit do.
    @ScaledMetric(relativeTo: .body) private var dateRowHeight: CGFloat =
        CalendarVisualLogic.scheduleDateRowHeight

    private enum Field {
        case title
        case details
        case tags
    }

    /// Which of the two date rows has its calendar open, if any. The editor has to know: an
    /// outside tap has to close that calendar rather than the whole form, and the panel has to
    /// scroll the calendar's own confirm into view. One value covers both rows, so opening one
    /// calendar closes the other.
    private enum ScheduleDateField: Hashable {
        case start
        case end
    }

    @State private var expandedDateField: ScheduleDateField?

    init(
        model: CalendarViewModel,
        day: CalendarDayContent,
        existing: ScheduleDTO?,
        maximumPanelHeight: CGFloat,
        onCancel: @escaping () -> Void,
        onSaved: @escaping () -> Void,
        dismissRequest: Int = 0,
        onWorkingChange: @escaping (Bool) -> Void = { _ in },
        @ViewBuilder header: () -> Header
    ) {
        self.model = model
        self.day = day
        self.existing = existing
        self.maximumPanelHeight = maximumPanelHeight
        self.onCancel = onCancel
        self.onSaved = onSaved
        self.dismissRequest = dismissRequest
        self.onWorkingChange = onWorkingChange
        self.header = header()
        let base = CalendarDateSupport.date(from: day.cell.date) ?? Date()
        let initialContent = existing?.content ?? ""
        let initialDescription = existing?.description ?? ""
        let initialVisibility = existing?.visibility ?? .family
        let initialStart = existing.flatMap { CalendarDateSupport.date(from: $0.startDateTime) } ?? base
        let initialEnd = existing.flatMap { CalendarDateSupport.date(from: $0.endDateTime) } ?? base
        let initialTagIDs = Set(existing?.tags.compactMap(\.id) ?? [])
        let initialAttachmentIDs = existing?.attachments.map(\.id) ?? []
        _initialContent = State(initialValue: initialContent)
        _initialDescription = State(initialValue: initialDescription)
        _initialVisibility = State(initialValue: initialVisibility)
        _initialStart = State(initialValue: initialStart)
        _initialEnd = State(initialValue: initialEnd)
        _initialTagIDs = State(initialValue: initialTagIDs)
        _initialAttachmentIDs = State(initialValue: initialAttachmentIDs)
        _content = State(initialValue: initialContent)
        _description = State(initialValue: initialDescription)
        _visibility = State(initialValue: initialVisibility)
        _startDate = State(initialValue: initialStart)
        _startTime = State(initialValue: ScheduleEditorTimePolicy.time(
            of: initialStart,
            calendar: CalendarDateSupport.calendar
        ))
        _endDate = State(initialValue: initialEnd)
        _endTime = State(initialValue: ScheduleEditorTimePolicy.endTime(
            of: initialEnd,
            start: initialStart,
            calendar: CalendarDateSupport.calendar
        ))
        _tagIDs = State(initialValue: initialTagIDs)
        _attachmentModel = StateObject(wrappedValue: AttachmentPickerModel(
            contextType: .schedule,
            targetContextId: existing?.id.uuidString,
            existingAttachments: existing?.attachments ?? []
        ))
    }

    private var start: Date {
        ScheduleEditorTimePolicy.combine(
            date: startDate,
            time: startTime,
            calendar: CalendarDateSupport.calendar
        )
    }

    private var end: Date {
        ScheduleEditorTimePolicy.effectiveEnd(
            start: start,
            endDate: endDate,
            endTime: endTime,
            calendar: CalendarDateSupport.calendar
        )
    }

    /// What the panel keeps in view. An open date calendar outranks everything: it is the
    /// tallest thing this form can grow, and its own confirm lands below the modal's footer the
    /// moment it opens — a step the user has to see to take. Otherwise it is the focused field,
    /// and finally the tag search, which belongs to `DPFriendTagSelector` and so never appears
    /// in `focusedField` at all. Expanding friend tags targets the reserved summary at the
    /// selector's bottom edge, so the zero-selection state is visible before the first pick.
    private var scrollTarget: AnyHashable? {
        if let expandedDateField { return AnyHashable(expandedDateField) }
        if let focusedField { return AnyHashable(focusedField) }
        if isTagSearchFocused { return AnyHashable(Field.tags) }
        return isTagSelectorExpanded
            ? AnyHashable(DPFriendTagSelectorScrollAnchor.selectionSummary)
            : nil
    }

    var body: some View {
        DPModalPanel(
            maximumPanelHeight: maximumPanelHeight,
            scrollTarget: scrollTarget
        ) {
            header
        } content: {
            editorForm
        } footer: {
            editorActions
        }
        .onAppear { onWorkingChange(interactionsDisabled) }
        .onChange(of: interactionsDisabled) { _, isWorking in
            onWorkingChange(isWorking)
        }
        .onChange(of: dismissRequest) { _, _ in handleOutsideDismissRequest() }
        .onDisappear { onWorkingChange(false) }
        .alert(
            CalendarLocalization.text("calendar.discard.title"),
            isPresented: $showsDiscardConfirmation
        ) {
            Button(CalendarLocalization.text("calendar.discard.action"), role: .destructive) {
                discardAndCancel()
            }
            Button(CalendarLocalization.text("calendar.cancel"), role: .cancel) {}
        } message: {
            Text(CalendarLocalization.text("calendar.discard.message"))
        }
        .alert(
            CalendarLocalization.text("calendar.aiConsent.prompt.title"),
            isPresented: Binding(
                get: { pendingAIConsentPolicy != nil },
                set: { if !$0 { pendingAIConsentPolicy = nil } }
            )
        ) {
            Button(CalendarLocalization.text("calendar.aiConsent.prompt.agree")) {
                guard let memberID = model.me?.id,
                      let version = pendingAIConsentPolicy?.version
                else {
                    pendingAIConsentPolicy = nil
                    saveWithoutConsentRequest()
                    return
                }
                pendingAIConsentPolicy = nil
                isSaving = true
                Task {
                    let granted = await aiConsent.grant(
                        for: memberID,
                        policyVersion: version,
                        emitsHaptic: false
                    )
                    await performSave(aiTimeParsingRequested: granted)
                }
            }
            Button(CalendarLocalization.text("calendar.aiConsent.prompt.decline"), role: .destructive) {
                let memberID = model.me?.id
                pendingAIConsentPolicy = nil
                isSaving = true
                Task {
                    if let memberID {
                        _ = await aiConsent.revoke(for: memberID, emitsHaptic: false)
                    }
                    await performSave(aiTimeParsingRequested: false)
                }
            }
            Button(CalendarLocalization.text("calendar.cancel"), role: .cancel) {}
        } message: {
            Text(CalendarLocalization.text("calendar.aiConsent.prompt.message"))
        }
    }

    private var editorForm: some View {
        VStack(spacing: DPSpacing.small) {
            formRow("calendar.schedule.content") {
                ZStack(alignment: .trailing) {
                    TextField(CalendarLocalization.text("calendar.schedule.content.placeholder"), text: $content)
                        .textInputAutocapitalization(.sentences)
                        .font(DPFont.light(size: 15, relativeTo: .body))
                        .focused($focusedField, equals: .title)
                        .padding(.trailing, 54)
                        .dpInputChrome(isInvalid: content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || content.count > 50)
                    Text("\(content.count)/50")
                        .font(DPTypography.caption)
                        .foregroundStyle(content.count > 50 ? DPColor.danger : DPColor.textMuted)
                        .padding(.trailing, DPSpacing.small)
                }
            }
            .id(Field.title)

            scheduleDateSection

            formRow("calendar.schedule.description", alignment: .top) {
                TextField(
                    CalendarLocalization.text("calendar.schedule.description.placeholder"),
                    text: $description,
                    axis: .vertical
                )
                .font(DPFont.light(size: 15, relativeTo: .body))
                .focused($focusedField, equals: .details)
                .lineLimit(2...4)
                .dpInputChrome()
            }
            .id(Field.details)

            formRow("calendar.schedule.visibility", alignment: .top) {
                HStack(spacing: DPSpacing.extraSmall) {
                    visibilityButton(.publicAccess, icon: "globe")
                    visibilityButton(.friends, icon: "person.2")
                    visibilityButton(.family, icon: "heart")
                    visibilityButton(.privateAccess, icon: "lock")
                }
            }

            formRow("calendar.schedule.attachments", alignment: .top) {
                AttachmentPicker(model: attachmentModel)
            }

            if ScheduleFriendTagSelectorPolicy.shouldShow(
                isMyCalendar: model.isMyCalendar,
                currentFriendCount: model.friends.count,
                selectedIDs: tagIDs,
                preservedValidIDCount: existing?.tags.compactMap(\.id).count ?? 0
            ) {
                formRow("calendar.schedule.tags", alignment: .top) {
                    DPFriendTagSelector(
                        items: model.friends.map(DPFriendTagAdapter.item),
                        preservedItems: (existing?.tags ?? []).compactMap(DPFriendTagAdapter.item),
                        selection: $tagIDs,
                        disabled: interactionsDisabled,
                        isSearchFocused: $isTagSearchFocused,
                        onExpand: {
                            expandedDateField = nil
                            focusedField = nil
                            isTagSelectorExpanded = true
                        }
                    )
                }
                .id(Field.tags)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var editorActions: some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                requestDismissal()
            } label: {
                Text(CalendarLocalization.text("calendar.close"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())
            .disabled(interactionsDisabled)

            Button {
                save()
            } label: {
                Text(CalendarLocalization.text("calendar.save"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(saveDisabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// Start and end are two rows of one shape: a label, the day, and the optional time beside
    /// it — the arrangement the web keeps as well. The two controls have to share a line: the
    /// end's time button is deliberately absent until a start time exists, and a row that
    /// stacked them had to reserve that absent button's height anyway (a time may never move
    /// the fields below it), which left a visible hole under the end date. Beside the date the
    /// same reserve is invisible.
    ///
    /// The calendar the day is picked in does not share the row's width: it bleeds back across
    /// the label column, because seven columns squeezed into what the label leaves are 29
    /// points wide in English.
    private var scheduleDateSection: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            formRow("calendar.schedule.start", alignment: .top) {
                startDateControl
            }
            .id(ScheduleDateField.start)
            formRow("calendar.schedule.end", alignment: .top) {
                endDateControl
            }
            .id(ScheduleDateField.end)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The calendar needs the height the keyboard is holding, and it has just taken the
        // screen from whatever field was being typed into.
        .onChange(of: expandedDateField) { _, field in
            if field != nil { focusedField = nil }
        }
        // Bounding the end controls cannot stop the *start* from moving past the end, which
        // edit mode allows, so the end follows the start whenever the start changes. The end
        // date is watched too: its clock has to stay anchored to the day it is shown on for
        // the bound on the end time to mean anything.
        .onChange(of: startDate) { _, _ in alignEndWithStart() }
        .onChange(of: startTime) { _, _ in alignEndWithStart() }
        .onChange(of: endDate) { _, _ in alignEndWithStart() }
    }

    /// The day the start falls on: the floor the end calendar is measured from, and the anchor
    /// its range is painted from.
    private var startDay: DateOnly {
        ScheduleEditorTimePolicy.day(of: startDate)
    }

    private func alignEndWithStart() {
        let aligned = ScheduleEditorTimePolicy.endFollowingStart(
            start: start,
            endDate: endDate,
            endTime: endTime,
            calendar: CalendarDateSupport.calendar
        )
        if aligned.date != endDate { endDate = aligned.date }
        if aligned.time != endTime { endTime = aligned.time }
    }

    /// A new schedule belongs to the day that opened the editor, so its start date is fixed —
    /// but it stays the very field the end row draws, only handed its read-only state. That
    /// state is what carries the lock, the drained colour and the one static VoiceOver reading;
    /// the editor no longer bolts decoration on beside an editable control to imitate them.
    ///
    /// An existing schedule's start is editable and deliberately single-select: only the end is
    /// a range, exactly as the web has it. A start picked as a range would ask the user to
    /// confirm a span whose other end the end row already owns.
    private var startDateControl: some View {
        dateControl(
            $startDate,
            fieldKey: "calendar.schedule.start",
            field: .start,
            isReadOnly: existing == nil
        ) {
            timeControl(
                time: $startTime,
                fieldKey: "calendar.schedule.start",
                canAdd: true,
                add: {
                    startTime = ScheduleEditorTimePolicy.defaultStartTime(
                        on: startDate,
                        now: Date(),
                        calendar: CalendarDateSupport.calendar
                    )
                },
                remove: {
                    startTime = nil
                    // Midnight is how the model stores "no time", so an end time left behind on
                    // its own would read back as a real 00:00 start.
                    endTime = nil
                }
            )
        }
    }

    /// The end is picked as a range anchored at the start, so the calendar paints the schedule's
    /// whole span as the user moves through it and every day before the start is untappable.
    /// The bound lives on the control, not on a check run once an impossible date is already in.
    private var endDateControl: some View {
        dateControl(
            $endDate,
            fieldKey: "calendar.schedule.end",
            field: .end,
            mode: .range(anchor: startDay),
            minimum: startDay
        ) {
            timeControl(
                time: $endTime,
                fieldKey: "calendar.schedule.end",
                canAdd: startTime != nil,
                notEarlierThan: start,
                add: {
                    let defaultEnd = ScheduleEditorTimePolicy.defaultEnd(
                        start: start,
                        endDate: endDate,
                        calendar: CalendarDateSupport.calendar
                    )
                    // The default can have to move the end date itself, so it sets both.
                    endDate = defaultEnd
                    endTime = ScheduleEditorTimePolicy.time(
                        of: defaultEnd,
                        calendar: CalendarDateSupport.calendar
                    )
                },
                remove: { endTime = nil }
            )
        }
    }

    /// Both date rows go through this one builder, so the locked start and the range end differ
    /// in nothing but the state handed to them. No fixed height wraps the field: it is told the
    /// row height it must hold when collapsed and grows past it when its calendar opens.
    private func dateControl<Accessory: View>(
        _ selection: Binding<Date>,
        fieldKey: String,
        field: ScheduleDateField,
        mode: DPDateFieldMode = .single,
        minimum: DateOnly? = nil,
        isReadOnly: Bool = false,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        DPDateField(
            value: dayBinding(selection),
            fieldName: CalendarLocalization.text(fieldKey),
            rowHeight: dateRowHeight,
            mode: mode,
            minimum: minimum,
            isReadOnly: isReadOnly,
            locale: CalendarLocalization.selectedLocale,
            calendarLeadingBleed: CalendarVisualLogic.formRowContentInset(labelWidth: rowLabelWidth),
            expansion: expansion(of: field),
            accessory: accessory
        )
    }

    /// The editor holds the open state so it can answer for the calendar — closing it on an
    /// outside tap and keeping its confirm in view — while the field goes on driving it.
    /// Writing `false` only ever closes the field's own calendar, never one that has since
    /// taken over.
    private func expansion(of field: ScheduleDateField) -> Binding<Bool> {
        Binding(
            get: { expandedDateField == field },
            set: { isExpanded in
                if isExpanded {
                    expandedDateField = field
                } else if expandedDateField == field {
                    expandedDateField = nil
                }
            }
        )
    }

    /// The editor stores instants and the field speaks calendar days, so a written day moves the
    /// stored date without disturbing the clock it carries — the time controls beside it are
    /// still editing that clock.
    private func dayBinding(_ selection: Binding<Date>) -> Binding<DateOnly> {
        Binding(
            get: { ScheduleEditorTimePolicy.day(of: selection.wrappedValue) },
            set: {
                selection.wrappedValue = ScheduleEditorTimePolicy.date(
                    selection.wrappedValue,
                    movedTo: $0,
                    calendar: CalendarDateSupport.calendar
                )
            }
        )
    }

    /// The time is optional: until it is added the field stays empty instead of showing a
    /// midnight the user would feel obliged to correct.
    @ViewBuilder
    /// The end time depends on the start, so until a start time exists the end offers no button
    /// at all: an always-visible control the user cannot use reads as something broken.
    private func timeControl(
        time: Binding<Date?>,
        fieldKey: String,
        canAdd: Bool,
        notEarlierThan lowerBound: Date? = nil,
        add: @escaping () -> Void,
        remove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DPSpacing.extraSmall) {
            if time.wrappedValue != nil {
                // The bound is a whole instant, not a clock reading, so it only narrows the
                // wheel while the end sits on the start's own day; a later end day is free.
                // That holds because the end's clock is kept anchored to the end's own date.
                DatePicker(
                    CalendarLocalization.text(fieldKey),
                    selection: Binding(
                        get: { time.wrappedValue ?? startDate },
                        set: { time.wrappedValue = $0 }
                    ),
                    in: (lowerBound ?? .distantPast)...,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, CalendarLocalization.selectedLocale)

                Button {
                    remove()
                    DPHapticCenter.shared.emit(.selection)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DPColor.textMuted)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CalendarLocalization.text("calendar.schedule.time.remove"))
            } else if canAdd {
                Button {
                    add()
                    DPHapticCenter.shared.emit(.selection)
                } label: {
                    Label(
                        CalendarLocalization.text("calendar.schedule.time.add"),
                        systemImage: "clock"
                    )
                    .font(DPFont.light(size: 13, relativeTo: .subheadline))
                    .foregroundStyle(DPColor.accent)
                    .padding(.horizontal, DPSpacing.small)
                    .padding(.vertical, 7)
                    .background(DPColor.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.compact))
                }
                .buttonStyle(.plain)
            }
        }
        // The button that adds a time is shorter than the picker that replaces it, so a row
        // sized to whichever it holds moved every field below it the moment a time was added.
        // The height is fixed rather than a floor because a picker handed a taller proposal
        // grows into it, and `fixedSize` keeps each control at its own size within that height.
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: dateRowHeight, alignment: .leading)
    }

    private func rowLabel(_ key: String, topPadding: CGFloat = 0) -> some View {
        Text(CalendarLocalization.text(key))
            .font(DPFont.light(size: 13, relativeTo: .subheadline))
            .foregroundStyle(DPColor.textSecondary)
            .frame(width: rowLabelWidth, alignment: .leading)
            .padding(.top, topPadding)
    }

    private func formRow<Content: View>(
        _ key: String,
        alignment: VerticalAlignment = .center,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: alignment, spacing: DPSpacing.small) {
            rowLabel(key, topPadding: alignment == .top ? 10 : 0)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func visibilityButton(_ option: Visibility, icon: String) -> some View {
        let selected = visibility == option
        return Button {
            guard visibility != option else { return }
            visibility = option
            DPHapticCenter.shared.emit(.selection)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DPColor.accent)
                            .offset(x: 9, y: -8)
                    }
                }
                    .font(.system(size: 15, weight: .semibold))
                Text(CalendarLocalization.text("calendar.visibility.\(visibilityKey(option))"))
                    .font(DPFont.light(size: 11, relativeTo: .caption))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(selected ? DPColor.accent : DPColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(selected ? DPColor.accentSoft : DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(selected ? DPColor.accent : DPColor.borderPrimary, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }

    /// A tap on the modal's backdrop, or a VoiceOver escape, arrives here. It closes the
    /// innermost thing that is open: with a calendar expanded that is the calendar, whose own
    /// backdrop is the editor's, and only otherwise the editor itself.
    private func handleOutsideDismissRequest() {
        switch ScheduleEditorDismissalPolicy.outsideRequest(
            hasOpenDateCalendar: expandedDateField != nil
        ) {
        case .closeDateCalendar:
            expandedDateField = nil
        case .requestEditorDismissal:
            requestDismissal()
        }
    }

    private func requestDismissal() {
        guard !interactionsDisabled else { return }
        if isDirty {
            showsDiscardConfirmation = true
        } else {
            discardAndCancel()
        }
    }

    private func discardAndCancel() {
        guard !interactionsDisabled else { return }
        isDiscarding = true
        Task {
            let discarded = await attachmentModel.discard()
            isDiscarding = false
            if discarded {
                await Task.yield()
                onCancel()
            }
        }
    }

    private var isDirty: Bool {
        ScheduleEditorDismissalPolicy.isDirty(
            initialContent: initialContent,
            content: content,
            initialDescription: initialDescription,
            description: description,
            initialVisibility: initialVisibility,
            visibility: visibility,
            initialStart: initialStart,
            start: start,
            initialEnd: initialEnd,
            end: end,
            initialTagIDs: initialTagIDs,
            tagIDs: tagIDs,
            initialAttachmentIDs: initialAttachmentIDs,
            attachmentIDs: attachmentModel.attachments.map(\.id),
            hasAttachmentSession: attachmentModel.attachmentSessionId != nil
        )
    }

    private func save() {
        isSaving = true
        Task {
            guard model.isMyCalendar else {
                await performSave(aiTimeParsingRequested: true)
                return
            }
            guard let memberID = model.me?.id else {
                await performSave(aiTimeParsingRequested: false)
                return
            }
            let decision = await aiConsent.saveDecision(
                for: memberID,
                start: start,
                end: end
            )
            switch decision {
            case .save(let aiTimeParsingRequested):
                await performSave(aiTimeParsingRequested: aiTimeParsingRequested)
            case .requestConsent(let policy):
                isSaving = false
                pendingAIConsentPolicy = policy
            }
        }
    }

    private func saveWithoutConsentRequest() {
        isSaving = true
        Task { await performSave(aiTimeParsingRequested: false) }
    }

    private func performSave(aiTimeParsingRequested: Bool) async {
        guard let attachments = await attachmentModel.resultForSave() else {
            isSaving = false
            return
        }
        let saved = await model.saveSchedule(
            existing: existing,
            content: content,
            description: description,
            visibility: visibility,
            start: start,
            end: end,
            tagFriendIDs: DPFriendTagSelectionLogic.sortedIDs(tagIDs),
            attachmentSessionID: attachments.attachmentSessionId,
            orderedAttachmentIDs: attachments.orderedAttachmentIds,
            aiTimeParsingRequested: aiTimeParsingRequested
        )
        isSaving = false
        if saved { onSaved() }
    }

    private var saveDisabled: Bool {
        interactionsDisabled
            || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || content.count > 50
            || end < start
    }

    private var interactionsDisabled: Bool {
        ScheduleEditorInteractionPolicy.interactionsDisabled(
            isSaving: isSaving,
            isUploading: attachmentModel.isBusy,
            isDiscarding: isDiscarding
        )
    }

    private func visibilityKey(_ value: Visibility) -> String {
        switch value {
        case .publicAccess: "public"
        case .friends: "friends"
        case .family: "family"
        case .privateAccess, .unknown: "private"
        }
    }
}

nonisolated enum DPFriendTagAdapter {
    static func item(_ friend: FriendDTO) -> DPFriendTagItem {
        DPFriendTagItem(
            id: friend.id,
            name: friend.name,
            team: friend.team,
            hasProfilePhoto: friend.hasProfilePhoto,
            profilePhotoVersion: friend.profilePhotoVersion,
            isFamily: friend.isFamily,
            pinOrder: friend.pinOrder
        )
    }

    static func item(_ member: MemberDTO) -> DPFriendTagItem? {
        guard let id = member.id else { return nil }
        return DPFriendTagItem(
            id: id,
            name: member.name,
            team: member.team,
            hasProfilePhoto: member.hasProfilePhoto,
            profilePhotoVersion: member.profilePhotoVersion
        )
    }

    static func item(_ member: MemberPreviewDTO) -> DPFriendTagItem? {
        guard let id = member.id else { return nil }
        return DPFriendTagItem(
            id: id,
            name: member.name,
            team: member.team,
            hasProfilePhoto: member.hasProfilePhoto,
            profilePhotoVersion: member.profilePhotoVersion
        )
    }
}

nonisolated enum ScheduleFriendTagSelectorPolicy {
    static func shouldShow(
        isMyCalendar: Bool,
        currentFriendCount: Int,
        selectedIDs: Set<MemberID>,
        preservedValidIDCount: Int
    ) -> Bool {
        isMyCalendar
            && (currentFriendCount > 0 || !selectedIDs.isEmpty || preservedValidIDCount > 0)
    }
}

/// The schedule model has no "has a time" flag: midnight means the schedule carries no
/// time at all, which is why the editor edits a date and an optional time separately and
/// only folds them back together on save.
nonisolated enum ScheduleEditorTimePolicy {
    /// `nil` for a stored value that means "no time", so the editor leaves the field empty
    /// instead of offering a midnight the user feels obliged to change.
    static func time(of date: Date, calendar: Foundation.Calendar) -> Date? {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let isMidnight = (parts.hour ?? 0) == 0
            && (parts.minute ?? 0) == 0
            && (parts.second ?? 0) == 0
        return isMidnight ? nil : date
    }

    /// Takes the calendar day from `date` and the clock reading from `time`; a missing time
    /// folds back to midnight, which is exactly how the model records "no time".
    static func combine(date: Date, time: Date?, calendar: Foundation.Calendar) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: date)
        let timeParts = time.map { calendar.dateComponents([.hour, .minute, .second], from: $0) }
        parts.hour = timeParts?.hour ?? 0
        parts.minute = timeParts?.minute ?? 0
        parts.second = timeParts?.second ?? 0
        return calendar.date(from: parts) ?? date
    }

    /// The calendar day a stored instant falls on. The editor keeps instants; the date field
    /// speaks days, so this is one half of the bridge between them. It reads through the app
    /// calendar's own time zone — the same one every calendar cell and schedule bound is built
    /// on — so a late-evening start cannot read back as the following day.
    static func day(of date: Date) -> DateOnly {
        DatePickerGridLogic.day(from: date)
    }

    /// `date` moved onto `day`, carrying its clock with it: the editor still needs the time it
    /// holds, and only the day is being picked. A value that names no real day leaves the
    /// instant alone rather than collapsing it onto some fallback.
    static func date(_ date: Date, movedTo day: DateOnly, calendar: Foundation.Calendar) -> Date {
        guard DatePickerGridLogic.isValidDay(day),
              let target = CalendarDateSupport.date(from: day)
        else { return date }
        return combine(date: target, time: date, calendar: calendar)
    }

    /// An end equal to the start is how the model stores a schedule that has a start time
    /// but no end time — it rejects an end before the start — so it reads back as no end time.
    static func endTime(of end: Date, start: Date, calendar: Foundation.Calendar) -> Date? {
        end == start ? nil : time(of: end, calendar: calendar)
    }

    /// Without an end time the end means that whole day, but the model rejects an end before
    /// the start, so a same-day end collapses onto the start — which is exactly how the day
    /// list already renders it, as a single time.
    static func effectiveEnd(
        start: Date,
        endDate: Date,
        endTime: Date?,
        calendar: Foundation.Calendar
    ) -> Date {
        let composed = combine(date: endDate, time: endTime, calendar: calendar)
        guard endTime == nil, calendar.isDate(endDate, inSameDayAs: start) else { return composed }
        return start
    }

    /// The next full hour, so adding a time lands on something usable — and never on
    /// midnight, which the model would read back as no time at all.
    static func defaultStartTime(on date: Date, now: Date, calendar: Foundation.Calendar) -> Date {
        let nextHour = calendar.component(.hour, from: now) + 1
        var parts = calendar.dateComponents([.year, .month, .day], from: date)
        parts.hour = nextHour > 23 ? 9 : nextHour
        parts.minute = 0
        parts.second = 0
        return calendar.date(from: parts) ?? date
    }

    /// An hour after the start. An added end has to stay visible, so it can be neither midnight
    /// — which reads back as no time at all — nor equal to the start, which reads back as no end
    /// time: it falls back to the last minute of the chosen end date, and rolls a day forward
    /// only when the start already sits on that minute. The end date can move, so this answers
    /// with the whole end rather than a clock reading.
    static func defaultEnd(start: Date, endDate: Date, calendar: Foundation.Calendar) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: start)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        if hour + 1 <= 23 {
            return at(hour: hour + 1, minute: minute, on: endDate, calendar: calendar)
        }
        let lastMinute = at(hour: 23, minute: 59, on: endDate, calendar: calendar)
        if lastMinute > start { return lastMinute }
        let nextDay = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        return at(hour: 0, minute: minute, on: nextDay, calendar: calendar)
    }

    /// The end may never precede the start, so the end date control is bounded here rather
    /// than corrected after the fact. The bound is the start of the start's day: the start's
    /// own date has to stay selectable whatever time of it the start carries.
    static func endDateLowerBound(start: Date, calendar: Foundation.Calendar) -> Date {
        calendar.startOfDay(for: start)
    }

    /// A bound on the end control cannot stop the start from moving past it, which edit mode
    /// allows — so the end follows the start instead of being left in a range the editor would
    /// only reject on save. The date rises to the start's day, and an end time that no longer
    /// falls after the start is re-proposed by the same rule that first offered one. An end
    /// without a time needs no bump: that end means the whole day, and `effectiveEnd` already
    /// folds a same-day one onto the start.
    static func endFollowingStart(
        start: Date,
        endDate: Date,
        endTime: Date?,
        calendar: Foundation.Calendar
    ) -> (date: Date, time: Date?) {
        let floor = endDateLowerBound(start: start, calendar: calendar)
        let date = calendar.startOfDay(for: endDate) < floor ? floor : endDate
        guard let endTime else { return (date, nil) }
        // The clock is kept on the end's own day so the bound on the end time control weighs
        // it against the day the user is actually editing.
        let anchored = combine(date: date, time: endTime, calendar: calendar)
        if anchored > start { return (date, anchored) }
        let proposed = defaultEnd(start: start, endDate: date, calendar: calendar)
        return (proposed, time(of: proposed, calendar: calendar))
    }

    private static func at(
        hour: Int,
        minute: Int,
        on date: Date,
        calendar: Foundation.Calendar
    ) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: date)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        return calendar.date(from: parts) ?? date
    }
}

nonisolated enum ScheduleEditorInteractionPolicy {
    static func interactionsDisabled(
        isSaving: Bool,
        isUploading: Bool,
        isDiscarding: Bool = false
    ) -> Bool {
        isSaving || isUploading || isDiscarding
    }
}

/// What a dismissal asked for from outside the editor — a tap on the modal's backdrop, or a
/// VoiceOver escape — should actually close.
nonisolated enum ScheduleEditorOutsideRequestAction: Equatable, Sendable {
    case closeDateCalendar
    case requestEditorDismissal
}

nonisolated enum ScheduleEditorDismissalPolicy {
    /// An outside request closes the innermost thing that is open. The date field's calendar
    /// expands inside the editor rather than on a layer of its own, so the backdrop behind it
    /// is the editor's: left to reach the editor's own dismissal, a tap next to the calendar
    /// threw the user out of the form — and offered to discard it on the way.
    ///
    /// The close button is deliberately not routed through here: pressing it is an explicit
    /// intent to leave, whatever else happens to be open.
    static func outsideRequest(hasOpenDateCalendar: Bool) -> ScheduleEditorOutsideRequestAction {
        hasOpenDateCalendar ? .closeDateCalendar : .requestEditorDismissal
    }

    static func isDirty(
        initialContent: String,
        content: String,
        initialDescription: String,
        description: String,
        initialVisibility: Visibility,
        visibility: Visibility,
        initialStart: Date,
        start: Date,
        initialEnd: Date,
        end: Date,
        initialTagIDs: Set<MemberID>,
        tagIDs: Set<MemberID>,
        initialAttachmentIDs: [AttachmentID],
        attachmentIDs: [AttachmentID],
        hasAttachmentSession: Bool
    ) -> Bool {
        initialContent != content
            || initialDescription != description
            || initialVisibility != visibility
            || initialStart != start
            || initialEnd != end
            || initialTagIDs != tagIDs
            || initialAttachmentIDs != attachmentIDs
            || hasAttachmentSession
    }
}

private struct ScheduleAttachmentGallery: View {
    let schedule: ScheduleDTO
    let canEdit: Bool
    @StateObject private var gallery: AttachmentGalleryModel

    init(schedule: ScheduleDTO, canEdit: Bool) {
        self.schedule = schedule
        self.canEdit = canEdit
        _gallery = StateObject(wrappedValue: AttachmentGalleryModel(
            contextType: .schedule,
            contextId: schedule.id.uuidString,
            attachments: schedule.attachments
        ))
    }

    var body: some View {
        AttachmentGallery(model: gallery, canEdit: canEdit)
            .onChange(of: schedule.attachments) { _, attachments in
                gallery.apply(attachments)
            }
    }
}

private struct ScheduleSearchView: View {
    @ObservedObject var model: CalendarViewModel
    let maximumHeight: CGFloat
    let onDismissabilityChange: (Bool) -> Void
    let dismiss: () -> Void
    @State private var isSelectingResult = false

    private var trimmedQuery: String {
        model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var maximumPanelHeight: CGFloat {
        min(maximumHeight, 874) * 0.85
    }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumPanelHeight) {
            header
        } content: {
            results
        }
        .onAppear { reportDismissability() }
        .onChange(of: model.isSearching) { _, _ in reportDismissability() }
        .onChange(of: isSelectingResult) { _, _ in reportDismissability() }
        .onDisappear { onDismissabilityChange(true) }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: DPSpacing.small) {
                Label(CalendarLocalization.text("calendar.search"), systemImage: "magnifyingglass")
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                Spacer(minLength: 0)
                Button(action: guardedDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DPColor.textPrimary)
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                .accessibilityLabel(CalendarLocalization.text("calendar.close"))
            }
            .padding(.leading, DPSpacing.medium)
            .padding(.trailing, DPSpacing.small)
            .padding(.vertical, DPSpacing.compact)
            .background(DPColor.backgroundTertiary)

            Divider().overlay(DPColor.borderPrimary)

            HStack(spacing: DPSpacing.small) {
                TextField(CalendarLocalization.text("calendar.search.placeholder"), text: $model.searchQuery)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                    .submitLabel(.search)
                    .onSubmit(performSearch)
                    .padding(.horizontal, DPSpacing.compact)
                    .frame(minHeight: DPSize.minimumTouchTarget)
                    .background(DPColor.backgroundInput)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                    .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderInput))

                Button(action: performSearch) {
                    Group {
                        if model.isSearching {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(trimmedQuery.isEmpty || model.isSearching)
                .accessibilityLabel(CalendarLocalization.text("calendar.search.short"))
            }
            .padding(.horizontal, DPSpacing.medium)
            .padding(.top, DPSpacing.medium)
            .padding(.bottom, DPSpacing.small)

            HStack {
                if trimmedQuery.isEmpty {
                    Text(CalendarLocalization.text("calendar.search.hint"))
                } else {
                    Text(CalendarLocalization.format("calendar.search.summary", trimmedQuery, model.searchResults.count))
                }
                Spacer(minLength: 0)
            }
            .font(DPTypography.caption)
            .foregroundStyle(DPColor.textMuted)
            .padding(.horizontal, DPSpacing.medium)
            .padding(.bottom, DPSpacing.small)
        }
    }

    private var results: some View {
        LazyVStack(spacing: DPSpacing.small) {
            if model.searchResults.isEmpty {
                Text(CalendarLocalization.text(trimmedQuery.isEmpty ? "calendar.search.hint" : "calendar.search.empty"))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 68)
            } else {
                ForEach(Array(model.searchResults.enumerated()), id: \.offset) { _, item in
                    Button {
                        Task {
                            guard !isWorking else { return }
                            isSelectingResult = true
                            await model.showSearchResult(item)
                            dismiss()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                            Text(item.content)
                                .font(DPTypography.label)
                                .foregroundStyle(DPColor.textPrimary)
                            Label(
                                CalendarVisualLogic.searchResultDateText(item.startDateTime),
                                systemImage: "calendar"
                            )
                            Text(item.author)
                        }
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                        .padding(.horizontal, DPSpacing.compact)
                        .background(DPColor.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                        .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary))
                    }
                    .buttonStyle(.plain)
                }
            }

            if model.canLoadMoreSearchResults {
                Button {
                    Task { await model.loadMoreSearchResults() }
                } label: {
                    HStack(spacing: DPSpacing.extraSmall) {
                        if model.isSearching { ProgressView().controlSize(.small) }
                        Text(CalendarLocalization.text("calendar.search.more"))
                    }
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                }
                .buttonStyle(DPOutlineButtonStyle())
                .disabled(model.isSearching)
            }
        }
        .padding(DPSpacing.medium)
    }

    private func performSearch() {
        guard !trimmedQuery.isEmpty, !model.isSearching else { return }
        Task { await model.search() }
    }

    private func guardedDismiss() {
        guard !isWorking else { return }
        dismiss()
    }

    private var isWorking: Bool { model.isSearching || isSelectingResult }

    private func reportDismissability() {
        onDismissabilityChange(!isWorking)
    }
}

enum CalendarDDayDetailPolicy {
    static func canManage(isMyCalendar: Bool) -> Bool { isMyCalendar }
}

private struct DDayModalView: View {
    private enum Route: Equatable {
        case detail
        case edit
        case confirmDelete
    }

    @ObservedObject var model: CalendarViewModel
    let selection: DDayModalSelection
    let maximumHeight: CGFloat
    let onDismissabilityChange: (Bool) -> Void
    let dismissRequest: Int
    let dismiss: () -> Void
    @State private var route: Route
    @State private var isDeleting = false
    @State private var isChildWorking = false

    init(
        model: CalendarViewModel,
        selection: DDayModalSelection,
        maximumHeight: CGFloat,
        onDismissabilityChange: @escaping (Bool) -> Void,
        dismissRequest: Int,
        dismiss: @escaping () -> Void
    ) {
        self.model = model
        self.selection = selection
        self.maximumHeight = maximumHeight
        self.onDismissabilityChange = onDismissabilityChange
        self.dismissRequest = dismissRequest
        self.dismiss = dismiss
        _route = State(initialValue: selection == .create ? .edit : .detail)
    }

    @ViewBuilder
    var body: some View {
        Group {
            switch selection {
            case .create:
                DDayEditorView(
                    model: model,
                    existing: nil,
                    maximumHeight: maximumHeight,
                    dismiss: dismiss,
                    dismissRequest: dismissRequest,
                    onWorkingChange: updateChildWorking
                )
            case .detail(let item):
                switch route {
                case .detail:
                    DDayDetailModal(
                        item: item,
                        isPinned: model.pinnedDDayID == item.id,
                        canManage: CalendarDDayDetailPolicy.canManage(isMyCalendar: model.isMyCalendar),
                        maximumHeight: maximumHeight,
                        dismiss: dismiss,
                        edit: { route = .edit },
                        delete: { route = .confirmDelete },
                        togglePin: { model.togglePinnedDDay(item) }
                    )
                case .edit:
                    DDayEditorView(
                        model: model,
                        existing: item,
                        maximumHeight: maximumHeight,
                        dismiss: dismiss,
                        onCancel: { route = .detail },
                        onDeleteRequest: { _ in route = .confirmDelete },
                        dismissRequest: dismissRequest,
                        onWorkingChange: updateChildWorking
                    )
                case .confirmDelete:
                    DDayDeleteConfirmationModal(
                        item: item,
                        isWorking: isDeleting,
                        cancel: { route = .detail },
                        confirm: {
                            guard CalendarDestructiveActionPolicy.canBegin(isWorking: isDeleting) else { return }
                            isDeleting = true
                            let succeeded = await model.deleteDDay(item)
                            isDeleting = false
                            if succeeded {
                                await CalendarDDayDeleteSuccessDismissalPolicy.prepareForDismiss(
                                    authorizeDismiss: { onDismissabilityChange(true) }
                                )
                                dismiss()
                            }
                        }
                    )
                }
            }
        }
        .onAppear(perform: reportDismissability)
        .onChange(of: route) { _, _ in reportDismissability() }
        .onChange(of: isDeleting) { _, _ in reportDismissability() }
        .onChange(of: dismissRequest) { _, _ in
            if selection != .create, route == .detail, !isDeleting, !isChildWorking {
                dismiss()
            }
        }
        .onDisappear { onDismissabilityChange(true) }
        .alert(
            CalendarLocalization.text("calendar.error.title"),
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button(CalendarLocalization.text("calendar.ok"), role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func updateChildWorking(_ isWorking: Bool) {
        isChildWorking = isWorking
        reportDismissability()
    }

    private func reportDismissability() {
        onDismissabilityChange(
            CalendarModalDismissabilityPolicy.dDayCanDismiss(
                isWorking: isDeleting || isChildWorking,
                isConfirmingDelete: route == .confirmDelete
            )
        )
    }
}

private struct DDayDetailModal: View {
    let item: DDayDTO
    let isPinned: Bool
    let canManage: Bool
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    let edit: () -> Void
    let delete: () -> Void
    let togglePin: () -> Void

    private var maximumPanelHeight: CGFloat {
        min(maximumHeight, 874) * CalendarCompactModalLayout.maximumPanelHeightRatio
    }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumPanelHeight) {
            header
        } content: {
            detailBody
        } footer: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DPSpacing.small) { footerActions }
                VStack(spacing: DPSpacing.small) { footerActions }
            }
            .padding(DPSpacing.compact)
        }
    }

    private var header: some View {
        HStack(spacing: DPSpacing.small) {
            Text(CalendarLocalization.text("calendar.dday.detail.title"))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(CalendarLocalization.text("calendar.close"))
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.compact)
        .background(DPColor.backgroundTertiary)
    }

    private var detailBody: some View {
        VStack(alignment: .leading, spacing: DPSpacing.large) {
            Text(dDayLabel)
                .font(DPFont.bold(size: 24, relativeTo: .title2))
                .foregroundStyle(DPColor.textOnDark)
                .padding(.horizontal, DPSpacing.large)
                .padding(.vertical, DPSpacing.compact)
                .background(badgeBackground, in: Capsule())
                .frame(maxWidth: .infinity)

            detailField(
                label: CalendarLocalization.text("calendar.dday.name"),
                value: item.title,
                systemImage: item.isPrivate ? "lock.fill" : nil
            )
            detailField(
                label: CalendarLocalization.text("calendar.dday.date"),
                value: formattedDate,
                systemImage: "calendar.badge.checkmark"
            )

            if canManage {
                HStack(spacing: DPSpacing.small) {
                    Label(
                        CalendarLocalization.text("calendar.dday.pin.action"),
                        systemImage: isPinned ? "star.fill" : "star"
                    )
                    .font(DPTypography.label)
                    .foregroundStyle(isPinned ? DPColor.warning : DPColor.textPrimary)
                    Spacer(minLength: 0)
                    Toggle(CalendarLocalization.text("calendar.dday.pin.action"), isOn: Binding(
                        get: { isPinned },
                        set: { _ in togglePin() }
                    ))
                    .labelsHidden()
                }
                .padding(DPSpacing.compact)
                .background(DPColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            }
        }
        .padding(DPSpacing.medium)
    }

    @ViewBuilder
    private var footerActions: some View {
        if canManage {
            Button(action: edit) {
                Label(CalendarLocalization.text("calendar.dday.edit.action"), systemImage: "pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())

            Button(action: delete) {
                Label(CalendarLocalization.text("calendar.delete"), systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPDestructiveButtonStyle())
        }

        Button(action: dismiss) {
            Text(CalendarLocalization.text("calendar.close"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(DPOutlineButtonStyle())
    }

    private func detailField(label: String, value: String, systemImage: String?) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
            Text(label)
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
            if let systemImage {
                Label(value, systemImage: systemImage)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
            } else {
                Text(value)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedDate: String {
        guard let date = CalendarDateSupport.date(from: item.date) else { return item.date.rawValue }
        let formatter = DateFormatter()
        formatter.locale = CalendarLocalization.selectedLocale
        formatter.calendar = CalendarDateSupport.calendar
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMMdEEEE")
        return formatter.string(from: date)
    }

    private var dDayLabel: String {
        item.calc == 0 ? "D-Day" : item.calc < 0 ? "D+\(abs(item.calc))" : "D-\(item.calc)"
    }

    private var badgeBackground: Color {
        switch item.calc {
        case 0, 1: DPColor.danger
        case 2, 3: DPColor.warning
        case ..<0: DPColor.textMuted
        default: DPColor.accent
        }
    }
}

private struct DDayDeleteConfirmationModal: View {
    let item: DDayDTO
    let isWorking: Bool
    let cancel: () -> Void
    let confirm: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(CalendarLocalization.text("calendar.dday.delete.confirm.title"))
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DPSpacing.large)
                .frame(minHeight: 56)
                .background(DPColor.backgroundTertiary)

            Text(CalendarLocalization.format("calendar.dday.delete.confirm.message", item.title))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DPSpacing.large)
                .padding(.vertical, DPSpacing.large)

            HStack(spacing: DPSpacing.compact) {
                Button(action: cancel) {
                    Text(CalendarLocalization.text("calendar.cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPOutlineButtonStyle())
                .disabled(isWorking)

                Button {
                    Task { await confirm() }
                } label: {
                    Group {
                        if isWorking { ProgressView().tint(DPColor.textOnDark) }
                        else { Text(CalendarLocalization.text("calendar.delete")) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPDestructiveButtonStyle())
                .disabled(isWorking)
            }
            .padding(.horizontal, DPSpacing.large)
            .padding(.bottom, DPSpacing.large)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DDayCard: View {
    let item: DDayDTO
    @ObservedObject var model: CalendarViewModel
    let showDetail: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
                HStack(alignment: .top) {
                    Text(dDayLabel)
                        .font(DPFont.bold(size: 12, relativeTo: .caption))
                        .foregroundStyle(badgeForeground)
                        .padding(.horizontal, DPSpacing.small)
                        .padding(.vertical, DPSpacing.extraSmall)
                        .background(badgeBackground)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
                    Spacer(minLength: 0)
                }
                HStack(alignment: .top, spacing: DPSpacing.extraSmall) {
                    if item.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DPColor.textMuted)
                    }
                    Text(item.title)
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                Label(item.date.rawValue, systemImage: "calendar.badge.checkmark")
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.large)
                    .stroke(model.pinnedDDayID == item.id ? DPColor.warning : DPColor.borderPrimary, lineWidth: model.pinnedDDayID == item.id ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if model.isMyCalendar {
                    Button { model.togglePinnedDDay(item) } label: {
                        Image(systemName: model.pinnedDDayID == item.id ? "star.fill" : "star")
                            .foregroundStyle(model.pinnedDDayID == item.id ? DPColor.warning : DPColor.textMuted)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .onTapGesture(perform: showDetail)
        .shadow(color: .black.opacity(model.pinnedDDayID == item.id ? 0.12 : 0.05), radius: model.pinnedDDayID == item.id ? 4 : 1, y: 1)
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: item.calc <= 0
                ? [DPColor.backgroundSecondary, DPColor.backgroundTertiary]
                : [DPColor.backgroundCard, DPColor.backgroundSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var badgeBackground: Color {
        switch item.calc {
        case 0, 1: DPColor.danger
        case 2, 3: DPColor.warning
        case ..<0: DPColor.textMuted
        default: DPColor.backgroundTertiary
        }
    }

    private var badgeForeground: Color {
        item.calc > 3 ? DPColor.textPrimary : DPColor.textOnDark
    }

    private var dDayLabel: String { item.calc == 0 ? "D-Day" : item.calc < 0 ? "D+\(abs(item.calc))" : "D-\(item.calc)" }
}

private struct DDayEditorView: View {
    @ObservedObject var model: CalendarViewModel
    let existing: DDayDTO?
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    let onCancel: (() -> Void)?
    let onDeleteRequest: ((DDayDTO) -> Void)?
    let dismissRequest: Int
    let onWorkingChange: (Bool) -> Void
    /// The dismissal baseline is pinned to the same snapshot that seeded the editable state.
    /// Recomputing it per render lets an unrelated re-render redefine "unchanged" — for a new
    /// D-Day the fallback is a fresh `Date()` — and marks an untouched editor dirty.
    @State private var initialTitle: String
    @State private var initialDate: Date
    @State private var initialIsPrivate: Bool
    @State private var title: String
    @State private var date: Date
    @State private var isPrivate: Bool
    @State private var isSaving = false
    @State private var showsDiscardConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field { case title }

    init(
        model: CalendarViewModel,
        existing: DDayDTO?,
        maximumHeight: CGFloat,
        dismiss: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        onDeleteRequest: ((DDayDTO) -> Void)? = nil,
        dismissRequest: Int = 0,
        onWorkingChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.model = model
        self.existing = existing
        self.maximumHeight = maximumHeight
        self.dismiss = dismiss
        self.onCancel = onCancel
        self.onDeleteRequest = onDeleteRequest
        self.dismissRequest = dismissRequest
        self.onWorkingChange = onWorkingChange
        let initialTitle = existing?.title ?? ""
        let initialDate = existing.flatMap { CalendarDateSupport.date(from: $0.date) } ?? Date()
        let initialIsPrivate = existing?.isPrivate ?? false
        _initialTitle = State(initialValue: initialTitle)
        _initialDate = State(initialValue: initialDate)
        _initialIsPrivate = State(initialValue: initialIsPrivate)
        _title = State(initialValue: initialTitle)
        _date = State(initialValue: initialDate)
        _isPrivate = State(initialValue: initialIsPrivate)
    }

    private var maximumPanelHeight: CGFloat {
        min(maximumHeight, 874) * CalendarCompactModalLayout.maximumPanelHeightRatio
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 30
    }

    var body: some View {
        DPModalPanel(
            maximumPanelHeight: maximumPanelHeight,
            scrollTarget: focusedField
        ) {
            header
        } content: {
            editorBody
        } footer: {
            footer
        }
        .onAppear { onWorkingChange(isSaving) }
        .onChange(of: isSaving) { _, isWorking in onWorkingChange(isWorking) }
        .onChange(of: date) { _, _ in
            guard !isSaving else { return }
            DPHapticCenter.shared.emit(.selection)
        }
        .onChange(of: isPrivate) { _, _ in
            guard !isSaving else { return }
            DPHapticCenter.shared.emit(.selection)
        }
        .onChange(of: dismissRequest) { _, _ in guardedDismiss() }
        .onDisappear { onWorkingChange(false) }
        .alert(
            CalendarLocalization.text("calendar.discard.title"),
            isPresented: $showsDiscardConfirmation
        ) {
            Button(CalendarLocalization.text("calendar.discard.action"), role: .destructive) {
                performDismissal()
            }
            Button(CalendarLocalization.text("calendar.cancel"), role: .cancel) {}
        } message: {
            Text(CalendarLocalization.text("calendar.discard.message"))
        }
    }

    private var header: some View {
        HStack(spacing: DPSpacing.small) {
            Text(CalendarLocalization.text(existing == nil ? "calendar.dday.add" : "calendar.dday.edit"))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Spacer(minLength: 0)
            Button(action: guardedDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .accessibilityLabel(CalendarLocalization.text("calendar.close"))
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.compact)
    }

    private var editorBody: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                HStack {
                    Text("calendar.dday.name", tableName: "Calendar")
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textSecondary)
                    Spacer()
                    Text("\(title.count)/30")
                        .font(DPTypography.caption)
                        .foregroundStyle(title.count > 30 ? DPColor.danger : DPColor.textMuted)
                }
                TextField(CalendarLocalization.text("calendar.dday.name"), text: $title)
                    .focused($focusedField, equals: .title)
                    .dpInputChrome(isInvalid: !canSave)
                    .disabled(isSaving)
            }
            .id(Field.title)

            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                Text("calendar.dday.date", tableName: "Calendar")
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textSecondary)
                DatePicker(
                    CalendarLocalization.text("calendar.dday.date"),
                    selection: $date,
                    displayedComponents: .date
                )
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DPSpacing.compact)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .background(DPColor.backgroundInput)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderInput))
                .disabled(isSaving)
            }

            HStack(spacing: DPSpacing.small) {
                ForEach([-7, -1, 0, 1, 7], id: \.self) { offset in
                    Button(offset == 0 ? CalendarLocalization.text("calendar.today") : (offset > 0 ? "+\(offset)" : "\(offset)")) {
                        date = CalendarDateSupport.calendar.date(
                            byAdding: .day,
                            value: offset,
                            to: offset == 0 ? Date() : date
                        ) ?? date
                    }
                    .font(DPTypography.caption)
                    .foregroundStyle(offset == 0 ? DPColor.accentHover : DPColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                    .background(offset == 0 ? DPColor.accentSoft : DPColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.small))
                    .disabled(isSaving)
                }
            }

            HStack {
                Label(CalendarLocalization.text("calendar.dday.private"), systemImage: isPrivate ? "lock.fill" : "lock.open")
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textPrimary)
                Spacer()
                Toggle(CalendarLocalization.text("calendar.dday.private"), isOn: $isPrivate)
                    .labelsHidden()
                    .disabled(isSaving)
            }
            .padding(DPSpacing.compact)
            .background(DPColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))

            if CalendarDDayEditorDeleteRoutingPolicy.route(
                hasExistingDDay: existing != nil,
                hasCentralConfirmationHandler: onDeleteRequest != nil
            ) == .centralConfirmation {
                Button(CalendarLocalization.text("calendar.delete"), role: .destructive) {
                    guard let existing, let onDeleteRequest else { return }
                    onDeleteRequest(existing)
                }
                .font(DPTypography.label)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .disabled(isSaving)
            }
        }
        .padding(DPSpacing.medium)
        .opacity(isSaving ? DPChrome.disabledOpacity : 1)
    }

    private var footer: some View {
        HStack(spacing: DPSpacing.small) {
            Button(action: guardedDismiss) {
                Text(CalendarLocalization.text("calendar.close"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())
            .disabled(isSaving)

            Button(action: save) {
                HStack(spacing: DPSpacing.extraSmall) {
                    if isSaving { ProgressView().controlSize(.small) }
                    Text(CalendarLocalization.text("calendar.save"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(!canSave || isSaving)
        }
        .padding(DPSpacing.compact)
    }

    private func guardedDismiss() {
        guard !isSaving else { return }
        if DDayEditorDismissalPolicy.isDirty(
            initialTitle: initialTitle,
            title: title,
            initialDate: initialDate,
            date: date,
            initialIsPrivate: initialIsPrivate,
            isPrivate: isPrivate
        ) {
            showsDiscardConfirmation = true
        } else {
            performDismissal()
        }
    }

    private func performDismissal() {
        guard !isSaving else { return }
        if let onCancel { onCancel() } else { dismiss() }
    }

    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        Task {
            let saved = await model.saveDDay(
                existing: existing,
                title: title,
                date: date,
                isPrivate: isPrivate
            )
            isSaving = false
            onWorkingChange(false)
            if saved { dismiss() }
        }
    }

}

nonisolated enum DDayEditorDismissalPolicy {
    static func isDirty(
        initialTitle: String,
        title: String,
        initialDate: Date,
        date: Date,
        initialIsPrivate: Bool,
        isPrivate: Bool
    ) -> Bool {
        initialTitle != title || initialDate != date || initialIsPrivate != isPrivate
    }
}
