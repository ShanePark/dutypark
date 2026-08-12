import XCTest
@testable import Dutypark

final class SettingsDeepLinkTests: XCTestCase {
    func testParsesExactAuthenticatedInformationRoutes() {
        XCTAssertEqual(route("https://dutypark.o-r.kr/guide"), .guide)
        XCTAssertEqual(route("https://dutypark.o-r.kr/terms"), .terms)
        XCTAssertEqual(route("https://dutypark.o-r.kr/privacy"), .privacy)
    }

    func testRejectsUntrustedOrNonExactInformationRoutes() {
        XCTAssertNil(route("http://dutypark.o-r.kr/guide"))
        XCTAssertNil(route("https://example.com/guide"))
        XCTAssertNil(route("https://dutypark.o-r.kr/guide/extra"))
    }

    private func route(_ value: String) -> SettingsDestination? {
        SettingsDeepLink.destination(from: URL(string: value)!)
    }
}
