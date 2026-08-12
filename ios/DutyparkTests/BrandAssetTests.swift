import UIKit
import Testing

struct BrandAssetTests {
    @Test func visualParityAssetsAreAvailable() {
        let names = [
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
}
