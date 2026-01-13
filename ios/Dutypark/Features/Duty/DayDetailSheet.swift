import SwiftUI

struct DayDetailSheet: View {
    @ObservedObject var viewModel: DutyViewModel
    let day: Int
    @Environment(\.dismiss) private var dismiss
    @State private var showAddSchedule = false
    @State private var scheduleToEdit: Schedule?
    @State private var showEditSchedule = false
    @State private var todoToEdit: Todo?
    @State private var showTodoDetail = false
    @StateObject private var scheduleViewModel = ScheduleViewModel()
    @StateObject private var todoViewModel = TodoViewModel()

    private var initialDate: Date {
        var components = DateComponents()
        components.year = viewModel.selectedYear
        components.month = viewModel.selectedMonth
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dateHeader

                    if viewModel.canManage {
                        dutyQuickButtons
                    }

                    schedulesSection

                    if let todos = viewModel.todosByDay[day], !todos.isEmpty {
                        todosSection(todos)
                    }
                }
                .padding()
            }
            .navigationTitle("\(viewModel.selectedMonth)월 \(day)일")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddSchedule) {
                ScheduleEditView(
                    viewModel: scheduleViewModel,
                    initialDate: initialDate
                ) {
                    Task { await viewModel.loadDutyData() }
                }
            }
            .sheet(isPresented: $showEditSchedule) {
                if let schedule = scheduleToEdit {
                    ScheduleEditView(
                        viewModel: scheduleViewModel,
                        schedule: schedule,
                        initialDate: initialDate
                    ) {
                        Task { await viewModel.loadDutyData() }
                    }
                }
            }
            .sheet(isPresented: $showTodoDetail) {
                if let todo = todoToEdit {
                    TodoDetailSheet(viewModel: todoViewModel, todo: todo)
                }
            }
        }
    }

    private var dateHeader: some View {
        VStack(spacing: 8) {
            if let duty = viewModel.duties[day] {
                HStack {
                    Circle()
                        .fill(Color(hex: duty.dutyColor ?? "#gray") ?? .gray)
                        .frame(width: 16, height: 16)

                    Text(duty.dutyType ?? "")
                        .font(.headline)

                    Spacer()
                }
                .padding()
                .background((Color(hex: duty.dutyColor ?? "#gray") ?? .gray).opacity(0.1))
                .cornerRadius(12)
            }

            if let holidayName = viewModel.holidays[day] {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.red)
                    Text(holidayName)
                        .font(.subheadline)
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        }
    }

    private var dutyQuickButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("근무 변경")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.changeDuty(day: day, dutyTypeId: nil) }
                    } label: {
                        Text("OFF")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.gray)
                            .cornerRadius(8)
                    }

                    ForEach(viewModel.dutyTypes, id: \.id) { dutyType in
                        Button {
                            Task { await viewModel.changeDuty(day: day, dutyTypeId: dutyType.id) }
                        } label: {
                            Text(dutyType.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(dutyType.swiftUIColor.opacity(0.3))
                                .foregroundColor(dutyType.swiftUIColor)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isCurrentDuty(dutyType) ? Color.orange : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
            }
        }
    }

    private var schedulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("일정")
                    .font(.headline)

                Spacer()

                Button {
                    showAddSchedule = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }

            if let schedules = viewModel.schedulesByDay[day], !schedules.isEmpty {
                ForEach(schedules) { schedule in
                    ScheduleCard(schedule: schedule)
                        .onTapGesture {
                            scheduleToEdit = schedule
                            showEditSchedule = true
                        }
                }
            } else {
                Text("일정이 없습니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }

    private func todosSection(_ todos: [Todo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("할 일")
                .font(.headline)

            ForEach(todos) { todo in
                HStack {
                    TodoStatusBadge(status: todo.status, showLabel: false)

                    Text(todo.title)
                        .font(.subheadline)

                    Spacer()

                    if todo.isOverdue {
                        Text("지남")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .onTapGesture {
                    todoToEdit = todo
                    showTodoDetail = true
                }
            }
        }
    }

    private func isCurrentDuty(_ dutyType: DutyType) -> Bool {
        guard let currentDuty = viewModel.duties[day] else { return false }
        return currentDuty.dutyType == dutyType.name
    }
}

struct ScheduleCard: View {
    let schedule: Schedule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(schedule.content)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if let visibility = schedule.visibility {
                    VisibilityBadge(visibility: visibility)
                }
            }

            if let description = schedule.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                if let startTime = schedule.startTime {
                    Text(startTime)
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                if !schedule.tags.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.caption2)
                        Text("\(schedule.tags.count)")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    DayDetailSheet(viewModel: DutyViewModel(), day: 15)
}
