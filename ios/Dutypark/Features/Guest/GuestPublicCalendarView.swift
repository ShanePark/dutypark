import SwiftUI

nonisolated enum GuestPublicCalendarLink {
    static func url(memberID: MemberID) -> URL {
        URL(string: "https://dutypark.o-r.kr/duty/\(memberID)")!
    }
}

@MainActor
enum GuestReportLoginNavigation {
    static func prepare(memberID: MemberID, session: SessionStore) {
        session.deferDestinationUntilAuthenticated(
            GuestPublicCalendarLink.url(memberID: memberID)
        )
    }
}

enum GuestCalendarLocalization {
    static func yearMonth(
        year: Int,
        month: Int,
        template: String = GuestLocalization.text("guest.calendar.month.format")
    ) -> String {
        String(
            format: template,
            locale: Locale(identifier: "en_US_POSIX"),
            arguments: [year, month]
        )
    }
}

struct GuestPublicCalendarView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var model: GuestPublicCalendarViewModel
    @State private var showsMonthPicker = false
    @State private var showsReportLoginPrompt = false
    private let memberID: MemberID

    init(memberID: MemberID) {
        self.memberID = memberID
        _model = StateObject(wrappedValue: GuestPublicCalendarViewModel(
            memberID: memberID,
            api: GuestPublicCalendarAPIProvider.make(),
            now: GuestPublicCalendarAPIProvider.now()
        ))
    }

    var body: some View {
        Group {
            if model.isLoading && model.days.isEmpty {
                ProgressView(GuestLocalization.text("guest.calendar.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.hasError && model.days.isEmpty {
                VStack(spacing: DPSpacing.medium) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(DPColor.danger)
                    Text(GuestLocalization.text("guest.calendar.error.title"))
                        .font(DPFont.bold(size: 17, relativeTo: .headline))
                    Text(GuestLocalization.text("guest.calendar.error.message"))
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                        .multilineTextAlignment(.center)
                    Button(GuestLocalization.text("guest.retry")) {
                        Task { await retryLoad() }
                    }
                    .buttonStyle(DPPrimaryButtonStyle())
                }
                .padding(DPSpacing.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .background(DPColor.backgroundPrimary)
        .navigationTitle(model.member?.name ?? GuestLocalization.text("guest.calendar.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: publicURL) {
                    Label(
                        GuestLocalization.text("guest.calendar.share"),
                        systemImage: "square.and.arrow.up"
                    )
                }
                .accessibilityIdentifier("guest.calendar.share")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showsReportLoginPrompt = true
                    } label: {
                        Label(
                            GuestLocalization.text("guest.calendar.report"),
                            systemImage: "flag"
                        )
                    }
                    .accessibilityIdentifier("guest.calendar.report")
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel(GuestLocalization.text("guest.calendar.more"))
                .accessibilityIdentifier("guest.calendar.menu")
                .simultaneousGesture(TapGesture().onEnded {
                    DPHapticCenter.shared.emit(.selection)
                })
            }
        }
        .task { if model.days.isEmpty { await model.load() } }
        .refreshable { await retryLoad() }
        .sheet(isPresented: $showsMonthPicker) {
            DPYearMonthPicker(
                selectedYear: model.year,
                selectedMonth: model.month,
                title: Text(verbatim: GuestLocalization.text("guest.calendar.month.choose")),
                previousYearLabel: Text(
                    verbatim: GuestLocalization.text("guest.calendar.month.previousYear")
                ),
                nextYearLabel: Text(
                    verbatim: GuestLocalization.text("guest.calendar.month.nextYear")
                ),
                currentMonthTitle: Text(
                    verbatim: GuestLocalization.text("guest.calendar.month.current")
                ),
                cancelTitle: GuestLocalization.text("guest.close"),
                identifierPrefix: "guest.calendar.monthPicker",
                onSelect: { year, month in
                    showsMonthPicker = false
                    Task { await model.selectYearMonth(year: year, month: month) }
                },
                onCurrentMonth: {
                    showsMonthPicker = false
                    Task { await model.goToToday() }
                }
            )
        }
        .fullScreenCover(item: $model.selectedDay) { day in
            DPModalOverlay(
                onDismiss: { model.selectedDay = nil },
                closeOnBackdrop: false
            ) { availableSize, dismiss in
                GuestCalendarDayDetailView(
                    day: day,
                    maximumHeight: availableSize.height,
                    dismiss: dismiss
                )
            }
        }
        .alert(GuestLocalization.text("guest.calendar.error.title"), isPresented: Binding(
            get: { model.hasError && !model.days.isEmpty },
            set: { if !$0 { model.hasError = false } }
        )) {
            Button(GuestLocalization.text("guest.ok"), role: .cancel) {}
        } message: {
            Text("guest.calendar.error.message", tableName: "Guest")
        }
        // The prompt stays inside the navigation stack instead of a cover so its
        // confirm control can be a real `NavigationLink` to `GuestRoute.login`;
        // a covered link would have no stack to push onto.
        .overlay {
            if showsReportLoginPrompt {
                DPModalOverlay(
                    maximumContentWidth: DPConfirmationPanel.maximumWidth,
                    onDismiss: { showsReportLoginPrompt = false },
                    isHostedInline: true,
                    onDismissRequest: { _ in
                        showsReportLoginPrompt = false
                        DPHapticCenter.shared.emit(.routine)
                    },
                    dismissHaptic: nil
                ) { availableSize, dismissPrompt in
                    GuestReportLoginPrompt(
                        maximumHeight: availableSize.height,
                        cancel: dismissPrompt,
                        willNavigate: {
                            GuestReportLoginNavigation.prepare(memberID: memberID, session: session)
                            showsReportLoginPrompt = false
                        }
                    )
                }
            }
        }
    }

    private func retryLoad() async {
        await model.load()
        if model.hasError {
            DPHapticCenter.shared.emit(.error)
        }
    }

    private var publicURL: URL {
        GuestPublicCalendarLink.url(memberID: memberID)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: DPSpacing.medium) {
                if let member = model.member {
                    Label(member.name, systemImage: "person.crop.circle.fill")
                        .font(DPFont.bold(size: 17, relativeTo: .headline))
                        .foregroundStyle(DPColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget, alignment: .leading)
                        .padding(.horizontal, DPSpacing.medium)
                        .background(DPColor.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                        .overlay(
                            RoundedRectangle(cornerRadius: DPRadius.standard)
                                .stroke(DPColor.borderPrimary)
                        )
                }
                monthControls
                dutySummary
                calendarGrid
                dDaySection
            }
            .padding(.horizontal, DPSpacing.small)
            .padding(.bottom, DPSpacing.large)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.22),
                value: visibleCalendarDays.count
            )
        }
    }

    private var monthControls: some View {
        DPMonthCapsule(
            yearMonth: GuestCalendarLocalization.yearMonth(year: model.year, month: model.month),
            monthAccessibilityLabel: GuestLocalization.text("guest.calendar.month.choose"),
            monthIdentifier: "guest.calendar.monthPicker.open",
            previous: DPMonthCapsuleArrow(
                label: GuestLocalization.text("guest.calendar.month.previous"),
                identifier: "guest.calendar.month.previous"
            ) {
                Task { await model.changeMonth(by: -1) }
            },
            next: DPMonthCapsuleArrow(
                label: GuestLocalization.text("guest.calendar.month.next"),
                identifier: "guest.calendar.month.next"
            ) {
                Task { await model.changeMonth(by: 1) }
            }
        ) {
            DPHapticCenter.shared.emit(.selection)
            showsMonthPicker = true
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            Button(GuestLocalization.text("guest.calendar.today")) {
                Task { await model.goToToday() }
            }
            .font(DPFont.bold(size: 15, relativeTo: .subheadline))
            .foregroundStyle(DPColor.accent)
            .frame(minHeight: DPSize.minimumTouchTarget)
        }
        .disabled(model.isLoading)
    }

    private var dutySummary: some View {
        let counts = Dictionary(
            grouping: model.days.compactMap(\.duty).filter { $0.month == model.month },
            by: { $0.dutyType ?? GuestLocalization.text("guest.calendar.off") }
        )
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DPSpacing.medium) {
                ForEach(counts.keys.sorted(), id: \.self) { name in
                    HStack(spacing: DPSpacing.extraSmall) {
                        Circle()
                            .fill(guestColor(hex: counts[name]?.first?.dutyColor))
                            .frame(width: 10, height: 10)
                        Text(name).foregroundStyle(DPColor.textSecondary)
                        Text("\(counts[name]?.count ?? 0)")
                            .font(DPFont.bold(size: 12, relativeTo: .caption))
                            .foregroundStyle(DPColor.textPrimary)
                    }
                    .font(DPTypography.caption)
                }
            }
            .frame(minHeight: DPSize.minimumTouchTarget)
        }
    }

    private var visibleCalendarDays: [GuestCalendarDay] {
        let cells = model.days.map(\.cell)
        let visibleRange = CalendarDateSupport.displayedCellRange(in: cells)
        return Array(model.days[visibleRange])
    }

    private var displayedMonth: (year: Int, month: Int) {
        guard let cell = model.days.first(where: { $0.cell.isCurrentMonth })?.cell else {
            return (model.year, model.month)
        }
        return (cell.year, cell.month)
    }

    // The same flat, connected grid as the member calendar: the gutter colour shows
    // through the gaps between tiles.
    private var calendarGrid: some View {
        VStack(spacing: DPCalendarCellStyle.gutterWidth) {
            DPCalendarWeekdayRow(
                labels: ["sun", "mon", "tue", "wed", "thu", "fri", "sat"].map {
                    GuestLocalization.text("guest.calendar.weekday.\($0)")
                },
                todayIndex: DPCalendarCellStyle.todayWeekdayIndex(
                    year: displayedMonth.year,
                    month: displayedMonth.month,
                    today: Date(),
                    calendar: CalendarDateSupport.calendar
                )
            )
            CalendarMonthCellGrid(items: visibleCalendarDays) { index, day in
                GuestCalendarDayCell(day: day, weekday: index % 7)
                    .onTapGesture {
                        DPHapticCenter.shared.emit(.routine)
                        withoutPresentationAnimation { model.selectedDay = day }
                    }
            }
        }
        .background(DPCalendarCellStyle.gutterColor)
        .clipShape(RoundedRectangle(cornerRadius: DPCalendarCellStyle.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DPCalendarCellStyle.cornerRadius)
                .stroke(DPCalendarCellStyle.gutterColor, lineWidth: 1)
        )
    }

    // The member calendar's flat D-Day list, read-only: a guest can neither open nor pin a D-Day.
    private var dDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
                Text("guest.calendar.dday.title", tableName: "Guest")
                    .font(DPFont.bold(size: 17, relativeTo: .headline))
                    .foregroundStyle(DPColor.textPrimary)
                Text(verbatim: "\(model.dDays.count)")
                    .font(DPFont.light(size: 13, relativeTo: .subheadline))
                    .monospacedDigit()
                    .foregroundStyle(DPColor.textMuted)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .padding(.horizontal, 2)
            .frame(minHeight: DPSize.minimumTouchTarget)

            VStack(spacing: 0) {
                if model.dDays.isEmpty {
                    Text("guest.calendar.dday.empty", tableName: "Guest")
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textMuted)
                        .frame(maxWidth: .infinity, minHeight: DDayListPresentation.rowHeight)
                } else {
                    ForEach(Array(model.dDays.enumerated()), id: \.element.id) { index, item in
                        DDayRow(
                            item: item,
                            isPinned: false,
                            showsRule: index > 0,
                            canPin: false,
                            open: nil,
                            togglePin: {}
                        )
                    }
                }
            }
            .background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.compact))
            .overlay(
                RoundedRectangle(cornerRadius: DPRadius.compact)
                    .stroke(DPColor.borderPrimary, lineWidth: 1)
            )
        }
        .padding(.top, DPSpacing.extraSmall)
    }
}

