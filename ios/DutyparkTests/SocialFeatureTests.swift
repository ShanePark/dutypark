import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class SocialFeatureTests: XCTestCase {
    private let baseURL = URL(string: "https://dutypark.test/api/")!

    func testPinnedOrderEditorStringsResolveInEveryLocale() throws {
        let keys = [
            "social.action.done",
            "social.action.editPinnedOrder",
            "social.hint.pinnedOrder",
            "social.section.pinnedOrder"
        ]

        for locale in ["en", "ko", "ja", "zh-Hans", "es"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try XCTUnwrap(Bundle(url: url))
            for key in keys {
                XCTAssertNotEqual(
                    bundle.localizedString(forKey: key, value: key, table: "Social"),
                    key,
                    "Missing \(key) for \(locale)"
                )
            }
        }
    }

    override func tearDown() {
        SocialURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testRepositoryDecodesDashboardRequestDirections() async throws {
        SocialURLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/dashboard/friends")
            return Self.response(
                request,
                status: 200,
                body: #"{"friends":[],"pendingRequestsTo":[{"id":1,"fromMember":{"id":11,"name":"Received","teamId":null,"team":null,"hasProfilePhoto":false,"profilePhotoVersion":0},"toMember":{"id":99,"name":"Me","teamId":null,"team":null,"hasProfilePhoto":false,"profilePhotoVersion":0},"status":"PENDING","createdAt":null,"requestType":"FRIEND_REQUEST"}],"pendingRequestsFrom":[{"id":2,"fromMember":{"id":99,"name":"Me","teamId":null,"team":null,"hasProfilePhoto":false,"profilePhotoVersion":0},"toMember":{"id":22,"name":"Sent","teamId":null,"team":null,"hasProfilePhoto":false,"profilePhotoVersion":0},"status":"PENDING","createdAt":null,"requestType":"FAMILY_REQUEST"}]}"#
            )
        }

        let info = try await LiveSocialRepository(client: makeClient()).friendInfo()

        XCTAssertEqual(info.pendingRequestsTo.first?.fromMember.id, 11)
        XCTAssertEqual(info.pendingRequestsFrom.first?.toMember.id, 22)
        XCTAssertEqual(info.pendingRequestsFrom.first?.requestType, .family)
    }

    func testRepositoryUsesExistingSearchAndMutationContracts() async throws {
        let recorder = SocialRequestRecorder()
        SocialURLProtocolStub.handler = { request in
            recorder.append(request)
            let body = if request.url?.path == "/api/friends/search" {
                #"{"content":[],"totalPages":0,"totalElements":0,"last":true,"first":true,"size":5,"number":2,"numberOfElements":0,"empty":true}"#
            } else {
                ""
            }
            return Self.response(request, status: request.url?.path == "/api/friends/search" ? 200 : 204, body: body)
        }

        let repository = LiveSocialRepository(client: makeClient())
        _ = try await repository.search(keyword: "shane park", page: 2, size: 5)
        try await repository.sendFriendRequest(to: 10)
        try await repository.cancelRequest(to: 11)
        try await repository.acceptRequest(from: 12)
        try await repository.rejectRequest(from: 13)
        try await repository.sendFamilyRequest(to: 14)
        try await repository.removeFromFamily(15)
        try await repository.removeFriend(16)
        try await repository.pin(17)
        try await repository.unpin(18)
        try await repository.updatePinnedOrder([18, 17])

        let requests = recorder.requests
        XCTAssertEqual(requests[0].url?.path, "/api/friends/search")
        XCTAssertEqual(
            URLComponents(url: requests[0].url!, resolvingAgainstBaseURL: false)?.queryItems,
            [
                URLQueryItem(name: "keyword", value: "shane park"),
                URLQueryItem(name: "page", value: "2"),
                URLQueryItem(name: "size", value: "5")
            ]
        )
        XCTAssertEqual(requests.dropFirst().map { $0.httpMethod }, [
            "POST", "DELETE", "POST", "POST", "PUT", "DELETE", "DELETE", "PATCH", "PATCH", "PATCH"
        ])
        XCTAssertEqual(requests.dropFirst().map { $0.url!.path }, [
            "/api/friends/request/send/10",
            "/api/friends/request/cancel/11",
            "/api/friends/request/accept/12",
            "/api/friends/request/reject/13",
            "/api/friends/family/14",
            "/api/friends/family/15",
            "/api/friends/16",
            "/api/friends/pin/17",
            "/api/friends/unpin/18",
            "/api/friends/pin/order"
        ])
    }

    func testPinnedOrderPayloadUsesArrayJSONShape() throws {
        let payload = try JSONEncoder().encode([MemberID](arrayLiteral: 18, 17))

        XCTAssertEqual(payload, Data("[18,17]".utf8))
    }

    func testViewModelKeepsReceivedAndSentRequestDirections() async {
        let repository = SocialRepositorySpy()
        let viewModel = SocialViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.receivedRequests.first?.fromMember.id, 11)
        XCTAssertEqual(viewModel.sentRequests.first?.toMember.id, 22)

        if let received = viewModel.receivedRequests.first {
            await viewModel.accept(received)
        }
        if let sent = viewModel.sentRequests.first {
            await viewModel.cancel(sent)
        }

        XCTAssertEqual(repository.actions, ["accept:11", "cancel:22"])
    }

    func testNativeListReorderSavesDraftOnlyOnceWhenConfirmed() async {
        let repository = SocialRepositorySpy()
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()

        var draftIDs = viewModel.pinnedFriends.compactMap(\.member.id)
        draftIDs.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        XCTAssertFalse(repository.actions.contains(where: { $0.hasPrefix("order:") }))

        let didSave = await viewModel.savePinnedOrder(draftIDs)

        XCTAssertTrue(didSave)
        XCTAssertEqual(repository.actions.last, "order:32,31")
        XCTAssertEqual(repository.actions.filter { $0.hasPrefix("order:") }.count, 1)
    }

    func testFailedNativeListReorderKeepsOriginalOrderAndReportsFailure() async {
        let repository = SocialRepositorySpy(failPinnedOrder: true)
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()
        let originalOrder = viewModel.pinnedFriends.compactMap(\.member.id)
        var draftIDs = originalOrder
        draftIDs.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        let didSave = await viewModel.savePinnedOrder(draftIDs)

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.pinnedFriends.compactMap(\.member.id), originalOrder)
        XCTAssertNil(viewModel.errorKey)
        XCTAssertFalse(viewModel.isReordering)
    }

    func testNativeListReorderRejectsIDsOutsidePinnedFriends() async {
        let repository = SocialRepositorySpy()
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()

        let didSave = await viewModel.savePinnedOrder([32, 33])

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.errorKey, "social.error.reorder")
        XCTAssertFalse(repository.actions.contains(where: { $0.hasPrefix("order:") }))
    }

    func testSuccessfulMutationsReportOnlyReceivedRequestCountEffects() async {
        let repository = SocialRepositorySpy()
        var effects: [Bool] = []
        let viewModel = SocialViewModel(repository: repository) { affectsReceivedRequestCount in
            effects.append(affectsReceivedRequestCount)
        }
        await viewModel.load()

        if let received = viewModel.receivedRequests.first {
            await viewModel.accept(received)
        }
        if let friend = viewModel.friends.first {
            await viewModel.togglePin(friend)
        }

        XCTAssertEqual(effects, [true, false])
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SocialURLProtocolStub.self]
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

