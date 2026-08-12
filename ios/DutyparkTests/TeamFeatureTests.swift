import Foundation
import Testing
@testable import Dutypark

@Suite(.serialized)
struct TeamFeatureTests {
    @Test
    func teamAdminToolPermissionIncludesServiceAdminAndTeamRoles() {
        let team = managedTeam(
            adminID: 1,
            members: [
                TeamMemberDTO(
                    id: 2,
                    name: "Manager",
                    email: nil,
                    isManager: true,
                    isAdmin: false,
                    hasProfilePhoto: false,
                    profilePhotoVersion: 0
                ),
                TeamMemberDTO(
                    id: 3,
                    name: "Member",
                    email: nil,
                    isManager: false,
                    isAdmin: false,
                    hasProfilePhoto: false,
                    profilePhotoVersion: 0
                )
            ]
        )

        #expect(
            TeamManageViewModel.canUseAdminTools(
                loginID: nil,
                team: team,
                isServiceAdmin: true
            )
        )
        #expect(
            TeamManageViewModel.canUseAdminTools(
                loginID: 1,
                team: team,
                isServiceAdmin: false
            )
        )
        #expect(
            TeamManageViewModel.canUseAdminTools(
                loginID: 2,
                team: team,
                isServiceAdmin: false
            )
        )
        #expect(
            TeamManageViewModel.canUseAdminTools(
                loginID: 3,
                team: team,
                isServiceAdmin: false
            ) == false
        )
        #expect(
            TeamManageViewModel.canUseAdminTools(
                loginID: nil,
                team: nil,
                isServiceAdmin: false
            ) == false
        )
    }

    @Test @MainActor
    func reportsManagementMutationFailureWithoutLosingRetryState() async {
        TeamURLProtocolStub.handler = { request in
            Self.response(request, status: 503)
        }
        let viewModel = TeamManageViewModel(
            teamID: 7,
            repository: TeamRepository(client: makeClient())
        )

        let succeeded = await viewModel.removeMember(3)

        #expect(succeeded == false)
        #expect(viewModel.showsError)
        #expect(viewModel.showsSuccess == false)
        TeamURLProtocolStub.handler = nil
    }

    @Test @MainActor
    func reportsManagementMutationSuccessOnlyAfterRefreshingTeam() async {
        TeamURLProtocolStub.handler = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("DELETE", "/api/teams/manage/7/members"):
                Self.response(request, status: 204)
            case ("GET", "/api/teams/manage/7"):
                Self.response(
                    request,
                    status: 200,
                    body: #"{"id":7,"name":"Team","description":null,"dutyTypes":[],"members":[],"createdDate":"2026-08-12T00:00:00","lastModifiedDate":"2026-08-12T00:00:00","adminId":null,"adminName":null,"dutyBatchTemplate":null}"#
                )
            default:
                Self.response(request, status: 404)
            }
        }
        let viewModel = TeamManageViewModel(
            teamID: 7,
            repository: TeamRepository(client: makeClient())
        )

        let succeeded = await viewModel.removeMember(3)

        #expect(succeeded)
        #expect(viewModel.team?.id == 7)
        #expect(viewModel.showsError == false)
        #expect(viewModel.showsSuccess)
        TeamURLProtocolStub.handler = nil
    }

    @Test @MainActor
    func preservesLoadFailureUntilSuccessfulNoTeamResponse() async {
        TeamURLProtocolStub.handler = { request in
            Self.response(request, status: 503)
        }
        let viewModel = TeamViewModel(repository: TeamRepository(client: makeClient()))

        await viewModel.load(memberID: 1)

        #expect(viewModel.loadFailed)
        #expect(viewModel.team == nil)

        TeamURLProtocolStub.handler = { request in
            switch request.url?.path {
            case "/api/calendar":
                Self.response(request, status: 200, body: "[]")
            case "/api/teams/my":
                Self.response(
                    request,
                    status: 200,
                    body: #"{"year":2026,"month":8,"team":null,"teamDays":[],"isTeamManager":false}"#
                )
            default:
                Self.response(request, status: 404)
            }
        }

        await viewModel.load(memberID: 1)

        #expect(viewModel.loadFailed == false)
        #expect(viewModel.team == nil)
        TeamURLProtocolStub.handler = nil
    }

    @Test
    func findsVisibleDutyTypeNeighborAcrossHiddenRows() {
        let dutyTypes = [
            dutyType(id: nil, hidden: false),
            dutyType(id: 1, hidden: false),
            dutyType(id: 2, hidden: true),
            dutyType(id: 3, hidden: false)
        ]

        #expect(
            TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: 1,
                direction: 1
            ) == 3
        )
        #expect(
            TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: 3,
                direction: -1
            ) == 1
        )
    }

    @Test
    func excludesDefaultAndHiddenDutyTypesFromReorderTargets() {
        let dutyTypes = [
            dutyType(id: nil, hidden: false),
            dutyType(id: 1, hidden: true),
            dutyType(id: 2, hidden: false),
            dutyType(id: 3, hidden: true)
        ]

        #expect(
            TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: 2,
                direction: -1
            ) == nil
        )
        #expect(
            TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: 2,
                direction: 1
            ) == nil
        )
    }

    @Test
    func returnsNoNeighborForInvalidIndexesOrDirection() {
        let dutyTypes = [dutyType(id: 1, hidden: false)]

        #expect(
            TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: -1,
                direction: 1
            ) == nil
        )
        #expect(
            TeamFeatureLogic.visibleDutyTypeNeighbor(
                in: dutyTypes,
                from: 0,
                direction: 0
            ) == nil
        )
    }

    @Test
    func buildsDutyUploadMultipartBody() {
        let boundary = "Dutypark-Test-Boundary"
        let fileData = Data([0x00, 0x41, 0xFF, 0x42])
        let form = TeamMultipartForm(boundary: boundary)

        let body = form.makeBody(
            fileName: "roster.xlsx",
            fileData: fileData,
            year: 2026,
            month: 8
        )
        let text = String(decoding: body, as: UTF8.self)

        #expect(form.contentType == "multipart/form-data; boundary=\(boundary)")
        #expect(text.contains("name=\"year\"\r\n\r\n2026\r\n"))
        #expect(text.contains("name=\"month\"\r\n\r\n8\r\n"))
        #expect(
            text.contains(
                "name=\"file\"; filename=\"roster.xlsx\"\r\n"
                    + "Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            )
        )
        #expect(body.range(of: fileData) != nil)
        #expect(body.suffix(Data("\r\n--\(boundary)--\r\n".utf8).count) == Data("\r\n--\(boundary)--\r\n".utf8))
    }

    @Test
    func decodesJacksonPairObjectInTeamBatchResult() throws {
        let result = try JSONDecoder().decode(
            TeamBatchResultDTO.self,
            from: Data(
                #"""
                {
                  "result": true,
                  "errorDetails": {"year": 2026, "month": 8},
                  "startDate": "2026-08-01",
                  "endDate": "2026-08-31",
                  "dutyBatchResult": [
                    {
                      "first": "Alice",
                      "second": {
                        "result": true,
                        "errorDetails": {"sheet": "August"},
                        "startDate": "2026-08-01",
                        "endDate": "2026-08-31",
                        "workingDays": 20,
                        "offDays": 11
                      }
                    }
                  ]
                }
                """#.utf8
            )
        )

        #expect(result.dutyBatchResult.count == 1)
        #expect(result.errorDetails?["year"] == .integer(2026))
        #expect(result.dutyBatchResult.first?.memberName == "Alice")
        #expect(result.dutyBatchResult.first?.result.result == true)
        #expect(result.dutyBatchResult.first?.result.workingDays == 20)
        #expect(result.dutyBatchResult.first?.result.offDays == 11)
        #expect(result.dutyBatchResult.first?.result.errorDetails?["sheet"] == .string("August"))
    }

    @Test
    func decodesTupleArrayInTeamBatchResult() throws {
        let result = try JSONDecoder().decode(
            TeamBatchResultDTO.self,
            from: Data(
                #"""
                {
                  "result": true,
                  "startDate": "2026-08-01",
                  "endDate": "2026-08-31",
                  "dutyBatchResult": [
                    [
                      "Bob",
                      {
                        "result": false,
                        "errorCode": "dutyBatch.nameNotFound",
                        "errorDetails": {"name": "Bob"},
                        "startDate": null,
                        "endDate": null,
                        "workingDays": 0,
                        "offDays": 0
                      }
                    ]
                  ]
                }
                """#.utf8
            )
        )

        #expect(result.dutyBatchResult.count == 1)
        #expect(result.dutyBatchResult.first?.memberName == "Bob")
        #expect(result.dutyBatchResult.first?.result.result == false)
        #expect(result.dutyBatchResult.first?.result.errorCode == "dutyBatch.nameNotFound")
        #expect(result.dutyBatchResult.first?.result.errorDetails?["name"] == .string("Bob"))
        #expect(result.dutyBatchResult.first?.result.startDate == nil)
    }

    @Test
    func validatesTeamScheduleDraft() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)

        #expect(schedule(content: "Team meeting", start: start, end: end).isValid)
        #expect(schedule(content: "   \n", start: start, end: end).isValid == false)
        #expect(schedule(content: String(repeating: "a", count: 51), start: start, end: end).isValid == false)
        #expect(schedule(content: "Team meeting", start: end, end: start).isValid == false)
        #expect(schedule(content: "Team meeting", start: start, end: start).isValid)
    }

    @Test
    func validatesWebParityDutyBatchInputs() {
        #expect(TeamFeatureLogic.isValidDutyBatchFileName("duty.xlsx"))
        #expect(TeamFeatureLogic.isValidDutyBatchFileName("DUTY.XLSX"))
        #expect(TeamFeatureLogic.isValidDutyBatchFileName("duty.xls") == false)
        #expect(TeamFeatureLogic.isValidDutyBatchFileName("duty.csv") == false)

        #expect(TeamFeatureLogic.isValidDutyBatchYear(2026, currentYear: 2026))
        #expect(TeamFeatureLogic.isValidDutyBatchYear(2027, currentYear: 2026))
        #expect(TeamFeatureLogic.isValidDutyBatchYear(2025, currentYear: 2026) == false)
        #expect(TeamFeatureLogic.isValidDutyBatchYear(2028, currentYear: 2026) == false)
    }

    @Test
    func limitsAndNormalizesDutyNamesForCompactEditor() {
        #expect(TeamManageModalLogic.limitedDutyName("12345678901") == "1234567890")
        #expect(TeamManageModalLogic.normalizedDutyName("  Day  ") == "Day")
        #expect(TeamManageModalLogic.normalizedDutyName("          Day") == "")
    }

    @Test
    func detectsDuplicateDutyNamesWhileExcludingEditedRow() {
        let defaultDuty = DutyTypeDTO(
            id: nil,
            teamId: 7,
            name: "Off",
            position: -1,
            color: "#FFB3BA",
            hidden: false
        )
        let day = dutyType(id: 1, hidden: false)
        let night = DutyTypeDTO(
            id: 2,
            teamId: 7,
            name: "Night",
            position: 2,
            color: "#112233",
            hidden: false
        )
        let dutyTypes = [defaultDuty, day, night]

        #expect(
            TeamManageModalLogic.hasDuplicateDutyName(
                "Night",
                editingID: 1,
                editingDefaultDuty: false,
                dutyTypes: dutyTypes
            )
        )
        #expect(
            TeamManageModalLogic.hasDuplicateDutyName(
                day.name,
                editingID: 1,
                editingDefaultDuty: false,
                dutyTypes: dutyTypes
            ) == false
        )
        #expect(
            TeamManageModalLogic.hasDuplicateDutyName(
                "Off",
                editingID: nil,
                editingDefaultDuty: true,
                dutyTypes: dutyTypes
            ) == false
        )
    }

    @Test
    func identifiesMyShiftGroupByMemberID() {
        let mine = MemberPreviewDTO(
            id: 7,
            name: "Mine",
            teamId: 1,
            team: "Team",
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
        let group = DutyByShiftDTO(dutyType: dutyType(id: 1, hidden: false), members: [mine])

        #expect(TeamFeatureLogic.isMyShiftGroup(group, memberID: 7))
        #expect(TeamFeatureLogic.isMyShiftGroup(group, memberID: 8) == false)
        #expect(TeamFeatureLogic.isMyShiftGroup(group, memberID: nil) == false)
    }

    private func dutyType(id: DutyTypeID?, hidden: Bool) -> DutyTypeDTO {
        DutyTypeDTO(
            id: id,
            teamId: 7,
            name: id.map { "Duty \($0)" } ?? "Off",
            position: Int(id ?? 0),
            color: "#112233",
            hidden: hidden
        )
    }

    private func managedTeam(adminID: MemberID?, members: [TeamMemberDTO]) -> TeamDTO {
        TeamDTO(
            id: 7,
            name: "Team",
            description: nil,
            dutyTypes: [],
            members: members,
            createdDate: LocalDateTimeValue(rawValue: "2026-08-12T00:00:00"),
            lastModifiedDate: LocalDateTimeValue(rawValue: "2026-08-12T00:00:00"),
            adminId: adminID,
            adminName: nil,
            dutyBatchTemplate: nil
        )
    }

    private func schedule(content: String, start: Date, end: Date) -> TeamScheduleDraft {
        TeamScheduleDraft(
            id: nil,
            content: content,
            description: "",
            startDate: start,
            endDate: end
        )
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TeamURLProtocolStub.self]
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

private final class TeamURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("TeamURLProtocolStub handler is not set")
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
