import SwiftUI
import UIKit

/// Which drags a sideways pager may take from the page it sits on.
nonisolated enum DPHorizontalPanPolicy {
    enum Axis {
        case undecided, horizontal, vertical
    }

    /// UIKit may begin before there is enough travel to determine an axis. Keep that
    /// touch alive; rejecting it in shouldBegin cannot be undone later in the swipe.
    static let minimumDirectionalTravel: CGFloat = 8

    static func axis(for translation: CGPoint) -> Axis {
        let horizontalTravel = abs(translation.x)
        let verticalTravel = abs(translation.y)
        guard max(horizontalTravel, verticalTravel) >= minimumDirectionalTravel else {
            return .undecided
        }
        return horizontalTravel > verticalTravel ? .horizontal : .vertical
    }

    static func shouldBegin(velocity _: CGPoint, translation: CGPoint) -> Bool {
        axis(for: translation) != .vertical
    }

    static func shouldSendChange(for state: UIGestureRecognizer.State) -> Bool {
        state == .began || state == .changed
    }

    static func shouldSendEnd(for state: UIGestureRecognizer.State) -> Bool {
        state == .ended
    }

    static func shouldSendCancel(for state: UIGestureRecognizer.State) -> Bool {
        state == .cancelled || state == .failed
    }
}

extension View {
    /// Follows sideways drags across this view without ever taking one that the
    /// scroll view underneath should have had.
    ///
    /// SwiftUI's own `DragGesture` claims a drag the instant it passes its minimum
    /// distance, whichever way it went, and from then on the scroll view sees
    /// nothing: a scroll that began with the smallest sideways roll of a thumb simply
    /// did not move the page. A simultaneous UIKit recogniser leaves the scroll free
    /// to move and sends pager updates only after enough sideways travel.
    ///
    /// `translation` arrives in the same shape `DragGesture` reports it, so callers
    /// read it the same way.
    func dpHorizontalPan(
        onChanged: @escaping (CGSize) -> Void,
        onEnded: @escaping (CGSize, CGSize) -> Void,
        onCancelled: @escaping (CGSize) -> Void
    ) -> some View {
        background(DPHorizontalPanBridge(onChanged: onChanged, onEnded: onEnded, onCancelled: onCancelled))
    }
}

private struct DPHorizontalPanBridge: UIViewRepresentable {
    let onChanged: (CGSize) -> Void
    let onEnded: (CGSize, CGSize) -> Void
    let onCancelled: (CGSize) -> Void

    func makeUIView(context: Context) -> DPHorizontalPanAnchorView {
        let view = DPHorizontalPanAnchorView(gesture: context.coordinator.gesture)
        view.isUserInteractionEnabled = false
        context.coordinator.anchor = view
        return view
    }

    func updateUIView(_ uiView: DPHorizontalPanAnchorView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
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
final class DPHorizontalPanCoordinator: NSObject, UIGestureRecognizerDelegate {
    /// Weak so that the recogniser, which the scrolling ancestor owns and this object
    /// is the target of, never keeps the view it measures alive.
    weak var anchor: UIView?
    var onChanged: (CGSize) -> Void = { _ in }
    var onEnded: (CGSize, CGSize) -> Void = { _, _ in }
    var onCancelled: (CGSize) -> Void = { _ in }
    private var axis = DPHorizontalPanPolicy.Axis.undecided

    lazy var gesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        gesture.delegate = self
        // The decorated view keeps its own taps; a drag that turns out to be a swipe
        // is turned away by the caller rather than by cancelling the touch.
        gesture.cancelsTouchesInView = false
        return gesture
    }()

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let velocity = gesture.velocity(in: gesture.view)
        handlePan(state: gesture.state, translation: translation, velocity: velocity)
    }

    func handlePan(state: UIGestureRecognizer.State, translation: CGPoint, velocity: CGPoint) {
        if state == .began { axis = .undecided }
        if axis == .undecided { axis = DPHorizontalPanPolicy.axis(for: translation) }
        let isTerminal = DPHorizontalPanPolicy.shouldSendEnd(for: state)
            || DPHorizontalPanPolicy.shouldSendCancel(for: state)
        defer { if isTerminal { axis = .undecided } }
        guard axis == .horizontal else { return }

        let size = CGSize(width: translation.x, height: translation.y)
        if DPHorizontalPanPolicy.shouldSendChange(for: state) {
            onChanged(size)
        } else if DPHorizontalPanPolicy.shouldSendEnd(for: state) {
            // A fast flick can go straight from an unresolved begin to its end.
            // Prepare the month track before asking the caller to commit it.
            onChanged(size)
            onEnded(size, CGSize(width: velocity.x, height: velocity.y))
        } else if DPHorizontalPanPolicy.shouldSendCancel(for: state) {
            onCancelled(size)
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let anchor else { return false }
        guard DPHorizontalPanPolicy.shouldBegin(
            velocity: pan.velocity(in: pan.view),
            translation: pan.translation(in: pan.view)
        ) else { return false }
        return anchor.bounds.contains(pan.location(in: anchor))
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
