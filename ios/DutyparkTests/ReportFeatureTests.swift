import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class ReportFeatureTests: XCTestCase {
    private let baseURL = URL(string: "https://dutypark.test/api/")!

    override func tearDown() {
        ReportURLProtocolStub.handler = nil
        super.tearDown()
    }

    // MARK: - Submission rules

    func testOnlyTheOtherReasonRequiresWrittenDetail() {
        XCTAssertTrue(ReportSubmissionPolicy.canSubmit(reason: .spam, detail: ""))
        XCTAssertFalse(ReportSubmissionPolicy.canSubmit(reason: .other, detail: ""))
        XCTAssertFalse(ReportSubmissionPolicy.canSubmit(reason: .other, detail: "   \n "))
        XCTAssertTrue(ReportSubmissionPolicy.canSubmit(reason: .other, detail: "광고 도배"))
        XCTAssertFalse(
            ReportSubmissionPolicy.canSubmit(
                reason: .spam,
                detail: String(repeating: "가", count: ReportSubmissionPolicy.detailLimit + 1)
            )
        )
    }

    func testSubmitSendsTrimmedDetailAndAlsoBlockFlag() async {
        let repository = ReportRepositorySpy()
        let model = ReportViewModel(
            target: ReportTarget(type: .schedule, targetID: "42", name: "회식"),
            repository: repository
        )
        model.reason = .harassment
        model.detail = "  욕설을 했습니다  "
        model.alsoBlock = true

        let submitted = await model.submit()

        XCTAssertTrue(submitted)
        XCTAssertTrue(model.didSubmit)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(
            repository.reports,
            [
                CreateReportRequest(
                    targetType: .schedule,
                    targetId: "42",
                    reason: .harassment,
                    detail: "욕설을 했습니다",
                    alsoBlock: true
                )
            ]
        )
        // `alsoBlock` travels with the report; the client never calls the block API itself.
        XCTAssertTrue(repository.blockedMembers.isEmpty)
        XCTAssertFalse(model.canSubmit, "A submitted report cannot be sent twice")
    }

    func testSubmitOmitsBlankDetailAndKeepsTheDefaultReason() async {
        let repository = ReportRepositorySpy()
        let model = ReportViewModel(
            target: ReportTarget(type: .member, targetID: "7", name: "홍길동"),
            repository: repository
        )
        model.detail = "   "

        let submitted = await model.submit()
        XCTAssertTrue(submitted)
        XCTAssertEqual(repository.reports.first?.reason, .spam)
        XCTAssertNil(repository.reports.first?.detail)
        XCTAssertEqual(repository.reports.first?.alsoBlock, false)
    }

    func testOtherReasonWithoutDetailNeverReachesTheServer() async {
        let repository = ReportRepositorySpy()
        let model = ReportViewModel(
            target: ReportTarget(type: .todo, targetID: "9", name: "청소"),
            repository: repository
        )
        model.reason = .other

        XCTAssertFalse(model.canSubmit)
        XCTAssertTrue(model.requiresDetail)
        let submitted = await model.submit()
        XCTAssertFalse(submitted)
        XCTAssertTrue(repository.reports.isEmpty)
        XCTAssertFalse(model.didSubmit)
    }

    func testSubmitFailureSurfacesTheServerMessageWithoutMarkingSuccess() async {
        let repository = ReportRepositorySpy(error: APIError.server(status: 400, code: "report.self"))
        let model = ReportViewModel(
            target: ReportTarget(type: .member, targetID: "7", name: "홍길동"),
            repository: repository
        )

        let submitted = await model.submit()
        XCTAssertFalse(submitted)
        XCTAssertFalse(model.didSubmit)
        let message = model.errorMessage ?? ""
        XCTAssertFalse(message.isEmpty)
        XCTAssertNotEqual(message, "report.self")
        XCTAssertTrue(model.canSubmit, "A failed report can be retried")
    }

    // MARK: - Repository contract

    func testANewReportPostsTheDocumentedBodyAndAcceptsA201() async throws {
        let recorder = ReportRequestRecorder()
        ReportURLProtocolStub.handler = { request in
            recorder.append(request)
            return Self.response(request, status: 201, body: #"{"id":1}"#)
        }

        let model = ReportViewModel(
            target: ReportTarget(type: .schedule, targetID: "42", name: "회식"),
            repository: ReportAPIRepository(client: makeClient())
        )
        model.reason = .impersonation

        let submitted = await model.submit()
        XCTAssertTrue(submitted)

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.url?.path, "/api/reports")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(recorder.bodies.first)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["targetType"] as? String, "SCHEDULE")
        XCTAssertEqual(payload["targetId"] as? String, "42")
        XCTAssertEqual(payload["reason"] as? String, "IMPERSONATION")
        XCTAssertEqual(payload["alsoBlock"] as? Bool, false)
        XCTAssertNil(payload["detail"])
    }

    func testADuplicateReportAnsweredWith200IsStillASuccess() async {
        ReportURLProtocolStub.handler = { request in
            Self.response(request, status: 200, body: #"{"id":1}"#)
        }

        let model = ReportViewModel(
            target: ReportTarget(type: .member, targetID: "7", name: "홍길동"),
            repository: ReportAPIRepository(client: makeClient())
        )

        let submitted = await model.submit()
        XCTAssertTrue(submitted)
        XCTAssertTrue(model.didSubmit)
        XCTAssertNil(model.errorMessage)
    }

    func testBlockingPostsToTheBlocksEndpoint() async throws {
        let recorder = ReportRequestRecorder()
        ReportURLProtocolStub.handler = { request in
            recorder.append(request)
            return Self.response(request, status: 204)
        }

        let model = MemberBlockViewModel(repository: ReportAPIRepository(client: makeClient()))

        let blocked = await model.block(memberID: 7)
        XCTAssertTrue(blocked)
        XCTAssertNil(model.errorMessage)
        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.url?.path, "/api/blocks/7")
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testAFailedBlockKeepsTheUserOnTheCalendar() async {
        let repository = ReportRepositorySpy(error: APIError.server(status: 400, code: "block.self"))
        let model = MemberBlockViewModel(repository: repository)

        let blocked = await model.block(memberID: 7)
        XCTAssertFalse(blocked)
        XCTAssertFalse(model.isBlocking)
        XCTAssertFalse((model.errorMessage ?? "").isEmpty)
    }

    // MARK: - Entry points

    func testMemberCalendarOffersReportAndBlockFromTheIdentityChip() throws {
        let source = try source(of: "Dutypark/Features/Calendar/CalendarView.swift")

        for wiring in [
            // The menu belongs to a signed-in visitor looking at somebody else's calendar.
            "isPushedMemberCalendar && !model.isMyCalendar && model.me != nil",
            // The avatar and the name are the menu label, the way a social app opens
            // member actions from the identity itself.
            "private var memberActionsMenu: some View",
            "        } label: {\n            memberIdentity",
            "calendar.report.member",
            "calendar.block.member",
            "calendar.member.menu",
            // With the overflow button gone the trailing slot is free to keep
            // "this month" as a plain bar button again.
            "if !isViewingCurrentMonth {",
            "calendar.block.confirm.message",
            "isWorking: blockModel.isBlocking",
            "memberBackAction?()",
            // Reporting one schedule reuses the same sheet.
            "calendar.schedule.report",
            "model.me != nil && (!model.isMyCalendar || schedule.isTagged)",
            "ReportSheet(",
        ] {
            XCTAssertTrue(source.contains(wiring), "CalendarView is missing: \(wiring)")
        }

        XCTAssertFalse(
            source.contains("Image(systemName: \"ellipsis\")"),
            "The member calendar must not keep a separate overflow button"
        )
    }

    // Back stays a control of its own so the identity chip is free to open the menu.
    func testMemberCalendarKeepsBackSeparateFromTheIdentityChip() throws {
        let source = try source(of: "Dutypark/Features/Calendar/CalendarView.swift")

        let backButton = try XCTUnwrap(
            source.range(of: "accessibilityIdentifier(\"calendar.member.back\")")
                .map { source[source.startIndex..<$0.lowerBound] }
        )
        let button = try XCTUnwrap(backButton.range(of: "Button(action: memberBackAction)", options: .backwards))
        XCTAssertFalse(
            backButton[button.upperBound...].contains("memberIdentity"),
            "The back button must not wrap the avatar and the name"
        )
    }

    func testTaggedTodoDetailOffersReport() throws {
        let source = try source(of: "Dutypark/Features/Todo/TodoModalViews.swift")

        XCTAssertTrue(source.contains("todo.action.report"))
        XCTAssertTrue(source.contains("todo.detail.report"))
        XCTAssertTrue(source.contains("reportTarget = ReportTarget("))
        XCTAssertTrue(source.contains("type: .todo,"))
        XCTAssertTrue(source.contains("ReportSheet("))
    }

    func testGuestReportAsksForSignInInsteadOfOpeningTheSheet() throws {
        let source = try source(of: "Dutypark/Features/Guest/GuestPublicCalendarView.swift")

        for wiring in [
            "guest.calendar.menu",
            "guest.calendar.report",
            "guest.calendar.report.loginMessage",
            "NavigationLink(value: GuestRoute.login)",
            "guest.calendar.report.login",
        ] {
            XCTAssertTrue(source.contains(wiring), "GuestPublicCalendarView is missing: \(wiring)")
        }
        // A guest has no account to report from, so no per-item report control exists.
        XCTAssertFalse(source.contains("ReportSheet("))
    }

    // MARK: - Localization

    func testEveryReportCatalogKeyIsTranslatedInBothLanguages() throws {
        let keys = try catalogKeys(of: "Dutypark/Features/Report/Report.xcstrings")
        XCTAssertFalse(keys.isEmpty)

        for locale in ["en", "ko"] {
            let bundle = try localizedBundle(locale)
            for key in keys {
                XCTAssertNotEqual(
                    bundle.localizedString(forKey: key, value: key, table: "Report"),
                    key,
                    "Missing \(key) for \(locale)"
                )
            }
        }
    }

    func testReportSuccessAndTargetCopyMatchesTheAgreedWording() throws {
        let korean = try localizedBundle("ko")

        XCTAssertEqual(
            korean.localizedString(forKey: "report.success.message", value: "", table: "Report"),
            "신고가 접수되었습니다. 24시간 이내에 확인합니다."
        )
        XCTAssertEqual(
            korean.localizedString(forKey: "report.target.schedule", value: "", table: "Report"),
            "일정: %@"
        )
        XCTAssertEqual(
            korean.localizedString(forKey: "report.field.alsoBlock", value: "", table: "Report"),
            "이 사용자 차단하기"
        )
    }

    func testCalendarBlockAndReportKeysAreTranslatedInBothLanguages() throws {
        try assertTranslated(
            keys: [
                "calendar.block.confirm.action",
                "calendar.block.confirm.message",
                "calendar.block.confirm.title",
                "calendar.block.member",
                "calendar.report.member",
                "calendar.report.schedule",
            ],
            table: "Calendar"
        )
        XCTAssertEqual(
            try localizedBundle("ko").localizedString(
                forKey: "calendar.block.confirm.message",
                value: "",
                table: "Calendar"
            ),
            "차단하면 친구 관계가 해제되고 서로의 달력·검색·요청·알림이 차단됩니다. 같은 팀 근무표는 계속 표시됩니다."
        )
    }

    func testGuestAndTodoReportKeysAreTranslatedInBothLanguages() throws {
        try assertTranslated(
            keys: [
                "guest.calendar.more",
                "guest.calendar.report",
                "guest.calendar.report.loginMessage",
                "guest.calendar.report.loginTitle",
            ],
            table: "Guest"
        )
        try assertTranslated(keys: ["todo.action.report"], table: "Todo")
    }

    func testTheNewServerErrorCodesResolveToLocalizedMessages() throws {
        try assertTranslated(
            keys: [
                "auth.account.suspended",
                "block.self",
                "friend.request.blocked",
                "inquiry.rateLimit.exceeded",
                "member.suspend.deletionPending",
                "report.detail.required",
                "report.self",
                "report.target.notDeletable",
            ],
            table: "Errors"
        )
        XCTAssertEqual(
            APIErrorLocalization.message(code: "auth.account.suspended", bundle: try localizedBundle("ko")),
            "계정이 이용 정지되었습니다. 이의제기는 문의 페이지를 이용해 주세요."
        )
    }

    // MARK: - Helpers

    private func assertTranslated(
        keys: [String],
        table: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for locale in ["en", "ko"] {
            let bundle = try localizedBundle(locale)
            for key in keys {
                XCTAssertNotEqual(
                    bundle.localizedString(forKey: key, value: key, table: table),
                    key,
                    "Missing \(key) in \(table) for \(locale)",
                    file: file,
                    line: line
                )
            }
        }
    }

    private func localizedBundle(_ locale: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: locale, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }

    private func catalogKeys(of relativePath: String) throws -> [String] {
        let catalog = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: projectRoot.appending(path: relativePath)))
                as? [String: Any]
        )
        return try XCTUnwrap(catalog["strings"] as? [String: Any]).keys.sorted()
    }

    private func source(of relativePath: String) throws -> String {
        try String(contentsOf: projectRoot.appending(path: relativePath), encoding: .utf8)
    }

    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReportURLProtocolStub.self]
        return APIClient(baseURL: baseURL, session: URLSession(configuration: configuration))
    }

    nonisolated private static func response(
        _ request: URLRequest,
        status: Int,
        body: String = ""
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
            Data(body.utf8)
        )
    }
}

