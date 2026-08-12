import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class HomeDashboardTests: XCTestCase {
    func testLoadsBothDashboardSectionsAndKeepsPinnedOrder() async throws {
        let myDashboard = try Self.decodeMyDashboard()
        let friendsDashboard = try Self.decodeFriendsDashboard()
        let viewModel = HomeViewModel(
            service: HomeServiceStub(my: myDashboard, friends: friendsDashboard)
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.myDashboard?.member.name, "Shane")
        XCTAssertEqual(viewModel.receivedRequestCount, 2)
        XCTAssertEqual(viewModel.sentRequestCount, 1)
        XCTAssertEqual(viewModel.sortedFriends.map(\.member.id), [2, 3, 4])
    }

    func testOneFailedSectionDoesNotHideTheOtherSection() async throws {
        let friendsDashboard = try Self.decodeFriendsDashboard()
        let viewModel = HomeViewModel(
            service: PartialFailureHomeService(friends: friendsDashboard)
        )

        await viewModel.refresh()

        if case .failed = viewModel.myState {
            // Expected.
        } else {
            XCTFail("My dashboard should expose its error state")
        }
        XCTAssertEqual(viewModel.friendsDashboard?.friends.count, 3)
    }

    func testServiceUsesTheExistingWebDashboardEndpoints() async throws {
        let recorder = HomeRequestRecorder()
        HomeURLProtocolStub.handler = { request in
            recorder.append(request.url?.path ?? "")
            let body: String
            switch request.url?.path {
            case "/api/dashboard/my":
                body = Self.myDashboardJSON
            case "/api/dashboard/friends":
                body = Self.friendsDashboardJSON
            default:
                return Self.response(request, status: 404, body: "")
            }
            return Self.response(request, status: 200, body: body)
        }
        defer { HomeURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HomeURLProtocolStub.self]
        let client = APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        )
        let service = HomeDashboardService(client: client)

        _ = try await service.loadMyDashboard()
        _ = try await service.loadFriendsDashboard()

        XCTAssertEqual(recorder.paths, ["/api/dashboard/my", "/api/dashboard/friends"])
    }

    private nonisolated static func decodeMyDashboard() throws -> DashboardMyDetailDTO {
        try JSONDecoder().decode(DashboardMyDetailDTO.self, from: Data(myDashboardJSON.utf8))
    }

    private nonisolated static func decodeFriendsDashboard() throws -> DashboardFriendInfoDTO {
        try JSONDecoder().decode(DashboardFriendInfoDTO.self, from: Data(friendsDashboardJSON.utf8))
    }

    private nonisolated static func response(
        _ request: URLRequest,
        status: Int,
        body: String
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

    private nonisolated static let myDashboardJSON = """
        {
          "member": {
            "id": 1,
            "name": "Shane",
            "email": "test@duty.park",
            "teamId": 7,
            "team": "Dutypark",
            "calendarVisibility": "FRIENDS",
            "kakaoId": null,
            "naverId": null,
            "hasPassword": true,
            "hasProfilePhoto": false,
            "profilePhotoVersion": 0
          },
          "duty": {
            "year": 2026,
            "month": 8,
            "day": 12,
            "dutyType": "Day",
            "dutyColor": "#FACC15",
            "isOff": false,
            "dutyTypeId": 11,
            "source": "PATTERN"
          },
          "schedules": []
        }
        """

    private nonisolated static let friendsDashboardJSON = """
        {
          "friends": [
            {
              "member": {"id":4,"name":"Unpinned","teamId":7,"team":"Dutypark","hasProfilePhoto":false,"profilePhotoVersion":0},
              "duty": null,
              "schedules": [],
              "isFamily": false,
              "pinOrder": null
            },
            {
              "member": {"id":3,"name":"Second","teamId":7,"team":"Dutypark","hasProfilePhoto":false,"profilePhotoVersion":0},
              "duty": null,
              "schedules": [],
              "isFamily": false,
              "pinOrder": 2
            },
            {
              "member": {"id":2,"name":"First","teamId":7,"team":"Dutypark","hasProfilePhoto":false,"profilePhotoVersion":0},
              "duty": null,
              "schedules": [],
              "isFamily": true,
              "pinOrder": 1
            }
          ],
          "pendingRequestsTo": [
            {
              "id": 10,
              "fromMember": {"id":5,"name":"Received One","teamId":null,"team":null,"hasProfilePhoto":false,"profilePhotoVersion":0},
              "toMember": {"id":1,"name":"Shane","teamId":7,"team":"Dutypark","hasProfilePhoto":false,"profilePhotoVersion":0},
              "status": "PENDING",
              "createdAt": null,
              "requestType": "FRIEND_REQUEST"
            },
            {
              "id": 12,
              "fromMember": {"id":7,"name":"Received Two","teamId":null,"team":null,"hasProfilePhoto":false,"profilePhotoVersion":0},
              "toMember": {"id":1,"name":"Shane","teamId":7,"team":"Dutypark","hasProfilePhoto":false,"profilePhotoVersion":0},
              "status": "PENDING",
              "createdAt": null,
              "requestType": "FRIEND_REQUEST"
            }
          ],
          "pendingRequestsFrom": [
            {
              "id": 11,
              "fromMember": {"id":1,"name":"Shane","teamId":7,"team":"Dutypark","hasProfilePhoto":false,"profilePhotoVersion":0},
              "toMember": {"id":6,"name":"Sent","teamId":null,"team":null,"hasProfilePhoto":false,"profilePhotoVersion":0},
              "status": "PENDING",
              "createdAt": null,
              "requestType": "FRIEND_REQUEST"
            }
          ]
        }
        """
}

private nonisolated struct HomeServiceStub: HomeDashboardServing {
    let my: DashboardMyDetailDTO
    let friends: DashboardFriendInfoDTO

    func loadMyDashboard() async throws -> DashboardMyDetailDTO { my }
    func loadFriendsDashboard() async throws -> DashboardFriendInfoDTO { friends }
}

private nonisolated struct PartialFailureHomeService: HomeDashboardServing {
    let friends: DashboardFriendInfoDTO

    func loadMyDashboard() async throws -> DashboardMyDetailDTO {
        throw HomeServiceStubError.failed
    }

    func loadFriendsDashboard() async throws -> DashboardFriendInfoDTO { friends }
}

private nonisolated enum HomeServiceStubError: Error {
    case failed
}

private final class HomeRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedPaths: [String] = []

    var paths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedPaths
    }

    func append(_ path: String) {
        lock.lock()
        storedPaths.append(path)
        lock.unlock()
    }
}

private final class HomeURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("HomeURLProtocolStub.handler is not set")
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
