import SwiftUI

struct DutyView: View {
    @StateObject private var viewModel = DutyViewModel()
    @State private var selectedDate = Date()

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthSelector
                weekdayHeader
                calendarGrid
                Spacer()
            }
            .navigationTitle("근무표")
            .task {
                await viewModel.loadDuties(for: selectedDate)
            }
            .onChange(of: selectedDate) { _, newDate in
                Task {
                    await viewModel.loadDuties(for: newDate)
                }
            }
        }
    }

    private var monthSelector: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(dateFormatter.string(from: selectedDate))
                .font(.headline)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding()
    }

    private var weekdayHeader: some View {
        let weekdays = ["일", "월", "화", "수", "목", "금", "토"]
        return HStack {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(day == "일" ? .red : (day == "토" ? .blue : .primary))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var calendarGrid: some View {
        let days = generateDaysInMonth()
        let columns = Array(repeating: GridItem(.flexible()), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .frame(height: 60)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let day = calendar.component(.day, from: date)
        let dateString = formatDateForAPI(date)
        let duty = viewModel.duties[dateString]
        let isToday = calendar.isDateInToday(date)
        let weekday = calendar.component(.weekday, from: date)

        VStack(spacing: 4) {
            Text("\(day)")
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(weekday == 1 ? .red : (weekday == 7 ? .blue : .primary))

            if let duty = duty {
                Text(duty.shortName ?? String(duty.name.prefix(2)))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(Color(hex: duty.color) ?? .gray)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .background(isToday ? Color.blue.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func moveMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func generateDaysInMonth() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: selectedDate),
              let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }

        return days
    }

    private func formatDateForAPI(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

#Preview {
    DutyView()
}
