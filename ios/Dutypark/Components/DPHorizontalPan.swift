import SwiftUI
import UIKit

/// Which drags a sideways pager may take from the page it sits on.
nonisolated enum DPHorizontalPanPolicy {
    /// A drag is the pager's only while it is travelling sideways faster than it is
    /// travelling down the page. A tie goes to the scroll, which is what the reader
    /// asked for far more often.
    static func shouldBegin(velocity: CGPoint) -> Bool {
        abs(velocity.x) > abs(velocity.y)
    }
}

extension View {
    /// Follows sideways drags across this view without ever taking one that the
    /// scroll view underneath should have had.
    ///
    /// SwiftUI's own `DragGesture` claims a drag the instant it passes its minimum
    /// distance, whichever way it went, and from then on the scroll view sees
    /// nothing: a scroll that began with the smallest sideways roll of a thumb simply
    /// did not move the page. A UIKit recogniser can refuse the drag before it begins
    /// instead, leaving the touch where it belongs.
    ///
    /// `translation` arrives in the same shape `DragGesture` reports it, so callers
    /// read it the same way.
    func dpHorizontalPan(
        onChanged: @escaping (CGSize) -> Void,
        onEnded: @escaping (CGSize) -> Void
    ) -> some View {
        background(DPHorizontalPanBridge(onChanged: onChanged, onEnded: onEnded))
    }
}

private struct DPHorizontalPanBridge: UIViewRepresentable {
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize) -> Void

    func makeUIView(context: Context) -> DPHorizontalPanAnchorView {
        let view = DPHorizontalPanAnchorView(gesture: context.coordinator.gesture)
        view.isUserInteractionEnabled = false
        context.coordinator.anchor = view
        return view
    }

    func updateUIView(_ uiView: DPHorizontalPanAnchorView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        uiView.attachGestureIfPossible()
    }

    func makeCoordinator() -> DPHorizontalPanCoordinator {
        DPHorizontalPanCoordinator()
    }
}

/// Sits behind the decorated view purely to mark out its bounds; the recogniser rides
/// on the scrolling ancestor, which is the one view guaranteed to see every touch the
/// page receives.
private final class DPHorizontalPanAnchorView: UIView {
    private let gesture: UIPanGestureRecognizer

    init(gesture: UIPanGestureRecognizer) {
        self.gesture = gesture
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            gesture.view?.removeGestureRecognizer(gesture)
        } else {
            attachGestureIfPossible()
        }
    }

    func attachGestureIfPossible() {
        guard let host = enclosingScrollView(), gesture.view !== host else { return }
        gesture.view?.removeGestureRecognizer(gesture)
        host.addGestureRecognizer(gesture)
    }

    private func enclosingScrollView() -> UIScrollView? {
        var candidate = superview
        while let view = candidate {
            if let scrollView = view as? UIScrollView { return scrollView }
            candidate = view.superview
        }
        return nil
    }
}

@MainActor
private final class DPHorizontalPanCoordinator: NSObject, UIGestureRecognizerDelegate {
    /// Weak so that the recogniser, which the scrolling ancestor owns and this object
    /// is the target of, never keeps the view it measures alive.
    weak var anchor: UIView?
    var onChanged: (CGSize) -> Void = { _ in }
    var onEnded: (CGSize) -> Void = { _ in }

    lazy var gesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        gesture.delegate = self
        // The decorated view keeps its own taps; a drag that turns out to be a swipe
        // is turned away by the caller rather than by cancelling the touch.
        gesture.cancelsTouchesInView = false
        return gesture
    }()

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let size = CGSize(width: translation.x, height: translation.y)
        switch gesture.state {
        case .changed:
            onChanged(size)
        case .ended, .cancelled, .failed:
            onEnded(size)
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let anchor else { return false }
        guard DPHorizontalPanPolicy.shouldBegin(velocity: pan.velocity(in: pan.view)) else { return false }
        return anchor.bounds.contains(pan.location(in: anchor))
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
