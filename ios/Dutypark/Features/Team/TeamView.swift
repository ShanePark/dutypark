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
                DPEmptyState(
                    systemImage: "building.2",
                    title: LocalizedStringKey(teamLocalized("team.view.emptyTitle")),
                    message: LocalizedStringKey(teamLocalized("team.view.emptyDescription"))
                )
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
            VStack(spacing: DPSpacing.medium) {
                HStack {
                    Label(team.name, systemImage: "building.2")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if viewModel.isTeamManager {
                        NavigationLink {
                            TeamManageView(teamID: team.id)
                        } label: {
                            Label {
                                Text("team.view.actions.manage", tableName: "Team")
                            } icon: {
                                Image(systemName: "gearshape")
                            }
                        }
                        .buttonStyle(.bordered)
                        .frame(minHeight: DPSize.minimumTouchTarget)
                    }
                }

                monthHeader
                calendar
                selectedSchedules
                shiftList
            }
            .padding(DPSpacing.medium)
        }
        .background(DPColor.backgroundPrimary)
    }

    private var monthHeader: some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                Task { await viewModel.previousMonth() }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .accessibilityLabel(Text("team.view.calendar.month", tableName: "Team"))

            Spacer()
            VStack(spacing: 0) {
                Button {
                    monthPickerPresented = true
                } label: {
                    HStack(spacing: DPSpacing.extraSmall) {
                        Text(
                            verbatim: "\(viewModel.year).\(String(format: "%02d", locale: AppLocalization.locale, viewModel.month))"
                        )
                            .font(.headline)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .frame(minHeight: DPSize.minimumTouchTarget)
                }
                .accessibilityLabel(Text("team.view.calendar.chooseMonth", tableName: "Team"))
                Button {
                    Task { await viewModel.goToToday() }
                } label: {
                    Text("team.view.calendar.today", tableName: "Team")
                        .font(.caption)
                }
            }
            Spacer()

            Button {
                Task { await viewModel.nextMonth() }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .accessibilityLabel(Text("team.view.calendar.month", tableName: "Team"))
        }
    }

    private var calendar: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        return VStack(spacing: DPSpacing.extraSmall) {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Calendar.current.veryShortStandaloneWeekdaySymbols, id: \.self) { weekday in
                    Text(verbatim: weekday)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DPColor.textSecondary)
                        .frame(maxWidth: .infinity)
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
                        isSelected: index == viewModel.selectedIndex
                    ) {
                        Task { await viewModel.selectDay(at: index) }
                    }
                }
            }
        }
        .padding(DPSpacing.small)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary)
        }
    }

    private var selectedSchedules: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack {
                Label {
                    if let day = viewModel.selectedDay {
                        Text(verbatim: "\(day.month).\(day.day)")
                            .font(.headline)
                    }
                } icon: {
                    Image(systemName: "calendar")
                }
                Spacer()
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
                    .buttonStyle(.borderedProminent)
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
                                Text(verbatim: schedule.content).font(.body.weight(.semibold))
                                if !schedule.description.isEmpty {
                                    Text(verbatim: schedule.description)
                                        .font(.subheadline)
                                        .foregroundStyle(DPColor.textSecondary)
                                }
                                Text(verbatim: schedule.createMember)
                                    .font(.caption)
                                    .foregroundStyle(DPColor.textMuted)
                                Text(
                                    verbatim: "\(schedule.startDateTime.rawValue.prefix(10)) – \(schedule.endDateTime.rawValue.prefix(10))"
                                )
                                .font(.caption)
                                .foregroundStyle(DPColor.textMuted)
                            }
                            Spacer()
                            if viewModel.isTeamManager {
                                Menu {
                                    Button {
                                        viewModel.editSchedule(schedule)
                                    } label: {
                                        Label(teamLocalized("team.dutyType.actions.edit"), systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        viewModel.schedulePendingDeletion = schedule
                                    } label: {
                                        Label(teamLocalized("team.common.delete"), systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                                }
                            }
                        }
                    }
                    .padding(DPSpacing.small)
                    .background(DPColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
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
            Text("team.view.shift.title", tableName: "Team")
                .font(.headline)
            if viewModel.shifts.isEmpty {
                Text("team.view.schedule.empty", tableName: "Team")
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
            } else {
                ForEach(Array(viewModel.shifts.enumerated()), id: \.offset) { _, shift in
                    VStack(alignment: .leading, spacing: DPSpacing.small) {
                        HStack {
                            Circle()
                                .fill(Color(teamHex: shift.dutyType.color))
                                .frame(width: 14, height: 14)
                            Text(verbatim: shift.dutyType.name).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(verbatim: String(shift.members.count))
                                .font(.caption)
                                .foregroundStyle(DPColor.textMuted)
                        }
                        FlowLayout(spacing: DPSpacing.extraSmall) {
                            ForEach(Array(shift.members.enumerated()), id: \.offset) { _, member in
                                if let id = member.id {
                                    Button {
                                        onOpenCalendar(id)
                                    } label: {
                                        memberPill(member)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint(Text("team.view.calendar.title", tableName: "Team"))
                                } else {
                                    memberPill(member)
                                }
                            }
                        }
                    }
                    .padding(DPSpacing.small)
                    .background(
                        TeamFeatureLogic.isMyShiftGroup(shift, memberID: memberID)
                            ? DPColor.accentSoft
                            : DPColor.backgroundSecondary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                    .overlay {
                        RoundedRectangle(cornerRadius: DPRadius.standard)
                            .stroke(
                                TeamFeatureLogic.isMyShiftGroup(shift, memberID: memberID)
                                    ? DPColor.textPrimary
                                    : Color.clear,
                                lineWidth: 2
                            )
                    }
                }
            }
        }
        .padding(DPSpacing.medium)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay { RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary) }
    }

    private func memberPill(_ member: MemberPreviewDTO) -> some View {
        HStack(spacing: DPSpacing.extraSmall) {
            TeamMemberAvatar(member: member, size: 28)
            Text(verbatim: member.name)
                .font(.caption)
                .lineLimit(1)
        }
            .padding(.horizontal, 10)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(
                member.id == memberID ? DPColor.accentSoft : DPColor.backgroundTertiary
            )
            .clipShape(Capsule())
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
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(verbatim: String(day.day))
                    .font(.caption.weight(isSelected ? .bold : .regular))
                if let duty {
                    Circle()
                        .fill(Color(teamHex: duty.dutyColor))
                        .frame(width: 7, height: 7)
                } else {
                    Color.clear.frame(width: 7, height: 7)
                }
                if let label = holidays.first?.dateName ?? schedules.first?.content {
                    Text(verbatim: label)
                        .font(.system(size: 8))
                        .lineLimit(1)
                } else {
                    Text(" ").font(.system(size: 8))
                }
            }
            .foregroundStyle(day.month == currentMonth ? DPColor.textPrimary : DPColor.textMuted)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(isSelected ? DPColor.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6).stroke(DPColor.accent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(day.year)-\(day.month)-\(day.day)"))
    }
}

