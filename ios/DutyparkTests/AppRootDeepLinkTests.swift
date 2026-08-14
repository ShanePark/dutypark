import XCTest
@testable import Dutypark

final class AppRootDeepLinkTests: XCTestCase {
    @MainActor
    func testGuestUniversalLinkIsDeferredUntilAuthentication() {
        XCTAssertTrue(AppRootDeepLinkPolicy.shouldDeferDestination(for: .guest))
    }
}
