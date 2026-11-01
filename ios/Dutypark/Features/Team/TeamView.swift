import SwiftUI

private struct TeamTopScrollEdgeEffectModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Same soft top edge as Calendar: only the bar controls float over the scrolled
            // content instead of the default opaque band.
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

private struct TeamCalendarMonthTransition: Identifiable {
    let id = UUID()
    var pages: [TeamCalendarMonthPage]
    let viewport: CalendarMonthBodyViewport
}

private struct TeamCalendarMonthHeights: PreferenceKey {
    static let defaultValue: [OfflineMonthKey: CGFloat] = [:]

    static func reduce(value: inout [OfflineMonthKey: CGFloat], nextValue: () -> [OfflineMonthKey: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { max($0, $1) })
    }
}

struct TeamView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel: TeamViewModel
    @StateObject private var teamCreationViewModel = TeamCreationViewModel()
    @State private var monthPickerPresented = false
    @State private var teamCreationPresented = false
    @State private var teamCreationFinishing = false
    @State private var teamManagementDestination: TeamID?
    @State private var pendingTeamManagementDestination: TeamID?
    @State private var scheduleDeletionCandidate: TeamScheduleDTO?
    @State private var scheduleDeletionIsWorking = false
    @State private var previewPages: [OfflineMonthKey: TeamCalendarMonthPage] = [:]
    @State private var monthTransition: TeamCalendarMonthTransition?
    @State private var monthTrackOffset: CGFloat = 0
    @State private var calendarWidth: CGFloat = 0
    @State private var calendarBodyHeight: CGFloat = 0
    @State private var isSwipingMonth = false
    @State private var isSlidingMonth = false
    @State private var monthSlideTask: Task<Void, Never>?
    private let onOpenCalendar: (MemberID) -> Void

    init(
        viewModel: TeamViewModel = TeamViewModel(),
        onOpenCalendar: @escaping (MemberID) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onOpenCalendar = onOpenCalendar
    }

    private var memberID: MemberID? {
        if case .authenticated(let member) = session.state { member.id } else { nil }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.team == nil {
                DPLoadingState(label: LocalizedStringKey(teamLocalized("team.common.loading")))
            } else if viewModel.loadFailed && viewModel.team == nil {
                DPErrorState(
                    title: LocalizedStringKey(teamLocalized("team.common.error")),
                    message: nil,
                    retryTitle: LocalizedStringKey(teamLocalized("team.common.retry"))
                ) {
                    Task { await viewModel.load(memberID: memberID, emitErrorFeedback: true) }
                }
            } else if let team = viewModel.team {
                teamContent(team)
            } else {
                VStack(spacing: 0) {
                    Text("team.view.calendar.title", tableName: "Team")
                        .font(DPTypography.sectionTitle)
                        .foregroundStyle(DPColor.textOnDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DPSpacing.compact)
                        .background(DPColor.surfaceStrong)
                    VStack(spacing: DPSpacing.small) {
                        Image(systemName: "building.2").font(.system(size: 64)).foregroundStyle(DPColor.textMuted)
                        Text("team.view.emptyTitle", tableName: "Team").font(DPTypography.sectionTitle)
                        Text("team.view.emptyDescription", tableName: "Team").font(DPTypography.heading).multilineTextAlignment(.center)
                        Button {
                            teamCreationViewModel.reset()
                            teamCreationFinishing = false
                            teamCreationPresented = true
                        } label: {
                            Label(
                                teamLocalized("team.view.actions.create"),
                                systemImage: "plus"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DPPrimaryButtonStyle())
                        .accessibilityIdentifier("team.create.open")
                    }
                    .foregroundStyle(DPColor.textSecondary)
                    .padding(48)
                }
                .background(DPColor.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                .padding(.horizontal, DPSpacing.small)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .task { await viewModel.loadIfNeeded(memberID: memberID) }
        .task(id: viewModel.calendarPreviewRevision) { await loadMonthPreviews() }
        .onDisappear {
            monthSlideTask?.cancel()
            resetMonthTransition()
        }
        .navigationDestination(item: $teamManagementDestination) { teamID in
            teamManagementView(teamID: teamID)
        }
        .onChange(of: teamCreationPresented) { _, isPresented in
            guard !isPresented, let destination = pendingTeamManagementDestination else {
                return
            }
            pendingTeamManagementDestination = nil
            DPHapticCenter.shared.emit(
                TeamNavigationHapticPolicy.automaticManagementNavigation
            )
            teamManagementDestination = destination
        }
        .refreshable {
            await viewModel.load(memberID: memberID, emitErrorFeedback: true)
        }
        .alert(
            Text("team.common.error", tableName: "Team"),
            isPresented: $viewModel.showsError
        ) {
            Button(teamLocalized("team.common.confirm"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? teamLocalized("team.common.error"))
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { viewModel.scheduleDraft != nil },
                set: { if !$0 { viewModel.scheduleDraft = nil } }
            )
        ) {
            if let draft = viewModel.scheduleDraft {
                DPModalOverlay(
                    onDismiss: { viewModel.scheduleDraft = nil }
                ) { availableSize, dismiss in
                    TeamScheduleEditor(
                        viewModel: viewModel,
                        draft: draft,
                        maximumHeight: availableSize.height,
                        dismiss: dismiss
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $teamCreationPresented) {
            DPModalOverlay(
                onDismiss: { teamCreationPresented = false },
                canDismiss: !teamCreationViewModel.isCreating && !teamCreationFinishing
            ) { availableSize, dismiss in
                TeamCreationView(
                    viewModel: teamCreationViewModel,
                    maximumHeight: availableSize.height,
                    isFinishing: $teamCreationFinishing,
                    dismiss: dismiss
                ) { createdTeam in
                    viewModel.applyCreatedTeam(createdTeam)
                    _ = await session.refreshCurrentMember(fallbackTeam: createdTeam)
                    await viewModel.load(
                        memberID: memberID,
                        emitErrorFeedback: false
                    )
                    pendingTeamManagementDestination = createdTeam.id
                }
            }
            .interactiveDismissDisabled(teamCreationViewModel.isCreating || teamCreationFinishing)
        }
        .sheet(isPresented: $monthPickerPresented) {
            DPYearMonthPicker(
                selectedYear: viewModel.year,
                selectedMonth: viewModel.month,
                title: Text("team.view.calendar.chooseMonth", tableName: "Team"),
                previousYearLabel: Text("team.view.calendar.previousYear", tableName: "Team"),
                nextYearLabel: Text("team.view.calendar.nextYear", tableName: "Team"),
                currentMonthTitle: Text("team.view.calendar.thisMonth", tableName: "Team"),
                cancelTitle: teamLocalized("team.common.cancel"),
                identifierPrefix: "team.calendar.monthPicker",
                onSelect: { year, month in
                    monthPickerPresented = false
                    Task { await viewModel.goTo(year: year, month: month) }
                },
                onCurrentMonth: {
                    monthPickerPresented = false
                    Task { await viewModel.goToToday() }
                }
            )
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { scheduleDeletionCandidate != nil },
                set: {
                    if !$0, TeamScheduleDeleteConfirmationPolicy.canDismiss(
                        isDeleting: scheduleDeletionIsWorking
                    ) {
                        clearScheduleDeletion()
                    }
                }
            )
        ) {
            if let scheduleDeletionCandidate {
                DPModalOverlay(
                    maximumContentWidth: DPConfirmationPanel.maximumWidth,
                    onDismiss: {
                        guard TeamScheduleDeleteConfirmationPolicy.canDismiss(
                            isDeleting: scheduleDeletionIsWorking
                        ) else { return }
                        clearScheduleDeletion()
                    },
                    canDismiss: TeamScheduleDeleteConfirmationPolicy.canDismiss(
                        isDeleting: scheduleDeletionIsWorking
                    ),
                    dismissHaptic: nil
                ) { availableSize, dismiss in
                    DPConfirmationPanel(
                        title: teamLocalized("team.view.actions.deleteSchedule"),
                        message: TeamLocalization.scheduleDeletionMessage(
                            title: scheduleDeletionCandidate.content
                        ),
                        confirmTitle: teamLocalized("team.common.delete"),
                        cancelTitle: teamLocalized("team.common.cancel"),
                        isDestructive: true,
                        isWorking: scheduleDeletionIsWorking,
                        maximumHeight: availableSize.height,
                        cancel: {
                            guard TeamScheduleDeleteConfirmationPolicy.canDismiss(
                                isDeleting: scheduleDeletionIsWorking
                            ) else { return }
                            dismiss()
                        },
                        confirm: {
                            deleteSchedule(dismiss: dismiss)
                        }
                    )
                    .alert(
                        Text("team.common.error", tableName: "Team"),
                        isPresented: $viewModel.showsError
                    ) {
                        Button(teamLocalized("team.common.confirm"), role: .cancel) {}
                    } message: {
                        Text(viewModel.errorMessage ?? teamLocalized("team.common.error"))
                    }
                }
                .interactiveDismissDisabled(scheduleDeletionIsWorking)
            }
        }
    }

    private func teamContent(_ team: TeamDTO) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: DPSpacing.compact) {
                    calendar
                    selectedSchedules
                    shiftList
                }
                .padding(.horizontal, DPSpacing.small)
                .padding(.top, DPSpacing.medium + Self.thisMonthCalloutClearance)
                .padding(.bottom, DPSpacing.medium)
            }

            thisMonthCalloutLayer
                .offset(y: DPThisMonthCallout.verticalOffset)
                .alignmentGuide(HorizontalAlignment.center) { _ in DPThisMonthCallout.tailCenter }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isCurrentMonth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .modifier(TeamTopScrollEdgeEffectModifier())
        .background(DPColor.backgroundPrimary)
        .toolbar { teamToolbar(team) }
    }

    // The calendar starts right below the bar, where Calendar has its legend row, so the
    // callout would cover the weekday row. The room stays open in every month so the
    // calendar does not jump when the callout appears.
    private static let thisMonthCalloutClearance: CGFloat = 10

    // Hosted by the body rather than the navigation-bar item, as on Calendar, so the bar
    // keeps its native height.
    @ViewBuilder
    private var thisMonthCalloutLayer: some View {
        if !isCurrentMonth {
            DPThisMonthCallout(label: teamLocalized("team.view.calendar.thisMonth")) {
                Task { await viewModel.goToToday() }
            }
            .disabled(viewModel.isLoading || isSlidingMonth)
            .transition(.offset(y: -4).combined(with: .opacity))
        }
    }

    // Caps the leading team chip. The side items otherwise keep their natural widths so the
    // principal month capsule gets every point the bar can spare; it ignores touches past the
    // room the bar gives it. The bar centres the capsule when it fits.
    private static let barSideWidth: CGFloat = 88

    @ToolbarContentBuilder
    private func teamToolbar(_ team: TeamDTO) -> some ToolbarContent {
        DPDashboardHeaderToolbarItem(placement: .topBarLeading) {
            // Reports its ideal width up to the cap; the bar otherwise squeezes the chip to
            // centre the capsule and hides the team name.
            teamNameChip(team)
                .frame(maxWidth: Self.barSideWidth, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
        }
        DPDashboardHeaderToolbarItem(placement: .principal) {
            monthHeader
        }
        DPDashboardHeaderToolbarItem(placement: .topBarTrailing) {
            if viewModel.isTeamManager {
                manageControl(team)
            }
        }
    }

    private func teamNameChip(_ team: TeamDTO) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "building.2")
                .font(.system(size: 14))
            Text(verbatim: team.name)
                .font(DPTypography.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(DPColor.textPrimary)
        .padding(.horizontal, DPSpacing.small)
        .frame(minHeight: 32)
        .background(DPColor.backgroundTertiary)
        .clipShape(Capsule())
        .overlay { Capsule().stroke(DPColor.borderSecondary) }
        .accessibilityElement(children: .combine)
    }

    private func manageControl(_ team: TeamDTO) -> some View {
        NavigationLink {
            teamManagementView(teamID: team.id)
        } label: {
            Image(systemName: "gearshape")
                .frame(width: 36, height: DPSize.minimumTouchTarget)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                DPHapticCenter.shared.emit(.routine)
            }
        )
        .accessibilityLabel(Text("team.view.actions.manage", tableName: "Team"))
    }

    private func teamManagementView(teamID: TeamID) -> some View {
        TeamManageView(
            teamID: teamID,
            onTeamChanged: { viewModel.applyManagedTeam($0) },
            onDutyBatchChanged: { year, month in
                Task {
                    await viewModel.refreshDutiesAfterBatch(year: year, month: month)
                }
            }
        )
    }

    private var monthHeader: some View {
        DPMonthCapsule(
            yearMonth: "\(viewModel.year)-\(String(format: "%02d", locale: AppLocalization.locale, viewModel.month))",
            monthFontSize: DPMonthCapsuleMetrics.compactMonthFontSize,
            monthAccessibilityLabel: teamLocalized("team.view.calendar.chooseMonth"),
            monthIdentifier: "team.calendar.month.display",
            previous: DPMonthCapsuleArrow(
                label: teamLocalized("team.view.calendar.previousMonth"),
                identifier: "team.calendar.month.previous"
            ) {
                Task { await viewModel.previousMonth() }
            },
            next: DPMonthCapsuleArrow(
                label: teamLocalized("team.view.calendar.nextMonth"),
                identifier: "team.calendar.month.next"
            ) {
                Task { await viewModel.nextMonth() }
            }
        ) {
            monthPickerPresented = true
        }
        .disabled(viewModel.isLoading || isSlidingMonth)
    }

    private var isCurrentMonth: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        return now.year == viewModel.year && now.month == viewModel.month
    }

    private var currentMonthPage: TeamCalendarMonthPage {
        TeamCalendarMonthPage(
            key: viewModel.calendarMonth,
            days: viewModel.days,
            duties: viewModel.duties,
            holidays: viewModel.holidays,
            schedules: viewModel.schedules,
            selectedDay: viewModel.selectedDay,
            visibleIndices: viewModel.calendarVisibleRange
        )
    }

    private var calendar: some View {
        let gutter = DPCalendarCellStyle.gutterWidth
        let columns = Array(repeating: GridItem(.flexible(), spacing: gutter), count: 7)
        let todayIndex = DPCalendarCellStyle.todayWeekdayIndex(
            year: viewModel.calendarMonth.year,
            month: viewModel.calendarMonth.month,
            today: Date(),
            calendar: CalendarDateSupport.calendar
        )
        // The weekday header and the day cells are indexed from zero, so sharing one
        // grid makes the first week collide with the header row in the grid's
        // identity space and render blank. Two grids keep the identities apart.
        return VStack(spacing: gutter) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(TeamLocalization.shortStandaloneWeekdaySymbols().enumerated()), id: \.offset) { index, weekday in
                    DPCalendarWeekdayHeaderCell(label: weekday, weekdayIndex: index, isToday: index == todayIndex)
                }
            }
            monthBodyPager
        }
        .background(DPCalendarCellStyle.gutterColor)
        .clipShape(RoundedRectangle(cornerRadius: DPCalendarCellStyle.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: DPCalendarCellStyle.cornerRadius)
                .stroke(DPCalendarCellStyle.gutterColor, lineWidth: 1)
        }
    }

    private var monthBodyPager: some View {
        Group {
            if let transition = monthTransition {
                CalendarMonthPageTrack(
                    pages: transition.pages,
                    width: calendarWidth,
                    height: transition.viewport.height,
                    offset: monthTrackOffset
                ) { page, index in
                    calendarMonthBody(page, isInteractive: index == 1)
                }
            } else {
                calendarMonthBody(currentMonthPage, isInteractive: true)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onPreferenceChange(TeamCalendarMonthHeights.self) { heights in
            if monthTransition == nil, let height = heights[viewModel.calendarMonth], height > 0 {
                calendarBodyHeight = height
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { calendarWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, width in calendarWidth = width }
            }
        }
        .background(DPCalendarCellStyle.gutterColor)
        .clipped()
        .dpHorizontalPan(
            onChanged: followMonthSwipe,
            onEnded: finishMonthSwipe,
            onCancelled: cancelMonthSwipe
        )
    }

    private func calendarMonthBody(_ page: TeamCalendarMonthPage, isInteractive: Bool) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DPCalendarCellStyle.gutterWidth), count: 7),
            spacing: DPCalendarCellStyle.gutterWidth
        ) {
                ForEach(Array(page.visibleIndices), id: \.self) { index in
                    let day = page.days[index]
                    TeamCalendarDayCell(
                        day: day,
                        currentMonth: page.key.month,
                        duty: page.duties.first { $0.year == day.year && $0.month == day.month && $0.day == day.day },
                        holidays: page.holidays.indices.contains(index)
                            ? page.holidays[index]
                            : [],
                        schedules: page.schedules.indices.contains(index)
                            ? page.schedules[index]
                            : [],
                        weekdayIndex: index % 7,
                        isSelected: day == page.selectedDay
                    ) {
                        guard !isSwipingMonth, !isSlidingMonth, !viewModel.isLoading else { return }
                        Task { await viewModel.selectDay(at: index) }
                    }
                }
        }
        .background(DPCalendarCellStyle.gutterColor)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: TeamCalendarMonthHeights.self, value: [page.key: proxy.size.height])
            }
        }
        .allowsHitTesting(isInteractive && !viewModel.isLoading && !isSlidingMonth)
        .accessibilityHidden(!isInteractive)
    }

    private func loadMonthPreviews() async {
        previewPages = [:]
        let revision = viewModel.calendarPreviewRevision
        let source = viewModel.calendarMonth
        await withTaskGroup(of: TeamCalendarMonthPage?.self) { group in
            for offset in [-1, 1] {
                let key = source.offsetByMonths(offset)
                group.addTask { await viewModel.monthPreview(for: key) }
            }
            for await page in group {
                guard !Task.isCancelled,
                      revision == viewModel.calendarPreviewRevision,
                      let page else { continue }
                previewPages[page.key] = page
                if var transition = monthTransition,
                   transition.pages[1].key == source,
                   let index = transition.pages.firstIndex(where: { $0.key == page.key }) {
                    transition.pages[index] = page
                    withTransaction(Transaction(animation: nil)) { monthTransition = transition }
                }
            }
        }
    }

    private func placeholderMonthPage(_ key: OfflineMonthKey) -> TeamCalendarMonthPage {
        if let page = previewPages[key] { return page }
        let cells = CalendarDateSupport.placeholderCells(year: key.year, month: key.month)
        return TeamCalendarMonthPage(
            key: key,
            days: cells.map {
                TeamDayDTO(year: $0.year, month: $0.month, day: $0.day)
            },
            duties: [], holidays: [], schedules: [], selectedDay: nil,
            visibleIndices: CalendarDateSupport.displayedCellRange(in: cells)
        )
    }

    private func followMonthSwipe(_ translation: CGSize) {
        guard !isSlidingMonth, !viewModel.isLoading, calendarWidth > 0 else { return }
        if monthTransition == nil {
            let page = currentMonthPage
            guard page.days.count == 42,
                  page.key == OfflineMonthKey(year: viewModel.year, month: viewModel.month)
            else { return }
            let transition = TeamCalendarMonthTransition(
                pages: [placeholderMonthPage(page.key.offsetByMonths(-1)), page, placeholderMonthPage(page.key.offsetByMonths(1))],
                viewport: CalendarMonthBodyViewport(sourceHeight: max(
                    calendarBodyHeight, CGFloat(page.visibleIndices.count / 7) * 60
                ))
            )
            withTransaction(Transaction(animation: nil)) {
                monthTransition = transition
                monthTrackOffset = CalendarMonthSwipe.trackOffset(width: calendarWidth, drag: 0)
            }
        }
        let drag = CalendarMonthSwipe.followOffset(translation: translation, viewportWidth: calendarWidth)
        monthTrackOffset = CalendarMonthSwipe.trackOffset(width: calendarWidth, drag: drag)
        if drag != 0 { isSwipingMonth = true }
    }

    private func finishMonthSwipe(_ translation: CGSize, velocity: CGSize) {
        guard !isSlidingMonth else { return }
        let offset = CalendarMonthSwipe.monthOffset(translation: translation, velocity: velocity, viewportWidth: calendarWidth)
        guard offset != 0, let transition = monthTransition else {
            settleMonthSwipe()
            return
        }
        isSlidingMonth = true
        let width = calendarWidth
        withAnimation(reduceMotion ? nil : .easeOut(duration: CalendarMonthSwipe.slideOutDuration)) {
            monthTrackOffset = CalendarMonthSwipe.settledTrackOffset(width: width, monthOffset: offset)
        }
        monthSlideTask?.cancel()
        monthSlideTask = Task {
            if !reduceMotion { try? await Task.sleep(for: .seconds(CalendarMonthSwipe.slideOutDuration)) }
            guard !Task.isCancelled, monthTransition?.id == transition.id else { return }
            if offset > 0 { await viewModel.nextMonth() }
            else { await viewModel.previousMonth() }
            guard !Task.isCancelled, monthTransition?.id == transition.id else { return }
            let destination = transition.pages[1].key.offsetByMonths(offset)
            if !viewModel.loadFailed, viewModel.calendarMonth == destination {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: CalendarMonthSwipe.slideInDuration)) {
                    resetMonthTransition()
                }
            } else {
                await returnMonthSwipeToCenter(width: width)
            }
        }
    }

    private func cancelMonthSwipe(_ translation: CGSize) {
        guard !isSlidingMonth else { return }
        settleMonthSwipe()
    }

    private func settleMonthSwipe() {
        guard monthTransition != nil else { isSwipingMonth = false; return }
        isSlidingMonth = true
        monthSlideTask?.cancel()
        monthSlideTask = Task { await returnMonthSwipeToCenter(width: calendarWidth) }
    }

    private func returnMonthSwipeToCenter(width: CGFloat) async {
        withAnimation(reduceMotion ? nil : .easeOut(duration: CalendarMonthSwipe.slideInDuration)) {
            monthTrackOffset = CalendarMonthSwipe.trackOffset(width: width, drag: 0)
        }
        if !reduceMotion { try? await Task.sleep(for: .seconds(CalendarMonthSwipe.slideInDuration)) }
        guard !Task.isCancelled else { return }
        withTransaction(Transaction(animation: nil)) { resetMonthTransition() }
    }

    private func resetMonthTransition() {
        monthTransition = nil
        monthTrackOffset = 0
        isSwipingMonth = false
        isSlidingMonth = false
    }

    private var selectedSchedules: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            VStack(alignment: .leading, spacing: DPSpacing.small) {
                HStack {
                    if let day = viewModel.selectedDay {
                        Text(
                            String(
                                format: teamLocalized("team.view.selectedDate"),
                                locale: AppLocalization.locale,
                                teamSelectedDate(day)
                            )
                        )
                        .font(DPTypography.heading)
                    }
                    Spacer()
                }
                if viewModel.isTeamManager {
                    Button {
                        guard viewModel.selectedDay != nil else { return }
                        viewModel.newSchedule()
                    } label: {
                        Label {
                            Text("team.view.actions.addSchedule", tableName: "Team")
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                    .buttonStyle(DPSuccessButtonStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(viewModel.isWorking)
                }
            }

            if viewModel.selectedSchedules.isEmpty {
                Text("team.view.schedule.empty", tableName: "Team")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
            } else {
                ForEach(viewModel.selectedSchedules, id: \.id) { schedule in
                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: schedule.content).font(DPTypography.bodyMedium)
                                Text(
                                    String(
                                        format: teamLocalized("team.view.schedule.createdBy"),
                                        locale: AppLocalization.locale,
                                        schedule.createMember
                                    )
                                )
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.textSecondary)
                                if !schedule.description.isEmpty {
                                    Text(verbatim: schedule.description)
                                        .font(DPTypography.supporting)
                                        .foregroundStyle(DPColor.textSecondary)
                                }
                                Text(verbatim: teamScheduleDateRange(schedule))
                                    .font(DPTypography.caption)
                                    .foregroundStyle(DPColor.textMuted)
                            }
                            Spacer()
                            if viewModel.isTeamManager {
                                HStack(spacing: 0) {
                                    DPIconActionButton(
                                        systemImage: "pencil",
                                        label: teamLocalized("team.view.actions.editSchedule"),
                                        tone: .accent
                                    ) {
                                        viewModel.editSchedule(schedule)
                                    }
                                    DPIconActionButton(
                                        systemImage: "trash",
                                        label: teamLocalized("team.view.actions.deleteSchedule"),
                                        tone: .danger
                                    ) {
                                        viewModel.schedulePendingDeletion = schedule
                                        scheduleDeletionCandidate = schedule
                                    }
                                }
                                .padding(.top, -DPIconActionMetrics.touchPadding)
                                .padding(.trailing, -DPIconActionMetrics.touchPadding)
                            }
                        }
                    }
                    .padding(DPSpacing.small)
                    .background(DPColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                    .overlay { RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary) }
                }
            }
        }
        .padding(DPSpacing.medium)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay { RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary) }
    }

    private func deleteSchedule(dismiss: @escaping () -> Void) {
        guard TeamScheduleDeleteConfirmationPolicy.canSubmit(
            isDeleting: scheduleDeletionIsWorking
        ) else { return }

        scheduleDeletionIsWorking = true
        Task {
            await viewModel.deleteSchedule()
            scheduleDeletionIsWorking = false
            if viewModel.schedulePendingDeletion == nil {
                dismiss()
            }
        }
    }

    private func clearScheduleDeletion() {
        scheduleDeletionCandidate = nil
        viewModel.schedulePendingDeletion = nil
    }

    private var shiftList: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            ForEach(Array(viewModel.shifts.enumerated()), id: \.offset) { _, shift in
                VStack(alignment: .leading, spacing: 0) {
                    TeamDutyTypeBadge(
                        name: shift.dutyType.name,
                        color: shift.dutyType.color,
                        memberCount: shift.members.count
                    )

                    let memberColumns = Array(repeating: GridItem(.flexible(), spacing: DPSpacing.small), count: 2)
                    LazyVGrid(columns: memberColumns, spacing: DPSpacing.small) {
                        ForEach(Array(shift.members.enumerated()), id: \.offset) { _, member in
                            Group {
                                if let id = member.id {
                                    Button {
                                        DPHapticCenter.shared.emit(.routine)
                                        onOpenCalendar(id)
                                    } label: { memberCard(member) }
                                        .buttonStyle(.plain)
                                } else {
                                    memberCard(member)
                                }
                            }
                        }
                    }
                    .padding(DPSpacing.compact)
                }
                .background(DPColor.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.standard)
                        .stroke(
                            TeamFeatureLogic.isMyShiftGroup(shift, memberID: memberID)
                                ? DPColor.textPrimary
                                : DPColor.borderSecondary,
                            lineWidth: TeamFeatureLogic.isMyShiftGroup(shift, memberID: memberID) ? 2 : 1
                        )
                }
            }
        }
    }

    private func memberCard(_ member: MemberPreviewDTO) -> some View {
        VStack(spacing: DPSpacing.extraSmall) {
            TeamMemberAvatar(member: member, size: 28)
            Text(verbatim: member.name)
                .font(DPTypography.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .padding(DPSpacing.small)
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(DPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(member.id == memberID ? DPColor.textPrimary : DPColor.borderSecondary, lineWidth: member.id == memberID ? 2 : 1)
        }
    }
}

private struct TeamMemberAvatar: View {
    let member: MemberPreviewDTO
    let size: CGFloat

    var body: some View {
        DPProfileAvatar(
            memberID: member.id,
            hasProfilePhoto: member.hasProfilePhoto,
            profilePhotoVersion: member.profilePhotoVersion,
            size: size
        )
        .accessibilityHidden(true)
    }
}

nonisolated enum TeamCalendarCellSchedules {
    // Multi-day schedules lead the cell, matching the personal calendar.
    static func ordered(_ schedules: [TeamScheduleDTO]) -> [TeamScheduleDTO] {
        DPCalendarSpan.orderedForCell(schedules, daysFromStart: \.daysFromStart, totalDays: \.totalDays)
    }
}

private struct TeamCalendarDayCell: View {
    let day: TeamDayDTO
    let currentMonth: Int
    let duty: DutyDTO?
    let holidays: [HolidayDTO]
    let schedules: [TeamScheduleDTO]
    let weekdayIndex: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DPCalendarDayTile(
                day: day.day,
                weekdayIndex: weekdayIndex,
                dutyColor: dutyColor,
                isCurrentMonth: isCurrentMonth,
                isToday: isToday,
                hasHoliday: !holidays.isEmpty,
                highlight: isSelected ? DPColor.accent : nil
            ) {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(holidays.enumerated()), id: \.offset) { _, holiday in
                        Text(verbatim: holiday.dateName)
                            .font(DPFont.light(size: 10, relativeTo: .caption2))
                            .foregroundStyle(holiday.isHoliday
                                ? DPCalendarCellStyle.holidayForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
                                : mutedInk)
                            .lineLimit(1)
                    }
                    // Every schedule is drawn; the tile grows instead of hiding any behind a count.
                    ForEach(Array(TeamCalendarCellSchedules.ordered(schedules).enumerated()), id: \.offset) { index, schedule in
                        let span = DPCalendarSpan(daysFromStart: schedule.daysFromStart, totalDays: schedule.totalDays)
                        DPCalendarItemRow(showsRule: index > 0, rule: rule, span: span, spanColor: ink) {
                            DPCalendarScheduleTitle.text(
                                Text(verbatim: schedule.content),
                                daysFromStart: schedule.daysFromStart,
                                totalDays: schedule.totalDays,
                                counterColor: mutedInk
                            )
                            .font(DPFont.light(size: 10, relativeTo: .caption2))
                            .tracking(-0.3)
                            .foregroundStyle(ink)
                            .lineLimit(2)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(day.year)-\(day.month)-\(day.day)"))
    }

    private var isToday: Bool {
        let today = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: Date())
        return today.year == day.year && today.month == day.month && today.day == day.day
    }

    private var dutyColor: String? { duty?.dutyColor }
    private var isCurrentMonth: Bool { day.month == currentMonth }
    private var ink: Color {
        DPCalendarCellStyle.primaryForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
    }
    private var mutedInk: Color {
        DPCalendarCellStyle.secondaryForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
    }
    private var rule: Color {
        DPCalendarCellStyle.ruleColor(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
    }
}

private enum TeamScheduleField: Hashable {
    case content
    case description
}

private struct TeamScheduleEditor: View {
    @ObservedObject var viewModel: TeamViewModel
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    @State private var draft: TeamScheduleDraft
    @FocusState private var focusedField: TeamScheduleField?

    init(
        viewModel: TeamViewModel,
        draft: TeamScheduleDraft,
        maximumHeight: CGFloat,
        dismiss: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.maximumHeight = maximumHeight
        self.dismiss = dismiss
        _draft = State(initialValue: draft)
    }

    var body: some View {
        DPModalPanel(
            maximumPanelHeight: maximumHeight,
            scrollTarget: focusedField
        ) {
            editorHeader
        } content: {
            editorForm
        } footer: {
            editorFooter
        }
    }

    private var editorHeader: some View {
        HStack {
            Text("team.view.schedule.modal.title", tableName: "Team")
                .font(DPTypography.bodyMedium)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DPSpacing.medium)
        .padding(.vertical, DPSpacing.small)
        .background(DPColor.backgroundTertiary)
    }

    private var editorForm: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                HStack {
                    Text("team.view.schedule.form.contentLabel", tableName: "Team").font(DPTypography.label)
                    Spacer()
                    Text(verbatim: "\(draft.content.count)/50").font(DPTypography.caption).foregroundStyle(DPColor.textMuted)
                }
                TextField(
                    teamLocalized("team.view.schedule.form.contentPlaceholder"),
                    text: $draft.content
                )
                .focused($focusedField, equals: .content)
                .dpInputChrome(isInvalid: draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .onChange(of: draft.content) { _, value in
                    if value.count > 50 { draft.content = String(value.prefix(50)) }
                }
            }
            .id(TeamScheduleField.content)
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                Text("team.view.schedule.form.descriptionLabel", tableName: "Team").font(DPTypography.label)
                TextField(
                    teamLocalized("team.view.schedule.form.descriptionPlaceholder"),
                    text: $draft.description,
                    axis: .vertical
                )
                .lineLimit(4...8)
                .focused($focusedField, equals: .description)
                .dpInputChrome()
            }
            .id(TeamScheduleField.description)
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                DatePicker(selection: $draft.startDate, displayedComponents: .date) {
                    Text("team.view.schedule.form.startDate", tableName: "Team")
                }
                .frame(minHeight: DPSize.minimumTouchTarget)
                .onChange(of: draft.startDate) { oldValue, newValue in
                    if oldValue != newValue {
                        DPHapticCenter.shared.emit(.selection)
                    }
                }
                DatePicker(
                    selection: $draft.endDate,
                    in: draft.startDate...,
                    displayedComponents: .date
                ) {
                    Text("team.view.schedule.form.endDate", tableName: "Team")
                }
                .frame(minHeight: DPSize.minimumTouchTarget)
                .onChange(of: draft.endDate) { oldValue, newValue in
                    if oldValue != newValue {
                        DPHapticCenter.shared.emit(.selection)
                    }
                }
            }
        }
        .padding(DPSpacing.medium)
    }

    private var editorFooter: some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                dismiss()
            } label: {
                Text(verbatim: teamLocalized("team.common.close"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPSecondaryButtonStyle())
            Button {
                Task { await viewModel.saveSchedule(draft) }
            } label: {
                Text(verbatim: teamLocalized("team.common.save"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(!draft.isValid || viewModel.isWorking)
        }
        .padding(DPSpacing.compact)
    }
}

private struct TeamCreationView: View {
    private enum Field: Hashable {
        case name
        case description
    }

    @ObservedObject private var viewModel: TeamCreationViewModel
    @State private var name = ""
    @State private var description = ""
    @Binding private var isFinishing: Bool
    @FocusState private var focusedField: Field?

    let maximumHeight: CGFloat
    let dismiss: () -> Void
    let didCreate: @MainActor (TeamDTO) async -> Void

    init(
        viewModel: TeamCreationViewModel,
        maximumHeight: CGFloat,
        isFinishing: Binding<Bool>,
        dismiss: @escaping () -> Void,
        didCreate: @escaping @MainActor (TeamDTO) async -> Void
    ) {
        self.viewModel = viewModel
        self.maximumHeight = maximumHeight
        self._isFinishing = isFinishing
        self.dismiss = dismiss
        self.didCreate = didCreate
    }

    private var normalizedName: String {
        TeamCreationLogic.normalizedName(name)
    }

    private var normalizedDescription: String {
        TeamCreationLogic.normalizedDescription(description)
    }

    private var isNameCheckedForCurrentValue: Bool {
        viewModel.checkedName == normalizedName
    }

    private var canCheckName: Bool {
        TeamCreationLogic.isValidName(normalizedName)
            && !viewModel.isChecking
            && !viewModel.isCreating
            && !isFinishing
    }

    private var canCreate: Bool {
        TeamCreationLogic.isValidName(normalizedName)
            && TeamCreationLogic.isValidDescription(normalizedDescription)
            && isNameCheckedForCurrentValue
            && viewModel.nameCheckResult == .ok
            && !viewModel.isChecking
            && !viewModel.isCreating
            && !isFinishing
    }

    var body: some View {
        DPModalPanel(
            maximumPanelHeight: min(maximumHeight * 0.8, 620),
            scrollTarget: focusedField
        ) {
            header
        } content: {
            form
        } footer: {
            footer
        }
        .accessibilityIdentifier("team.create.form")
    }

    private var header: some View {
        HStack {
            Text("team.create.title", tableName: "Team")
                .font(DPTypography.bodyMedium)
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isCreating || isFinishing)
            .accessibilityLabel(Text("team.create.cancel", tableName: "Team"))
        }
        .padding(.horizontal, DPSpacing.medium)
        .padding(.vertical, DPSpacing.small)
        .background(DPColor.backgroundTertiary)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                HStack(alignment: .firstTextBaseline) {
                    Text("team.create.name", tableName: "Team")
                        .font(DPTypography.label)
                    Spacer()
                    Text("team.create.nameLength", tableName: "Team")
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textMuted)
                }
                HStack(spacing: DPSpacing.extraSmall) {
                    TextField(
                        teamLocalized("team.create.namePlaceholder"),
                        text: $name
                    )
                    .focused($focusedField, equals: .name)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .dpInputChrome(
                        isFocused: focusedField == .name,
                        isInvalid: !name.isEmpty && !TeamCreationLogic.isValidName(normalizedName),
                        isDisabled: viewModel.isCreating || isFinishing
                    )
                    .disabled(viewModel.isCreating || isFinishing)
                    .onChange(of: name) { _, value in
                        if value.count > TeamCreationLogic.maximumNameLength {
                            name = String(value.prefix(TeamCreationLogic.maximumNameLength))
                        }
                        viewModel.invalidateNameCheck()
                    }

                    Button {
                        Task { await viewModel.checkName(name) }
                    } label: {
                        if viewModel.isChecking {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("team.create.checkName", tableName: "Team")
                        }
                    }
                    .buttonStyle(DPSecondaryButtonStyle())
                    .disabled(!canCheckName)
                    .accessibilityIdentifier("team.create.checkName")
                }
                .id(Field.name)

                if isNameCheckedForCurrentValue {
                    nameCheckMessage
                }
            }

            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                HStack(alignment: .firstTextBaseline) {
                    Text("team.create.description", tableName: "Team")
                        .font(DPTypography.label)
                    Spacer()
                    Text(verbatim: "\(description.count)/\(TeamCreationLogic.maximumDescriptionLength)")
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textMuted)
                }
                TextEditor(text: $description)
                    .frame(minHeight: 88)
                    .focused($focusedField, equals: .description)
                    .dpInputChrome(
                        isFocused: focusedField == .description,
                        isInvalid: description.count > TeamCreationLogic.maximumDescriptionLength,
                        isDisabled: viewModel.isCreating || isFinishing
                    )
                    .disabled(viewModel.isCreating || isFinishing)
                    .overlay(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("team.create.descriptionPlaceholder", tableName: "Team")
                                .font(DPTypography.body)
                                .foregroundStyle(DPColor.textMuted)
                                .padding(.horizontal, DPChrome.inputHorizontalPadding)
                                .padding(.vertical, DPChrome.inputVerticalPadding)
                                .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: description) { _, value in
                        if value.count > TeamCreationLogic.maximumDescriptionLength {
                            description = String(value.prefix(TeamCreationLogic.maximumDescriptionLength))
                        }
                    }
                .id(Field.description)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(verbatim: errorMessage)
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DPSpacing.medium)
    }

    @ViewBuilder
    private var nameCheckMessage: some View {
        switch viewModel.nameCheckResult {
        case .ok:
            Text("team.create.nameAvailable", tableName: "Team")
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.success)
        case .duplicated:
            Text("team.create.nameDuplicated", tableName: "Team")
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.danger)
        case .tooShort:
            Text("team.create.nameTooShort", tableName: "Team")
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.warning)
        case .tooLong:
            Text("team.create.nameTooLong", tableName: "Team")
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.warning)
        case nil:
            EmptyView()
        }
    }

    private var footer: some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                dismiss()
            } label: {
                Text("team.create.cancel", tableName: "Team")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPSecondaryButtonStyle())
            .disabled(viewModel.isCreating || isFinishing)

            Button {
                guard !isFinishing else { return }
                isFinishing = true
                Task {
                    guard let createdTeam = await viewModel.createTeam(
                        name: name,
                        description: description
                    ) else {
                        isFinishing = false
                        return
                    }
                    await didCreate(createdTeam)
                    dismiss()
                }
            } label: {
                Group {
                    if viewModel.isCreating {
                        ProgressView()
                            .tint(DPColor.textOnDark)
                    } else {
                        Text("team.create.submit", tableName: "Team")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(!canCreate)
            .accessibilityIdentifier("team.create.submit")
        }
        .padding(DPSpacing.compact)
    }
}

