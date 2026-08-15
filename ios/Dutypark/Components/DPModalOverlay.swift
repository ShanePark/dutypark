import SwiftUI

nonisolated enum DPModalDismissSource: Equatable, Sendable {
    case backdrop
    case accessibilityEscape
    case content
}

nonisolated enum DPModalDismissAction: Equatable, Sendable {
    case ignore
    case request(DPModalDismissSource)
    case dismissImmediately
}

nonisolated struct DPModalDismissPolicy: Sendable {
    let closeOnBackdrop: Bool
    let canDismiss: Bool
    let isDismissing: Bool

    func action(
        for source: DPModalDismissSource,
        hasRequestHandler: Bool
    ) -> DPModalDismissAction {
        guard allows(source) else { return .ignore }

        switch source {
        case .backdrop:
            return hasRequestHandler ? .request(source) : .dismissImmediately
        case .accessibilityEscape:
            return hasRequestHandler ? .request(source) : .dismissImmediately
        case .content:
            return .dismissImmediately
        }
    }

    func allows(_ source: DPModalDismissSource) -> Bool {
        guard canDismiss, !isDismissing else { return false }
        switch source {
        case .backdrop:
            return closeOnBackdrop
        case .accessibilityEscape, .content:
            return true
        }
    }
}

/// Web-style centered modal presentation used instead of the native bottom sheet.
struct DPModalOverlay<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var isDismissing = false

    let onDismiss: () -> Void
    let maximumContentWidth: CGFloat
    let closeOnBackdrop: Bool
    let canDismiss: Bool
    /// Intercepts backdrop and VoiceOver escape requests without closing immediately.
    /// `closeOnBackdrop == false` suppresses backdrop requests; `canDismiss == false` suppresses all requests.
    let onDismissRequest: ((DPModalDismissSource) -> Void)?
    /// Receives an authorized immediate-dismiss closure that bypasses `onDismissRequest`.
    private let content: (CGSize, @escaping () -> Void) -> Content

    init(
        maximumContentWidth: CGFloat = 512,
        onDismiss: @escaping () -> Void,
        closeOnBackdrop: Bool = true,
        canDismiss: Bool = true,
        onDismissRequest: ((DPModalDismissSource) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onDismiss = onDismiss
        self.maximumContentWidth = maximumContentWidth
        self.closeOnBackdrop = closeOnBackdrop
        self.canDismiss = canDismiss
        self.onDismissRequest = onDismissRequest
        self.content = { _, _ in content() }
    }

    init(
        maximumContentWidth: CGFloat = 512,
        onDismiss: @escaping () -> Void,
        closeOnBackdrop: Bool = true,
        canDismiss: Bool = true,
        onDismissRequest: ((DPModalDismissSource) -> Void)? = nil,
        @ViewBuilder content: @escaping (CGSize) -> Content
    ) {
        self.onDismiss = onDismiss
        self.maximumContentWidth = maximumContentWidth
        self.closeOnBackdrop = closeOnBackdrop
        self.canDismiss = canDismiss
        self.onDismissRequest = onDismissRequest
        self.content = { size, _ in content(size) }
    }

    init(
        maximumContentWidth: CGFloat = 512,
        onDismiss: @escaping () -> Void,
        closeOnBackdrop: Bool = true,
        canDismiss: Bool = true,
        onDismissRequest: ((DPModalDismissSource) -> Void)? = nil,
        @ViewBuilder content: @escaping (CGSize, @escaping () -> Void) -> Content
    ) {
        self.onDismiss = onDismiss
        self.maximumContentWidth = maximumContentWidth
        self.closeOnBackdrop = closeOnBackdrop
        self.canDismiss = canDismiss
        self.onDismissRequest = onDismissRequest
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = min(
                max(proxy.size.width - 32, 0),
                max(maximumContentWidth, 0)
            )
            let panelHeight = max(proxy.size.height - 32, 0)

            ZStack {
                Color.black.opacity(isVisible ? 0.36 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismiss(source: .backdrop)
                    }
                    .accessibilityHidden(true)

                content(CGSize(width: panelWidth, height: panelHeight)) {
                    dismiss(source: .content)
                }
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
                .allowsHitTesting(!isDismissing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .presentationBackground(.clear)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            dismiss(source: .accessibilityEscape)
        }
        .onAppear {
            withAnimation(presentationAnimation) {
                isVisible = true
            }
        }
    }

    private var presentationAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.18)
    }

    private func dismiss(source: DPModalDismissSource) {
        let policy = DPModalDismissPolicy(
            closeOnBackdrop: closeOnBackdrop,
            canDismiss: canDismiss,
            isDismissing: isDismissing
        )
        switch policy.action(
            for: source,
            hasRequestHandler: onDismissRequest != nil
        ) {
        case .ignore:
            return
        case let .request(source):
            onDismissRequest?(source)
            return
        case .dismissImmediately:
            dismissImmediately()
        }
    }

    private func dismissImmediately() {
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
