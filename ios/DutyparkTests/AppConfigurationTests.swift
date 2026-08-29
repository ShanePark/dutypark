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

    func testDemoCaptureEndpointIsLocalOnly() {
        XCTAssertTrue(
            AppConfiguration.isLocalCaptureEndpoint(
                URL(string: "http://localhost:8080/api/")!
            )
        )
        XCTAssertTrue(
            AppConfiguration.isLocalCaptureEndpoint(
                URL(string: "http://127.0.0.1:8080/api/")!
            )
        )
        XCTAssertFalse(
            AppConfiguration.isLocalCaptureEndpoint(
                URL(string: "https://dutypark.o-r.kr/api/")!
            )
        )
    }
}
