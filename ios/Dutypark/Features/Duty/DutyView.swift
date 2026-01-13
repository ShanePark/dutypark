import SwiftUI

struct DutyView: View {
    @StateObject private var viewModel: DutyViewModel
    @StateObject private var ddayViewModel = DDayViewModel()
    @StateObject private var scheduleViewModel = ScheduleViewModel()
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.colorScheme) var colorScheme
    private let member: Friend?
    private let isReadOnly: Bool
    @State private var showDayDetail = false
    @State private var selectedDay: Int = 0
    @State private var showAddDDay = false
    @State private var selectedDDayForEdit: DDayDto?
    @State private var showSearch = false
    @State private var showAddSchedule = false
    @State private var scheduleInitialDate = Date()
    @State private var selectedDDay: DDayDto?
    @State private var showFilterSheet = false
    @State private var showTodoTodo = true
    @State private var selectedDutyTypeFilters: Set<String> = []
    @State private var isBatchEditMode = false
    @State private var focusedDay: Int?
    @State private var showCompareSheet = false

    init(member: Friend? = nil) {
        self.member = member
        self.isReadOnly = member != nil
        _viewModel = StateObject(wrappedValue: DutyViewModel(memberId: member?.id))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? DesignSystem.Colors.Dark.bgPrimary : DesignSystem.Colors.Light.bgSecondary)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Header with profile and navigation
                        headerSection

                        // Filter buttons
                        filterButtonsSection

                        // Legend
                        legendSection

                        if isBatchEditMode {
                            batchEditSection
                        }

                        // Weekday headers
                        weekdayHeaders

                        // Calendar grid
                        calendarGrid

                        // D-Day section
                        ddaySection
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await loadAllData()
                }
            }
            .navigationBarHidden(true)
            .task {
                if authManager.currentUser == nil && member == nil {
                    await authManager.checkAuthStatus()
                }
                await loadAllData()
            }
            .onChange(of: authManager.currentUser?.id) { _, newId in
                guard member == nil, let newId else { return }
                viewModel.memberId = newId
                Task { await loadAllData() }
            }
            .loading(viewModel.isLoading && viewModel.duties.isEmpty)
            .sheet(isPresented: $showDayDetail) {
                DayDetailSheet(viewModel: viewModel, day: selectedDay, isReadOnly: isReadOnly)
            }
            .sheet(isPresented: $showAddDDay) {
                AddDDaySheet(viewModel: ddayViewModel, ddayToEdit: selectedDDayForEdit)
            }
            .sheet(isPresented: $showSearch) {
                ScheduleSearchView(memberId: viewModel.memberId ?? authManager.currentUser?.id ?? 0)
            }
            .sheet(isPresented: $showAddSchedule) {
                ScheduleEditView(viewModel: scheduleViewModel, initialDate: scheduleInitialDate) {
                    Task { await viewModel.loadDutyData() }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                DutyFilterSheet(showTodoTodo: $showTodoTodo, selectedDutyTypeFilters: $selectedDutyTypeFilters)
            }
            .sheet(isPresented: $showCompareSheet) {
                CompareFriendSheet(selectedIds: compareSelectionBinding) { memberIds in
                    Task { await viewModel.updateCompareMembers(memberIds) }
                }
            }
            .sheet(item: $selectedDDay) { dday in
                DDayDetailSheet(
                    dday: dday,
                    viewModel: ddayViewModel,
                    memberId: viewModel.memberId ?? authManager.currentUser?.id,
                    isReadOnly: isReadOnly
                ) {
                    selectedDDay = nil
                }
            }
            .onChange(of: showAddDDay) { _, isPresented in
                if !isPresented {
                    selectedDDayForEdit = nil
                }
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Profile avatar
            if let member {
                ProfileAvatar(
                    memberId: member.id,
                    name: member.name,
                    hasProfilePhoto: member.hasProfilePhoto ?? false,
                    profilePhotoVersion: member.profilePhotoVersion,
                    size: 36
                )

                Text(member.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
            } else if let user = authManager.currentUser {
                ProfileAvatar(
                    memberId: user.id,
                    name: user.name,
                    hasProfilePhoto: user.hasProfilePhoto ?? false,
                    profilePhotoVersion: user.profilePhotoVersion,
                    size: 36
                )

                Text(user.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
            }

            Spacer()

            // Month navigation
            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    viewModel.previousMonth()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                }

                Button {
                    viewModel.goToToday()
                } label: {
                    Text("\(viewModel.selectedYear)-\(String(format: "%02d", viewModel.selectedMonth))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
                }

                Button {
                    viewModel.nextMonth()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    showCompareSheet = true
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xxs) {
                        Text("함께보기")
                            .font(.caption)
                        if viewModel.selectedCompareMemberIds.count > 0 {
                            Text("(\(viewModel.selectedCompareMemberIds.count))")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        Image(systemName: "person.2")
                            .font(.caption)
                    }
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }

                // Search button
                Button {
                    showSearch = true
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text("검색")
                            .font(.caption)
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                    }
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Filter Buttons Section
    private var filterButtonsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Todo filter button
                FilterButton(title: "할일", isActive: showTodoTodo) {
                    showTodoTodo.toggle()
                }

                if !isReadOnly {
                    // Add button
                    Button {
                        scheduleInitialDate = Date()
                        showAddSchedule = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                            .padding(DesignSystem.Spacing.sm)
                            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                }

                // Filter button
                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                        .padding(DesignSystem.Spacing.sm)
                        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }

                // Duty type filters (dynamic based on available types)
                ForEach(viewModel.dutyTypeNames, id: \.self) { dutyType in
                    FilterButton(title: dutyType, isActive: selectedDutyTypeFilters.contains(dutyType)) {
                        toggleDutyTypeFilter(dutyType)
                    }
                }
            }
        }
        .padding(.bottom, DesignSystem.Spacing.md)
    }

    // MARK: - Legend Section
    private var legendSection: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Duty type counts
            ForEach(viewModel.dutyTypeCounts.sorted(by: { $0.key < $1.key }), id: \.key) { type, count in
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Rectangle()
                        .fill(Color(hex: viewModel.dutyTypeColors[type] ?? "#gray") ?? .gray)
                        .frame(width: 12, height: 12)
                        .cornerRadius(2)

                    Text(type)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)

                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
                }
            }

            Spacer()

            if !isReadOnly {
                // Edit mode toggle
                Button {
                    toggleBatchEditMode()
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "person.2")
                            .font(.caption)
                        Text("편집모드")
                            .font(.caption)
                    }
                    .foregroundColor(isBatchEditMode ? DesignSystem.Colors.accent : (colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted))
                }
            }
        }
        .padding(.bottom, DesignSystem.Spacing.md)
    }

    private var batchEditSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    moveFocusedDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                }
                .disabled(focusedDay == 1)

                if let focusedDay {
                    Text("\(focusedDay)일")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.warning)
                }

                Button {
                    moveFocusedDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                }
                .disabled(focusedDay == lastDayOfSelectedMonth())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    let focusedDutyName = focusedDay.flatMap { viewModel.duties[$0]?.dutyType }
                    let isFocusedOff = focusedDay.flatMap { viewModel.duties[$0]?.isOff } ?? false

                    Button {
                        applyBatchDuty(nil)
                    } label: {
                        Text("OFF")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(isFocusedOff ? DesignSystem.Colors.accent.opacity(0.2) : (colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary))
                            .foregroundColor(isFocusedOff ? DesignSystem.Colors.accent : .gray)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                    }

                    ForEach(viewModel.dutyTypes, id: \.id) { dutyType in
                        Button {
                            applyBatchDuty(dutyType.id)
                        } label: {
                            Text(dutyType.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                .background(dutyType.swiftUIColor.opacity(focusedDutyName == dutyType.name ? 0.4 : 0.2))
                                .foregroundColor(dutyType.swiftUIColor)
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                        }
                    }
                }
            }
        }
        .padding(.bottom, DesignSystem.Spacing.md)
    }

    // MARK: - Weekday Headers
    private var weekdayHeaders: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
            ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(day == "일" ? DesignSystem.Colors.sunday : day == "토" ? DesignSystem.Colors.saturday : (colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgTertiary)
            }
        }
        .cornerRadius(DesignSystem.CornerRadius.sm, corners: [.topLeft, .topRight])
    }

    // MARK: - Calendar Grid
    private var calendarGrid: some View {
        let days = generateCalendarDays()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
            ForEach(days.indices, id: \.self) { index in
                let dayInfo = days[index]

                if dayInfo.day > 0 && dayInfo.isCurrentMonth {
                    let duty = filteredDuty(for: dayInfo.day)
                    let todos = filteredTodos(for: dayInfo.day)
                    let holidays = viewModel.holidays[dayInfo.day] ?? []
                    let ddayText = pinnedDDayText(for: dayInfo.day)
                    let dayDDays = ddaysForDay(dayInfo.day)
                    let otherDuties = viewModel.otherDutiesByDay[dayInfo.day] ?? []

                    DayCell(
                        day: dayInfo.day,
                        duty: duty,
                        holidays: holidays,
                        ddayText: ddayText,
                        ddays: dayDDays,
                        isToday: isToday(dayInfo.day),
                        schedules: viewModel.schedulesByDay[dayInfo.day] ?? [],
                        otherDuties: otherDuties,
                        todos: todos,
                        weekdayIndex: index % 7,
                        isFocused: isBatchEditMode && focusedDay == dayInfo.day
                    )
                    .onTapGesture {
                        if isBatchEditMode {
                            focusedDay = dayInfo.day
                            return
                        }
                        selectedDay = dayInfo.day
                        showDayDetail = true
                    }
                } else {
                    Rectangle()
                        .fill(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                        .frame(height: 90)
                }
            }
        }
        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.borderPrimary : DesignSystem.Colors.Light.borderPrimary)
        .cornerRadius(DesignSystem.CornerRadius.sm, corners: [.bottomLeft, .bottomRight])
    }

    // MARK: - D-Day Section
    private var ddaySection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // D-Day cards in grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.md) {
                ForEach(ddayViewModel.ddays) { dday in
                    DDayCard(
                        dday: dday,
                        isPinned: ddayViewModel.pinnedDDayId == dday.id,
                        onSelect: {
                            selectedDDay = dday
                        },
                        onTogglePin: {
                            if let memberId = viewModel.memberId ?? authManager.currentUser?.id {
                                ddayViewModel.togglePinnedDDay(dday, memberId: memberId)
                            }
                        },
                        onEdit: nil,
                        onDelete: nil
                    )
                }
            }

            if !isReadOnly {
                // Add D-Day button
                Button {
                    showAddDDay = true
                } label: {
                    HStack {
                        Image(systemName: "plus")
                            .font(.title3)
                        Text("디데이 추가")
                            .font(.subheadline)
                    }
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.xl)
                    .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgCard)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.borderPrimary : DesignSystem.Colors.Light.borderPrimary)
                    )
                }
            }
        }
        .padding(.top, DesignSystem.Spacing.xl)
    }

    // MARK: - Helper Methods
    private func generateCalendarDays() -> [(day: Int, isCurrentMonth: Bool)] {
        var calendar = Calendar.current
        calendar.firstWeekday = 1

        guard let date = calendar.date(from: DateComponents(year: viewModel.selectedYear, month: viewModel.selectedMonth, day: 1)) else {
            return []
        }

        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 0
        let firstWeekday = calendar.component(.weekday, from: date)

        var days: [(day: Int, isCurrentMonth: Bool)] = []

        for _ in 1..<firstWeekday {
            days.append((0, false))
        }

        for day in 1...daysInMonth {
            days.append((day, true))
        }

        while days.count % 7 != 0 {
            days.append((0, false))
        }

        return days
    }

    private func isToday(_ day: Int) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        return calendar.component(.year, from: now) == viewModel.selectedYear &&
               calendar.component(.month, from: now) == viewModel.selectedMonth &&
               calendar.component(.day, from: now) == day
    }

    private func toggleDutyTypeFilter(_ dutyType: String) {
        if selectedDutyTypeFilters.contains(dutyType) {
            selectedDutyTypeFilters.remove(dutyType)
        } else {
            selectedDutyTypeFilters.insert(dutyType)
        }
    }

    private func filteredDuty(for day: Int) -> DutyCalendarDay? {
        guard let duty = viewModel.duties[day] else { return nil }
        if selectedDutyTypeFilters.isEmpty {
            return duty
        }
        guard let dutyType = duty.dutyType else { return nil }
        return selectedDutyTypeFilters.contains(dutyType) ? duty : nil
    }

    private func filteredTodos(for day: Int) -> [Todo] {
        let todos = viewModel.todosByDay[day] ?? []
        return todos.filter { todo in
            if todo.status == .inProgress { return true }
            if todo.status == .todo { return showTodoTodo }
            return false
        }
    }

    private func toggleBatchEditMode() {
        guard viewModel.canManage else { return }
        isBatchEditMode.toggle()
        if isBatchEditMode {
            focusedDay = focusedDay ?? 1
        } else {
            focusedDay = nil
        }
    }

    private func moveFocusedDay(by delta: Int) {
        guard let focusedDay else { return }
        let lastDay = lastDayOfSelectedMonth()
        let nextDay = min(max(1, focusedDay + delta), lastDay)
        self.focusedDay = nextDay
    }

    private func applyBatchDuty(_ dutyTypeId: Int?) {
        guard let focusedDay else { return }
        Task {
            let success = await viewModel.changeDuty(day: focusedDay, dutyTypeId: dutyTypeId)
            if success {
                let lastDay = lastDayOfSelectedMonth()
                if focusedDay < lastDay {
                    self.focusedDay = focusedDay + 1
                }
            }
        }
    }

    private func pinnedDDayText(for day: Int) -> String? {
        guard let pinned = ddayViewModel.pinnedDDay else { return nil }
        guard let pinnedDate = parseDate(pinned.date) else { return nil }
        var components = DateComponents()
        components.year = viewModel.selectedYear
        components.month = viewModel.selectedMonth
        components.day = day
        guard let dayDate = Calendar.current.date(from: components) else { return nil }
        let diff = Calendar.current.dateComponents([.day], from: dayDate, to: pinnedDate).day ?? 0
        if diff == 0 { return "D-Day" }
        if diff > 0 { return "D-\(diff)" }
        return "D+\(abs(diff))"
    }

    private func ddaysForDay(_ day: Int) -> [DDayDto] {
        ddayViewModel.ddays.filter { dday in
            guard let date = parseDate(dday.date) else { return false }
            let calendar = Calendar.current
            return calendar.component(.year, from: date) == viewModel.selectedYear &&
                calendar.component(.month, from: date) == viewModel.selectedMonth &&
                calendar.component(.day, from: date) == day
        }
    }

    private var compareSelectionBinding: Binding<Set<Int>> {
        Binding(
            get: { Set(viewModel.selectedCompareMemberIds) },
            set: { viewModel.selectedCompareMemberIds = Array($0) }
        )
    }

    private func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func lastDayOfSelectedMonth() -> Int {
        var components = DateComponents()
        components.year = viewModel.selectedYear
        components.month = viewModel.selectedMonth
        components.day = 1
        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else { return 30 }
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func loadAllData() async {
        if viewModel.memberId == nil {
            viewModel.memberId = authManager.currentUser?.id
        }

        await viewModel.loadDutyData()

        if let memberId = viewModel.memberId ?? authManager.currentUser?.id {
            await ddayViewModel.loadDDays(memberId: memberId)
            ddayViewModel.loadPinnedDDay(memberId: memberId)
        } else {
            await ddayViewModel.loadDDays()
        }
    }
}