nonisolated enum TeamVisualStyle {
    static func foregroundColor(on hex: String?) -> Color {
        isLightColor(hex) ? DPColor.textOnLight : DPColor.textOnDark
    }

    static func isLightColor(_ hex: String?) -> Bool {
        guard let hex else { return false }
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let number = UInt64(value, radix: 16) else { return false }
        let red = Double((number >> 16) & 0xff) / 255
        let green = Double((number >> 8) & 0xff) / 255
        let blue = Double(number & 0xff) / 255
        return (red * 0.299 + green * 0.587 + blue * 0.114) > 0.64
    }
}

nonisolated struct TeamDutyTypeBadge: View {
    let name: String
    let color: String?
    let memberCount: Int?

    var body: some View {
        HStack {
            Text(verbatim: name)
                .font(DPTypography.bodyMedium)
                .foregroundStyle(TeamVisualStyle.foregroundColor(on: color))
            Spacer()
            if let memberCount {
                Text(verbatim: TeamLocalization.shiftMemberCount(memberCount))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textOnLight)
                    .padding(.horizontal, DPSpacing.small)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.65))
                    .clipShape(Capsule())
                    .accessibilityIdentifier("team.shift.memberCount")
            }
        }
        .padding(DPSpacing.compact)
        .background(Color(teamHex: color))
    }
}

