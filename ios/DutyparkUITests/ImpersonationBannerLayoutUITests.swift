import XCTest

final class ImpersonationBannerLayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testImpersonationBannerDoesNotOverlapHomeHeaderControls() {
        let app = launchImpersonatingApp()
        defer { app.terminate() }

        XCTAssertTrue(
            app.descendants(matching: .any)["screen.home"].waitForExistence(timeout: 20)
        )

        let banner = app.descendants(matching: .any)["impersonation.banner"].firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "Impersonation banner is missing")
        // SwiftUI propagates the identifier to the banner's leaf elements, so the banner's
        // real extent is the union of every element carrying it.
        let bannerElements = app.descendants(matching: .any)
            .matching(identifier: "impersonation.banner")
            .allElementsBoundByIndex

        let brand = app.descendants(matching: .any)["header.brand"].firstMatch
        let bell = app.descendants(matching: .any)["notifications.bell"].firstMatch
        XCTAssertTrue(brand.waitForExistence(timeout: 10), "Brand mark is missing")
        XCTAssertTrue(bell.waitForExistence(timeout: 10), "Notification bell is missing")

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "regression-ios-impersonation-banner-header-overlap"
        attachment.lifetime = .keepAlways
        add(attachment)

        let bannerFrame = bannerElements
            .map(\.frame)
            .reduce(banner.frame) { $0.union($1) }
        let window = app.windows.firstMatch.frame

        XCTAssertGreaterThanOrEqual(
            bannerFrame.minY,
            0,
            "Banner is clipped above the window. banner=\(describe(bannerFrame))"
        )
        XCTAssertLessThanOrEqual(
            bannerFrame.maxY,
            window.maxY,
            "Banner extends past the window. banner=\(describe(bannerFrame)),"
                + " window=\(describe(window))"
        )

        let epsilon: CGFloat = 1
        for (name, element) in [("header.brand", brand), ("notifications.bell", bell)] {
            let headerFrame = element.frame
            let overlap = bannerFrame.maxY - headerFrame.minY
            XCTAssertLessThanOrEqual(
                bannerFrame.maxY,
                headerFrame.minY + epsilon,
                "Impersonation banner vertically overlaps \(name) by \(overlap)pt."
                    + " banner=\(describe(bannerFrame)), \(name)=\(describe(headerFrame)),"
                    + " window=\(describe(window))"
            )
        }
    }

    @MainActor
    private func launchImpersonatingApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-dp-theme", "dark",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
            "-ui-testing-authenticated",
            "-ui-testing-impersonating",
        ]
        app.launch()
        return app
    }

    private func describe(_ frame: CGRect) -> String {
        String(
            format: "(x: %.1f, y: %.1f, w: %.1f, h: %.1f, maxY: %.1f)",
            frame.minX,
            frame.minY,
            frame.width,
            frame.height,
            frame.maxY
        )
    }
}
