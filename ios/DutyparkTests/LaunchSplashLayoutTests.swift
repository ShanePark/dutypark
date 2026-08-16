import SwiftUI
import Testing
import UIKit
@testable import Dutypark

@MainActor
struct LaunchSplashLayoutTests {
    /// The static launch storyboard centers the splash artwork with `scaleAspectFill`.
    /// The SwiftUI splash that replaces it must resolve to exactly the screen size, or the
    /// window places the oversized view at its leading edge and the artwork visibly jumps
    /// sideways during the hand-off.
    @Test(arguments: [
        CGSize(width: 402, height: 874),
        CGSize(width: 393, height: 852),
        CGSize(width: 320, height: 568)
    ])
    func launchSplashResolvesToTheProposedScreenSize(screen: CGSize) {
        let resolved = UIHostingController(rootView: LaunchSplashView()).sizeThatFits(in: screen)

        #expect(resolved.width == screen.width, "width was \(resolved.width) for \(screen)")
        #expect(resolved.height == screen.height, "height was \(resolved.height) for \(screen)")
    }
}
