import SwiftUI

struct ScheduleEditView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss

    let existingSchedule: Schedule?
    let initialDate: Date
    let onSave: () -> Void

    @State private var content: String
    @State private var description: String
    @State private var date: Date
    @State private var hasStartTime: Bool
    @State private var hasEndTime: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var visibility: CalendarVisibility
    @State private var selectedFriendIds: Set<Int>
    @State private var isSaving = false
    @State private var showFriendPicker = false

    var isEditing: Bool { existingSchedule != nil }

    private let calendar = Calendar.current

    init(viewModel: ScheduleViewModel, schedule: Schedule? = nil, initialDate: Date = Date(), onSave: @escaping () -> Void) {
        self.viewModel = viewModel
        self.existingSchedule = schedule
        self.initialDate = initialDate
        self.onSave = onSave

        let now = Date()
        if let schedule = schedule {
            _content = State(initialValue: schedule.content)
            _description = State(initialValue: schedule.description ?? "")
            _date = State(initialValue: Self.parseDate(schedule.startDateTime) ?? now)
            _hasStartTime = State(initialValue: schedule.startTime != nil)
            _hasEndTime = State(initialValue: schedule.endTime != nil)
            _startTime = State(initialValue: Self.parseTimeToDate(schedule.startTime) ?? now)
            _endTime = State(initialValue: Self.parseTimeToDate(schedule.endTime) ?? now)
            _visibility = State(initialValue: schedule.visibility ?? .friends)
            _selectedFriendIds = State(initialValue: Set(schedule.tags.map { $0.memberId }))
        } else {
            _content = State(initialValue: "")
            _description = State(initialValue: "")
            _date = State(initialValue: initialDate)
            _hasStartTime = State(initialValue: false)
            _hasEndTime = State(initialValue: false)
            _startTime = State(initialValue: now)
            _endTime = State(initialValue: now)
            _visibility = State(initialValue: .private)
            _selectedFriendIds = State(initialValue: [])
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("날짜") {
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                }

                Section("내용") {
                    TextField("일정 제목을 입력하세요", text: $content, axis: .vertical)
                        .lineLimit(1...3)
                    TextField("상세 설명 (선택)", text: $description, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section("시간 (선택)") {
                    Toggle("시작 시간", isOn: $hasStartTime)

                    if hasStartTime {
                        DatePicker(
                            "시작",
                            selection: $startTime,
                            displayedComponents: .hourAndMinute
                        )
                    }

                    Toggle("종료 시간", isOn: $hasEndTime)

                    if hasEndTime {
                        DatePicker(
                            "종료",
                            selection: $endTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                Section("공개 범위") {
                    Picker("공개 범위", selection: $visibility) {
                        Text("전체 공개").tag(CalendarVisibility.public)
                        Text("친구에게만").tag(CalendarVisibility.friends)
                        Text("가족에게만").tag(CalendarVisibility.family)
                        Text("비공개").tag(CalendarVisibility.private)
                    }
                }

                Section("친구 태그") {
                    Button {
                        showFriendPicker = true
                    } label: {
                        HStack {
                            Text("친구 선택")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(selectedFriendIds.count)명")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !selectedFriendIds.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.friends.filter { selectedFriendIds.contains($0.id) }) { friend in
                                    HStack(spacing: 4) {
                                        Text(friend.name)
                                            .font(.caption)
                                        Button {
                                            selectedFriendIds.remove(friend.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "일정 수정" : "새 일정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "저장" : "추가") {
                        saveSchedule()
                    }
                    .disabled(content.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showFriendPicker) {
                FriendPickerSheet(friends: viewModel.friends, selectedIds: $selectedFriendIds)
            }
            .task {
                await viewModel.loadFriends()
            }
        }
    }

    private func saveSchedule() {
        isSaving = true
        Task {
            let success: Bool
            if let schedule = existingSchedule {
                success = await viewModel.updateSchedule(
                    id: schedule.id,
                    content: content,
                    description: description.isEmpty ? nil : description,
                    date: date,
                    startTime: hasStartTime ? startTime : nil,
                    endTime: hasEndTime ? endTime : nil,
                    visibility: visibility,
                    taggedFriendIds: Array(selectedFriendIds)
                )
            } else {
                success = await viewModel.createSchedule(
                    content: content,
                    description: description.isEmpty ? nil : description,
                    date: date,
                    startTime: hasStartTime ? startTime : nil,
                    endTime: hasEndTime ? endTime : nil,
                    visibility: visibility,
                    taggedFriendIds: Array(selectedFriendIds)
                )
            }
            if success {
                onSave()
                dismiss()
            }
            isSaving = false
        }
    }

    private static func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: dateString)
    }

    private static func parseTimeToDate(_ timeString: String?) -> Date? {
        guard let timeString = timeString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeString)
    }
}

struct FriendPickerSheet: View {
    let friends: [Friend]
    @Binding var selectedIds: Set<Int>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(friends) { friend in
                Button {
                    if selectedIds.contains(friend.id) {
                        selectedIds.remove(friend.id)
                    } else {
                        selectedIds.insert(friend.id)
                    }
                } label: {
                    HStack {
                        ProfileAvatar(
                            memberId: friend.id,
                            name: friend.name,
                            hasProfilePhoto: friend.hasProfilePhoto ?? false,
                            profilePhotoVersion: friend.profilePhotoVersion,
                            size: 36
                        )

                        VStack(alignment: .leading) {
                            Text(friend.name)
                                .foregroundColor(.primary)
                            if let team = friend.team {
                                Text(team)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        if selectedIds.contains(friend.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("친구 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ScheduleEditView(viewModel: ScheduleViewModel(), initialDate: Date()) {}
}
