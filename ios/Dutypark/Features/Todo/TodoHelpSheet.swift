import SwiftUI

struct TodoHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    helpSection(title: "칸반 보드란?") {
                        Text("할 일을 단계별로 나누어 관리하는 방식입니다. 드래그하여 상태를 변경하고 우선순위를 조정할 수 있습니다.")
                    }

                    helpSection(title: "할 일") {
                        Text("아직 시작하지 않은 작업을 모아두는 영역입니다. 마감일을 설정하면 캘린더에 표시됩니다.")
                    }

                    helpSection(title: "진행중") {
                        Text("현재 진행 중인 작업입니다. 진행중 항목은 내 달력에 표시됩니다.")
                    }

                    helpSection(title: "완료") {
                        Text("완료된 작업을 모아둡니다. 필요하면 다시 열어 재개할 수 있습니다.")
                    }

                    helpSection(title: "사용 팁") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• 카드를 드래그하여 순서를 변경할 수 있습니다.")
                            Text("• 다른 컬럼으로 드래그하면 상태가 변경됩니다.")
                            Text("• 첨부파일과 마감일을 추가해 중요한 작업을 강조하세요.")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("할일 도움말")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func helpSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    TodoHelpSheet()
}
