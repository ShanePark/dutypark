import Foundation

nonisolated enum DutyTypeColorPalette {
    struct Option: Identifiable, Equatable, Sendable {
        let name: String
        let hex: String
        var id: String { hex }
        var localizationKey: String { "team.dutyType.palette.\(name)" }
    }

    static let options = [
        Option(name: "blush", hex: "#ECC2C9"),
        Option(name: "orange", hex: "#F6BC7A"),
        Option(name: "yellow", hex: "#F6D365"),
        Option(name: "sand", hex: "#D8BF9B"),
        Option(name: "lime", hex: "#C8DD70"),
        Option(name: "leaf", hex: "#A6D99B"),
        Option(name: "mint", hex: "#8FDCBD"),
        Option(name: "aqua", hex: "#9DDBDE"),
        Option(name: "lilac", hex: "#D1B8EC"),
        Option(name: "magenta", hex: "#E9AEE9"),
        Option(name: "stone", hex: "#CCC8BD")
    ]
    static let defaultColor = "#F6D365"
    static let sundayHex = "#991B1B"
    static let saturdayHex = "#1E40AF"

    static func contains(_ hex: String?) -> Bool {
        guard let hex else { return false }
        return options.contains { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
    }

    static func initialColor(existing: String?) -> String {
        existing ?? defaultColor
    }

    static func shouldSelect(_ hex: String, current: String) -> Bool {
        guard hex.count == 7, hex.first == "#", UInt32(hex.dropFirst(), radix: 16) != nil else { return false }
        return hex.caseInsensitiveCompare(current) != .orderedSame
    }
}
