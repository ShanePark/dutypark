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
