import CoreGraphics
import Foundation

/// Rules for the horizontal swipe that moves the calendar grid a month at a time, so
/// changing month does not have to go through the small chevrons in the navigation bar.
///
/// The grid sits inside a vertical scroll view and its cells are tappable, so the
/// gesture has to stay a passenger: it only claims a drag that is clearly sideways,
/// and leaves vertical travel to the enclosing scroll view.
nonisolated enum CalendarMonthSwipe {
    /// How far the finger has to travel sideways before lifting it changes the month.
    static let threshold: CGFloat = 56

    /// A vertical scroll drifts sideways as the thumb rolls, so the horizontal travel
    /// has to beat the vertical travel by this much before the drag counts as a swipe.
    static let verticalTolerance: CGFloat = 28

    static let slideOutDuration: TimeInterval = 0.22
    static let slideInDuration: TimeInterval = 0.22

    /// The resting position of the three-page body track, with the current month
    /// centered and its neighbours exactly one viewport away.
    static func trackOffset(width: CGFloat, drag: CGFloat) -> CGFloat {
        -width + drag
    }

    /// The destination after a committed swipe: `+1` moves the next slot to center,
    /// while `-1` moves the previous slot to center.
    static func settledTrackOffset(width: CGFloat, monthOffset: Int) -> CGFloat {
        monthOffset > 0 ? -2 * width : monthOffset < 0 ? 0 : -width
    }

    static func interpolatedBodyHeight(source: CGFloat, target: CGFloat, progress: CGFloat) -> CGFloat {
        let progress = min(max(progress, 0), 1)
        return source + (target - source) * progress
    }

    /// The month offset a finished drag asks for: `-1` for the previous month when the
    /// finger travelled left to right, `+1` for the next month, and `0` when the drag
    /// was too short or too vertical to be a month swipe.
    static func monthOffset(translation: CGSize) -> Int {
        guard abs(translation.width) >= threshold,
              abs(translation.width) > abs(translation.height) + verticalTolerance
        else { return 0 }
        return translation.width > 0 ? -1 : 1
    }

    /// The month track follows a horizontal drag one point for each point the finger
    /// moves, stopping at the neighbouring page so the three-page track cannot expose
    /// empty space. Vertical drags are left to the enclosing scroll view.
    static func followOffset(translation: CGSize, viewportWidth: CGFloat) -> CGFloat {
        guard abs(translation.width) > abs(translation.height) else { return 0 }
        guard viewportWidth > 0 else { return 0 }
        return min(max(translation.width, -viewportWidth), viewportWidth)
    }
}
