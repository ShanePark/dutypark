import CoreGraphics
import Foundation

/// Rules for the horizontal swipe that moves the calendar grid a month at a time, so
/// changing month does not have to go through the small chevrons in the navigation bar.
///
/// The grid sits inside a vertical scroll view and its cells are tappable, so the
/// gesture has to stay a passenger: it only claims a drag that is clearly sideways,
/// and leaves vertical travel to the enclosing scroll view.
nonisolated enum CalendarMonthSwipe {
    /// A deliberate page drag covers about a third of the calendar's width.
    static let releaseDistanceFraction: CGFloat = 1.0 / 3.0

    /// A quick flick can page before reaching the distance threshold, but only after
    /// the finger has moved far enough to distinguish a swipe from a small adjustment.
    static let minimumFlickTravel: CGFloat = 24
    static let outwardFlickVelocity: CGFloat = 650
    static let minimumInwardReleaseVelocity: CGFloat = 80

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

    /// The month offset a finished horizontal pan asks for. Once the recognizer has
    /// classified the gesture as horizontal, vertical drift no longer changes the
    /// decision. A short release commits only when it was a quick outward flick; a
    /// deliberate inward release settles back to the current month.
    static func monthOffset(translation: CGSize, velocity: CGSize, viewportWidth: CGFloat) -> Int {
        guard viewportWidth > 0, translation.width != 0 else { return 0 }
        let isClearlyReturning = translation.width * velocity.width < 0
            && abs(velocity.width) >= minimumInwardReleaseVelocity
        guard !isClearlyReturning else { return 0 }

        let travel = abs(translation.width)
        let reachedReleaseDistance = travel >= viewportWidth * releaseDistanceFraction
        let madeOutwardFlick = travel >= minimumFlickTravel
            && abs(velocity.width) >= outwardFlickVelocity
            && translation.width * velocity.width > 0
        guard reachedReleaseDistance || madeOutwardFlick else { return 0 }

        return translation.width > 0 ? -1 : 1
    }

    /// Once UIKit has started a horizontal pan, the month track follows only its
    /// horizontal translation. Later vertical drift must not make the page jump back.
    static func followOffset(translation: CGSize, viewportWidth: CGFloat) -> CGFloat {
        guard viewportWidth > 0 else { return 0 }
        return min(max(translation.width, -viewportWidth), viewportWidth)
    }
}
