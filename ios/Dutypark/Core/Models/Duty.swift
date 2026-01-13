import Foundation
import SwiftUI

struct DutyResponse: Decodable {
    let memberId: Int
    let memberName: String
    let duties: [String: DutyInfo]
    let dutyTypes: [DutyType]
}

struct DutyInfo: Decodable {
    let dutyTypeId: Int
    let name: String
    let color: String
    let shortName: String?
}

struct DutyType: Decodable, Identifiable {
    let id: Int
    let name: String
    let color: String
    let shortName: String?

    var swiftUIColor: Color {
        Color(hex: color) ?? .gray
    }
}

// MARK: - Duty Calendar (matches Vue DutyCalendarDay)
struct DutyCalendarDay: Decodable {
    let year: Int
    let month: Int
    let day: Int
    let dutyType: String?
    let dutyColor: String?
    let isOff: Bool

    var swiftUIColor: Color? {
        guard let dutyColor = dutyColor else { return nil }
        return Color(hex: dutyColor)
    }
}

// MARK: - Other Duties Response (for "view together" feature)
struct OtherDutyResponse: Decodable {
    let name: String
    let duties: [DutyCalendarDay]
}

// MARK: - Holiday
struct HolidayDto: Decodable {
    let dateName: String
    let isHoliday: Bool
    let localDate: String
}

// MARK: - Duty Batch
struct DutyBatchResult: Decodable {
    let result: Bool
    let errorMessage: String?
    let startDate: String?
    let endDate: String?
    let workingDays: Int
    let offDays: Int
}

struct DutyBatchTeamResult: Decodable {
    let success: Bool
    let message: String
    let teamId: Int?
    let year: Int?
    let month: Int?
    let processedCount: Int?
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
