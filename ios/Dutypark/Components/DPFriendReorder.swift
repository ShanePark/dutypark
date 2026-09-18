import SwiftUI

/// Long-press activation thresholds for the friend reorder drag, shared by
/// the Home dashboard list and the Social friend list so both screens lift a card
/// after the same deliberate press.
///
/// The threshold itself comes from `DPDragActivation` so the press progress ring
/// empties exactly when the card lifts.
enum DPFriendDragLayout {
    static let minimumPressDuration: TimeInterval = DPDragActivation.pressDuration
    static let maximumPressDistance: CGFloat = DPDragActivation.maximumPressMovement
    static let activationDistance: CGFloat = 4
}

/// A friend row's live frame, published in its screen's drag coordinate space.
struct DPFriendDropTarget: Equatable {
    let memberID: MemberID
    let frame: CGRect
}

struct DPFriendDropTargetPreferenceKey: PreferenceKey {
    static let defaultValue: [DPFriendDropTarget] = []

    static func reduce(
        value: inout [DPFriendDropTarget],
        nextValue: () -> [DPFriendDropTarget]
    ) {
        value.append(contentsOf: nextValue())
    }
}

/// Adapts the published drop targets to the pure reorder math in `FriendReorder`.
enum DPFriendLiveOrder {
    static func reordered(
        _ originalOrder: [MemberID],
        draggedID: MemberID,
        previewFrame: CGRect,
        axis: FriendReorderAxis = .vertical,
        targets: [DPFriendDropTarget]
    ) -> [MemberID] {
        FriendReorder.reordered(
            originalOrder,
            draggedID: draggedID,
            previewFrame: previewFrame,
            axis: axis,
            framesByID: FriendReorder.framesByID(
                targets,
                memberID: \.memberID,
                frame: \.frame
            )
        )
    }
}

/// The long-press-then-drag reorder gesture behind the friend lists.
///
/// iOS 18 attaches the UIKit recognizer (`DPLongPressGestureRecognizer`) so the
/// drag participates in the card's own hit-test chain and can recognize alongside
/// the enclosing scroll view. iOS 17 has no `UIGestureRecognizerRepresentable`, so
/// it keeps the `LongPressGesture.sequenced(before: DragGesture)` fallback; the
/// deployment target is still 17.0, so both paths have to stay.
///
/// The two paths do not report the same events, and the callbacks say so rather
/// than papering over it:
/// - only the iOS 18 path reports a distinct lift through `onBegan`; the fallback
///   reports its first movement through `onChanged`.
/// - only the fallback publishes a final drag location, so `onEnded` receives one
///   there and `nil` on iOS 18.
struct DPFriendReorderGesture: ViewModifier {
    let isEnabled: Bool
    let coordinateSpaceName: String
    /// Touch down and its ending, which is what the press progress ring counts
    /// down. Reported by the reorder gesture itself so no second gesture has to be
    /// layered on the card to notice the finger.
    let onPressBegan: () -> Void
    let onPressEnded: () -> Void
    let onBegan: (CGPoint) -> Void
    let onChanged: (CGPoint) -> Void
    let onEnded: (CGPoint?) -> Void
    let onCancelled: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if !isEnabled {
            content
        } else if #available(iOS 18.0, *) {
            content.gesture(modernFriendReorderGesture)
        } else {
            content.simultaneousGesture(legacyFriendReorderGesture)
        }
    }

    @available(iOS 18.0, *)
    private var modernFriendReorderGesture: DPLongPressGestureRecognizer {
        DPLongPressGestureRecognizer(
            minimumDuration: DPFriendDragLayout.minimumPressDuration,
            maximumMovement: DPFriendDragLayout.maximumPressDistance,
            coordinateSpaceName: coordinateSpaceName,
            onPressBegan: onPressBegan,
            onPressEnded: onPressEnded,
            onBegan: onBegan,
            onChanged: onChanged,
            onEnded: { self.onEnded(nil) },
            onCancelled: onCancelled
        )
    }

    private var legacyFriendReorderGesture: some Gesture {
        LongPressGesture(
            minimumDuration: DPFriendDragLayout.minimumPressDuration,
            maximumDistance: DPFriendDragLayout.maximumPressDistance
        )
        .sequenced(
            before: DragGesture(
                minimumDistance: DPFriendDragLayout.activationDistance,
                coordinateSpace: .named(coordinateSpaceName)
            )
        )
        .onChanged { value in
            if case .first(true) = value {
                onPressBegan()
                return
            }
            guard case .second(true, let dragValue) = value,
                  let dragValue else { return }
            onChanged(dragValue.location)
        }
        .onEnded { value in
            onPressEnded()
            guard case .second(true, let dragValue) = value,
                  let dragValue else {
                onCancelled()
                return
            }
            onEnded(dragValue.location)
        }
    }
}
