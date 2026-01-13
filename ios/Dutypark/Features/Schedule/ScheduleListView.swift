import SwiftUI

struct ScheduleListView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var selectedDate = Date()
    @State private var showingAddSheet = false
    @State private var showingSearchSheet = false
    @State private var scheduleToEdit: Schedule?
    @State private var showDeleteConfirmation = false
    @State private var scheduleToDelete: Schedule?

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
                    ForEach(groupedSchedules.keys.sorted(), id: \.self) { dateKey in
                        Section(header: Text(formatDateHeader(dateKey))) {
                            ForEach(groupedSchedules[dateKey] ?? []) { schedule in
                                scheduleRow(schedule)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        scheduleToEdit = schedule
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            scheduleToDelete = schedule
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }

                                        Button {
                                            scheduleToEdit = schedule
                                        } label: {
                                            Label("수정", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("일정")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingSearchSheet = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }

                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
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
                ScheduleEditView(viewModel: viewModel, initialDate: selectedDate) {
                    Task {
                        await viewModel.loadSchedules(for: selectedDate)
                    }
                }
            }
            .sheet(item: $scheduleToEdit) { schedule in
                ScheduleEditView(viewModel: viewModel, schedule: schedule, initialDate: selectedDate) {
                    Task {
                        await viewModel.loadSchedules(for: selectedDate)
                    }
                }
            }
            .sheet(isPresented: $showingSearchSheet) {
                ScheduleSearchView(memberId: getCurrentMemberId())
            }
            .alert("일정 삭제", isPresented: $showDeleteConfirmation, presenting: scheduleToDelete) { schedule in
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) {
                    Task {
                        _ = await viewModel.deleteSchedule(schedule)
                    }
                }
            } message: { schedule in
                Text("'\(schedule.content)' 일정을 삭제하시겠습니까?")
            }
        }
    }

    private var groupedSchedules: [String: [Schedule]] {
        Dictionary(grouping: viewModel.schedules, by: { schedule in
            String(format: "%04d-%02d-%02d", schedule.year, schedule.month, schedule.dayOfMonth)
        })
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
                Text(schedule.content)
                    .font(.body)
                Spacer()
                if let visibility = schedule.visibility {
                    Image(systemName: visibility.iconName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let description = schedule.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !schedule.tags.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text(schedule.tags.map(\.memberName).joined(separator: ", "))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            if !schedule.attachments.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "paperclip")
                        .font(.caption2)
                    Text("\(schedule.attachments.count)개의 첨부파일")
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

    private func getCurrentMemberId() -> Int {
        return AuthManager.shared.currentUser?.id ?? 0
    }
}

// MARK: - Schedule Search View

struct ScheduleSearchView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var searchQuery = ""
    @State private var hasSearched = false
    let memberId: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    SearchBar(text: $searchQuery, placeholder: "검색어 입력...") {
                        performSearch()
                    }

                    Button {
                        performSearch()
                    } label: {
                        Text("검색")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(DesignSystem.Colors.accent)
                            .cornerRadius(10)
                    }
                }
                .padding()

                if hasSearched && !searchQuery.isEmpty {
                    Text("\"\(searchQuery)\" 검색 결과 \(viewModel.searchResults.count)건")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                if viewModel.isSearching {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !searchQuery.isEmpty && hasSearched {
                    Spacer()
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "검색 결과가 없습니다",
                        message: "다른 검색어로 시도해보세요"
                    )
                    Spacer()
                } else if searchQuery.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "검색어를 입력해주세요",
                        message: "검색어를 입력하면 일정을 찾을 수 있습니다."
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.searchResults) { schedule in
                                ScheduleSearchResultRow(schedule: schedule)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("검색 결과")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                }
            }
        }
    }

    private func performSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            hasSearched = false
            return
        }
        hasSearched = true
        Task { await viewModel.searchSchedules(memberId: memberId, query: query) }
    }
}

struct ScheduleSearchResultRow: View {
    let schedule: Schedule
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(schedule.content)
                    .font(.headline)
                Spacer()
                if let visibility = schedule.visibility {
                    VisibilityBadge(visibility: visibility)
                }
            }

            Text(formatDateTimeRange())
                .font(.caption)
                .foregroundColor(.secondary)

            if let description = schedule.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !schedule.tags.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text(schedule.tags.map(\.memberName).joined(separator: ", "))
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
        .cornerRadius(12)
        .shadow(color: DesignSystem.Shadow.sm(colorScheme), radius: 2, x: 0, y: 1)
    }

    private func formatDateTimeRange() -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        guard let start = inputFormatter.date(from: schedule.startDateTime),
              let end = inputFormatter.date(from: schedule.endDateTime) else {
            return "\(schedule.year)-\(String(format: "%02d", schedule.month))-\(String(format: "%02d", schedule.dayOfMonth))"
        }

        let dateText = dateFormatter.string(from: start)
        let startText = timeFormatter.string(from: start)
        let endText = timeFormatter.string(from: end)
        return "\(dateText) \(startText) ~ \(endText)"
    }
}

#Preview {
    ScheduleListView()
}
