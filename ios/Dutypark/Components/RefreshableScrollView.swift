import SwiftUI

struct RefreshableScrollView<Content: View>: View {
    let content: Content
    let onRefresh: () async -> Void

    init(@ViewBuilder content: () -> Content, onRefresh: @escaping () async -> Void) {
        self.content = content()
        self.onRefresh = onRefresh
    }

    var body: some View {
        ScrollView {
            content
        }
        .refreshable {
            await onRefresh()
        }
    }
}

#Preview {
    RefreshableScrollView {
        VStack(spacing: 20) {
            ForEach(0..<10) { index in
                Text("Item \(index)")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
    } onRefresh: {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}