private final class ReportRepositorySpy: ReportRepository, @unchecked Sendable {
    private let lock = NSLock()
    private let error: (any Error)?
    private var recordedReports: [CreateReportRequest] = []
    private var recordedBlocks: [MemberID] = []

    init(error: (any Error)? = nil) {
        self.error = error
    }

    var reports: [CreateReportRequest] {
        lock.withLock { recordedReports }
    }

    var blockedMembers: [MemberID] {
        lock.withLock { recordedBlocks }
    }

    func createReport(_ request: CreateReportRequest) async throws {
        if let error { throw error }
        lock.withLock { recordedReports.append(request) }
    }

    func block(memberID: MemberID) async throws {
        if let error { throw error }
        lock.withLock { recordedBlocks.append(memberID) }
    }
}

private final class ReportRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [(URLRequest, Data?)] = []

    var requests: [URLRequest] {
        lock.withLock { recorded.map(\.0) }
    }

    var bodies: [Data] {
        lock.withLock { recorded.compactMap(\.1) }
    }

    func append(_ request: URLRequest) {
        // `URLProtocol` strips `httpBody` from the request it hands to the loader.
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll)
        lock.withLock { recorded.append((request, body)) }
    }

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let capacity = 1024
        var buffer = [UInt8](repeating: 0, count: capacity)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: capacity)
            guard read > 0 else { break }
            data.append(contentsOf: buffer[0..<read])
        }
        return data
    }
}

private final class ReportURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { fatalError("Missing ReportURLProtocolStub handler") }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
