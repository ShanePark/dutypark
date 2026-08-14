import SwiftUI

struct TeamView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = TeamViewModel()
    @State private var monthPickerPresented = false
    private let onOpenCalendar: (MemberID) -> Void

    init(onOpenCalendar: @escaping (MemberID) -> Void = { _ in }) {
        self.onOpenCalendar = onOpenCalendar
    }

    private var memberID: MemberID? {
        if case .authenticated(let member) = session.state { member.id } else { nil }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                DPLoadingState(label: LocalizedStringKey(teamLocalized("team.common.loading")))
            } else if viewModel.loadFailed {
                DPErrorState(
                    title: LocalizedStringKey(teamLocalized("team.common.error")),
                    message: nil,
                    retryTitle: LocalizedStringKey(teamLocalized("team.common.retry"))
                ) {
                    Task { await viewModel.load(memberID: memberID) }
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
        .task { await viewModel.load(memberID: memberID) }
        .refreshable { await viewModel.load(memberID: memberID) }
        .alert(
            Text("team.common.error", tableName: "Team"),
            isPresented: $viewModel.showsError
        ) {
            Button(teamLocalized("team.common.confirm"), role: .cancel) {}
        } message: {
            Text("team.common.error", tableName: "Team")
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.scheduleDraft != nil },
                set: { if !$0 { viewModel.scheduleDraft = nil } }
            )
        ) {
            TeamScheduleEditor(viewModel: viewModel)
        }
        .sheet(isPresented: $monthPickerPresented) {
            TeamYearMonthPicker(
                selectedYear: viewModel.year,
                selectedMonth: viewModel.month
            ) { year, month in
                monthPickerPresented = false
                Task { await viewModel.goTo(year: year, month: month) }
            } onToday: {
                monthPickerPresented = false
                Task { await viewModel.goToToday() }
            }
        }
        .alert(
            Text("team.common.delete", tableName: "Team"),
            isPresented: Binding(
                get: { viewModel.schedulePendingDeletion != nil },
                set: { if !$0 { viewModel.schedulePendingDeletion = nil } }
            )
        ) {
            Button(teamLocalized("team.common.delete"), role: .destructive) {
                Task { await viewModel.deleteSchedule() }
            }
            Button(teamLocalized("team.common.cancel"), role: .cancel) {
                viewModel.schedulePendingDeletion = nil
            }
        } message: {
            Text("team.view.schedule.deleteConfirm", tableName: "Team")
        }
    }

    private func teamContent(_ team: TeamDTO) -> some View {
        ScrollView {
            VStack(spacing: DPSpacing.compact) {
                HStack(spacing: DPSpacing.extraSmall) {
                    HStack(spacing: 6) {
                        Image(systemName: "building.2")
                            .font(.system(size: 14))
                        Text(verbatim: team.name)
                            .font(DPTypography.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(DPColor.textPrimary)
                    .padding(.horizontal, DPSpacing.small)
                    .frame(width: 80, alignment: .leading)
                    .frame(minHeight: 32)
                    .background(DPColor.backgroundTertiary)
                    .clipShape(Capsule())
                    .overlay { Capsule().stroke(DPColor.borderSecondary) }

                    monthHeader
                        .frame(maxWidth: .infinity)

                    Group {
                    if viewModel.isTeamManager {
                        NavigationLink {
                            TeamManageView(teamID: team.id)
                        } label: {
                            Image(systemName: "gearshape")
                                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("team.view.actions.manage", tableName: "Team"))
                    } else {
                        Color.clear.frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    }
                    }
                }

                calendar
                selectedSchedules
                shiftList
            }
            .padding(.horizontal, DPSpacing.small)
            .padding(.vertical, DPSpacing.medium)
        }
        .background(DPColor.backgroundPrimary)
    }

    private var monthHeader: some View {
        HStack(spacing: 0) {
            Button {
                Task { await viewModel.previousMonth() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 36, height: DPSize.minimumTouchTarget)
            }
            .accessibilityLabel(Text("team.view.calendar.month", tableName: "Team"))

            VStack(spacing: -2) {
                Button {
                    monthPickerPresented = true
                } label: {
                    HStack(spacing: DPSpacing.extraSmall) {
                        Text(
                            verbatim: "\(viewModel.year)-\(String(format: "%02d", locale: AppLocalization.locale, viewModel.month))"
                        )
                            .font(DPTypography.label)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .frame(minHeight: 26)
                }
                .accessibilityLabel(Text("team.view.calendar.chooseMonth", tableName: "Team"))
                if !isCurrentMonth {
                    Button {
                        Task { await viewModel.goToToday() }
                    } label: {
                        Text("team.view.calendar.thisMonth", tableName: "Team")
                            .font(DPTypography.caption)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                Task { await viewModel.nextMonth() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 36, height: DPSize.minimumTouchTarget)
            }
            .accessibilityLabel(Text("team.view.calendar.month", tableName: "Team"))
        }
    }

    private var isCurrentMonth: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        return now.year == viewModel.year && now.month == viewModel.month
    }

    private var calendar: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(Calendar.current.shortStandaloneWeekdaySymbols.enumerated()), id: \.offset) { index, weekday in
                    Text(verbatim: weekday)
                        .font(DPTypography.caption)
                        .foregroundStyle(TeamVisualStyle.weekdayColor(index))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(DPColor.backgroundTertiary)
                        .overlay(alignment: .trailing) {
                            if index < 6 { Rectangle().fill(DPColor.borderSecondary).frame(width: 1) }
                        }
                        .overlay(alignment: .bottom) { Rectangle().fill(DPColor.borderSecondary).frame(height: 1) }
                }
                ForEach(Array(viewModel.days.enumerated()), id: \.offset) { index, day in
                    TeamCalendarDayCell(
                        day: day,
                        currentMonth: viewModel.month,
                        duty: viewModel.duty(for: day),
                        holidays: viewModel.holidays.indices.contains(index)
                            ? viewModel.holidays[index]
                            : [],
                        schedules: viewModel.schedules.indices.contains(index)
                            ? viewModel.schedules[index]
                            : [],
                        weekdayIndex: index % 7,
                        isSelected: index == viewModel.selectedIndex
                    ) {
                        Task { await viewModel.selectDay(at: index) }
                    }
                }
            }
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary)
        }
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
                                        .font(.subheadline)
                                        .foregroundStyle(DPColor.textSecondary)
                                }
                                Text(verbatim: teamScheduleDateRange(schedule))
                                    .font(DPTypography.caption)
                                    .foregroundStyle(DPColor.textMuted)
                            }
                            Spacer()
                            if viewModel.isTeamManager {
                                HStack(spacing: 0) {
                                    Button { viewModel.editSchedule(schedule) } label: {
                                        Image(systemName: "pencil")
                                            .foregroundStyle(DPColor.accent)
                                            .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                                    }
                                    .accessibilityLabel(Text("team.view.actions.editSchedule", tableName: "Team"))
                                    Button { viewModel.schedulePendingDeletion = schedule } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(DPColor.danger)
                                            .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                                    }
                                    .accessibilityLabel(Text("team.view.actions.deleteSchedule", tableName: "Team"))
                                }
                                .buttonStyle(.plain)
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

    private var shiftList: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            if viewModel.shifts.isEmpty {
                Text("team.view.schedule.empty", tableName: "Team")
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
            } else {
                ForEach(Array(viewModel.shifts.enumerated()), id: \.offset) { _, shift in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(verbatim: shift.dutyType.name)
                                .font(DPTypography.bodyMedium)
                                .foregroundStyle(TeamVisualStyle.foregroundColor(on: shift.dutyType.color))
                            Spacer()
                            Text(verbatim: String(shift.members.count))
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.textOnLight)
                                .padding(.horizontal, DPSpacing.small)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.65))
                                .clipShape(Capsule())
                        }
                        .padding(DPSpacing.compact)
                        .background(Color(teamHex: shift.dutyType.color))

                        let memberColumns = Array(repeating: GridItem(.flexible(), spacing: DPSpacing.small), count: 2)
                        LazyVGrid(columns: memberColumns, spacing: DPSpacing.small) {
                            ForEach(Array(shift.members.enumerated()), id: \.offset) { _, member in
                                Group {
                                    if let id = member.id {
                                        Button { onOpenCalendar(id) } label: { memberCard(member) }
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
        Group {
            if member.hasProfilePhoto, let memberID = member.id {
                AsyncImage(url: profileURL(memberID)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    fallback
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Circle()
            .fill(DPColor.backgroundCard)
            .overlay {
                Text(verbatim: String(member.name.prefix(1)).uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DPColor.textSecondary)
            }
    }

    private func profileURL(_ memberID: MemberID) -> URL {
        AppConfiguration.apiBaseURL
            .appending(path: "members/\(memberID)/profile-photo")
            .appending(queryItems: [
                URLQueryItem(name: "thumbnail", value: "true"),
                URLQueryItem(name: "v", value: String(member.profilePhotoVersion))
            ])
    }
}

private struct TeamYearMonthPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var year: Int
    private let selectedYear: Int
    private let selectedMonth: Int
    let onSelect: (Int, Int) -> Void
    let onToday: () -> Void

    init(
        selectedYear: Int,
        selectedMonth: Int,
        onSelect: @escaping (Int, Int) -> Void,
        onToday: @escaping () -> Void
    ) {
        self.selectedYear = selectedYear
        self.selectedMonth = selectedMonth
        self.onSelect = onSelect
        self.onToday = onToday
        _year = State(initialValue: selectedYear)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DPSpacing.medium) {
                HStack {
                    Button { year -= 1 } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    }
                    .accessibilityLabel(Text("team.view.calendar.previousYear", tableName: "Team"))
                    Spacer()
                    Text(verbatim: String(year)).font(.title3.bold())
                    Spacer()
                    Button { year += 1 } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    }
                    .accessibilityLabel(Text("team.view.calendar.nextYear", tableName: "Team"))
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                    ForEach(1...12, id: \.self) { month in
                        Button {
                            onSelect(year, month)
                        } label: {
                            Text(verbatim: Calendar.current.monthSymbols[month - 1])
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                                .background(
                                    year == selectedYear && month == selectedMonth
                                        ? DPColor.accent
                                        : DPColor.backgroundTertiary
                                )
                                .foregroundStyle(
                                    year == selectedYear && month == selectedMonth
                                        ? DPColor.textOnDark
                                        : DPColor.textPrimary
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    onToday()
                } label: {
                    Text("team.view.calendar.thisMonth", tableName: "Team")
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(DPSpacing.medium)
            .navigationTitle(Text("team.view.calendar.chooseMonth", tableName: "Team"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(teamLocalized("team.common.cancel")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
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
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: String(day.day))
                    .font(DPFont.light(size: 12, relativeTo: .caption))
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundStyle(dayNumberColor)
                ForEach(Array(holidays.enumerated()), id: \.offset) { _, holiday in
                    Text(verbatim: holiday.dateName)
                        .font(DPFont.light(size: 9, relativeTo: .caption2))
                        .foregroundStyle(holiday.isHoliday ? DPColor.danger : adaptiveMuted)
                        .lineLimit(1)
                }
                ForEach(Array(schedules.prefix(2).enumerated()), id: \.offset) { _, schedule in
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle().fill(adaptiveBorder).frame(height: 1)
                        Text(verbatim: scheduleLabel(schedule))
                            .font(DPFont.light(size: 9, relativeTo: .caption2))
                            .foregroundStyle(adaptiveText)
                            .lineLimit(2)
                    }
                }
                if schedules.count > 2 {
                    Text(verbatim: "+\(schedules.count - 2)")
                        .font(DPFont.light(size: 9, relativeTo: .caption2))
                        .foregroundStyle(adaptiveMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(3)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
            .background(cellBackground)
            .opacity(day.month == currentMonth ? 1 : 0.5)
            .overlay {
                Rectangle().stroke(adaptiveBorder, lineWidth: 0.5)
                Rectangle()
                    .stroke(isToday ? DPColor.danger : isSelected ? DPColor.accent : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(day.year)-\(day.month)-\(day.day)"))
    }

    private var isToday: Bool {
        let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return today.year == day.year && today.month == day.month && today.day == day.day
    }

    private var isLightDuty: Bool { TeamVisualStyle.isLightColor(duty?.dutyColor) }
    private var cellBackground: Color {
        if let color = duty?.dutyColor { return Color(teamHex: color) }
        return day.month == currentMonth ? DPColor.backgroundCard : DPColor.backgroundTertiary
    }
    private var adaptiveText: Color { duty == nil ? DPColor.textPrimary : isLightDuty ? DPColor.textOnLight : DPColor.textOnDark }
    private var adaptiveMuted: Color { duty == nil ? DPColor.textMuted : isLightDuty ? DPColor.textMuted : DPColor.textOnDarkMuted }
    private var adaptiveBorder: Color { duty == nil ? DPColor.borderSecondary : isLightDuty ? DPColor.textOnLight.opacity(0.32) : DPColor.textOnDark.opacity(0.7) }
    private var dayNumberColor: Color {
        if weekdayIndex == 0 { return DPColor.danger }
        if weekdayIndex == 6 { return DPColor.accent }
        return adaptiveText
    }

    private func scheduleLabel(_ schedule: TeamScheduleDTO) -> String {
        guard let from = schedule.daysFromStart, let total = schedule.totalDays, total > 1 else { return schedule.content }
        return "\(schedule.content) (\(from)/\(total))"
    }
}

private struct TeamScheduleEditor: View {
    @ObservedObject var viewModel: TeamViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("team.view.schedule.modal.title", tableName: "Team")
                        .font(DPTypography.bodyMedium)
                    Spacer()
                    Button {
                        viewModel.scheduleDraft = nil
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
                .overlay(alignment: .bottom) { Rectangle().fill(DPColor.borderPrimary).frame(height: 1) }

                ScrollView {
                if let draft = Binding($viewModel.scheduleDraft) {
                    VStack(alignment: .leading, spacing: DPSpacing.medium) {
                        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                            HStack {
                                Text("team.view.schedule.form.contentLabel", tableName: "Team").font(DPTypography.label)
                                Spacer()
                                Text(verbatim: "\(draft.wrappedValue.content.count)/50").font(DPTypography.caption).foregroundStyle(DPColor.textMuted)
                            }
                        TextField(
                            teamLocalized("team.view.schedule.form.contentPlaceholder"),
                            text: draft.content
                        )
                        .dpInputChrome(isInvalid: draft.wrappedValue.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .onChange(of: draft.wrappedValue.content) { _, value in
                            if value.count > 50 { draft.wrappedValue.content = String(value.prefix(50)) }
                        }
                        }
                        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                            Text("team.view.schedule.form.descriptionLabel", tableName: "Team").font(DPTypography.label)
                        TextField(
                            teamLocalized("team.view.schedule.form.descriptionPlaceholder"),
                            text: draft.description,
                            axis: .vertical
                        )
                        .lineLimit(4...8)
                        .dpInputChrome()
                        }
                        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        DatePicker(selection: draft.startDate, displayedComponents: .date) {
                            Text("team.view.schedule.form.startDate", tableName: "Team")
                        }
                        .frame(minHeight: DPSize.minimumTouchTarget)
                        DatePicker(
                            selection: draft.endDate,
                            in: draft.wrappedValue.startDate...,
                            displayedComponents: .date
                        ) {
                            Text("team.view.schedule.form.endDate", tableName: "Team")
                        }
                        .frame(minHeight: DPSize.minimumTouchTarget)
                        }
                    }
                    .padding(DPSpacing.medium)
                }
                }
                HStack(spacing: DPSpacing.small) {
                    Button(teamLocalized("team.common.save")) {
                        Task { await viewModel.saveSchedule() }
                    }
                    .buttonStyle(DPPrimaryButtonStyle())
                    .disabled(viewModel.scheduleDraft?.isValid != true || viewModel.isWorking)
                    Button(teamLocalized("team.common.cancel")) {
                        viewModel.scheduleDraft = nil
                        dismiss()
                    }
                    .buttonStyle(DPSecondaryButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(DPSpacing.medium)
                .overlay(alignment: .top) { Rectangle().fill(DPColor.borderPrimary).frame(height: 1) }
            }
            .background(DPColor.backgroundModal)
            .navigationBarHidden(true)
        }
        .dpKeyboardDismissToolbar()
        .presentationDetents([.medium, .large])
    }
}

private enum TeamVisualStyle {
    static func weekdayColor(_ index: Int) -> Color {
        if index == 0 { return DPColor.danger }
        if index == 6 { return DPColor.accent }
        return DPColor.textPrimary
    }

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

func teamLocalized(_ key: String) -> String {
    AppLocalization.string(key, table: "Team")
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
