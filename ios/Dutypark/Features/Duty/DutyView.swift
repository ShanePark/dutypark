import SwiftUI

struct DutyView: View {
    @StateObject private var viewModel = DutyViewModel()
    @StateObject private var ddayViewModel = DDayViewModel()
    @Environment(\.colorScheme) var colorScheme
    @State private var showDayDetail = false
    @State private var selectedDay: Int = 0
    @State private var showAddDDay = false
    @State private var selectedDDayForEdit: DDayDto?
    @State private var showSearch = false

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
                    await viewModel.loadDutyData()
                    await ddayViewModel.loadDDays()
                }
            }
            .navigationBarHidden(true)
            .task {
                viewModel.memberId = AuthManager.shared.currentUser?.id
                await viewModel.loadDutyData()
                await ddayViewModel.loadDDays()
            }
            .loading(viewModel.isLoading && viewModel.duties.isEmpty)
            .sheet(isPresented: $showDayDetail) {
                DayDetailSheet(viewModel: viewModel, day: selectedDay)
            }
            .sheet(isPresented: $showAddDDay) {
                AddDDaySheet(viewModel: ddayViewModel, ddayToEdit: selectedDDayForEdit)
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
            if let user = AuthManager.shared.currentUser {
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
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Filter Buttons Section
    private var filterButtonsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Todo filter button
                FilterButton(title: "할일", isActive: false) {}

                // Add button
                Button {
                    // Add new schedule
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                        .padding(DesignSystem.Spacing.sm)
                        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }

                // Filter button
                Button {
                    // Show filters
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
                    FilterButton(title: dutyType, isActive: false) {}
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

            // Edit mode toggle
            Button {
                // Toggle edit mode
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "person.2")
                        .font(.caption)
                    Text("편집모드")
                        .font(.caption)
                }
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
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
                    DayCell(
                        day: dayInfo.day,
                        duty: viewModel.duties[dayInfo.day],
                        isHoliday: viewModel.holidays[dayInfo.day] != nil,
                        holidayName: viewModel.holidays[dayInfo.day],
                        isToday: isToday(dayInfo.day),
                        schedules: viewModel.schedulesByDay[dayInfo.day] ?? [],
                        todos: viewModel.todosByDay[dayInfo.day] ?? [],
                        weekdayIndex: index % 7
                    )
                    .onTapGesture {
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
                    DDayCard(dday: dday, onEdit: {
                        selectedDDayForEdit = dday
                        showAddDDay = true
                    }, onDelete: {
                        Task { await ddayViewModel.deleteDDay(dday.id) }
                    })
                }
            }

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
    let isHoliday: Bool
    let holidayName: String?
    let isToday: Bool
    let schedules: [Schedule]
    let todos: [Todo]
    let weekdayIndex: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Day number and holiday
            HStack {
                Text("\(day)")
                    .font(.caption)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(textColor)

                if isHoliday, let name = holidayName {
                    Text(name)
                        .font(.system(size: 8))
                        .foregroundColor(DesignSystem.Colors.sunday)
                        .lineLimit(1)
                }

                Spacer()
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

            Spacer()

            // Schedule previews
            VStack(alignment: .leading, spacing: 1) {
                ForEach(schedules.prefix(2)) { schedule in
                    Text(schedule.content)
                        .font(.system(size: 8))
                        .foregroundColor(DesignSystem.Colors.accent)
                        .lineLimit(1)
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
                        .background(DesignSystem.Colors.accent.opacity(0.1))
                        .cornerRadius(2)
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
                .stroke(isToday ? DesignSystem.Colors.sunday : Color.clear, lineWidth: 2)
        )
    }

    private var textColor: Color {
        if isHoliday || weekdayIndex == 0 {
            return DesignSystem.Colors.sunday
        } else if weekdayIndex == 6 {
            return DesignSystem.Colors.saturday
        }
        return colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary
    }

    private var backgroundColor: Color {
        if weekdayIndex == 0 || weekdayIndex == 6 || isHoliday {
            return colorScheme == .dark ? Color(hex: "#2D1F2F")! : Color(hex: "#FFF0F0")!
        }
        return colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard
    }

    private func todoColor(for status: TodoStatus) -> Color {
        switch status {
        case .todo: return .blue
        case .inProgress: return .orange
        case .done: return .green
        }
    }
}

#Preview {
    DutyView()
        .environmentObject(AuthManager.shared)
}
