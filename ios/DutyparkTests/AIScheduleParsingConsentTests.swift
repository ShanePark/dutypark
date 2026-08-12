import Foundation
import Testing
@testable import Dutypark

@Suite(.serialized)
@MainActor
struct AIScheduleParsingConsentTests {
    @Test
    func responseDecodesAIpolicyAndCurrentConsent() throws {
        let response = try JSONDecoder().decode(
            AIScheduleParsingConsentResponse.self,
            from: Self.responseData(consented: true, needsRenewal: false)
        )

        #expect(response.policy.policyType == .aiScheduleParsing)
        #expect(response.currentPolicyVersion == "2026-08-13")
        #expect(response.consentVersion == "2026-08-13")
        #expect(response.hasCurrentConsent)
    }

    @Test
    func serviceUsesConsentEndpointForGetGrantAndRevoke() async throws {
        let recorder = AIConsentRequestRecorder()
        AIConsentURLProtocolStub.handler = { request in
            let requestBody = Self.requestBody(request)
            recorder.record(request, body: requestBody)
            let consented = request.httpMethod == "PUT"
                ? (Self.jsonBody(requestBody)["consented"] as? Bool) ?? false
                : false
            return (
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!,
                Self.responseData(consented: consented, needsRenewal: false)
            )
        }
        defer { AIConsentURLProtocolStub.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AIConsentURLProtocolStub.self]
        let service = AIScheduleParsingConsentService(client: APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        ))

        _ = try await service.status()
        _ = try await service.update(consented: true, policyVersion: "2026-08-13")
        _ = try await service.update(consented: false, policyVersion: nil)

