import Foundation
import Testing
import UIKit
@testable import Dutypark

@Suite("Admin feature", .serialized)
struct AdminFeatureTests {
    @Test("Admin landing matches the web navigation and summary hierarchy")
    func landingPresentation() {
        let members = [
            AdminMemberDTO(
                id: 1,
                name: "Alpha",
                email: nil,
                teamId: 10,
                teamName: "One",
                tokens: [],
                hasProfilePhoto: true,
                profilePhotoVersion: 3
            ),
            AdminMemberDTO(
                id: 2,
                name: "Bravo",
                email: nil,
                teamId: 10,
                teamName: "One",
                tokens: [],
                hasProfilePhoto: false,
                profilePhotoVersion: 0
            ),
        ]
        let sessions = [
            SettingsRefreshToken(
                memberName: "Alpha",
                memberId: 1,
                validUntil: "2026-09-01T00:00:00",
                createdDate: "2026-08-01T00:00:00",
                lastUsed: "2026-08-15T09:00:00",
                remoteAddr: nil,
                id: 1,
                userAgent: nil,
                isCurrentLogin: false
            ),
            SettingsRefreshToken(
                memberName: "Bravo",
                memberId: 2,
                validUntil: "2026-09-01T00:00:00",
                createdDate: "2026-08-01T00:00:00",
                lastUsed: "2026-08-14T23:59:59",
                remoteAddr: nil,
                id: 2,
                userAgent: nil,
                isCurrentLogin: false
            ),
        ]
        let stats = AdminDashboardStatsPresentation(
            totalMembers: 24,
            loadedMembers: members,
            sessions: sessions,
            today: "2026-08-15"
        )

        #expect(AdminRootNavigationPresentation.tileKeys == [
            "admin.nav.members",
            "admin.nav.teams",
            "admin.nav.development",
            "admin.nav.apiDocumentation",
        ])
        #expect(AdminRootDestination.allCases == [.teams, .development])
        #expect(AdminRootDestination.teams.embeddedWebPath == nil)
        #expect(AdminRootDestination.development.embeddedWebPath == "admin/dev")
        #expect(stats.values == [24, 1, 2, 1])
        #expect(AdminMemberSearchPolicy.debounce == .milliseconds(300))
        #expect(AdminMemberSearchPolicy.normalized("  Shane  ") == "Shane")
    }

    @Test("Selected admin tile keeps readable contrast in light and dark appearances")
    func selectedAdminTileContrast() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let background = UIColor(AdminTopTilePresentation.selectedBackground)
                .resolvedColor(with: traits)
            let foreground = UIColor(AdminTopTilePresentation.selectedForeground)
                .resolvedColor(with: traits)

            #expect(contrastRatio(foreground, background) >= 4.5)
        }
    }

    @Test("Admin member identity metadata is localized and profile-photo URLs are cache-safe")
    func memberIdentityPresentation() {
        let value = LocalDateTimeValue(rawValue: "2026-08-15T09:30:00")
        let ko = AdminMemberDetailPresentation.dateText(
            value,
            locale: Locale(identifier: "ko"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        let en = AdminMemberDetailPresentation.dateText(
            value,
            locale: Locale(identifier: "en"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        let photoURL = AdminMemberAvatarPresentation.url(memberID: 7, version: 9)

        #expect(!ko.contains("T"))
        #expect(!en.contains("T"))
        #expect(ko != en)
        #expect(photoURL.path.hasSuffix("/members/7/profile-photo"))
        #expect(URLComponents(url: photoURL, resolvingAgainstBaseURL: false)?.queryItems == [
            URLQueryItem(name: "thumbnail", value: "true"),
            URLQueryItem(name: "v", value: "9"),
        ])
        #expect(AdminMemberDetailPresentation.roleKeys(
            serviceAdmin: true,
            teamAdmin: false,
            teamManager: true,
            auxiliaryAccount: true
        ) == [
            "admin.members.role.serviceAdmin",
            "admin.members.role.teamManager",
            "admin.members.role.auxiliary",
        ])
    }

    @Test("Admin fixture search filters, empties, and restores the member list")
    func memberSearchFixture() async throws {
        let repository = AdminVisualFixtureRepository()

        let filtered = try await repository.members(keyword: "세션 없는", page: 0, size: 20)
        let empty = try await repository.members(keyword: "존재하지 않음", page: 0, size: 20)
        let restored = try await repository.members(keyword: "", page: 0, size: 20)

        #expect(filtered.content.map(\.id) == [8])
        #expect(empty.content.isEmpty)
        #expect(restored.content.map(\.id) == [7, 8])
    }

    @Test("Admin member detail exposes every web status metric")
    func memberDetailStatusMetrics() {
        let metrics = AdminMemberDetailMetricsPresentation(
            totalScheduleCount: 12,
            upcomingScheduleCount: 3,
            taggedScheduleCount: 2,
            todoCount: 4,
            inProgressTodoCount: 2,
            doneTodoCount: 7,
            overdueTodoCount: 1,
            dueTodayTodoCount: 5,
            dDayPrivacy: [false, true, false],
            pendingReceivedFriendRequestCount: 6,
            pendingSentFriendRequestCount: 8
        )

        #expect(metrics.scheduleCounts == [12, 3, 2])
        #expect(metrics.todoCounts == [4, 2, 7, 1, 5])
        #expect(metrics.dDayCounts == [3, 2, 1])
        #expect(metrics.friendRequestCounts == [6, 8])
    }

    @Test("Admin member rows describe active-session counts exactly like the web")
    func memberActiveSessionCountPresentation() {
        #expect(AdminMemberSessionCountPresentation.text(count: 2, locale: Locale(identifier: "ko")) == "2개의 활성 세션")
        #expect(AdminMemberSessionCountPresentation.text(count: 0, locale: Locale(identifier: "ko")) == "활성 세션 없음")
        #expect(AdminMemberSessionCountPresentation.text(count: 2, locale: Locale(identifier: "en")) == "2 active sessions")
        #expect(AdminMemberSessionCountPresentation.text(count: 0, locale: Locale(identifier: "en")) == "No active sessions")
    }

    @Test("Selecting Home always resets its navigation path")
    func homeNavigationResetPolicy() {
        #expect(RootNavigationPolicy.resetsHomePath(for: .home))
        #expect(!RootNavigationPolicy.resetsHomePath(for: .calendar))
        #expect(!RootNavigationPolicy.resetsHomePath(for: .settings))
    }

    @Test("Admin member contract decodes without exposing the raw refresh token")
    func memberContract() throws {
        let json = #"""
        {
          "content":[{
            "id":7,"name":"Shane","email":"test@duty.park","teamId":2,"teamName":"Dutypark",
            "tokens":[{
              "memberName":"Shane","memberId":7,"validUntil":"2026-09-01T00:00:00",
              "createdDate":"2026-08-01T00:00:00","lastUsed":null,"remoteAddr":"127.0.0.1",
              "id":99,"token":"server-secret","userAgent":{"os":"iOS","browser":"Dutypark","device":"iPhone"}
            }],
            "hasProfilePhoto":true,"profilePhotoVersion":3
          }],
          "totalPages":1,"totalElements":1,"last":true,"first":true,"size":10,"number":0,
          "numberOfElements":1,"empty":false
        }
        """#
        let page = try JSONDecoder().decode(PageResponse<AdminMemberDTO>.self, from: Data(json.utf8))

        #expect(page.content.first?.id == 7)
        #expect(page.content.first?.tokens.first?.userAgent?.device == "iPhone")
    }

    @Test("Admin member repository uses the expected API namespaces and payloads")
    func memberRepositoryContract() async throws {
        let recorder = AdminRequestRecorder()
        AdminURLProtocolStub.handler = { request in
            recorder.record(request)
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/admin/api/members"):
                return Self.response(request, status: 200, body: Self.emptyPageJSON)
            case ("GET", "/admin/api/members/7"):
                return Self.response(request, status: 200, body: "{}")
            case ("GET", "/admin/api/refresh-tokens"):
                return Self.response(request, status: 200, body: "[]")
            case ("DELETE", "/api/auth/refresh-tokens/99"):
                return Self.response(request, status: 204)
            case ("PUT", "/api/auth/password"):
                return Self.response(request, status: 204)
            default:
                return Self.response(request, status: 404)
            }
        }
        defer { AdminURLProtocolStub.handler = nil }
        let repository = AdminRepository(client: Self.makeClient())

        _ = try await repository.members(keyword: "Shane Park", page: 2, size: 10)
        do {
            _ = try await repository.memberDetail(id: 7)
            Issue.record("The deliberately incomplete detail response should not decode")
        } catch APIError.decoding {
            // The request path is the contract under test; the full DTO contract has a dedicated test.
        }
        #expect(try await repository.sessions().isEmpty)
        try await repository.revokeSession(id: 99)
        try await repository.changePassword(memberID: 7, newPassword: "new-password")

        let requests = recorder.snapshots
        #expect(requests.map(\.route) == [
            "GET /admin/api/members",
            "GET /admin/api/members/7",
            "GET /admin/api/refresh-tokens",
            "DELETE /api/auth/refresh-tokens/99",
            "PUT /api/auth/password"
        ])
        #expect(requests[0].query["keyword"] == "Shane Park")
        #expect(requests[0].query["page"] == "2")
        #expect(requests[0].query["size"] == "10")
        #expect(requests[4].contentType == "application/json")
        let passwordBody = Self.jsonObject(from: requests[4].body)
        #expect(passwordBody["memberId"] as? Int == 7)
        #expect(passwordBody["currentPassword"] == nil)
        #expect(passwordBody["newPassword"] as? String == "new-password")
    }

    @Test("Admin team repository uses the expected endpoints and normalized payloads")
    func teamRepositoryContract() async throws {
        let recorder = AdminRequestRecorder()
        AdminURLProtocolStub.handler = { request in
            recorder.record(request)
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/admin/api/teams"):
                return Self.response(request, status: 200, body: Self.emptyPageJSON)
            case ("POST", "/admin/api/teams/check"):
                return Self.response(request, status: 200, body: #""OK""#)
            case ("POST", "/admin/api/teams"):
                return Self.response(
                    request,
                    status: 200,
                    body: #"{"id":3,"name":"Duty Park","description":"Admin team","dutyTypes":[],"members":[],"createdDate":"2026-08-14T00:00:00","lastModifiedDate":"2026-08-14T00:00:00","adminId":null,"adminName":null,"dutyBatchTemplate":null}"#
                )
            case ("DELETE", "/admin/api/teams/3"):
                return Self.response(request, status: 204)
            default:
                return Self.response(request, status: 404)
            }
        }
        defer { AdminURLProtocolStub.handler = nil }
        let repository = AdminRepository(client: Self.makeClient())

        _ = try await repository.teams(keyword: "Duty Park", page: 1, size: 10)
        #expect(try await repository.checkTeamName("Duty Park") == .ok)
        #expect(try await repository.createTeam(name: "Duty Park", description: "Admin team").id == 3)
        try await repository.deleteTeam(id: 3)

        let requests = recorder.snapshots
        #expect(requests.map(\.route) == [
            "GET /admin/api/teams",
            "POST /admin/api/teams/check",
            "POST /admin/api/teams",
            "DELETE /admin/api/teams/3"
        ])
        #expect(requests[0].query["keyword"] == "Duty Park")
        #expect(requests[0].query["page"] == "1")
        #expect(requests[0].query["size"] == "10")
        let nameCheckBody = Self.jsonObject(from: requests[1].body)
        #expect(nameCheckBody["name"] as? String == "Duty Park")
        let createBody = Self.jsonObject(from: requests[2].body)
        #expect(createBody["name"] as? String == "Duty Park")
        #expect(createBody["description"] as? String == "Admin team")
    }

    @Test("Team name validation catches lengths before calling the server") @MainActor
    func teamNameValidation() async {
        let repository = AdminRepositorySpy()
        let model = AdminTeamListViewModel(repository: repository)

        await model.checkName("A")
        #expect(model.nameCheckResult == .tooShort)
        await model.checkName(String(repeating: "A", count: 21))
        #expect(model.nameCheckResult == .tooLong)
        #expect(await repository.nameCheckCalls == 0)
    }

    @Test("Team-name check clears a stale success on failure and remains retryable") @MainActor
    func teamNameCheckFailureStateCanRecover() async {
        let repository = AdminNameCheckSequenceRepository()
        let model = AdminTeamListViewModel(repository: repository)

        await model.checkName("  Alpha  ")
        #expect(model.nameCheckResult == .ok)
        #expect(await repository.checkedNames == ["Alpha"])

        await model.checkName("Bravo")
        #expect(model.nameCheckResult == nil)

        await model.checkName("Charlie")
        #expect(model.nameCheckResult == .duplicated)
        #expect(await repository.checkedNames == ["Alpha", "Bravo", "Charlie"])
    }

    @Test("Admin list load failures leave retryable error state") @MainActor
    func listLoadFailureStateCanRecover() async {
        let repository = AdminLoadRecoveryRepository()
        let memberModel = AdminMemberListViewModel(repository: repository)
        let teamModel = AdminTeamListViewModel(repository: repository)

        await memberModel.load()
        #expect(memberModel.loadFailed)
        #expect(memberModel.isLoading == false)
        await memberModel.load()
        #expect(memberModel.loadFailed == false)
        #expect(memberModel.members.map(\.name) == ["Recovered member"])

        await teamModel.load()
        #expect(teamModel.loadFailed)
        #expect(teamModel.isLoading == false)
        await teamModel.load()
        #expect(teamModel.loadFailed == false)
        #expect(teamModel.teams.map(\.name) == ["Recovered team"])
    }

    @Test("A stale team-name response cannot overwrite the latest check") @MainActor
    func staleTeamNameResponseIsIgnored() async {
        let repository = AdminNameCheckRaceRepository()
        let model = AdminTeamListViewModel(repository: repository)

        let firstCheck = Task { await model.checkName("Alpha") }
        await repository.waitUntilRequested("Alpha")

        let secondCheck = Task { await model.checkName("Bravo") }
        await repository.waitUntilRequested("Bravo")
        await repository.complete("Bravo", with: .ok)
        await secondCheck.value
        #expect(model.nameCheckResult == .ok)

        await repository.complete("Alpha", with: .duplicated)
        await firstCheck.value
        #expect(model.nameCheckResult == .ok)

        model.resetNameCheck()
        #expect(model.nameCheckResult == nil)
    }

    @Test("A stale member-list response cannot overwrite a newer search") @MainActor
    func staleMemberSearchResponseIsIgnored() async {
        let repository = AdminListRaceRepository()
        let model = AdminMemberListViewModel(repository: repository)

        let initialLoad = Task { await model.load() }
        await repository.waitUntilMemberRequestStarts()

        await model.search("  Latest  ")
        #expect(await repository.memberKeywords == ["", "Latest"])
        #expect(model.members.map(\.name) == ["Latest"])

        await repository.completeInitialMemberRequest()
        await initialLoad.value
        #expect(model.members.map(\.name) == ["Latest"])
        #expect(model.isLoading == false)
    }

    @Test("A stale team-list response cannot overwrite a newer search") @MainActor
    func staleTeamSearchResponseIsIgnored() async {
        let repository = AdminListRaceRepository()
        let model = AdminTeamListViewModel(repository: repository)

        let initialLoad = Task { await model.load() }
        await repository.waitUntilTeamRequestStarts()

        await model.search("  Latest  ")
        #expect(await repository.teamKeywords == ["", "Latest"])
        #expect(model.teams.map(\.name) == ["Latest"])

        await repository.completeInitialTeamRequest()
        await initialLoad.value
        #expect(model.teams.map(\.name) == ["Latest"])
        #expect(model.isLoading == false)
    }

    @Test("Creating a team updates an active description search without reloading it") @MainActor
    func creatingTeamUpdatesCurrentPageLocally() async throws {
        let repository = AdminTeamMutationRepository(
            teams: [],
            createdTeam: Self.managedTeam(id: 7, name: "Created team")
        )
        let model = AdminTeamListViewModel(repository: repository)

        await model.search("  Description  ")
        let created = try await model.create(name: "  Created team  ", description: "  Description  ")

        #expect(created.id == 7)
        #expect(model.teams == [
            SimpleTeamDTO(id: 7, name: "Created team", description: "Description", memberCount: 0)
        ])
        #expect(model.totalElements == 1)
        #expect(model.totalPages == 1)
        #expect(model.page == 0)
        #expect(model.isLoading == false)
        #expect(await repository.teamLoadCount == 1)
        let createdValues = await repository.createdValues
        #expect(createdValues.count == 1)
        #expect(createdValues.first?.0 == "Created team")
        #expect(createdValues.first?.1 == "Description")
    }

    @Test("Deleting a team removes it and updates pagination without reloading the page") @MainActor
    func deletingTeamUpdatesCurrentPageLocally() async throws {
        let first = SimpleTeamDTO(id: 1, name: "First", description: nil, memberCount: 2)
        let second = SimpleTeamDTO(id: 2, name: "Second", description: nil, memberCount: 1)
        let repository = AdminTeamMutationRepository(
            teams: [first, second],
            createdTeam: Self.managedTeam(id: 7, name: "Unused")
        )
        let model = AdminTeamListViewModel(repository: repository)

        await model.load()
        try await model.delete(first)

        #expect(model.teams == [second])
        #expect(model.totalElements == 1)
        #expect(model.totalPages == 1)
        #expect(model.page == 0)
        #expect(model.isLoading == false)
        #expect(await repository.deletedIDs == [first.id])
        #expect(await repository.teamLoadCount == 1)
    }

    @Test("Clearing a submitted team search restores the unfiltered first page") @MainActor
    func clearingTeamSearchRestoresFirstPage() async {
        let team = SimpleTeamDTO(
            id: 1,
            name: "Visible team",
            description: "Description",
            memberCount: 2
        )
        let repository = AdminTeamMutationRepository(
            teams: [team],
            createdTeam: Self.managedTeam(id: 7, name: "Unused")
        )
        let model = AdminTeamListViewModel(repository: repository)

        await model.search("  Missing  ")
        #expect(model.searchKeyword == "Missing")
        #expect(model.teams.isEmpty)

        await model.search("")
        #expect(model.searchKeyword.isEmpty)
        #expect(model.teams == [team])
        #expect(model.page == 0)
        #expect(await repository.teamKeywords == ["Missing", ""])
    }

    @Test("Team pagination mirrors the web mobile hierarchy")
    func teamPaginationPresentation() {
        #expect(AdminTeamPaginationPolicy.items(currentPage: 0, totalPages: 1) == [.page(0)])
        #expect(AdminTeamPaginationPolicy.items(currentPage: 2, totalPages: 5) == [
            .page(0), .page(1), .page(2), .page(3), .page(4),
        ])
        #expect(AdminTeamPaginationPolicy.items(currentPage: 4, totalPages: 10) == [
            .page(0), .gap, .page(3), .page(4), .page(5), .gap, .page(9),
        ])
        #expect(AdminTeamPaginationPolicy.compactItems(currentPage: 4, totalPages: 10) == [
            .page(0), .gap, .page(4), .gap, .page(9),
        ])
    }

    @Test("Admin edit modals use one dirty-form dismissal policy for every request source")
    func modalDismissPolicy() {
        let pristine = AdminModalInteractionState()
        #expect(pristine.allowsDismiss)
        #expect(pristine.dismissDecision == .dismiss)

        let dirty = AdminModalInteractionState(isDirty: true)
        #expect(dirty.allowsDismiss)
        #expect(dirty.dismissDecision == .confirmDiscard)

        let saving = AdminModalInteractionState(isDirty: true, isSaving: true)
        #expect(!saving.allowsDismiss)
        #expect(saving.dismissDecision == .blocked)

        let checking = AdminModalInteractionState(isDirty: true, isChecking: true)
        #expect(!checking.allowsDismiss)
        #expect(checking.dismissDecision == .blocked)
    }

    @Test("Admin form dirtiness is an exact comparison with its initial values")
    func modalDirtyBaseline() {
        #expect(!AdminModalInteractionState.passwordIsDirty(password: "", confirmation: ""))
        #expect(AdminModalInteractionState.passwordIsDirty(password: " ", confirmation: ""))
        #expect(!AdminModalInteractionState.passwordIsDirty(
            password: "original",
            confirmation: "original",
            baselinePassword: "original",
            baselineConfirmation: "original"
        ))

        #expect(!AdminModalInteractionState.teamIsDirty(name: "", description: ""))
        #expect(AdminModalInteractionState.teamIsDirty(name: " ", description: ""))
        #expect(!AdminModalInteractionState.teamIsDirty(
            name: "Dutypark",
            description: "Team",
            baselineName: "Dutypark",
            baselineDescription: "Team"
        ))
    }

    @Test("Session revoke confirmation keeps the selected session and explains its scope")
    func sessionRevokeConfirmationContent() {
        let token = SettingsRefreshToken(
            memberName: "Shane",
            memberId: 7,
            validUntil: "2026-09-01T00:00:00",
            createdDate: "2026-08-01T00:00:00",
            lastUsed: nil,
            remoteAddr: "127.0.0.1",
            id: 99,
            userAgent: .init(os: "iOS", browser: "Dutypark", device: "iPhone 13 mini"),
            isCurrentLogin: false
        )

        let confirmation = AdminSessionRevokeConfirmation(token: token)

        #expect(confirmation.id == token.id)
        #expect(confirmation.token == token)
        #expect(confirmation.title == AdminLocalization.string("admin.members.revokeSession.title"))
        #expect(confirmation.message == AdminLocalization.format(
            "admin.members.revokeSession.message",
            "Shane",
            "iPhone 13 mini",
            "Dutypark",
            "127.0.0.1"
        ))
    }

    fileprivate static let emptyPageJSON =
        #"{"content":[],"totalPages":0,"totalElements":0,"last":true,"first":true,"size":10,"number":0,"numberOfElements":0,"empty":true}"#

    private static func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AdminURLProtocolStub.self]
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

    private static func jsonObject(from body: Data?) -> [String: Any] {
        guard let body,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return [:]
        }
        return object
    }

    private static func managedTeam(id: TeamID, name: String) -> TeamDTO {
        TeamDTO(
            id: id,
            name: name,
            description: "Description",
            dutyTypes: [],
            members: [],
            createdDate: LocalDateTimeValue(rawValue: "2026-08-15T00:00:00"),
            lastModifiedDate: LocalDateTimeValue(rawValue: "2026-08-15T00:00:00"),
            adminId: nil,
            adminName: nil,
            dutyBatchTemplate: nil
        )
    }
}

private func contrastRatio(_ first: UIColor, _ second: UIColor) -> Double {
    let brighter = max(relativeLuminance(first), relativeLuminance(second))
    let darker = min(relativeLuminance(first), relativeLuminance(second))
    return (brighter + 0.05) / (darker + 0.05)
}

private func relativeLuminance(_ color: UIColor) -> Double {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: nil)

    func component(_ value: CGFloat) -> Double {
        let value = Double(value)
        return value <= 0.04045
            ? value / 12.92
            : pow((value + 0.055) / 1.055, 2.4)
    }

    return 0.2126 * component(red) + 0.7152 * component(green) + 0.0722 * component(blue)
}

private struct AdminRequestSnapshot: Sendable {
    let method: String
    let path: String
    let query: [String: String]
    let contentType: String?
    let body: Data?

    var route: String { "\(method) \(path)" }
}

private final class AdminRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [AdminRequestSnapshot] = []

    func record(_ request: URLRequest) {
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?
            .reduce(into: [String: String]()) { result, item in
                result[item.name] = item.value
            } ?? [:]
        let snapshot = AdminRequestSnapshot(
            method: request.httpMethod ?? "",
            path: request.url?.path ?? "",
            query: query,
            contentType: request.value(forHTTPHeaderField: "Content-Type"),
            body: Self.requestBody(request)
        )
        lock.lock()
        storage.append(snapshot)
        lock.unlock()
    }

    var snapshots: [AdminRequestSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    private static func requestBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }

        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private final class AdminURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("AdminURLProtocolStub handler is not set")
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private actor AdminNameCheckSequenceRepository: AdminRepositoryProtocol {
    private(set) var checkedNames: [String] = []

    func checkTeamName(_ name: String) async throws -> AdminTeamNameCheckResult {
        checkedNames.append(name)
        switch checkedNames.count {
        case 1: return .ok
        case 2: throw APIError.server(status: 503, code: nil)
        default: return .duplicated
        }
    }

    func members(keyword: String, page: Int, size: Int) async throws -> PageResponse<AdminMemberDTO> { try emptyPage() }
    func memberDetail(id: MemberID) async throws -> AdminMemberDetailDTO { throw APIError.invalidResponse }
    func sessions() async throws -> [SettingsRefreshToken] { [] }
    func revokeSession(id: Int64) async throws {}
    func changePassword(memberID: MemberID, newPassword: String) async throws {}
    func teams(keyword: String, page: Int, size: Int) async throws -> PageResponse<SimpleTeamDTO> { try emptyPage() }
    func createTeam(name: String, description: String) async throws -> TeamDTO { throw APIError.invalidResponse }
    func deleteTeam(id: TeamID) async throws {}

    private func emptyPage<Element: Codable & Equatable & Sendable>() throws -> PageResponse<Element> {
        try JSONDecoder().decode(PageResponse<Element>.self, from: Data(AdminFeatureTests.emptyPageJSON.utf8))
    }
}

private actor AdminLoadRecoveryRepository: AdminRepositoryProtocol {
    private var memberLoads = 0
    private var teamLoads = 0

    func members(keyword: String, page: Int, size: Int) async throws -> PageResponse<AdminMemberDTO> {
        memberLoads += 1
        guard memberLoads > 1 else { throw APIError.server(status: 503, code: nil) }
        return PageResponse(
            content: [AdminMemberDTO(
                id: 1,
                name: "Recovered member",
                email: nil,
                teamId: nil,
                teamName: nil,
                tokens: [],
                hasProfilePhoto: false,
                profilePhotoVersion: 0
            )],
            totalPages: 1,
            totalElements: 1,
            last: true,
            first: true,
            size: size,
            number: page,
            numberOfElements: 1,
            empty: false
        )
    }

    func teams(keyword: String, page: Int, size: Int) async throws -> PageResponse<SimpleTeamDTO> {
        teamLoads += 1
        guard teamLoads > 1 else { throw APIError.server(status: 503, code: nil) }
        return PageResponse(
            content: [SimpleTeamDTO(id: 1, name: "Recovered team", description: nil, memberCount: 1)],
            totalPages: 1,
            totalElements: 1,
            last: true,
            first: true,
            size: size,
            number: page,
            numberOfElements: 1,
            empty: false
        )
    }

    func memberDetail(id: MemberID) async throws -> AdminMemberDetailDTO { throw APIError.invalidResponse }
    func sessions() async throws -> [SettingsRefreshToken] { [] }
    func revokeSession(id: Int64) async throws {}
    func changePassword(memberID: MemberID, newPassword: String) async throws {}
    func checkTeamName(_ name: String) async throws -> AdminTeamNameCheckResult { .ok }
    func createTeam(name: String, description: String) async throws -> TeamDTO { throw APIError.invalidResponse }
    func deleteTeam(id: TeamID) async throws {}
}

private actor AdminListRaceRepository: AdminRepositoryProtocol {
    private var initialMemberContinuation: CheckedContinuation<PageResponse<AdminMemberDTO>, Never>?
    private var initialMemberWaiters: [CheckedContinuation<Void, Never>] = []
    private var initialTeamContinuation: CheckedContinuation<PageResponse<SimpleTeamDTO>, Never>?
    private var initialTeamWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var memberKeywords: [String] = []
    private(set) var teamKeywords: [String] = []

    func members(keyword: String, page: Int, size: Int) async throws -> PageResponse<AdminMemberDTO> {
        memberKeywords.append(keyword)
        if keyword == "Latest" {
            return memberPage(name: "Latest", page: page, size: size)
        }
        initialMemberWaiters.forEach { $0.resume() }
        initialMemberWaiters.removeAll()
        return await withCheckedContinuation { continuation in
            initialMemberContinuation = continuation
        }
    }

    func teams(keyword: String, page: Int, size: Int) async throws -> PageResponse<SimpleTeamDTO> {
        teamKeywords.append(keyword)
        if keyword == "Latest" {
            return teamPage(name: "Latest", page: page, size: size)
        }
        initialTeamWaiters.forEach { $0.resume() }
        initialTeamWaiters.removeAll()
        return await withCheckedContinuation { continuation in
            initialTeamContinuation = continuation
        }
    }

    func waitUntilMemberRequestStarts() async {
        guard initialMemberContinuation == nil else { return }
        await withCheckedContinuation { initialMemberWaiters.append($0) }
    }

    func waitUntilTeamRequestStarts() async {
        guard initialTeamContinuation == nil else { return }
        await withCheckedContinuation { initialTeamWaiters.append($0) }
    }

    func completeInitialMemberRequest() {
        initialMemberContinuation?.resume(returning: memberPage(name: "Stale", page: 0, size: 10))
        initialMemberContinuation = nil
    }

    func completeInitialTeamRequest() {
        initialTeamContinuation?.resume(returning: teamPage(name: "Stale", page: 0, size: 10))
        initialTeamContinuation = nil
    }

    func memberDetail(id: MemberID) async throws -> AdminMemberDetailDTO { throw APIError.invalidResponse }
    func sessions() async throws -> [SettingsRefreshToken] { [] }
    func revokeSession(id: Int64) async throws {}
    func changePassword(memberID: MemberID, newPassword: String) async throws {}
    func checkTeamName(_ name: String) async throws -> AdminTeamNameCheckResult { .ok }
    func createTeam(name: String, description: String) async throws -> TeamDTO { throw APIError.invalidResponse }
    func deleteTeam(id: TeamID) async throws {}

    private func memberPage(name: String, page: Int, size: Int) -> PageResponse<AdminMemberDTO> {
        PageResponse(
            content: [
                AdminMemberDTO(
                    id: name == "Latest" ? 2 : 1,
                    name: name,
                    email: nil,
                    teamId: nil,
                    teamName: nil,
                    tokens: [],
                    hasProfilePhoto: false,
                    profilePhotoVersion: 0
                )
            ],
            totalPages: 1,
            totalElements: 1,
            last: true,
            first: true,
            size: size,
            number: page,
            numberOfElements: 1,
            empty: false
        )
    }

    private func teamPage(name: String, page: Int, size: Int) -> PageResponse<SimpleTeamDTO> {
        PageResponse(
            content: [SimpleTeamDTO(id: name == "Latest" ? 2 : 1, name: name, description: nil, memberCount: 1)],
            totalPages: 1,
            totalElements: 1,
            last: true,
            first: true,
            size: size,
            number: page,
            numberOfElements: 1,
            empty: false
        )
    }
}

private actor AdminNameCheckRaceRepository: AdminRepositoryProtocol {
    private var pending: [String: CheckedContinuation<AdminTeamNameCheckResult, any Error>] = [:]
    private var requestWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    func members(keyword: String, page: Int, size: Int) async throws -> PageResponse<AdminMemberDTO> {
        try emptyPage()
    }

    func memberDetail(id: MemberID) async throws -> AdminMemberDetailDTO { throw APIError.invalidResponse }
    func sessions() async throws -> [SettingsRefreshToken] { [] }
    func revokeSession(id: Int64) async throws {}
    func changePassword(memberID: MemberID, newPassword: String) async throws {}

    func teams(keyword: String, page: Int, size: Int) async throws -> PageResponse<SimpleTeamDTO> {
        try emptyPage()
    }

    func checkTeamName(_ name: String) async throws -> AdminTeamNameCheckResult {
        try await withCheckedThrowingContinuation { continuation in
            pending[name] = continuation
            requestWaiters.removeValue(forKey: name)?.forEach { $0.resume() }
        }
    }

    func createTeam(name: String, description: String) async throws -> TeamDTO {
        throw APIError.invalidResponse
    }

    func deleteTeam(id: TeamID) async throws {}

    func waitUntilRequested(_ name: String) async {
        guard pending[name] == nil else { return }
        await withCheckedContinuation { continuation in
            requestWaiters[name, default: []].append(continuation)
        }
    }

    func complete(_ name: String, with result: AdminTeamNameCheckResult) {
        pending.removeValue(forKey: name)?.resume(returning: result)
    }

    private func emptyPage<Element: Codable & Equatable & Sendable>() throws -> PageResponse<Element> {
        try JSONDecoder().decode(
            PageResponse<Element>.self,
            from: Data(#"{"content":[],"totalPages":0,"totalElements":0,"last":true,"first":true,"size":10,"number":0,"numberOfElements":0,"empty":true}"#.utf8)
        )
    }
}

private actor AdminRepositorySpy: AdminRepositoryProtocol {
    private(set) var nameCheckCalls = 0

    func members(keyword: String, page: Int, size: Int) async throws -> PageResponse<AdminMemberDTO> {
        try emptyPage()
    }

    func memberDetail(id: MemberID) async throws -> AdminMemberDetailDTO { throw APIError.invalidResponse }
    func sessions() async throws -> [SettingsRefreshToken] { [] }
    func revokeSession(id: Int64) async throws {}
    func changePassword(memberID: MemberID, newPassword: String) async throws {}

    func teams(keyword: String, page: Int, size: Int) async throws -> PageResponse<SimpleTeamDTO> {
        try emptyPage()
    }

    func checkTeamName(_ name: String) async throws -> AdminTeamNameCheckResult {
        nameCheckCalls += 1
        return .ok
    }

    func createTeam(name: String, description: String) async throws -> TeamDTO { throw APIError.invalidResponse }
    func deleteTeam(id: TeamID) async throws {}

    private func emptyPage<Element: Codable & Equatable & Sendable>() throws -> PageResponse<Element> {
        try JSONDecoder().decode(
            PageResponse<Element>.self,
            from: Data(#"{"content":[],"totalPages":0,"totalElements":0,"last":true,"first":true,"size":10,"number":0,"numberOfElements":0,"empty":true}"#.utf8)
        )
    }
}

private actor AdminTeamMutationRepository: AdminRepositoryProtocol {
    private let initialTeams: [SimpleTeamDTO]
    private let createdTeam: TeamDTO
    private(set) var teamLoadCount = 0
    private(set) var teamKeywords: [String] = []
    private(set) var createdValues: [(String, String)] = []
    private(set) var deletedIDs: [TeamID] = []

    init(teams: [SimpleTeamDTO], createdTeam: TeamDTO) {
        initialTeams = teams
        self.createdTeam = createdTeam
    }

    func teams(keyword: String, page: Int, size: Int) async throws -> PageResponse<SimpleTeamDTO> {
        teamLoadCount += 1
        teamKeywords.append(keyword)
        let filtered = initialTeams.filter { team in
            keyword.isEmpty
                || team.name.localizedCaseInsensitiveContains(keyword)
                || team.description?.localizedCaseInsensitiveContains(keyword) == true
        }
        return PageResponse(
            content: filtered,
            totalPages: filtered.isEmpty ? 0 : 1,
            totalElements: Int64(filtered.count),
            last: true,
            first: true,
            size: size,
            number: page,
            numberOfElements: filtered.count,
            empty: filtered.isEmpty
        )
    }

    func createTeam(name: String, description: String) async throws -> TeamDTO {
        createdValues.append((name, description))
        return TeamDTO(
            id: createdTeam.id,
            name: createdTeam.name,
            description: description,
            dutyTypes: createdTeam.dutyTypes,
            members: createdTeam.members,
            createdDate: createdTeam.createdDate,
            lastModifiedDate: createdTeam.lastModifiedDate,
            adminId: createdTeam.adminId,
            adminName: createdTeam.adminName,
            dutyBatchTemplate: createdTeam.dutyBatchTemplate
        )
    }

    func deleteTeam(id: TeamID) async throws {
        deletedIDs.append(id)
    }

    func members(keyword: String, page: Int, size: Int) async throws -> PageResponse<AdminMemberDTO> {
        try emptyPage()
    }
    func memberDetail(id: MemberID) async throws -> AdminMemberDetailDTO { throw APIError.invalidResponse }
    func sessions() async throws -> [SettingsRefreshToken] { [] }
    func revokeSession(id: Int64) async throws {}
    func changePassword(memberID: MemberID, newPassword: String) async throws {}
    func checkTeamName(_ name: String) async throws -> AdminTeamNameCheckResult { .ok }

    private func emptyPage<Element: Codable & Equatable & Sendable>() throws -> PageResponse<Element> {
        try JSONDecoder().decode(
            PageResponse<Element>.self,
            from: Data(AdminFeatureTests.emptyPageJSON.utf8)
        )
    }
}
