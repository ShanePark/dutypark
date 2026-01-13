import SwiftUI

struct DutyBadge: View {
    let dutyType: String?
    let dutyColor: String?
    let isOff: Bool
    let size: BadgeSize

    enum BadgeSize {
        case small, medium, large

        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .large: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            }
        }
    }

    init(dutyType: String?, dutyColor: String?, isOff: Bool = false, size: BadgeSize = .medium) {
        self.dutyType = dutyType
        self.dutyColor = dutyColor
        self.isOff = isOff
        self.size = size
    }

    var body: some View {
        if isOff {
            Text("OFF")
                .font(.system(size: size.fontSize, weight: .semibold))
                .foregroundColor(.gray)
                .padding(size.padding)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(6)
        } else if let dutyType = dutyType {
            Text(dutyType)
                .font(.system(size: size.fontSize, weight: .semibold))
                .foregroundColor(textColor)
                .padding(size.padding)
                .background(backgroundColor)
                .cornerRadius(6)
        }
    }

    private var backgroundColor: Color {
        guard let dutyColor = dutyColor else { return Color.gray.opacity(0.2) }
        return Color(hex: dutyColor)?.opacity(0.3) ?? Color.gray.opacity(0.2)
    }

    private var textColor: Color {
        guard let dutyColor = dutyColor else { return .gray }
        if isLightColor(hex: dutyColor) {
            return .black.opacity(0.8)
        }
        return Color(hex: dutyColor) ?? .gray
    }

    private func isLightColor(hex: String) -> Bool {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return false }
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.7
    }
}

#Preview {
    VStack(spacing: 12) {
        DutyBadge(dutyType: "주간", dutyColor: "#FF5733", size: .small)
        DutyBadge(dutyType: "야간", dutyColor: "#3366FF", size: .medium)
        DutyBadge(dutyType: "비번", dutyColor: "#33CC33", size: .large)
        DutyBadge(dutyType: nil, dutyColor: nil, isOff: true, size: .medium)
    }
}
