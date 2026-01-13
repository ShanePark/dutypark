import SwiftUI

struct VisibilityBadge: View {
    let visibility: CalendarVisibility

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: visibility.iconName)
                .font(.system(size: 10))
            Text(visibility.displayName)
                .font(.system(size: 10))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }

    private var color: Color {
        switch visibility {
        case .public: return .green
        case .friends: return .blue
        case .family: return .purple
        case .private: return .gray
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        VisibilityBadge(visibility: .public)
        VisibilityBadge(visibility: .friends)
        VisibilityBadge(visibility: .family)
        VisibilityBadge(visibility: .private)
    }
}
