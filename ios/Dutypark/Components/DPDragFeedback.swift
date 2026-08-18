import SwiftUI

/// Drag haptics shared by every screen that lifts a card under the finger.
///
/// The screens all track the held item in one optional piece of state, so the
/// edges of that optional are the whole rule: it is `nil` while nothing is held,
/// which is why a plain tap — which never sets it — stays silent, and why a lift
/// fires once instead of once per drag update.
///
/// Both values use `impact(flexibility:intensity:)` for the same reason as
/// `DPButtonFeedback`: `impact(weight:)` collapses every weight to one light tap
/// on the current SDK, which would leave the lift and the drop indistinguishable.
nonisolated enum DPDragFeedback {
    /// A firm pick-up, deliberately heavier than the button press tick so the
    /// card reads as detached from the list.
    static let lift: SensoryFeedback = .impact(flexibility: .solid, intensity: 0.8)

    /// A lighter settle when the card is released.
    static let drop: SensoryFeedback = .impact(flexibility: .soft, intensity: 0.5)

    /// The tick as the card crosses into a new slot, matching the system list
    /// reorder so the finger can feel the order settle without watching it.
    static let retarget: SensoryFeedback = .selection

    static func firesOnLift<ID>(previous: ID?, next: ID?) -> Bool {
        previous == nil && next != nil
    }

    /// Covers a committed drop and a cancelled drag alike: both put the card back
    /// down, and the finger cannot tell the difference at that moment.
    static func firesOnDrop<ID>(previous: ID?, next: ID?) -> Bool {
        previous != nil && next == nil
    }

    /// Only a move between two live slots ticks: picking the first slot up is
    /// already covered by the lift, and losing the last one by the drop.
    static func firesOnRetarget<Target: Equatable>(previous: Target?, next: Target?) -> Bool {
        guard let previous, let next else { return false }
        return previous != next
    }
}

extension View {
    /// Fires a pick-up haptic when `dragID` becomes non-nil and a settle haptic
    /// when it clears again.
    func dpDragFeedback<ID: Equatable>(dragID: ID?) -> some View {
        sensoryFeedback(DPDragFeedback.lift, trigger: dragID) { previous, next in
            DPDragFeedback.firesOnLift(previous: previous, next: next)
        }
        .sensoryFeedback(DPDragFeedback.drop, trigger: dragID) { previous, next in
            DPDragFeedback.firesOnDrop(previous: previous, next: next)
        }
    }

    /// Ticks once each time the slot the card would drop into changes.
    func dpDragRetargetFeedback<Target: Equatable>(target: Target?) -> some View {
        sensoryFeedback(DPDragFeedback.retarget, trigger: target) { previous, next in
            DPDragFeedback.firesOnRetarget(previous: previous, next: next)
        }
    }
}
