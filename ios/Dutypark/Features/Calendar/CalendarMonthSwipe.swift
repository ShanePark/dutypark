import CoreGraphics
import Foundation

/// Rules for the horizontal swipe that moves the calendar grid a month at a time, so
/// changing month does not have to go through the small chevrons in the navigation bar.
///
/// The grid sits inside a vertical scroll view and its cells are tappable, so the
/// gesture has to stay a passenger: it only claims a drag that is clearly sideways,
/// and while the finger is down it lets the grid follow only a short, damped distance.
nonisolated enum CalendarMonthSwipe {
    /// How far the finger has to travel sideways before lifting it changes the month.
    static let threshold: CGFloat = 56

    /// A vertical scroll drifts sideways as the thumb rolls, so the horizontal travel
    /// has to beat the vertical travel by this much before the drag counts as a swipe.
    static let verticalTolerance: CGFloat = 28

    /// The furthest the grid follows the finger. A drag that turns out to be a scroll
    /// therefore never pulls the calendar meaningfully off its column.
    static let maximumFollowDistance: CGFloat = 72

    static let slideOutDuration: TimeInterval = 0.16
    static let slideInDuration: TimeInterval = 0.22

    /// The month offset a finished drag asks for: `-1` for the previous month when the
    /// finger travelled left to right, `+1` for the next month, and `0` when the drag
    /// was too short or too vertical to be a month swipe.
    static func monthOffset(translation: CGSize) -> Int {
        guard abs(translation.width) >= threshold,
              abs(translation.width) > abs(translation.height) + verticalTolerance
        else { return 0 }
        return translation.width > 0 ? -1 : 1
    }

    /// How far the grid sits from its column while the finger is down. The travel is
    /// rubber-banded towards `maximumFollowDistance`: the first few points follow the
    /// finger almost exactly, and a long drag stops well before the grid leaves.
    static func followOffset(translation: CGSize) -> CGFloat {
        guard abs(translation.width) > abs(translation.height) else { return 0 }
        let magnitude = maximumFollowDistance
            * (1 - exp(-abs(translation.width) / maximumFollowDistance))
        return translation.width < 0 ? -magnitude : magnitude
    }
}
