import SwiftUI

struct ScheduleEditView: View {
    @Environment(\.dismiss) private var dismiss
    let date: Date
    let onSave: () -> Void

    @State private var content = ""
    @State private var startTime: Date?
    @State private var endTime: Date?
    @State private var showStartTimePicker = false
    @State private var showEndTimePicker = false
    @State private var isSaving = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("날짜") {
                    Text(dateFormatter.string(from: date))
                }

                Section("내용") {
                    TextField("일정 내용을 입력하세요", text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("시간 (선택)") {
                    Toggle("시작 시간", isOn: $showStartTimePicker)

                    if showStartTimePicker {
                        DatePicker(
                            "시작",
                            selection: Binding(
                                get: { startTime ?? Date() },
                                set: { startTime = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }

                    Toggle("종료 시간", isOn: $showEndTimePicker)

                    if showEndTimePicker {
                        DatePicker(
                            "종료",
                            selection: Binding(
                                get: { endTime ?? Date() },
                                set: { endTime = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
            }
            .navigationTitle("새 일정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task {
                            await saveSchedule()
                        }
                    }
                    .disabled(content.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveSchedule() async {
        isSaving = true
        defer { isSaving = false }

        let apiDateFormatter = DateFormatter()
        apiDateFormatter.dateFormat = "yyyy-MM-dd"

        let request = CreateScheduleRequest(
            content: content,
            date: apiDateFormatter.string(from: date),
            startTime: showStartTimePicker ? startTime.map { timeFormatter.string(from: $0) } : nil,
            endTime: showEndTimePicker ? endTime.map { timeFormatter.string(from: $0) } : nil,
            taggedFriendIds: nil
        )

        do {
            _ = try await APIClient.shared.request(
                .createSchedule(request: request),
                responseType: Schedule.self
            )
            onSave()
            dismiss()
        } catch {
            // TODO: Show error alert
        }
    }
}

#Preview {
    ScheduleEditView(date: Date()) {}
}
