import SwiftUI
import UIKit

struct DutyTypeEditorSheet: View {
    let dutyType: DutyTypeDto?
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: Color

    init(dutyType: DutyTypeDto?, onSave: @escaping (String, String) -> Void) {
        self.dutyType = dutyType
        self.onSave = onSave
        _name = State(initialValue: dutyType?.name ?? "")
        if let hex = dutyType?.color, let color = Color(hex: hex) {
            _color = State(initialValue: color)
        } else {
            _color = State(initialValue: .blue)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("근무명") {
                    TextField("근무명 입력", text: $name)
                }

                Section("색상") {
                    ColorPicker("색상 선택", selection: $color, supportsOpacity: false)
                }
            }
            .navigationTitle(dutyType == nil ? "근무 유형 추가" : "근무 유형 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(name, colorHex(color))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func colorHex(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

#Preview {
    DutyTypeEditorSheet(dutyType: nil) { _, _ in }
}
