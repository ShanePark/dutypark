import SwiftUI

struct AddDDaySheet: View {
    @ObservedObject var viewModel: DDayViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Date()
    @State private var isPrivate = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("D-Day 정보") {
                    TextField("제목", text: $title)

                    DatePicker("날짜", selection: $date, displayedComponents: .date)

                    Toggle("비공개", isOn: $isPrivate)
                }

                Section {
                    // Preview
                    HStack {
                        Text("미리보기")
                            .foregroundColor(.secondary)

                        Spacer()

                        DDayBadge(daysLeft: calculateDaysLeft())
                    }
                }
            }
            .navigationTitle("D-Day 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        saveDDay()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }

    private func calculateDaysLeft() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: today, to: target)
        return components.day ?? 0
    }

    private func saveDDay() {
        isSaving = true
        Task {
            let success = await viewModel.createDDay(title: title, date: date, isPrivate: isPrivate)
            if success {
                dismiss()
            }
            isSaving = false
        }
    }
}

#Preview {
    AddDDaySheet(viewModel: DDayViewModel())
}
