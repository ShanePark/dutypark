import SwiftUI
import UIKit

/// A UIKit long-press recognizer attached directly to its SwiftUI content.
/// Unlike an overlaid representable view, this participates in the content's
/// existing hit-test chain and can recognize alongside an enclosing scroll view.
@available(iOS 18.0, *)
struct DPLongPressGestureRecognizer: UIGestureRecognizerRepresentable {
    let minimumDuration: TimeInterval
    let maximumMovement: CGFloat
    let coordinateSpaceName: String
    /// Touch down, long before the press succeeds. Reported by the recognizer
    /// itself rather than by a second gesture: an extra `DragGesture` layered on
    /// the card competes with the enclosing scroll view and breaks both scrolling
    /// and the reorder it was meant to illustrate.
    let onPressBegan: () -> Void
    /// The finger left, drifted too far, or the press turned into a drag — every
    /// way the countdown can stop.
    let onPressEnded: () -> Void
    let onBegan: (CGPoint) -> Void
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void
    let onCancelled: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> DPPressReportingLongPressGestureRecognizer {
        let recognizer = DPPressReportingLongPressGestureRecognizer()
        recognizer.minimumPressDuration = minimumDuration
        recognizer.allowableMovement = maximumMovement
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = context.coordinator
        recognizer.onPressBegan = onPressBegan
        recognizer.onPressEnded = onPressEnded
        return recognizer
    }

    func updateUIGestureRecognizer(
        _ recognizer: DPPressReportingLongPressGestureRecognizer,
        context: Context
    ) {
        recognizer.minimumPressDuration = minimumDuration
        recognizer.allowableMovement = maximumMovement
        recognizer.onPressBegan = onPressBegan
        recognizer.onPressEnded = onPressEnded
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: DPPressReportingLongPressGestureRecognizer,
        context: Context
    ) {
        let location = context.converter.location(in: .named(coordinateSpaceName))
        switch recognizer.state {
        case .began:
            context.coordinator.hasBegun = true
            onBegan(location)
        case .changed:
            guard context.coordinator.hasBegun else { return }
            onChanged(location)
        case .ended:
            guard context.coordinator.hasBegun else { return }
            context.coordinator.hasBegun = false
            onChanged(location)
            onEnded()
        case .cancelled, .failed:
            guard context.coordinator.hasBegun else { return }
            context.coordinator.hasBegun = false
            onCancelled()
        case .possible:
            break
        @unknown default:
            if context.coordinator.hasBegun {
                context.coordinator.hasBegun = false
                onCancelled()
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var hasBegun = false

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

/// A long press that also reports the part of itself the target-action mechanism
/// cannot: the stretch before the press succeeds, which is exactly the stretch the
/// press progress ring counts down.
///
/// `.possible` never fires an action, so the touch callbacks are the only place
/// this is observable from inside the recognizer.
final class DPPressReportingLongPressGestureRecognizer: UILongPressGestureRecognizer {
    var onPressBegan: (() -> Void)?
    var onPressEnded: (() -> Void)?

    private var isReportingPress = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard !isReportingPress else { return }
        isReportingPress = true
        onPressBegan?()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        reportPressEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        reportPressEnded()
    }

    /// Covers the endings the touch callbacks do not: drifting past
    /// `allowableMovement`, losing to another recognizer, and the successful press
    /// itself, all of which land here on the way back to `.possible`.
    override func reset() {
        super.reset()
        reportPressEnded()
    }

    private func reportPressEnded() {
        guard isReportingPress else { return }
        isReportingPress = false
        onPressEnded?()
    }
}
