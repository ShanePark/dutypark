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

    // The account sections moved out of settings, so only the preference-owned
    // documents may keep landing on the settings screen.
    func testRoutesEachMoreDestinationToTheScreenThatOwnsIt() {
        XCTAssertEqual(moreRoute("https://dutypark.o-r.kr/guide"), .guide)
        XCTAssertEqual(moreRoute("https://dutypark.o-r.kr/terms"), .settings)
        XCTAssertEqual(moreRoute("https://dutypark.o-r.kr/privacy"), .settings)
        XCTAssertEqual(moreRoute("https://dutypark.o-r.kr/member"), .myInfo)
        XCTAssertEqual(moreRoute("https://dutypark.o-r.kr/member/edit"), .myInfo)
    }

    func testRejectsUntrustedOrUnknownMoreRoutes() {
        XCTAssertNil(moreRoute("http://dutypark.o-r.kr/member"))
        XCTAssertNil(moreRoute("https://example.com/member"))
        XCTAssertNil(moreRoute("https://dutypark.o-r.kr/todo"))
        XCTAssertNil(moreRoute("https://dutypark.o-r.kr/"))
    }

    func testMapsSettingsDestinationsToTheirMoreScreen() {
        XCTAssertEqual(RootMoreDeepLinkPolicy.destination(for: .guide), .guide)
        XCTAssertEqual(RootMoreDeepLinkPolicy.destination(for: .terms), .settings)
        XCTAssertEqual(RootMoreDeepLinkPolicy.destination(for: .privacy), .settings)
    }

    private func route(_ value: String) -> SettingsDestination? {
        SettingsDeepLink.destination(from: URL(string: value)!)
    }

    private func moreRoute(_ value: String) -> MoreDestination? {
        RootMoreDeepLinkPolicy.destination(from: URL(string: value)!)
    }
}
