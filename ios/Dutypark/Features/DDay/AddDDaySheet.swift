import SwiftUI

struct AddDDaySheet: View {
    @ObservedObject var viewModel: DDayViewModel
    @Environment(\.dismiss) private var dismiss

    // Optional existing D-Day for edit mode
    var ddayToEdit: DDayDto?

    @State private var title = ""
    @State private var date = Date()
    @State private var isPrivate = false
    @State private var isSaving = false

    private var isEditMode: Bool {
        ddayToEdit != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("D-Day 정보") {
                    TextField("제목", text: $title)
                        .onChange(of: title) { _, newValue in
                            if newValue.count > 30 {
                                title = String(newValue.prefix(30))
                            }
                        }

                    HStack {
                        Text("제목")
                            .foregroundColor(.clear)
                        Spacer()
                        Text("\(title.count)/30")
                            .font(.caption)
                            .foregroundColor(title.count >= 30 ? .red : .secondary)
                    }
                    .listRowInsets(EdgeInsets(top: -8, leading: 16, bottom: 8, trailing: 16))

                    DatePicker("날짜", selection: $date, displayedComponents: .date)

                    // Quick date adjustment buttons
                    HStack(spacing: 8) {
                        quickDateButton("-7일", days: -7)
                        quickDateButton("-1일", days: -1)
                        quickDateButton("오늘", days: nil)
                        quickDateButton("+1일", days: 1)
                        quickDateButton("+7일", days: 7)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

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
            .navigationTitle(isEditMode ? "D-Day 수정" : "D-Day 추가")
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
            .onAppear {
                if let dday = ddayToEdit {
                    title = dday.title
                    isPrivate = dday.isPrivate
                    // Parse date from string
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let parsedDate = formatter.date(from: dday.date) {
                        date = parsedDate
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func quickDateButton(_ label: String, days: Int?) -> some View {
        Button {
            if let days = days {
                date = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
            } else {
                date = Date()
            }
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
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
            let success: Bool
            if let existingDDay = ddayToEdit {
                success = await viewModel.updateDDay(id: existingDDay.id, title: title, date: date, isPrivate: isPrivate)
            } else {
                success = await viewModel.createDDay(title: title, date: date, isPrivate: isPrivate)
            }
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
