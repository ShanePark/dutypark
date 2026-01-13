import SwiftUI

struct NotificationBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red)
                .clipShape(Capsule())
        }
    }
}

struct NotificationBellButton: View {
    @StateObject private var viewModel = NotificationViewModel()
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.title3)

                NotificationBadge(count: viewModel.unreadCount)
                    .offset(x: 8, y: -8)
            }
        }
        .task {
            await viewModel.loadUnreadCount()
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        NotificationBadge(count: 0)
        NotificationBadge(count: 5)
        NotificationBadge(count: 99)
        NotificationBadge(count: 150)
    }
    .padding()
}
