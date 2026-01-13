import SwiftUI

struct ConfirmationAlert {
    var title: String
    var message: String?
    var confirmTitle: String = "확인"
    var cancelTitle: String = "취소"
    var isDestructive: Bool = false
}

struct ConfirmationDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let alert: ConfirmationAlert
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(alert.title, isPresented: $isPresented) {
                Button(alert.cancelTitle, role: .cancel) { }
                Button(alert.confirmTitle, role: alert.isDestructive ? .destructive : nil) {
                    onConfirm()
                }
            } message: {
                if let message = alert.message {
                    Text(message)
                }
            }
    }
}

extension View {
    func confirmationAlert(isPresented: Binding<Bool>, alert: ConfirmationAlert, onConfirm: @escaping () -> Void) -> some View {
        modifier(ConfirmationDialogModifier(isPresented: isPresented, alert: alert, onConfirm: onConfirm))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var showAlert = false

        var body: some View {
            Button("Show Alert") {
                showAlert = true
            }
            .confirmationAlert(
                isPresented: $showAlert,
                alert: ConfirmationAlert(
                    title: "삭제하시겠습니까?",
                    message: "이 작업은 되돌릴 수 없습니다.",
                    confirmTitle: "삭제",
                    isDestructive: true
                )
            ) {
                print("Deleted!")
            }
        }
    }

    return PreviewWrapper()
}
