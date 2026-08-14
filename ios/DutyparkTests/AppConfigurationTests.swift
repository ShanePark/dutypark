import XCTest
@testable import Dutypark

final class AppConfigurationTests: XCTestCase {
    func testAcceptsDevelopmentAndProductionAPIBaseURLs() {
        XCTAssertEqual(
            AppConfiguration.validatedAPIBaseURL("http://localhost:8080/api/"),
            URL(string: "http://localhost:8080/api/")
        )
        XCTAssertEqual(
            AppConfiguration.validatedAPIBaseURL("https://dutypark.o-r.kr/api/"),
            URL(string: "https://dutypark.o-r.kr/api/")
        )
    }

    func testRejectsMalformedOrNonAPIBaseURLs() {
        XCTAssertNil(AppConfiguration.validatedAPIBaseURL("dutypark.o-r.kr/api/"))
        XCTAssertNil(AppConfiguration.validatedAPIBaseURL("file:///tmp/api/"))
        XCTAssertNil(AppConfiguration.validatedAPIBaseURL("https://dutypark.o-r.kr/"))
    }

    func testBuildsAdminBaseURLFromAPIOrigin() {
        XCTAssertEqual(
            AppConfiguration.baseURL(
                for: .admin,
                apiBaseURL: URL(string: "http://localhost:8080/api/")!
            ),
            URL(string: "http://localhost:8080/admin/api/")
        )
        XCTAssertEqual(
            AppConfiguration.baseURL(
                for: .admin,
                apiBaseURL: URL(string: "https://dutypark.o-r.kr/api/")!
            ),
            URL(string: "https://dutypark.o-r.kr/admin/api/")
        )
    }

    func testAdminBaseURLUsesOnlyOriginFromAPIBaseURL() {
        XCTAssertEqual(
            AppConfiguration.baseURL(
                for: .admin,
                apiBaseURL: URL(string: "https://dutypark.test/nested/api/?ignored=true#fragment")!
            ),
            URL(string: "https://dutypark.test/admin/api/")
        )
    }
}
