import SwiftUI

struct ScheduleListView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var selectedDate = Date()
    @State private var showingAddSheet = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                if viewModel.schedules.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "일정이 없습니다",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("이번 달 일정을 추가해보세요")
                    )
                } else {
                    ForEach(groupedSchedules.keys.sorted(), id: \.self) { date in
                        Section(header: Text(formatDateHeader(date))) {
                            ForEach(groupedSchedules[date] ?? []) { schedule in
                                scheduleRow(schedule)
                            }
                        }
                    }
                }
            }
            .navigationTitle("일정")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("이전 달") {
                            moveMonth(by: -1)
                        }
                        Button("다음 달") {
                            moveMonth(by: 1)
                        }
                        Button("오늘") {
                            selectedDate = Date()
                        }
                    } label: {
                        Text(dateFormatter.string(from: selectedDate))
                    }
                }
            }
            .refreshable {
                await viewModel.loadSchedules(for: selectedDate)
            }
            .task {
                await viewModel.loadSchedules(for: selectedDate)
            }
            .onChange(of: selectedDate) { _, newDate in
                Task {
                    await viewModel.loadSchedules(for: newDate)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                ScheduleEditView(date: selectedDate) {
                    Task {
                        await viewModel.loadSchedules(for: selectedDate)
                    }
                }
            }
        }
    }

    private var groupedSchedules: [String: [Schedule]] {
        Dictionary(grouping: viewModel.schedules, by: { $0.date })
    }

    @ViewBuilder
    private func scheduleRow(_ schedule: Schedule) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let startTime = schedule.startTime {
                    Text(startTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(schedule.contentWithoutTime ?? schedule.content)
                    .font(.body)
            }

            if let taggedFriends = schedule.taggedFriends, !taggedFriends.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text(taggedFriends.map(\.name).joined(separator: ", "))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            if schedule.attachmentCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "paperclip")
                        .font(.caption2)
                    Text("\(schedule.attachmentCount)개의 첨부파일")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDateHeader(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "M월 d일 (E)"
        displayFormatter.locale = Locale(identifier: "ko_KR")
        return displayFormatter.string(from: date)
    }

    private func moveMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

#Preview {
    ScheduleListView()
}
