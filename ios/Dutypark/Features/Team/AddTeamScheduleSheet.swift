import SwiftUI

struct AddTeamScheduleSheet: View {
    @ObservedObject var viewModel: TeamViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var content = ""
    @State private var description = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("일정 내용") {
                    TextField("제목", text: $content)
                    TextField("설명 (선택)", text: $description)
                }

                Section("기간") {
                    DatePicker("시작일", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("종료일", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("팀 일정 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        saveSchedule()
                    }
                    .disabled(content.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveSchedule() {
        isSaving = true
        Task {
            let success = await viewModel.createTeamSchedule(
                content: content,
                description: description.isEmpty ? nil : description,
                startDate: startDate,
                endDate: endDate
            )
            if success {
                dismiss()
            }
            isSaving = false
        }
    }
}
