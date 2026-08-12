import SwiftUI

/// Web-style centered modal presentation used instead of the native bottom sheet.
struct DPModalOverlay<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var isDismissing = false

    let onDismiss: () -> Void
    let closeOnBackdrop: Bool
    private let content: (CGSize, @escaping () -> Void) -> Content

    init(
        onDismiss: @escaping () -> Void,
        closeOnBackdrop: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onDismiss = onDismiss
        self.closeOnBackdrop = closeOnBackdrop
        self.content = { _, _ in content() }
    }

    init(
        onDismiss: @escaping () -> Void,
        closeOnBackdrop: Bool = true,
        @ViewBuilder content: @escaping (CGSize) -> Content
    ) {
        self.onDismiss = onDismiss
        self.closeOnBackdrop = closeOnBackdrop
        self.content = { size, _ in content(size) }
    }

    init(
        onDismiss: @escaping () -> Void,
        closeOnBackdrop: Bool = true,
        @ViewBuilder content: @escaping (CGSize, @escaping () -> Void) -> Content
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
                Color.black.opacity(isVisible ? 0.36 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if closeOnBackdrop { dismiss() }
                    }
                    .accessibilityHidden(true)

                content(CGSize(width: panelWidth, height: panelHeight), dismiss)
                    .frame(width: panelWidth)
                    .background(DPColor.backgroundModal)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.extraLarge))
                    .overlay {
                        RoundedRectangle(cornerRadius: DPRadius.extraLarge)
                            .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
                    }
                    .shadow(color: .black.opacity(0.24), radius: 24, y: 12)
                    .padding(.vertical, DPSpacing.medium)
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(reduceMotion || isVisible ? 1 : 0.97)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .presentationBackground(.clear)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
        .onAppear {
            withAnimation(presentationAnimation) {
                isVisible = true
            }
        }
    }

    private var presentationAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.18)
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true

        withAnimation(presentationAnimation) {
            isVisible = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 180))
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                onDismiss()
            }
        }
    }
}

@MainActor
func withoutPresentationAnimation(_ updates: () -> Void) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction, updates)
}