        let requests = recorder.requests
        #expect(requests.map(\.httpMethod) == ["GET", "PUT", "PUT"])
        #expect(requests.compactMap { $0.url?.path } == [
            "/api/consents/ai-schedule-parsing",
            "/api/consents/ai-schedule-parsing",
            "/api/consents/ai-schedule-parsing",
        ])
        let bodies = recorder.bodies
        #expect(Self.jsonBody(bodies[1])["consented"] as? Bool == true)
        #expect(Self.jsonBody(bodies[1])["policyVersion"] as? String == "2026-08-13")
        #expect(Self.jsonBody(bodies[2])["consented"] as? Bool == false)
        #expect(Self.jsonBody(bodies[2])["policyVersion"] == nil)
    }

    @Test
    func accountScopeClearsPreviousMembersServerState() async {
        let service = AIConsentServiceMock(statusResponse: Self.response(consented: true))
        let store = AIScheduleParsingConsentStore(service: service)

        await store.load(for: 1)
        #expect(store.isEnabled)
        #expect(store.memberID == 1)

        store.scope(to: 2)
        #expect(store.memberID == 2)
        #expect(store.response == nil)
        #expect(!store.isEnabled)
    }

    @Test
    func editorDecisionPromptsOnlyForAllDayWithoutCurrentConsent() {
        let allDay = Self.date(hour: 0)
        let manualTime = Self.date(hour: 9)
        let denied = Self.response(consented: false)
        let current = Self.response(consented: true)

        #expect(AIScheduleConsentDecisionPolicy.saveDecision(
            isAllDay: true,
            response: denied
        ) == .requestConsent(denied.policy))
        #expect(AIScheduleConsentDecisionPolicy.saveDecision(
            isAllDay: true,
            response: current
        ) == .saveWithoutPrompt)
        #expect(AIScheduleConsentDecisionPolicy.saveDecision(
            isAllDay: false,
            response: denied
        ) == .saveWithoutPrompt)
        #expect(AIScheduleConsentDecisionPolicy.isAllDay(
            start: allDay,
            end: allDay,
            calendar: CalendarDateSupport.calendar
        ))
        #expect(!AIScheduleConsentDecisionPolicy.isAllDay(
            start: manualTime,
            end: manualTime,
            calendar: CalendarDateSupport.calendar
        ))
    }

    @Test
    func failedConsentLookupFallsBackToSavingWithoutPrompt() async {
        let service = AIConsentServiceMock(
            statusResponse: Self.response(consented: false),
            failsStatus: true
        )
        let store = AIScheduleParsingConsentStore(service: service)

        let decision = await store.saveDecision(
            for: 7,
            start: Self.date(hour: 0),
            end: Self.date(hour: 0)
        )

        #expect(decision == .saveWithoutPrompt)
        #expect(store.response == nil)
        #expect(store.errorKey == "settings.aiConsent.loadFailed")
    }

    @Test
    func settingsUpdateFailureKeepsLastServerState() async {
        let current = Self.response(consented: true)
        let service = AIConsentServiceMock(
            statusResponse: current,
            failsUpdate: true
        )
        let store = AIScheduleParsingConsentStore(service: service)
        await store.load(for: 1)

        let revoked = await store.revoke(for: 1)

        #expect(!revoked)
        #expect(store.isEnabled)
        #expect(store.response == current)
        #expect(store.errorKey == "settings.aiConsent.disableFailed")
    }

    @Test
    func allAIConsentStringsResolveInFiveLanguages() throws {
        let settingsKeys = [
            "settings.aiConsent.title",
            "settings.aiConsent.toggle",
            "settings.aiConsent.description",
            "settings.aiConsent.dataFlow",
            "settings.aiConsent.confirmTitle",
            "settings.aiConsent.confirmMessage",
            "settings.aiConsent.confirmEnable",
            "settings.aiConsent.policy",
            "settings.aiConsent.renewalRequired",
            "settings.aiConsent.updating",
            "settings.aiConsent.loadFailed",
            "settings.aiConsent.enableFailed",
            "settings.aiConsent.disableFailed",
        ]
        let calendarKeys = [
            "calendar.aiConsent.prompt.title",
            "calendar.aiConsent.prompt.message",
            "calendar.aiConsent.prompt.agree",
            "calendar.aiConsent.prompt.decline",
        ]

        for locale in ["en", "ko", "ja", "zh-Hans", "es"] {
            let url = try #require(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try #require(Bundle(url: url))
            for key in settingsKeys {
                #expect(bundle.localizedString(forKey: key, value: key, table: "Settings") != key)
            }
            for key in calendarKeys {
                #expect(bundle.localizedString(forKey: key, value: key, table: "Calendar") != key)
            }
        }
    }

    @Test
    func privacyManifestDeclaresOnlyRequestedLinkedFunctionalityData() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let entries = try #require(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let types = Set(entries.compactMap { $0["NSPrivacyCollectedDataType"] as? String })

        #expect(types == [
            "NSPrivacyCollectedDataTypeName",
            "NSPrivacyCollectedDataTypeEmailAddress",
            "NSPrivacyCollectedDataTypePhotosorVideos",
            "NSPrivacyCollectedDataTypeOtherUserContent",
            "NSPrivacyCollectedDataTypeUserID",
            "NSPrivacyCollectedDataTypeDeviceID",
            "NSPrivacyCollectedDataTypeOtherDataTypes",
        ])
        for entry in entries {
            #expect(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool == true)
            #expect(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool == false)
            #expect(entry["NSPrivacyCollectedDataTypePurposes"] as? [String] == [
                "NSPrivacyCollectedDataTypePurposeAppFunctionality"
            ])
        }
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
    }

    private static func response(consented: Bool) -> AIScheduleParsingConsentResponse {
        AIScheduleParsingConsentResponse(
            consented: consented,
            currentPolicyVersion: "2026-08-13",
            consentVersion: consented ? "2026-08-13" : nil,
            needsRenewal: false,
            consentedAt: consented ? "2026-08-13T00:00:00Z" : nil,
            revokedAt: consented ? nil : "2026-08-13T00:00:00Z",
            policy: PolicyDTO(
                policyType: .aiScheduleParsing,
                version: "2026-08-13",
                content: "AI policy",
                effectiveDate: DateOnly(rawValue: "2026-08-13")
            )
        )
    }

    private static func responseData(consented: Bool, needsRenewal: Bool) -> Data {
        Data("""
        {"consented":\(consented),"currentPolicyVersion":"2026-08-13","consentVersion":\(consented ? "\"2026-08-13\"" : "null"),"needsRenewal":\(needsRenewal),"consentedAt":null,"revokedAt":null,"policy":{"policyType":"AI_SCHEDULE_PARSING","version":"2026-08-13","content":"AI policy","effectiveDate":"2026-08-13"}}
        """.utf8)
    }

    private static func date(hour: Int) -> Date {
        CalendarDateSupport.calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 13,
            hour: hour
        ))!
    }

    private static func jsonBody(_ body: Data?) -> [String: Any] {
        guard let body,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return [:] }
        return object
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

private actor AIConsentServiceMock: AIScheduleParsingConsentServicing {
    let statusResponse: AIScheduleParsingConsentResponse
    let failsStatus: Bool
    let failsUpdate: Bool

    init(
        statusResponse: AIScheduleParsingConsentResponse,
        failsStatus: Bool = false,
        failsUpdate: Bool = false
    ) {
        self.statusResponse = statusResponse
        self.failsStatus = failsStatus
        self.failsUpdate = failsUpdate
    }

    func status() async throws -> AIScheduleParsingConsentResponse {
        if failsStatus { throw APIError.transport }
        return statusResponse
    }

    func update(
        consented: Bool,
        policyVersion: String?
    ) async throws -> AIScheduleParsingConsentResponse {
        if failsUpdate { throw APIError.transport }
        return statusResponse
    }
}

private final class AIConsentRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []
    private var bodyStorage: [Data?] = []

    func record(_ request: URLRequest, body: Data?) {
        lock.lock()
        storage.append(request)
        bodyStorage.append(body)
        lock.unlock()
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var bodies: [Data?] {
        lock.lock()
        defer { lock.unlock() }
        return bodyStorage
    }
}

private final class AIConsentURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw APIError.invalidResponse }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
