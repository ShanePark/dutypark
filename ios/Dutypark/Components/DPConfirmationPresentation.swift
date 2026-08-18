import SwiftUI

/// Authorized immediate-dismiss closure handed to the confirmation actions by
/// `DPModalOverlay`. Calling it plays the dismissal animation before the
/// presentation state is reset.
typealias DPConfirmationDismiss = () -> Void

/// Text and emphasis shown by a `DPConfirmationPanel` presentation.
nonisolated struct DPConfirmationCopy: Equatable, Sendable {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    let isDestructive: Bool

    init(
        title: String,
        message: String,
        confirmTitle: String,
        cancelTitle: String,
        isDestructive: Bool = false
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.isDestructive = isDestructive
    }
}

/// The `DPModalOverlay` + `DPConfirmationPanel` pairing every confirmation cover
/// repeats. Kept in one place so the overlay width, dismissal policy and panel
/// wiring stay identical across the app.
private struct DPConfirmationCover: View {
    let copy: DPConfirmationCopy
    let isWorking: Bool
    let closeOnBackdrop: Bool
    let canDismiss: Bool
    let finishDismissal: () -> Void
    let cancel: ((DPConfirmationDismiss) -> Void)?
    let confirm: (DPConfirmationDismiss) -> Void

    var body: some View {
        DPModalOverlay(
            maximumContentWidth: DPConfirmationPanel.maximumWidth,
            onDismiss: finishDismissal,
            closeOnBackdrop: closeOnBackdrop,
            canDismiss: canDismiss
        ) { availableSize, dismiss in
            DPConfirmationPanel(
                title: copy.title,
                message: copy.message,
                confirmTitle: copy.confirmTitle,
                cancelTitle: copy.cancelTitle,
                isDestructive: copy.isDestructive,
                isWorking: isWorking,
                maximumHeight: availableSize.height,
                cancel: {
                    if let cancel {
                        cancel(dismiss)
                    } else {
                        dismiss()
                    }
                },
                confirm: { confirm(dismiss) }
            )
        }
        .interactiveDismissDisabled(!canDismiss)
    }
}

extension View {
    /// Presents the shared confirmation panel while `isPresented` is `true`.
    ///
    /// - Parameters:
    ///   - isWorking: Shows the in-button spinner and blocks both buttons while an
    ///     action is in flight. System dialogs cannot do this, which is why the app
    ///     keeps its own panel.
    ///   - finishDismissal: Resets the presentation state once the dismissal
    ///     animation finishes. Defaults to clearing `isPresented`.
    ///   - cancel: Receives the authorized dismiss closure. Defaults to dismissing.
    ///   - confirm: Receives the authorized dismiss closure so the call site keeps
    ///     control over whether it dismisses before, after, or instead of its action.
    func dpConfirmation(
        isPresented: Binding<Bool>,
        copy: DPConfirmationCopy,
        isWorking: Bool = false,
        closeOnBackdrop: Bool = true,
        canDismiss: Bool = true,
        finishDismissal: (() -> Void)? = nil,
        cancel: ((DPConfirmationDismiss) -> Void)? = nil,
        confirm: @escaping (DPConfirmationDismiss) -> Void
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            DPConfirmationCover(
                copy: copy,
                isWorking: isWorking,
                closeOnBackdrop: closeOnBackdrop,
                canDismiss: canDismiss,
                finishDismissal: {
                    if let finishDismissal {
                        finishDismissal()
                    } else {
                        isPresented.wrappedValue = false
                    }
                },
                cancel: cancel,
                confirm: confirm
            )
        }
    }

    /// Presents the shared confirmation panel for a non-`nil` `item`.
    ///
    /// `copy` and `confirm` receive the presented item so the panel text and the
    /// action can be derived from it.
    func dpConfirmation<Item: Identifiable>(
        item: Binding<Item?>,
        copy: @escaping (Item) -> DPConfirmationCopy,
        isWorking: Bool = false,
        closeOnBackdrop: Bool = true,
        canDismiss: Bool = true,
        finishDismissal: (() -> Void)? = nil,
        cancel: ((DPConfirmationDismiss) -> Void)? = nil,
        confirm: @escaping (Item, DPConfirmationDismiss) -> Void
    ) -> some View {
        fullScreenCover(item: item) { value in
            DPConfirmationCover(
                copy: copy(value),
                isWorking: isWorking,
                closeOnBackdrop: closeOnBackdrop,
                canDismiss: canDismiss,
                finishDismissal: {
                    if let finishDismissal {
                        finishDismissal()
                    } else {
                        item.wrappedValue = nil
                    }
                },
                cancel: cancel,
                confirm: { dismiss in confirm(value, dismiss) }
            )
        }
    }
}
