import Foundation
import XCTest
@testable import Dutypark

final class GuestDeepLinkTests: XCTestCase {
    func testParsesSupportedHTTPSRoutes() {
        XCTAssertEqual(route("https://dutypark.o-r.kr/guide"), .guide)
        XCTAssertEqual(route("https://dutypark.o-r.kr/terms"), .terms)
        XCTAssertEqual(route("https://dutypark.o-r.kr/privacy"), .privacy)
        XCTAssertEqual(route("https://dutypark.o-r.kr/duty/42?month=8"), .publicCalendar(42))
    }

    func testRejectsUnsupportedOrUntrustedLinks() {
        XCTAssertNil(route("http://dutypark.o-r.kr/duty/42"))
        XCTAssertNil(route("https://example.com/duty/42"))
        XCTAssertNil(route("https://dutypark.o-r.kr/duty/0"))
        XCTAssertNil(route("https://dutypark.o-r.kr/admin"))
    }

    private func route(_ value: String) -> GuestRoute? {
        GuestDeepLink.route(from: URL(string: value)!)
    }
}

final class GuestPublicLinkTests: XCTestCase {
    func testBuildsExistingHTTPSCalendarURL() {
        XCTAssertEqual(
            GuestPublicCalendarLink.url(memberID: 42).absoluteString,
            "https://dutypark.o-r.kr/duty/42"
        )
    }

    func testGuideWebLocaleFollowsExplicitAppSelection() {
        XCTAssertEqual(GuideLocaleResolver.webLocale(languageCode: "ko"), "ko")
        XCTAssertEqual(GuideLocaleResolver.webLocale(languageCode: "en"), "en")
        XCTAssertEqual(GuideLocaleResolver.webLocale(languageCode: "ja"), "ja")
        XCTAssertEqual(GuideLocaleResolver.webLocale(languageCode: "zh-Hans"), "zh")
        XCTAssertEqual(GuideLocaleResolver.webLocale(languageCode: "es"), "es")
    }

    func testGuideWebLocaleUsesDeviceLanguageOnlyWithoutSelection() {
        XCTAssertEqual(
            GuideLocaleResolver.webLocale(languageCode: "", preferredLanguages: ["zh-Hans-KR"]),
            "zh"
        )
        XCTAssertEqual(
            GuideLocaleResolver.webLocale(languageCode: "", preferredLanguages: ["fr-FR"]),
            "ko"
        )
    }
}

@MainActor
final class GuestPublicCalendarTests: XCTestCase {
    func testLoadsPublicCalendarWithoutAuthenticatedEndpoints() async {
        let api = GuestAPIMock()
        let model = GuestPublicCalendarViewModel(
            memberID: 42,
            api: api,
            now: date(2026, 8, 12)
        )

        await model.load()

        XCTAssertFalse(model.hasError)
        XCTAssertEqual(model.member?.name, "Public member")
        XCTAssertEqual(model.days.count, 42)
        XCTAssertEqual(model.days[11].duty?.dutyType, "Night")
        XCTAssertEqual(model.dDays.first?.title, "Anniversary")
    }

    func testMonthNavigationCrossesYearBoundary() async {
        let model = GuestPublicCalendarViewModel(
            memberID: 42,
            api: GuestAPIMock(),
            now: date(2026, 12, 1)
        )
        await model.load()

        await model.changeMonth(by: 1)

        XCTAssertEqual(model.year, 2027)
        XCTAssertEqual(model.month, 1)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        CalendarDateSupport.calendar.date(
            from: DateComponents(year: year, month: month, day: day)
        )!
    }
}

final class GuestAPIRequestTests: XCTestCase {
    override func tearDown() {
        GuestURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testPublicRequestDoesNotAttemptSessionRefreshAfterUnauthorized() async {
        let refreshes = GuestLockedCounter()
        GuestURLProtocolStub.handler = { request in
            if request.url?.path == "/api/auth/refresh" {
                refreshes.increment()
                return Self.response(request, status: 200)
            }
            return Self.response(
                request,
                status: 401,
                body: #"{"status":401,"code":"auth.required"}"#
            )
        }

        do {
            _ = try await GuestAPI(client: makeClient()).member(id: 42)
            XCTFail("Expected unauthorized response")
        } catch APIError.server(status: 401, code: "auth.required") {
            XCTAssertEqual(refreshes.value, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GuestURLProtocolStub.self]
        return APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        )
    }

    private static func response(
        _ request: URLRequest,
        status: Int,
        body: String = ""
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!,
            Data(body.utf8)
        )
    }
}

private actor GuestAPIMock: GuestAPIProtocol {
    func member(id: MemberID) async throws -> MemberPreviewDTO {
        MemberPreviewDTO(
            id: id,
            name: "Public member",
            teamId: nil,
            team: nil,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
    }

    func calendar(year: Int, month: Int) async throws -> [TeamDayDTO] {
        (1...42).map { TeamDayDTO(year: year, month: month, day: $0) }
    }

    func duties(memberID: MemberID, year: Int, month: Int) async throws -> [DutyDTO] {
        [DutyDTO(
            year: year,
            month: month,
            day: 12,
            dutyType: "Night",
            dutyColor: "#3B82F6",
            isOff: false,
            dutyTypeId: 1,
            source: .override
        )]
    }

    func schedules(memberID: MemberID, year: Int, month: Int) async throws -> [[ScheduleDTO]] {
        Array(repeating: [], count: 42)
    }

    func holidays(year: Int, month: Int) async throws -> [[HolidayDTO]] {
        Array(repeating: [], count: 42)
    }

    func dDays(memberID: MemberID) async throws -> [DDayDTO] {
        [DDayDTO(
            id: 1,
            title: "Anniversary",
            date: DateOnly(rawValue: "2026-08-20"),
            isPrivate: false,
            calc: 8,
            daysLeft: 8
        )]
    }

    func policy(_ type: PolicyType) async throws -> PolicyDTO {
        PolicyDTO(
            policyType: type,
            version: "2026-08-12",
            content: "Policy",
            effectiveDate: DateOnly(rawValue: "2026-08-12")
        )
    }
}

private final class GuestLockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

private final class GuestURLProtocolStub: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let result: (HTTPURLResponse, Data)
        do {
            Self.lock.lock()
            let handler = Self.handler
            Self.lock.unlock()
            guard let handler else { throw URLError(.badServerResponse) }
            result = try handler(request)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        client?.urlProtocol(self, didReceive: result.0, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: result.1)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