private struct TeamScheduleEditor: View {
    @ObservedObject var viewModel: TeamViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let draft = Binding($viewModel.scheduleDraft) {
                    Section {
                        TextField(
                            teamLocalized("team.view.schedule.form.contentPlaceholder"),
                            text: draft.content
                        )
                        .onChange(of: draft.wrappedValue.content) { _, value in
                            if value.count > 50 { draft.wrappedValue.content = String(value.prefix(50)) }
                        }
                        TextField(
                            teamLocalized("team.view.schedule.form.descriptionPlaceholder"),
                            text: draft.description,
                            axis: .vertical
                        )
                        DatePicker(selection: draft.startDate, displayedComponents: .date) {
                            Text("team.view.schedule.form.startDate", tableName: "Team")
                        }
                        DatePicker(
                            selection: draft.endDate,
                            in: draft.wrappedValue.startDate...,
                            displayedComponents: .date
                        ) {
                            Text("team.view.schedule.form.endDate", tableName: "Team")
                        }
                    }
                }
            }
            .navigationTitle(Text("team.view.schedule.form.title", tableName: "Team"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(teamLocalized("team.common.cancel")) {
                        viewModel.scheduleDraft = nil
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(teamLocalized("team.common.save")) {
                        Task { await viewModel.saveSchedule() }
                    }
                    .disabled(viewModel.scheduleDraft?.isValid != true || viewModel.isWorking)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct FlowLayout: Layout {
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
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
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
