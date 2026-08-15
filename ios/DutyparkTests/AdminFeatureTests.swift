import Foundation
import Testing
@testable import Dutypark

@Suite("Admin feature", .serialized)
struct AdminFeatureTests {
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
