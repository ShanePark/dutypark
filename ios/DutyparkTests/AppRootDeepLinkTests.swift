import Foundation
import XCTest
@testable import Dutypark

final class AppRootDeepLinkTests: XCTestCase {
    // The site root is the dashboard, so it has to clear whatever the home tab had
    // pushed instead of leaving the previous screen on top of it.
    @MainActor
    func testSiteRootDestinationOpensTheHomeDashboardInsteadOfKeepingThePushedScreen() throws {
        let rootSource = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Dutypark/App/RootTabView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(
            rootSource.contains("case nil:\n            openHome()"),
            "A link to the site root must go through openHome() so the home stack is reset"
        )
    }

    @MainActor
    func testColdLaunchAuthenticatedDestinationSurvivesGuestRestore() {
        let destination = URL(string: "https://dutypark.o-r.kr/todo")!
        let store = SessionStore(initialState: .guest)

        XCTAssertTrue(AppRootDeepLinkPolicy.shouldDeferDestination(destination, for: .restoring))
        store.deferDestinationUntilAuthenticated(destination)

        if GuestPendingDestinationPolicy.shouldConsume(destination) {
            _ = store.consumePendingDestination()
        }

        XCTAssertEqual(store.pendingDestination, destination)
        XCTAssertEqual(store.consumePendingDestination(), destination)
    }

    @MainActor
    func testWarmGuestAuthenticatedDestinationIsDeferred() {
        let destination = URL(string: "https://dutypark.o-r.kr/friends")!

        XCTAssertTrue(AppRootDeepLinkPolicy.shouldDeferDestination(destination, for: .guest))
        XCTAssertFalse(GuestPendingDestinationPolicy.shouldShowUnsupported(destination))
    }

    @MainActor
    func testUnknownAndExternalDestinationsAreNotDeferred() {
        let unknown = URL(string: "https://dutypark.o-r.kr/not-a-route")!
        let external = URL(string: "https://example.com/todo")!

        XCTAssertFalse(AppRootDeepLinkPolicy.shouldDeferDestination(unknown, for: .guest))
        XCTAssertFalse(AppRootDeepLinkPolicy.shouldDeferDestination(external, for: .restoring))
    }

    @MainActor
    func testWarmGuestPublicLinkOpensWithoutBeingDeferredForAuthentication() {
        let destination = URL(string: "https://dutypark.o-r.kr/duty/42")!

        XCTAssertTrue(GuestPendingDestinationPolicy.shouldConsume(destination))
        XCTAssertEqual(GuestDeepLink.route(from: destination), .publicCalendar(42))
        XCTAssertFalse(AppRootDeepLinkPolicy.shouldDeferDestination(destination, for: .guest))
        XCTAssertTrue(AppRootDeepLinkPolicy.shouldDeferDestination(destination, for: .restoring))
    }
}