private func teamSelectedDate(_ day: TeamDayDTO) -> String {
    let components = DateComponents(year: day.year, month: day.month, day: day.day)
    guard let date = Calendar.current.date(from: components) else {
        return "\(day.year)-\(day.month)-\(day.day)"
    }
    let formatter = DateFormatter()
    formatter.locale = AppLocalization.locale
    formatter.setLocalizedDateFormatFromTemplate("yMMMd")
    return formatter.string(from: date)
}

private func teamScheduleDateRange(_ schedule: TeamScheduleDTO) -> String {
    let start = String(schedule.startDateTime.rawValue.prefix(10))
    let end = String(schedule.endDateTime.rawValue.prefix(10))
    return "\(start) – \(end)"
}

func teamLocalized(_ key: String, locale: Locale? = nil) -> String {
    AppLocalization.string(key, table: "Team", locale: locale)
}

nonisolated enum TeamLocalization {
    static func shortStandaloneWeekdaySymbols(locale: Locale? = nil) -> [String] {
        var calendar = Calendar.current
        calendar.locale = locale ?? AppLocalization.locale
        return calendar.shortStandaloneWeekdaySymbols
    }

    static func scheduleDeletionMessage(title: String, locale: Locale? = nil) -> String {
        AppLocalization.format(
            "team.view.schedule.deleteConfirm",
            table: "Team",
            arguments: [title],
            locale: locale
        )
    }

    static func shiftMemberCount(_ count: Int, locale: Locale? = nil) -> String {
        AppLocalization.format(
            "team.view.shift.memberCount",
            table: "Team",
            arguments: [Int64(count)],
            locale: locale
        )
    }
}

nonisolated enum TeamScheduleDeleteConfirmationPolicy {
    static func canSubmit(isDeleting: Bool) -> Bool {
        !isDeleting
    }

    static func canDismiss(isDeleting: Bool) -> Bool {
        !isDeleting
    }
}

extension Color {
    init(teamHex: String?) {
        guard let teamHex else {
            self = DPColor.accent
            return
        }
        let value = teamHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let number = UInt64(value, radix: 16) else {
            self = DPColor.accent
            return
        }
        self = Color(
            red: Double((number >> 16) & 0xff) / 255,
            green: Double((number >> 8) & 0xff) / 255,
            blue: Double(number & 0xff) / 255
        )
    }
}
