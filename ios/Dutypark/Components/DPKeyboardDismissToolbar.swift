import SwiftUI
import UIKit

private struct DPKeyboardDismissToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    } label: {
                        Text("common.keyboard.done")
                    }
                    .accessibilityIdentifier("keyboard.dismiss")
                }
            }
    }
}

extension View {
    func dpKeyboardDismissToolbar() -> some View {
        modifier(DPKeyboardDismissToolbar())
    }
}
