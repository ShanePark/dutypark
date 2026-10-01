import SwiftUI

nonisolated extension DutyTypeColorPalette {
    static let sundayColor = Color(red: Double(0x99) / 255, green: Double(0x1B) / 255, blue: Double(0x1B) / 255)
    static let saturdayColor = Color(red: Double(0x1E) / 255, green: Double(0x40) / 255, blue: Double(0xAF) / 255)
}

struct DPDutyTypeColorPicker: View {
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
            Text("team.dutyType.fields.color", tableName: "Team")
                .font(DPTypography.label)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DPSpacing.small) {
                ForEach(DutyTypeColorPalette.options) { option in
                    Button {
                        select(option.hex)
                    } label: {
                        HStack(spacing: DPSpacing.small) {
                            Circle()
                                .fill(Color(teamHex: option.hex))
                                .frame(width: 24, height: 24)
                                .overlay { Circle().stroke(DPColor.borderSecondary) }
                            Text(LocalizedStringKey(option.localizationKey), tableName: "Team")
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if isSelected(option.hex) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(DPColor.textPrimary)
                            }
                        }
                        .padding(.horizontal, DPSpacing.small)
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                        .background(DPColor.backgroundInput)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.small))
                        .overlay {
                            RoundedRectangle(cornerRadius: DPRadius.small)
                                .stroke(isSelected(option.hex) ? DPColor.textPrimary : DPColor.borderSecondary, lineWidth: isSelected(option.hex) ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringKey(option.localizationKey), tableName: "Team"))
                    .accessibilityAddTraits(isSelected(option.hex) ? .isSelected : [])
                    .accessibilityIdentifier("team.dutyType.color.\(option.name)")
                }
                ColorPicker(selection: customColor, supportsOpacity: false) {
                    HStack(spacing: DPSpacing.extraSmall) {
                        Text("team.dutyType.palette.custom", tableName: "Team")
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textPrimary)
                            .lineLimit(1)
                        if !DutyTypeColorPalette.contains(selection) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DPColor.textPrimary)
                        }
                    }
                }
                .padding(.horizontal, DPSpacing.small)
                .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                .background(DPColor.backgroundInput)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.small))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.small)
                        .stroke(!DutyTypeColorPalette.contains(selection) ? DPColor.textPrimary : DPColor.borderSecondary, lineWidth: !DutyTypeColorPalette.contains(selection) ? 2 : 1)
                }
                .accessibilityLabel(Text("team.dutyType.palette.custom", tableName: "Team"))
                .accessibilityAddTraits(!DutyTypeColorPalette.contains(selection) ? .isSelected : [])
                .accessibilityIdentifier("team.dutyType.color.custom")
            }
        }
    }

    private var customColor: Binding<Color> {
        Binding {
            Color(teamHex: selection)
        } set: { color in
            let uiColor = UIColor(color)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return }
            select(String(format: "#%02X%02X%02X", Int(round(red * 255)), Int(round(green * 255)), Int(round(blue * 255))))
        }
    }

    private func isSelected(_ hex: String) -> Bool {
        hex.caseInsensitiveCompare(selection) == .orderedSame
    }

    private func select(_ hex: String) {
        guard DutyTypeColorPalette.shouldSelect(hex, current: selection) else { return }
        selection = hex
        DPHapticCenter.shared.emit(.selection)
    }
}
