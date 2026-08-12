import SwiftUI

/// Web-style centered modal presentation used instead of the native bottom sheet.
struct DPModalOverlay<Content: View>: View {
    let onDismiss: () -> Void
    let closeOnBackdrop: Bool
    private let content: (CGSize) -> Content

    init(
        onDismiss: @escaping () -> Void,
        closeOnBackdrop: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onDismiss = onDismiss
        self.closeOnBackdrop = closeOnBackdrop
        self.content = { _ in content() }
    }

    init(
        onDismiss: @escaping () -> Void,
        closeOnBackdrop: Bool = true,
        @ViewBuilder content: @escaping (CGSize) -> Content
    ) {
        self.onDismiss = onDismiss
        self.closeOnBackdrop = closeOnBackdrop
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = min(max(proxy.size.width - 32, 0), 512)
            let panelHeight = max(proxy.size.height - 32, 0)

            ZStack {
                Color.black.opacity(0.50)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if closeOnBackdrop { onDismiss() }
                    }
                    .accessibilityHidden(true)

                content(CGSize(width: panelWidth, height: panelHeight))
                    .frame(width: panelWidth)
                    .background(DPColor.backgroundModal)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.extraLarge))
                    .overlay {
                        RoundedRectangle(cornerRadius: DPRadius.extraLarge)
                            .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
                    }
                    .shadow(color: .black.opacity(0.24), radius: 24, y: 12)
                    .padding(.vertical, DPSpacing.medium)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .presentationBackground(.clear)
        .accessibilityAction(.escape, onDismiss)
    }
}
