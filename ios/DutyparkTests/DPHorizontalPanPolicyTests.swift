import XCTest
@testable import Dutypark

/// A calendar grid that pages sideways sits inside a page that scrolls down, and only
/// one of them can have any given drag. These are the rules that hand it over.
final class DPHorizontalPanPolicyTests: XCTestCase {
    func testADragHeadingSidewaysBelongsToThePager() {
        XCTAssertTrue(DPHorizontalPanPolicy.shouldBegin(velocity: CGPoint(x: 900, y: 30)))
        XCTAssertTrue(DPHorizontalPanPolicy.shouldBegin(velocity: CGPoint(x: -900, y: -30)))
    }

    func testADragHeadingDownThePageBelongsToTheScroll() {
        XCTAssertFalse(DPHorizontalPanPolicy.shouldBegin(velocity: CGPoint(x: 0, y: 900)))
        XCTAssertFalse(DPHorizontalPanPolicy.shouldBegin(velocity: CGPoint(x: 0, y: -900)))
    }

    // The regression this rule exists for: a thumb starting a scroll rolls sideways for
    // the first few points, and that was enough for the pager to swallow the scroll.
    func testAScrollThatDriftsSidewaysStillBelongsToTheScroll() {
        XCTAssertFalse(DPHorizontalPanPolicy.shouldBegin(velocity: CGPoint(x: 190, y: -940)))
        XCTAssertFalse(DPHorizontalPanPolicy.shouldBegin(velocity: CGPoint(x: -190, y: 940)))
    }

    func testADeadHeatBelongsToTheScroll() {
        XCTAssertFalse(DPHorizontalPanPolicy.shouldBegin(velocity: CGPoint(x: 500, y: 500)))
        XCTAssertFalse(DPHorizontalPanPolicy.shouldBegin(velocity: .zero))
    }
}
