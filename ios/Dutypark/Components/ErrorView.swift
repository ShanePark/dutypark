import SwiftUI

struct ErrorView: View {
    let code: String?
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(code: String? = nil, title: String, message: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.code = code
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            if let code {
                Text(code)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.gray.opacity(0.5))
            }

            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

#Preview {
    VStack(spacing: 24) {
        ErrorView(code: "404", title: "페이지를 찾을 수 없습니다", actionTitle: "홈으로 돌아가기") {}
        ErrorView(title: "네트워크 오류", message: "다시 시도해주세요")
    }
    .padding()
}