private final class SocialRepositorySpy: SocialRepository, @unchecked Sendable {
    private let lock = NSLock()
    private let failPinnedOrder: Bool
    private var storedActions: [String] = []

    init(failPinnedOrder: Bool = false) {
        self.failPinnedOrder = failPinnedOrder
    }

    var actions: [String] {
        lock.withLock { storedActions }
    }

    func friendInfo() async throws -> DashboardFriendInfoDTO {
        DashboardFriendInfoDTO(
            friends: [
                friend(id: 31, pinOrder: 1),
                friend(id: 32, pinOrder: 2),
                friend(id: 33, pinOrder: nil)
            ],
            pendingRequestsTo: [request(id: 1, from: 11, to: 99)],
            pendingRequestsFrom: [request(id: 2, from: 99, to: 22)]
        )
    }

    func search(keyword: String, page: Int, size: Int) async throws -> PageResponse<MemberPreviewDTO> {
        throw APIError.transport
    }

    func sendFriendRequest(to memberID: MemberID) async throws { record("send:\(memberID)") }
    func cancelRequest(to memberID: MemberID) async throws { record("cancel:\(memberID)") }
    func acceptRequest(from memberID: MemberID) async throws { record("accept:\(memberID)") }
    func rejectRequest(from memberID: MemberID) async throws { record("reject:\(memberID)") }
    func sendFamilyRequest(to memberID: MemberID) async throws { record("family:\(memberID)") }
    func removeFromFamily(_ memberID: MemberID) async throws { record("demote:\(memberID)") }
    func removeFriend(_ memberID: MemberID) async throws { record("remove:\(memberID)") }
    func pin(_ memberID: MemberID) async throws { record("pin:\(memberID)") }
    func unpin(_ memberID: MemberID) async throws { record("unpin:\(memberID)") }
    func updatePinnedOrder(_ memberIDs: [MemberID]) async throws {
        record("order:\(memberIDs.map(String.init).joined(separator: ","))")
        if failPinnedOrder { throw SocialTestError.reorder }
    }

    private func record(_ action: String) {
        lock.withLock { storedActions.append(action) }
    }

    private func member(_ id: MemberID) -> MemberPreviewDTO {
        MemberPreviewDTO(
            id: id,
            name: "Member \(id)",
            teamId: nil,
            team: nil,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
    }

    private func friend(id: MemberID, pinOrder: Int64?) -> DashboardFriendDetailDTO {
        DashboardFriendDetailDTO(
            member: member(id),
            duty: nil,
            schedules: [],
            isFamily: false,
            pinOrder: pinOrder
        )
    }

    private func request(id: Int64, from: MemberID, to: MemberID) -> FriendRequestDTO {
        FriendRequestDTO(
            id: id,
            fromMember: member(from),
            toMember: member(to),
            status: .pending,
            createdAt: nil,
            requestType: .friend
        )
    }
}

private enum SocialTestError: Error {
    case reorder
}

private final class SocialRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequests: [URLRequest] = []

    var requests: [URLRequest] {
        lock.withLock { storedRequests }
    }

    func append(_ request: URLRequest) {
        lock.withLock { storedRequests.append(request) }
    }
}

private final class SocialURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { fatalError("Missing SocialURLProtocolStub handler") }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
