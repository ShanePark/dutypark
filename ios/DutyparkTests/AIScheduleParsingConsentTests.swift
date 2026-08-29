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
            from: Self.responseData(
                consented: true,
                needsRenewal: false,
                previouslyConsentedToCurrentPolicy: true
            )
        )

        #expect(response.policy.policyType == .aiScheduleParsing)
        #expect(response.currentPolicyVersion == "2026-08-13")
        #expect(response.consentVersion == "2026-08-13")
        #expect(response.previouslyConsentedToCurrentPolicy)
        #expect(response.hasCurrentConsent)
    }

    @Test
    func legacyResponseDefaultsPreviousConsentToFalseAndEncodingIncludesTheField() throws {
        let legacyData = Data(#"{"consented":false,"currentPolicyVersion":"2026-08-13","consentVersion":null,"needsRenewal":false,"consentedAt":null,"revokedAt":null,"policy":{"policyType":"AI_SCHEDULE_PARSING","version":"2026-08-13","content":"AI policy","effectiveDate":"2026-08-13"}}"#.utf8)

        let decoded = try JSONDecoder().decode(
            AIScheduleParsingConsentResponse.self,
            from: legacyData
        )
        #expect(!decoded.previouslyConsentedToCurrentPolicy)

        let encoded = try JSONEncoder().encode(decoded)
        #expect(Self.jsonBody(encoded)["previouslyConsentedToCurrentPolicy"] as? Bool == false)
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
        #expect(store.lastSuccessfulRefreshAt != nil)

        store.scope(to: 2)
        #expect(store.memberID == 2)
        #expect(store.response == nil)
        #expect(store.lastSuccessfulRefreshAt == nil)
        #expect(!store.isEnabled)
    }

    @Test
    func freshnessPolicyRefreshesMissingStaleAndClockRollbackStates() {
        let refreshedAt = Date(timeIntervalSince1970: 1_000)

        #expect(AIScheduleConsentFreshnessPolicy.shouldRefresh(
            hasResponse: false,
            lastSuccessfulRefreshAt: refreshedAt,
            now: refreshedAt.addingTimeInterval(1),
            minimumInterval: 30
        ))
        #expect(AIScheduleConsentFreshnessPolicy.shouldRefresh(
            hasResponse: true,
            lastSuccessfulRefreshAt: nil,
            now: refreshedAt.addingTimeInterval(1),
            minimumInterval: 30
        ))
        #expect(!AIScheduleConsentFreshnessPolicy.shouldRefresh(
            hasResponse: true,
            lastSuccessfulRefreshAt: refreshedAt,
            now: refreshedAt.addingTimeInterval(29),
            minimumInterval: 30
        ))
        #expect(AIScheduleConsentFreshnessPolicy.shouldRefresh(
            hasResponse: true,
            lastSuccessfulRefreshAt: refreshedAt,
            now: refreshedAt.addingTimeInterval(30),
            minimumInterval: 30
        ))
        #expect(AIScheduleConsentFreshnessPolicy.shouldRefresh(
            hasResponse: true,
            lastSuccessfulRefreshAt: refreshedAt,
            now: refreshedAt.addingTimeInterval(-1),
            minimumInterval: 30
        ))
    }

    @Test
    func refreshIfStaleSkipsRecentResponseAndFetchesAfterThirtySeconds() async {
        let clock = AIConsentTestClock(now: Date(timeIntervalSince1970: 1_000))
        let service = AIConsentServiceMock(statusResponse: Self.response(consented: true))
        let store = AIScheduleParsingConsentStore(service: service, now: { clock.now })

        await store.refreshIfStale(for: 7, minimumInterval: 30)
        #expect(await service.statusCallCount == 1)
        #expect(store.lastSuccessfulRefreshAt == clock.now)

        clock.advance(by: 29)
        await store.refreshIfStale(for: 7, minimumInterval: 30)
        #expect(await service.statusCallCount == 1)

        clock.advance(by: 1)
        await store.refreshIfStale(for: 7, minimumInterval: 30)
        #expect(await service.statusCallCount == 2)
        #expect(store.lastSuccessfulRefreshAt == clock.now)
    }

    @Test
    func concurrentRefreshesForSameMemberShareOneRequest() async {
        let service = AIConsentServiceMock(
            statusResponse: Self.response(consented: true),
            suspendsStatus: true
        )
        let store = AIScheduleParsingConsentStore(service: service)

        let first = Task { await store.load(for: 7, force: true) }
        await service.waitForStatusCall()
        let second = Task { await store.refreshIfStale(for: 7, minimumInterval: 0) }
        await Task.yield()

        #expect(await service.statusCallCount == 1)
        await service.resumeStatusRequests()
        await first.value
        await second.value
        #expect(await service.statusCallCount == 1)
        #expect(store.isEnabled)
    }

    @Test
    func accountScopeChangeRequiresARefreshEvenWithinMinimumInterval() async {
        let clock = AIConsentTestClock(now: Date(timeIntervalSince1970: 1_000))
        let service = AIConsentServiceMock(statusResponse: Self.response(consented: true))
        let store = AIScheduleParsingConsentStore(service: service, now: { clock.now })

        await store.refreshIfStale(for: 1, minimumInterval: 30)
        clock.advance(by: 1)
        await store.refreshIfStale(for: 2, minimumInterval: 30)

        #expect(await service.statusCallCount == 2)
        #expect(store.memberID == 2)
        #expect(store.lastSuccessfulRefreshAt == clock.now)
    }

    @Test
    func successfulGrantAndRevokeUpdateFreshnessTimestamp() async {
        let clock = AIConsentTestClock(now: Date(timeIntervalSince1970: 1_000))
        let grantedService = AIConsentServiceMock(statusResponse: Self.response(consented: true))
        let grantedStore = AIScheduleParsingConsentStore(
            service: grantedService,
            now: { clock.now }
        )

        clock.advance(by: 1)
        #expect(await grantedStore.grant(for: 1, policyVersion: "2026-08-13"))
        #expect(grantedStore.lastSuccessfulRefreshAt == clock.now)

        let revokedService = AIConsentServiceMock(statusResponse: Self.response(consented: false))
        let revokedStore = AIScheduleParsingConsentStore(
            service: revokedService,
            now: { clock.now }
        )
        clock.advance(by: 1)
        #expect(await revokedStore.revoke(for: 1))
        #expect(revokedStore.lastSuccessfulRefreshAt == clock.now)
    }

    @Test
    func editorDecisionDistinguishesCurrentNeverRevokedRenewalAndLookupFailure() {
        let allDay = Self.date(hour: 0)
        let manualTime = Self.date(hour: 9)
        let never = Self.response(consented: false, revokedAt: nil)
        let revoked = Self.response(consented: false)
        let current = Self.response(consented: true)
        let renewal = Self.response(consented: true, needsRenewal: true)

        #expect(AIScheduleConsentDecisionPolicy.saveDecision(
            isAllDay: true,
            response: never
        ) == .requestConsent(never.policy))
        #expect(AIScheduleConsentDecisionPolicy.saveDecision(
            isAllDay: true,
            response: current
        ) == .save(aiTimeParsingRequested: true))
        #expect(AIScheduleConsentDecisionPolicy.saveDecision(
            isAllDay: true,
            response: revoked
        ) == .save(aiTimeParsingRequested: false))
        #expect(AIScheduleConsentDecisionPolicy.saveDecision(
            isAllDay: true,
            response: renewal
        ) == .requestConsent(renewal.policy))
        #expect(AIScheduleConsentDecisionPolicy.saveDecision(
            isAllDay: true,
            response: nil
        ) == .save(aiTimeParsingRequested: false))
        #expect(AIScheduleConsentDecisionPolicy.saveDecision(
            isAllDay: false,
            response: revoked
        ) == .save(aiTimeParsingRequested: true))
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

        #expect(decision == .save(aiTimeParsingRequested: false))
        #expect(store.response == nil)
        #expect(store.errorKey == "settings.aiConsent.loadFailed")
    }

    @Test
    func editorDecisionAlwaysReloadsConsentBeforeAnAllDaySave() async {
        let service = AIConsentServiceMock(statusResponse: Self.response(consented: true))
        let store = AIScheduleParsingConsentStore(service: service)
        await store.load(for: 7)

        let decision = await store.saveDecision(
            for: 7,
            start: Self.date(hour: 0),
            end: Self.date(hour: 0)
        )

        #expect(decision == .save(aiTimeParsingRequested: true))
        #expect(await service.statusCallCount == 2)
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
    func failedActivationKeepsSettingOffAndExposesInlineErrorKey() async {
        let current = Self.response(consented: false)
        let service = AIConsentServiceMock(
            statusResponse: current,
            failsUpdate: true
        )
        let store = AIScheduleParsingConsentStore(service: service)
        await store.load(for: 1)

        let granted = await store.grant(for: 1, policyVersion: current.currentPolicyVersion)

        #expect(!granted)
        #expect(!store.isEnabled)
        #expect(store.response == current)
        #expect(store.errorKey == "settings.aiConsent.enableFailed")
    }

    @Test
    func activationRequiresExplicitConfirmationPolicyAndIdleState() {
        #expect(!AIScheduleConsentActivationPolicy.canSubmit(
            hasConfirmedTerms: false,
            hasPolicy: true,
            policyVersion: "2026-08-13",
            isUpdating: false
        ))
        #expect(!AIScheduleConsentActivationPolicy.canSubmit(
            hasConfirmedTerms: true,
            hasPolicy: false,
            policyVersion: "2026-08-13",
            isUpdating: false
        ))
        #expect(!AIScheduleConsentActivationPolicy.canSubmit(
            hasConfirmedTerms: true,
            hasPolicy: true,
            policyVersion: nil,
            isUpdating: false
        ))
        #expect(!AIScheduleConsentActivationPolicy.canSubmit(
            hasConfirmedTerms: true,
            hasPolicy: true,
            policyVersion: "   ",
            isUpdating: false
        ))
        #expect(!AIScheduleConsentActivationPolicy.canSubmit(
            hasConfirmedTerms: true,
            hasPolicy: true,
            policyVersion: "2026-08-13",
            isUpdating: true
        ))
        #expect(AIScheduleConsentActivationPolicy.canSubmit(
            hasConfirmedTerms: true,
            hasPolicy: true,
            policyVersion: "2026-08-13",
            isUpdating: false
        ))
    }

    @Test
    func settingsActivationDecisionSeparatesFirstConsentFromSafeReactivation() {
        let firstConsent = Self.response(
            consented: false,
            previouslyConsentedToCurrentPolicy: false
        )
        let previousConsent = Self.response(
            consented: false,
            previouslyConsentedToCurrentPolicy: true
        )

        #expect(AIScheduleConsentSettingsActivationPolicy.decision(response: nil) == .unavailable)
        #expect(AIScheduleConsentSettingsActivationPolicy.decision(
            response: firstConsent
        ) == .showAgreement)
        #expect(AIScheduleConsentSettingsActivationPolicy.decision(
            response: previousConsent
        ) == .grant(policyVersion: "2026-08-13"))
        #expect(!previousConsent.hasCurrentConsent)
        #expect(AIScheduleConsentSettingsActivationPolicy.decision(
            response: Self.response(
                consented: false,
                previouslyConsentedToCurrentPolicy: true,
                currentPolicyVersion: ""
            )
        ) == .unavailable)
        #expect(AIScheduleConsentSettingsActivationPolicy.decision(
            response: Self.response(
                consented: false,
                previouslyConsentedToCurrentPolicy: true,
                policyVersion: "2026-08-12"
            )
        ) == .unavailable)
        #expect(AIScheduleConsentSettingsActivationPolicy.decision(
            response: Self.response(
                consented: false,
                previouslyConsentedToCurrentPolicy: true,
                policyContent: "  "
            )
        ) == .unavailable)
    }

    @Test
    func allAIConsentStringsResolveInSupportedLanguages() throws {
        let settingsKeys = [
            "settings.aiConsent.title",
            "settings.aiConsent.toggle",
            "settings.aiConsent.description",
            "settings.aiConsent.dataFlow",
            "settings.aiConsent.effectiveDate",
            "settings.aiConsent.confirmAcknowledgement",
            "settings.aiConsent.confirmAcknowledgementHint",
            "settings.aiConsent.confirmTitle",
            "settings.aiConsent.confirmMessage",
            "settings.aiConsent.confirmEnable",
            "settings.aiConsent.confirmEnableHint",
            "settings.aiConsent.policy",
            "settings.aiConsent.policyVersion",
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

        for locale in ["en", "ko"] {
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
    func userFacingAIConsentCopyIsProviderNeutral() throws {
        let keysByTable = [
            "Settings": [
                "settings.aiConsent.dataFlow",
                "settings.aiConsent.confirmMessage",
            ],
            "Calendar": [
                "calendar.aiConsent.prompt.message",
            ],
        ]

        for locale in ["en", "ko"] {
            let url = try #require(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try #require(Bundle(url: url))
            for (table, keys) in keysByTable {
                for key in keys {
                    let copy = bundle.localizedString(forKey: key, value: key, table: table)
                    #expect(!copy.localizedCaseInsensitiveContains("Google"))
                    #expect(!copy.localizedCaseInsensitiveContains("Generative Language"))
                    #expect(copy.localizedCaseInsensitiveContains(locale == "ko" ? "외부 AI" : "external AI"))
                }
            }
        }
    }

    @Test
    func privacyManifestDeclaresExactDataTrackingAndRequiredReasonAPIs() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let entries = try #require(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let declaredTypes = entries.compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        let types = Set(declaredTypes)

        #expect(declaredTypes.count == entries.count)
        #expect(types.count == entries.count)
        #expect(types == [
            "NSPrivacyCollectedDataTypeName",
            "NSPrivacyCollectedDataTypeEmailAddress",
            "NSPrivacyCollectedDataTypePhotosorVideos",
            "NSPrivacyCollectedDataTypeOtherUserContent",
            "NSPrivacyCollectedDataTypeCustomerSupport",
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

        let accessedAPIs = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(accessedAPIs.count == 1)
        let userDefaultsAPI = try #require(accessedAPIs.first)
        #expect(userDefaultsAPI["NSPrivacyAccessedAPIType"] as? String ==
            "NSPrivacyAccessedAPICategoryUserDefaults")
        #expect(userDefaultsAPI["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        #expect(plist["NSPrivacyTrackingDomains"] as? [String] == [])
    }

    private static func response(
        consented: Bool,
        needsRenewal: Bool = false,
        revokedAt: String? = "2026-08-13T00:00:00Z",
        previouslyConsentedToCurrentPolicy: Bool = false,
        currentPolicyVersion: String = "2026-08-13",
        policyVersion: String = "2026-08-13",
        policyContent: String = "AI policy"
    ) -> AIScheduleParsingConsentResponse {
        AIScheduleParsingConsentResponse(
            consented: consented,
            currentPolicyVersion: currentPolicyVersion,
            consentVersion: consented ? "2026-08-13" : nil,
            needsRenewal: needsRenewal,
            previouslyConsentedToCurrentPolicy: previouslyConsentedToCurrentPolicy,
            consentedAt: consented ? "2026-08-13T00:00:00Z" : nil,
            revokedAt: consented ? nil : revokedAt,
            policy: PolicyDTO(
                policyType: .aiScheduleParsing,
                version: policyVersion,
                content: policyContent,
                effectiveDate: DateOnly(rawValue: "2026-08-13")
            )
        )
    }

    private static func responseData(
        consented: Bool,
        needsRenewal: Bool,
        previouslyConsentedToCurrentPolicy: Bool = false
    ) -> Data {
        Data("""
        {"consented":\(consented),"currentPolicyVersion":"2026-08-13","consentVersion":\(consented ? "\"2026-08-13\"" : "null"),"needsRenewal":\(needsRenewal),"previouslyConsentedToCurrentPolicy":\(previouslyConsentedToCurrentPolicy),"consentedAt":null,"revokedAt":null,"policy":{"policyType":"AI_SCHEDULE_PARSING","version":"2026-08-13","content":"AI policy","effectiveDate":"2026-08-13"}}
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
    let suspendsStatus: Bool
    private(set) var statusCallCount = 0
    private var statusCallWaiter: CheckedContinuation<Void, Never>?
    private var statusRequestContinuations: [CheckedContinuation<Void, Never>] = []

    init(
        statusResponse: AIScheduleParsingConsentResponse,
        failsStatus: Bool = false,
        failsUpdate: Bool = false,
        suspendsStatus: Bool = false
    ) {
        self.statusResponse = statusResponse
        self.failsStatus = failsStatus
        self.failsUpdate = failsUpdate
        self.suspendsStatus = suspendsStatus
    }

    func status() async throws -> AIScheduleParsingConsentResponse {
        statusCallCount += 1
        statusCallWaiter?.resume()
        statusCallWaiter = nil
        if suspendsStatus {
            await withCheckedContinuation { continuation in
                statusRequestContinuations.append(continuation)
            }
        }
        if failsStatus { throw APIError.transport }
        return statusResponse
    }

    func waitForStatusCall() async {
        guard statusCallCount == 0 else { return }
        await withCheckedContinuation { continuation in
            statusCallWaiter = continuation
        }
    }

    func resumeStatusRequests() {
        let continuations = statusRequestContinuations
        statusRequestContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func update(
        consented: Bool,
        policyVersion: String?
    ) async throws -> AIScheduleParsingConsentResponse {
        if failsUpdate { throw APIError.transport }
        return statusResponse
    }
}

@MainActor
private final class AIConsentTestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
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
