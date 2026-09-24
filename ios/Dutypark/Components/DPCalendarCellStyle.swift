import SwiftUI

/// Shared colors and measurements for the month calendar grids.
nonisolated enum DPCalendarCellStyle {
    static let weekdayFontSize: CGFloat = 14
    static let dayNumberFontSize: CGFloat = 12
    static let weekdayHeaderBackground = DPColor.backgroundHover
    static let weekdayHeaderHeight: CGFloat = 34
    static let weekdaySeparatorColor = DPColor.borderSecondary
    static let weekdayBottomBorderHeight: CGFloat = 2
    static let cellSeparatorWidth: CGFloat = 0.5

    static func usesLightForeground(on hex: String?) -> Bool {
        guard let components = rgb(hex) else { return false }
        let luminance = (Double(components.red) * 299 + Double(components.green) * 587 + Double(components.blue) * 114) / 1_000
        return luminance <= 127.5
    }

    static func rgb(_ hex: String?) -> (red: UInt8, green: UInt8, blue: UInt8)? {
        guard var value = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        return (
            UInt8((number >> 16) & 0xFF),
            UInt8((number >> 8) & 0xFF),
            UInt8(number & 0xFF)
        )
    }

    static func cellBackground(dutyColor: String?, isCurrentMonth: Bool) -> Color {
        guard let components = rgb(dutyColor) else {
            return isCurrentMonth ? DPColor.backgroundCard : DPColor.backgroundSecondary
        }
        return Color(
            red: Double(components.red) / 255,
            green: Double(components.green) / 255,
            blue: Double(components.blue) / 255
        )
    }

    static func primaryForeground(dutyColor: String?) -> Color {
        guard dutyColor != nil else { return DPColor.textPrimary }
        return usesLightForeground(on: dutyColor) ? DPColor.textOnDark : DPColor.textOnLight
    }

    static func secondaryForeground(dutyColor: String?) -> Color {
        guard dutyColor != nil else { return DPColor.textMuted }
        return usesLightForeground(on: dutyColor) ? DPColor.textOnDarkMuted : DPColor.textMuted
    }

    static func cellBorder(dutyColor: String?) -> Color {
        guard dutyColor != nil else { return DPColor.borderSecondary }
        return usesLightForeground(on: dutyColor)
            ? DPColor.textOnDark.opacity(0.30)
            : DPColor.textOnLight.opacity(0.15)
    }

    static func dayNumberColor(dutyColor: String?, weekdayIndex: Int, hasHoliday: Bool) -> Color {
        if weekdayIndex == 0 || hasHoliday { return DPColor.dangerHover }
        if weekdayIndex == 6 { return DPColor.accentHover }
        return primaryForeground(dutyColor: dutyColor)
    }

    static func weekdayColor(_ index: Int) -> Color {
        if index == 0 { return DPColor.dangerHover }
        if index == 6 { return DPColor.accentHover }
        return DPColor.textPrimary
    }
}

nonisolated struct DPCalendarDayNumber: View {
    let day: Int
    let weekdayIndex: Int
    let dutyColor: String?
    let hasHoliday: Bool

    init(day: Int, weekdayIndex: Int, dutyColor: String?, hasHoliday: Bool = false) {
        self.day = day
        self.weekdayIndex = weekdayIndex
        self.dutyColor = dutyColor
        self.hasHoliday = hasHoliday
    }

    var body: some View {
        Text(verbatim: String(day))
            .font(DPFont.bold(size: DPCalendarCellStyle.dayNumberFontSize, relativeTo: .caption))
            .foregroundStyle(
                DPCalendarCellStyle.dayNumberColor(
                    dutyColor: dutyColor,
                    weekdayIndex: weekdayIndex,
                    hasHoliday: hasHoliday
                )
            )
    }
}

nonisolated struct DPCalendarWeekdayHeaderCell: View {
    let label: String
    let weekdayIndex: Int

    var body: some View {
        Text(verbatim: label)
            .font(DPFont.bold(size: DPCalendarCellStyle.weekdayFontSize, relativeTo: .subheadline))
            .foregroundStyle(DPCalendarCellStyle.weekdayColor(weekdayIndex))
            .frame(maxWidth: .infinity, minHeight: DPCalendarCellStyle.weekdayHeaderHeight)
            .background(DPCalendarCellStyle.weekdayHeaderBackground)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(DPCalendarCellStyle.weekdaySeparatorColor)
                    .frame(width: DPCalendarCellStyle.cellSeparatorWidth)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DPCalendarCellStyle.weekdaySeparatorColor)
                    .frame(height: DPCalendarCellStyle.weekdayBottomBorderHeight)
            }
    }
}
