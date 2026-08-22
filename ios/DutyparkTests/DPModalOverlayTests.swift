import Testing
@testable import Dutypark

struct DPModalOverlayTests {
    @Test
    func onlyImmediateDismissalsProduceRoutineFeedback() {
        #expect(
            DPModalDismissFeedback.kind(
                for: .dismissImmediately,
                configured: .routine
            ) == .routine
        )
        #expect(
            DPModalDismissFeedback.kind(
                for: .request(.backdrop),
                configured: .routine
            ) == nil
        )
        #expect(
            DPModalDismissFeedback.kind(
                for: .ignore,
                configured: .routine
            ) == nil
        )
    }

    @Test
    func dismissalFeedbackCanBeDisabledForConfirmationScaffolds() {
        #expect(
            DPModalDismissFeedback.kind(
                for: .dismissImmediately,
                configured: nil
            ) == nil
        )
    }

    @Test
    func defaultExternalDismissalClosesImmediately() {
        let policy = makePolicy()

        #expect(
            policy.action(for: .backdrop, hasRequestHandler: false)
                == .dismissImmediately
        )
        #expect(
            policy.action(for: .accessibilityEscape, hasRequestHandler: false)
                == .dismissImmediately
        )
    }

    @Test
    func externalDismissalIsInterceptedWithoutClosing() {
        let policy = makePolicy()

        #expect(
            policy.action(for: .backdrop, hasRequestHandler: true)
                == .request(.backdrop)
        )
        #expect(
            policy.action(for: .accessibilityEscape, hasRequestHandler: true)
                == .request(.accessibilityEscape)
        )
        #expect(
            policy.action(for: .content, hasRequestHandler: true)
                == .dismissImmediately
        )
    }

    @Test
    func disabledDismissalNeitherRequestsNorCloses() {
        let policy = makePolicy(canDismiss: false)

        #expect(policy.action(for: .backdrop, hasRequestHandler: false) == .ignore)
        #expect(policy.action(for: .backdrop, hasRequestHandler: true) == .ignore)
        #expect(policy.action(for: .accessibilityEscape, hasRequestHandler: true) == .ignore)
        #expect(policy.action(for: .content, hasRequestHandler: true) == .ignore)
    }

    @Test
    func backdropDismissalCanBeDisabledIndependently() {
        let policy = makePolicy(closeOnBackdrop: false)

        #expect(policy.action(for: .backdrop, hasRequestHandler: false) == .ignore)
        #expect(policy.action(for: .backdrop, hasRequestHandler: true) == .ignore)
        #expect(
            policy.action(for: .accessibilityEscape, hasRequestHandler: true)
                == .request(.accessibilityEscape)
        )
    }

    @Test
    func escapeUsesTheSameRequestPolicyAsBackdrop() {
        let policy = makePolicy()

        for source in [DPModalDismissSource.backdrop, .accessibilityEscape] {
            #expect(policy.action(for: source, hasRequestHandler: false) == .dismissImmediately)
            #expect(policy.action(for: source, hasRequestHandler: true) == .request(source))
        }
    }

    private func makePolicy(
        closeOnBackdrop: Bool = true,
        canDismiss: Bool = true,
        isDismissing: Bool = false
    ) -> DPModalDismissPolicy {
        DPModalDismissPolicy(
            closeOnBackdrop: closeOnBackdrop,
            canDismiss: canDismiss,
            isDismissing: isDismissing
        )
    }
}
