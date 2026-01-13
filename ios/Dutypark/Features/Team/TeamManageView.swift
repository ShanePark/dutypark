import SwiftUI

struct TeamManageView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("팀 관리 기능은 추후 구현 예정입니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("팀 관리")
    }
}

#Preview {
    NavigationStack {
        TeamManageView()
    }
}