private nonisolated enum GuestPublicCalendarAPIProvider {
    static func make() -> GuestAPIProtocol {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-guest-calendar") {
            return GuestPublicCalendarUITestingAPI()
        }
#endif
        return GuestAPI()
    }

    static func now() -> Date {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-guest-calendar"),
           let date = CalendarDateSupport.calendar.date(
               from: DateComponents(year: 2026, month: 8, day: 15)
           ) {
            return date
        }
#endif
        return Date()
    }
}

#if DEBUG
private nonisolated struct GuestPublicCalendarUITestingAPI: GuestAPIProtocol, Sendable {
    func member(id: MemberID) async throws -> MemberPreviewDTO {
        MemberPreviewDTO(
            id: id,
            name: "김듀티",
            teamId: nil,
            team: nil,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
    }

    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO] {
        guard let firstDay = CalendarDateSupport.calendar.date(
            from: DateComponents(year: year, month: month, day: 1)
        ) else { return [] }
        let weekday = CalendarDateSupport.calendar.component(.weekday, from: firstDay)
        guard let gridStart = CalendarDateSupport.calendar.date(
            byAdding: .day,
            value: -(weekday - 1),
            to: firstDay
        ) else { return [] }

        return (0..<42).compactMap { offset in
            guard let date = CalendarDateSupport.calendar.date(
                byAdding: .day,
                value: offset,
                to: gridStart
            ) else { return nil }
            let components = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = components.year, let month = components.month, let day = components.day else {
                return nil
            }
            return TeamDayDTO(year: year, month: month, day: day)
        }
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
#endif

/// Reporting requires an account, so a guest is asked to sign in first and lands on
/// the same login screen the rest of the guest experience uses.
private struct GuestReportLoginPrompt: View {
    let maximumHeight: CGFloat
    let cancel: () -> Void
    let willNavigate: () -> Void

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            Text(verbatim: GuestLocalization.text("guest.calendar.report.loginTitle"))
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, DPSpacing.large)
                .background(DPColor.backgroundTertiary)
                .accessibilityAddTraits(.isHeader)
        } content: {
            Text(verbatim: GuestLocalization.text("guest.calendar.report.loginMessage"))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(DPSpacing.large)
        } footer: {
            HStack(spacing: DPSpacing.compact) {
                Button(role: .cancel, action: cancel) {
                    Text(verbatim: GuestLocalization.text("guest.close"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPOutlineButtonStyle())
                .frame(maxWidth: .infinity)

                NavigationLink(value: GuestRoute.login) {
                    Text(verbatim: GuestLocalization.text("guest.login.short"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .simultaneousGesture(TapGesture().onEnded { willNavigate() })
                .accessibilityIdentifier("guest.calendar.report.login")
            }
            .padding(.horizontal, DPSpacing.large)
            .padding(.vertical, DPSpacing.medium)
        }
        .frame(minWidth: DPConfirmationPanel.minimumWidth, maxWidth: DPConfirmationPanel.maximumWidth)
        .accessibilityElement(children: .contain)
    }
}

private struct GuestCalendarDayCell: View {
    let day: GuestCalendarDay
    let weekday: Int

    var body: some View {
        DPCalendarDayTile(
            day: day.cell.day,
            weekdayIndex: weekday,
            dutyColor: dutyColor,
            isCurrentMonth: isCurrentMonth,
            isToday: isToday,
            hasHoliday: !day.holidays.isEmpty
        ) {
            EmptyView()
        } content: {
            details
        }
        .contentShape(Rectangle())
        .accessibilityLabel(day.cell.date.rawValue)
    }

    // Every holiday, D-Day and schedule of the day is drawn: the tile grows instead of
    // hiding any behind a count.
    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(day.holidays.enumerated()), id: \.offset) { _, holiday in
                Text(verbatim: holiday.dateName)
                    .font(DPFont.light(size: CalendarTypography.cellContent, relativeTo: .caption2))
                    .lineLimit(1)
                    .padding(.horizontal, 1)
                    .foregroundStyle(holiday.isHoliday
                        ? DPCalendarCellStyle.holidayForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
                        : secondaryForeground)
            }
            ForEach(Array(day.dDays.enumerated()), id: \.element.id) { index, item in
                DPCalendarItemRow(showsRule: index > 0, rule: ruleColor) {
                    (Text(Image(systemName: "flag.fill")).font(.system(size: 7)) + Text(verbatim: " \(item.title)"))
                        .font(DPFont.bold(size: CalendarTypography.cellContent, relativeTo: .caption2))
                        .foregroundStyle(primaryForeground)
                        .lineLimit(2)
                }
            }
            ForEach(Array(day.schedules.enumerated()), id: \.element.id) { index, schedule in
                DPCalendarItemRow(
                    showsRule: index + day.dDays.count > 0,
                    rule: ruleColor,
                    span: DPCalendarSpan(daysFromStart: schedule.daysFromStart, totalDays: schedule.totalDays),
                    spanColor: primaryForeground
                ) {
                    scheduleTitleLine(schedule)
                        .font(DPFont.light(size: CalendarTypography.cellContent, relativeTo: .caption2))
                        .tracking(-0.3)
                        .lineSpacing(1)
                        .foregroundStyle(primaryForeground)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }
        }
    }

    private var dutyColor: String? { day.duty?.dutyColor }
    private var isCurrentMonth: Bool { day.cell.isCurrentMonth }

    private var primaryForeground: Color {
        DPCalendarCellStyle.primaryForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
    }

    private var secondaryForeground: Color {
        DPCalendarCellStyle.secondaryForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
    }

    private var ruleColor: Color {
        DPCalendarCellStyle.ruleColor(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
    }

    private var isToday: Bool {
        let today = CalendarDateSupport.calendar.dateComponents([.year, .month, .day], from: Date())
        return day.cell.year == today.year && day.cell.month == today.month && day.cell.day == today.day
    }

    /// A narrow tile shows the title alone, as the member calendar does: the time and the
    /// day counter belong to the day detail.
    private func scheduleTitleLine(_ schedule: ScheduleDTO) -> Text {
        var line = Text(verbatim: schedule.content)
        if !schedule.description.isEmpty || !schedule.attachments.isEmpty {
            line = line + Text(verbatim: " ") + Text(Image(systemName: "text.bubble"))
        }
        return line
    }
}

private struct GuestCalendarDayDetailView: View {
    let day: GuestCalendarDay
    let maximumHeight: CGFloat
    let dismiss: () -> Void

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            modalHeader
        } content: {
            VStack(alignment: .leading, spacing: DPSpacing.small) {
                if let duty = day.duty {
                    detailSection(GuestLocalization.text("guest.calendar.duty")) {
                        HStack(spacing: DPSpacing.small) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(guestColor(hex: duty.dutyColor))
                                .frame(width: 14, height: 14)
                            Text(duty.dutyType ?? GuestLocalization.text("guest.calendar.off"))
                                .font(DPTypography.label)
                                .foregroundStyle(DPColor.textPrimary)
                        }
                    }
                }

                if !day.holidays.isEmpty {
                    detailSection(GuestLocalization.text("guest.calendar.holidays")) {
                        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                            ForEach(Array(day.holidays.enumerated()), id: \.offset) { _, holiday in
                                Text(holiday.dateName)
                                    .font(DPTypography.label)
                                    .foregroundStyle(DPColor.danger)
                            }
                        }
                    }
                }

                detailSection(GuestLocalization.text("guest.calendar.schedules")) {
                    if day.schedules.isEmpty {
                        Text("guest.calendar.schedule.empty", tableName: "Guest")
                            .font(DPTypography.label)
                            .foregroundStyle(DPColor.textMuted)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                    } else {
                        VStack(alignment: .leading, spacing: DPSpacing.compact) {
                            ForEach(day.schedules, id: \.id) { schedule in
                                scheduleCard(schedule)
                            }
                        }
                    }
                }

                if !day.dDays.isEmpty {
                    detailSection(GuestLocalization.text("guest.calendar.dday.title")) {
                        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                            ForEach(day.dDays, id: \.id) { item in
                                HStack {
                                    Text(item.title)
                                        .font(DPTypography.label)
                                        .foregroundStyle(DPColor.textPrimary)
                                    Spacer()
                                    Text(guestDDayLabel(item))
                                        .font(DPTypography.label)
                                        .foregroundStyle(DPColor.accent)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var modalHeader: some View {
        HStack(spacing: DPSpacing.small) {
            Text(formattedDate)
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DPColor.textPrimary)
            .accessibilityLabel(GuestLocalization.text("guest.close"))
        }
        .padding(.leading, 14)
        .padding(.trailing, DPSpacing.extraSmall)
        .padding(.vertical, DPSpacing.extraSmall)
        .background(DPColor.backgroundTertiary)
    }

    private func scheduleCard(_ schedule: ScheduleDTO) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            scheduleTitleLine(schedule)

            if !schedule.description.isEmpty {
                Divider().overlay(DPColor.borderPrimary)
                Text(schedule.description)
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textSecondary)
                    .textSelection(.enabled)
            }

            if !schedule.attachments.isEmpty {
                Divider().overlay(DPColor.borderPrimary)
                GuestScheduleAttachments(schedule: schedule)
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

    private func scheduleTitleLine(_ schedule: ScheduleDTO) -> Text {
        var line = Text(verbatim: schedule.content)
            .font(DPTypography.body)
            .foregroundColor(DPColor.textPrimary)
        if let time = guestScheduleTime(schedule) {
            line = line + Text(verbatim: " \(time)")
                .font(DPTypography.caption)
                .foregroundColor(DPColor.textMuted)
        }
        return line
    }

    private func detailSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
            Text(title)
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedDate: String {
        guard let date = CalendarDateSupport.date(from: day.cell.date) else {
            return day.cell.date.rawValue
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = selectedLocale
        dateFormatter.calendar = CalendarDateSupport.calendar
        dateFormatter.setLocalizedDateFormatFromTemplate("yyyyMMMMdEEE")
        return dateFormatter.string(from: date)
    }

    private var selectedLocale: Locale {
        AppLocalization.locale
    }
}

private struct GuestScheduleAttachments: View {
    let schedule: ScheduleDTO
    @StateObject private var gallery: AttachmentGalleryModel

    init(schedule: ScheduleDTO) {
        self.schedule = schedule
        _gallery = StateObject(wrappedValue: AttachmentGalleryModel(
            contextType: .schedule,
            contextId: schedule.id.uuidString,
            attachments: schedule.attachments
        ))
    }

    var body: some View {
        AttachmentGallery(model: gallery, canEdit: false)
            .onChange(of: schedule.attachments) { _, attachments in
                gallery.apply(attachments)
            }
    }
}

private func guestScheduleTime(_ schedule: ScheduleDTO) -> String? {
    CalendarVisualLogic.scheduleListTimeText(
        start: schedule.startDateTime,
        end: schedule.endDateTime
    )
}

private func guestDDayLabel(_ item: DDayDTO) -> String {
    item.calc == 0 ? "D-Day" : item.calc < 0 ? "D+\(abs(item.calc))" : "D-\(item.calc)"
}

private func guestColor(hex: String?) -> Color {
    guard let hex else { return DPColor.textMuted }
    let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x6B7280
    return Color(
        red: Double((value >> 16) & 0xff) / 255,
        green: Double((value >> 8) & 0xff) / 255,
        blue: Double(value & 0xff) / 255
    )
}
