import SwiftUI

struct TodoStatusBadge: View {
    let status: TodoStatus
    let showLabel: Bool

    init(status: TodoStatus, showLabel: Bool = true) {
        self.status = status
        self.showLabel = showLabel
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.iconName)
                .font(.system(size: 12))
            if showLabel {
                Text(status.displayName)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, showLabel ? 8 : 6)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }

    private var color: Color {
        switch status {
        case .todo: return .blue
        case .inProgress: return .orange
        case .done: return .green
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        TodoStatusBadge(status: .todo)
        TodoStatusBadge(status: .inProgress)
        TodoStatusBadge(status: .done)
        TodoStatusBadge(status: .todo, showLabel: false)
    }
}