// MARK: - Filter Button
struct FilterButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundColor(isActive ? .white : (colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary))
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(isActive ? DesignSystem.Colors.accent : (colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary))
                .cornerRadius(DesignSystem.CornerRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(isActive ? Color.clear : (colorScheme == .dark ? DesignSystem.Colors.Dark.borderPrimary : DesignSystem.Colors.Light.borderPrimary), lineWidth: 1)
                )
        }
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let day: Int
    let duty: DutyCalendarDay?
    let holidays: [HolidayDto]
    let ddayText: String?
    let ddays: [DDayDto]
    let isToday: Bool
    let schedules: [Schedule]
    let otherDuties: [OtherDutySummary]
    let todos: [Todo]
    let weekdayIndex: Int
    let isFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Day number and holiday
            HStack {
                Text("\(day)")
                    .font(.caption)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(textColor)

                if let ddayText {
                    Text(ddayText)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.accent.opacity(0.15))
                        .cornerRadius(4)
                }

                Spacer()
            }

            if !holidays.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(holidays.enumerated()), id: \.offset) { _, holiday in
                        Text(holiday.dateName)
                            .font(.system(size: 8))
                            .foregroundColor(holiday.isHoliday ? DesignSystem.Colors.sunday : mutedHolidayColor)
                            .lineLimit(1)
                    }
                }
            }

            // Duty badge
            if let duty = duty, !duty.isOff {
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color(hex: duty.dutyColor ?? "#gray") ?? .gray)
                        .frame(width: 6, height: 6)
                    Text(duty.dutyType ?? "")
                        .font(.system(size: 9))
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                        .lineLimit(1)
                }
            }

            if !otherDuties.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(otherDuties.prefix(2)) { other in
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color(hex: other.dutyColor ?? "#9CA3AF") ?? .gray)
                                .frame(width: 4, height: 4)
                            Text("\(other.name): \(otherDutyLabel(other))")
                                .font(.system(size: 7))
                                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                                .lineLimit(1)
                        }
                    }
                    if otherDuties.count > 2 {
                        Text("+\(otherDuties.count - 2)")
                            .font(.system(size: 7))
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                    }
                }
            }

            Spacer()

            // Schedule previews
            VStack(alignment: .leading, spacing: 1) {
                ForEach(schedules.prefix(2)) { schedule in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 2) {
                            Text(schedulePreviewText(schedule))
                                .font(.system(size: 8))
                                .foregroundColor(DesignSystem.Colors.accent)
                                .lineLimit(1)

                            if !schedule.attachments.isEmpty {
                                Image(systemName: "camera")
                                    .font(.system(size: 7))
                                    .foregroundColor(DesignSystem.Colors.accent)
                            }
                        }

                        if schedule.isTagged, let owner = schedule.owner, !owner.isEmpty {
                            Text("by \(owner)")
                                .font(.system(size: 7))
                                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 1)
                    .background(DesignSystem.Colors.accent.opacity(0.1))
                    .cornerRadius(2)
                }
            }

            if !ddays.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(ddays.prefix(2)) { dday in
                        Text(dday.title)
                            .font(.system(size: 7))
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                            .lineLimit(1)
                    }
                }
            }

            // Todo indicators
            if !todos.isEmpty {
                HStack(spacing: 2) {
                    ForEach(todos.prefix(3)) { todo in
                        Circle()
                            .fill(todoColor(for: todo.status))
                            .frame(width: 5, height: 5)
                    }
                    if todos.count > 3 {
                        Text("+\(todos.count - 3)")
                            .font(.system(size: 7))
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                    }
                }
            }
        }
        .padding(4)
        .frame(height: 90)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .stroke(isFocused ? DesignSystem.Colors.accent : (isToday ? DesignSystem.Colors.sunday : Color.clear), lineWidth: 2)
        )
    }

    private var textColor: Color {
        if hasHoliday || weekdayIndex == 0 {
            return DesignSystem.Colors.sunday
        } else if weekdayIndex == 6 {
            return DesignSystem.Colors.saturday
        }
        return colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary
    }

    private var backgroundColor: Color {
        if weekdayIndex == 0 || weekdayIndex == 6 || hasHoliday {
            return colorScheme == .dark ? Color(hex: "#2D1F2F")! : Color(hex: "#FFF0F0")!
        }
        return colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard
    }

    private var hasHoliday: Bool {
        holidays.contains { $0.isHoliday }
    }

    private var mutedHolidayColor: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted
    }

    private func todoColor(for status: TodoStatus) -> Color {
        switch status {
        case .todo: return .blue
        case .inProgress: return .orange
        case .done: return .green
        }
    }

    private func otherDutyLabel(_ other: OtherDutySummary) -> String {
        if let dutyType = other.dutyType, !dutyType.isEmpty {
            return dutyType
        }
        return other.isOff ? "OFF" : "-"
    }

    private func schedulePreviewText(_ schedule: Schedule) -> String {
        let timeText = scheduleTimeSuffix(schedule)
        let progressText = scheduleProgressSuffix(schedule)
        return "\(schedule.content)\(timeText)\(progressText)"
    }

    private func scheduleTimeSuffix(_ schedule: Schedule) -> String {
        guard let start = parseDateTime(schedule.startDateTime),
              let end = parseDateTime(schedule.endDateTime) else {
            return ""
        }
        let dayInfo = scheduleDayInfo(schedule, start: start, end: end)
        let daysFromStart = schedule.daysFromStart ?? dayInfo?.daysFromStart
        let totalDays = schedule.totalDays ?? dayInfo?.totalDays
        guard let daysFromStart, let totalDays else { return "" }

        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: start)
        let startMinute = calendar.component(.minute, from: start)
        let endHour = calendar.component(.hour, from: end)
        let endMinute = calendar.component(.minute, from: end)

        let startTime = String(format: "%02d:%02d", startHour, startMinute)
        let endTime = String(format: "%02d:%02d", endHour, endMinute)

        let isStartMidnight = startHour == 0 && startMinute == 0
        let isEndMidnight = endHour == 0 && endMinute == 0
        let isSameDateTime = start == end

        let showStartTime = daysFromStart == 1 && !isStartMidnight
        let showEndTime = daysFromStart == totalDays && !isEndMidnight && !(totalDays == 1 && isSameDateTime)

        if showStartTime && showEndTime {
            return "(\(startTime)~\(endTime))"
        }
        if showStartTime {
            return "(\(startTime))"
        }
        if showEndTime {
            return "(~\(endTime))"
        }
        return ""
    }

    private func scheduleProgressSuffix(_ schedule: Schedule) -> String {
        let start = parseDateTime(schedule.startDateTime)
        let end = parseDateTime(schedule.endDateTime)
        let dayInfo = (start != nil && end != nil) ? scheduleDayInfo(schedule, start: start!, end: end!) : nil
        let daysFromStart = schedule.daysFromStart ?? dayInfo?.daysFromStart
        let totalDays = schedule.totalDays ?? dayInfo?.totalDays
        guard let daysFromStart, let totalDays,
              totalDays > 1 else {
            return ""
        }
        return " (\(daysFromStart)/\(totalDays))"
    }

    private func scheduleDayInfo(_ schedule: Schedule, start: Date, end: Date) -> (daysFromStart: Int, totalDays: Int)? {
        var components = DateComponents()
        components.year = schedule.year
        components.month = schedule.month
        components.day = schedule.dayOfMonth
        let calendar = Calendar.current
        guard let current = calendar.date(from: components) else { return nil }

        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let currentDay = calendar.startOfDay(for: current)

        let daysFromStart = (calendar.dateComponents([.day], from: startDay, to: currentDay).day ?? 0) + 1
        let totalDays = (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1
        return (daysFromStart, totalDays)
    }

    private func parseDateTime(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

struct DutyFilterSheet: View {
    @Binding var showTodoTodo: Bool
    @Binding var selectedDutyTypeFilters: Set<String>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("할일 표시") {
                    Toggle("할일 표시", isOn: $showTodoTodo)
                }

                Section("근무 필터") {
                    if selectedDutyTypeFilters.isEmpty {
                        Text("선택된 필터가 없습니다.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(selectedDutyTypeFilters).sorted(), id: \.self) { dutyType in
                            Text(dutyType)
                        }
                    }

                    Button("필터 초기화") {
                        selectedDutyTypeFilters.removeAll()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("필터")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DutyView()
        .environmentObject(AuthManager.shared)
}
