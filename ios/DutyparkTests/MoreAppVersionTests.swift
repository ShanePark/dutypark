import Foundation
import Testing
@testable import Dutypark

struct MoreAppVersionTests {
    private let korean = Locale(identifier: "ko")
    private let english = Locale(identifier: "en")

    @Test
    func versionFooterShowsOnlyTheMarketingVersion() {
        #expect(
            MoreAppVersion.displayText(shortVersion: "1.2.0", build: "34", locale: korean)
                == "버전 1.2.0"
        )
        #expect(
            MoreAppVersion.displayText(shortVersion: "1.2.0", build: "34", locale: english)
                == "Version 1.2.0"
        )
    }

    @Test
    func versionFooterIgnoresTheBuildNumberWhenMarketingVersionIsValid() {
        #expect(
            MoreAppVersion.displayText(shortVersion: "1.2.0", build: "1.2.0", locale: english)
                == "Version 1.2.0"
        )
        #expect(
            MoreAppVersion.displayText(shortVersion: "1.2.0", build: nil, locale: english)
                == "Version 1.2.0"
        )
        #expect(
            MoreAppVersion.displayText(shortVersion: " 1.2.0 ", build: "   ", locale: english)
                == "Version 1.2.0"
        )
    }

    @Test
    func versionFooterIsHiddenWithoutAMarketingVersion() {
        #expect(MoreAppVersion.displayText(shortVersion: nil, build: "34", locale: english) == nil)
        #expect(MoreAppVersion.displayText(shortVersion: "   ", build: "34", locale: english) == nil)
    }

    @Test
    func installedBundleExposesItsOwnVersion() {
        #expect(MoreAppVersion.displayText != nil)
    }
}
