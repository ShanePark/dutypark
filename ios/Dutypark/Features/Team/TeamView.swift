import SwiftUI

struct TeamView: View {
    @StateObject private var viewModel = TeamViewModel()
    @Environment(\.colorScheme) var colorScheme
    @State private var showShiftDetail = false
    @State private var showAddSchedule = false
    @State private var selectedDay: Int?

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? DesignSystem.Colors.Dark.bgPrimary : DesignSystem.Colors.Light.bgSecondary)
                    .ignoresSafeArea()

                if let team = viewModel.teamSummary?.team {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header with team selector
                            headerSection(team)

                            // Weekday headers
                            weekdayHeaders

                            // Calendar grid
                            calendarGrid

                            // Selected day detail section
                            selectedDaySection
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        await viewModel.loadTeamData()
                    }
                } else if !viewModel.isLoading {
                    EmptyStateView(
                        icon: "person.3.slash",
                        title: "소속 팀이 없습니다",
                        message: "팀에 가입하면 팀 일정을 확인할 수 있습니다"
                    )
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showShiftDetail) {
                if let day = selectedDay {
                    ShiftDetailSheet(
                        viewModel: viewModel,
                        year: viewModel.selectedYear,
                        month: viewModel.selectedMonth,
                        day: day
                    )
                }
            }
            .sheet(isPresented: $showAddSchedule) {
                AddTeamScheduleSheet(viewModel: viewModel)
            }
            .task {
                await viewModel.loadTeamData()
            }
            .loading(viewModel.isLoading)
        }
    }

    // MARK: - Header Section
    private func headerSection(_ team: TeamDto) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Team selector
            Button {
                // Show team selector
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "building.2")
                        .font(.subheadline)
                    Text(team.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgCard)
                .cornerRadius(DesignSystem.CornerRadius.sm)
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

                Text("\(viewModel.selectedYear)-\(String(format: "%02d", viewModel.selectedMonth))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                Button {
                    viewModel.nextMonth()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                }
            }

            Spacer()

            // Settings button
            if viewModel.teamSummary?.isTeamManager == true,
               let teamId = viewModel.teamSummary?.team?.id {
                NavigationLink(destination: TeamManageView(teamId: teamId)) {
                    Image(systemName: "gearshape")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
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
                    let holidays = viewModel.holidays[dayInfo.day] ?? []
                    TeamDayCell(
                        day: dayInfo.day,
                        isToday: isToday(dayInfo.day),
                        weekdayIndex: index % 7,
                        hasTeamSchedule: viewModel.teamSummary?.teamDays.contains(where: { $0.day == dayInfo.day }) ?? false,
                        isSelected: selectedDay == dayInfo.day,
                        holidays: holidays
                    )
                    .onTapGesture {
                        selectedDay = dayInfo.day
                        Task {
                            await viewModel.loadShiftForDay(dayInfo.day)
                        }
                    }
                } else {
                    Rectangle()
                        .fill(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                        .frame(height: 70)
                }
            }
        }
        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.borderPrimary : DesignSystem.Colors.Light.borderPrimary)
        .cornerRadius(DesignSystem.CornerRadius.sm, corners: [.bottomLeft, .bottomRight])
    }

    // MARK: - Selected Day Section
    private var selectedDaySection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Selected date display
            if let day = selectedDay {
                Text("\(viewModel.selectedYear)년 \(viewModel.selectedMonth)월 \(day)일")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSystem.Spacing.lg)
                    .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgCard)
                    .cornerRadius(DesignSystem.CornerRadius.md)
            }

            // Add team schedule button
            if viewModel.teamSummary?.isTeamManager == true {
                Button {
                    showAddSchedule = true
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text("팀 일정 추가")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                    .background(DesignSystem.Colors.success)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
            }

            // Team schedules for selected day
            if let day = selectedDay {
                let schedules = viewModel.teamSchedules.filter { $0.dayOfMonth == day }
                if schedules.isEmpty {
                    Text("이 날의 팀 일정이 없습니다.")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.xl)
                } else {
                    ForEach(schedules) { schedule in
                        TeamScheduleCard(
                            schedule: schedule,
                            canDelete: viewModel.teamSummary?.isTeamManager == true
                        ) {
                            Task { await viewModel.deleteTeamSchedule(schedule.id) }
                        }
                    }
                }
            }

            // Team members section
            if !viewModel.shiftData.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    ForEach(viewModel.shiftData, id: \.dutyType.name) { shift in
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            // Duty type label
                            Text(shift.dutyType.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach(shift.members) { member in
                                        TeamMemberChip(member: member)
                                    }
                                }
                            }
                        }
                    }
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
}

// MARK: - Team Day Cell
struct TeamDayCell: View {
    let day: Int
    let isToday: Bool
    let weekdayIndex: Int
    let hasTeamSchedule: Bool
    let isSelected: Bool
    let holidays: [HolidayDto]
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text("\(day)")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(textColor)

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

            if hasTeamSchedule {
                Circle()
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: 6, height: 6)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(height: 70)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .stroke(isToday ? DesignSystem.Colors.sunday : Color.clear, lineWidth: 2)
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
        if isSelected {
            return DesignSystem.Colors.accent.opacity(0.1)
        }
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
}

// MARK: - Team Member Chip
struct TeamMemberChip: View {
    let member: SimpleMemberDto
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ProfileAvatar(
                memberId: member.id,
                name: member.name,
                hasProfilePhoto: member.hasProfilePhoto ?? false,
                profilePhotoVersion: member.profilePhotoVersion,
                size: 24
            )

            Text(member.name)
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgCard)
        .cornerRadius(DesignSystem.CornerRadius.full)
    }
}

#Preview {
    TeamView()
}
