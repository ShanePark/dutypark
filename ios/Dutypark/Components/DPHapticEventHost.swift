import Combine
import SwiftUI

/// Semantic haptic events shared by feature views and view models.
///
/// The kind intentionally describes the meaning of an interaction instead of the
/// control that caused it. This keeps navigation, completed mutations, and
/// actionable failures consistent across the app.
nonisolated enum DPHapticKind: Equatable, Sendable {
    case selection
    case routine
    case success
    case warning
    case error

    /// The SwiftUI feedback represented by this semantic event.
    var sensoryFeedback: SensoryFeedback {
        switch self {
        case .selection:
            return .selection
        case .routine:
            return .impact(flexibility: .soft, intensity: 0.6)
        case .success:
            return .success
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
}

/// One haptic event delivered through the app-level host.
///
/// `id` is part of the value so two consecutive events with the same kind still
/// produce a trigger transition for SwiftUI's `sensoryFeedback` modifier.
nonisolated struct DPHapticEvent: Equatable, Identifiable, Sendable {
    let id: UInt64
    let kind: DPHapticKind
}

/// Main-actor event center used by the whole app.
///
/// Feature code should emit semantic events only after the corresponding
/// action/result boundary has been reached. The root host observes the latest
/// event and translates it into the system haptic on the view hierarchy.
@MainActor
final class DPHapticCenter: ObservableObject {
    static let shared = DPHapticCenter()

    @Published private(set) var event: DPHapticEvent?
    private var nextEventID: UInt64 = 0

    @discardableResult
    func emit(_ kind: DPHapticKind) -> DPHapticEvent {
        nextEventID &+= 1
        let event = DPHapticEvent(id: nextEventID, kind: kind)
        self.event = event
        return event
    }
}

/// A root-level SwiftUI host for semantic haptic events.
@MainActor
struct DPHapticEventHost: ViewModifier {
    @ObservedObject var center: DPHapticCenter

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(trigger: center.event) { _, newEvent in
                newEvent?.kind.sensoryFeedback
            }
    }
}

extension View {
    /// Installs the shared haptic event host for this view hierarchy.
    @MainActor
    func dpHapticEventHost(_ center: DPHapticCenter = .shared) -> some View {
        modifier(DPHapticEventHost(center: center))
    }
}
