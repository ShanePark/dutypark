import UIKit
import Testing
@testable import Dutypark

struct BrandAssetTests {
    @Test func visualParityAssetsAreAvailable() {
        let names = [
            "DefaultProfile",
            "DutyparkLogo",
            "IntroDDay",
            "IntroDuty",
            "IntroHoliday",
            "IntroSchedule",
            "IntroTodo",
            "KakaoLogo",
            "NaverLogo"
        ]

        for name in names {
            #expect(UIImage(named: name) != nil, "Missing asset: \(name)")
        }
    }

    @Test func launchScreenUsesCurrentEvolvedSplashAsset() {
        #expect(UIImage(named: LaunchSplashPresentation.assetName) != nil)
        #expect(
            Bundle.main.object(forInfoDictionaryKey: "UILaunchStoryboardName") as? String
                == "LaunchScreen"
        )
        #expect(Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen") == nil)
    }
}
