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
    let onBegan: (CGPoint) -> Void
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void
    let onCancelled: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = minimumDuration
        recognizer.allowableMovement = maximumMovement
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(
        _ recognizer: UILongPressGestureRecognizer,
        context: Context
    ) {
        recognizer.minimumPressDuration = minimumDuration
        recognizer.allowableMovement = maximumMovement
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UILongPressGestureRecognizer,
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
