import Combine
import Foundation

nonisolated struct AIScheduleParsingConsentResponse: Codable, Equatable, Sendable {
    let consented: Bool
    let currentPolicyVersion: String
    let consentVersion: String?
    let needsRenewal: Bool
    let previouslyConsentedToCurrentPolicy: Bool
    let consentedAt: String?
    let revokedAt: String?
    let policy: PolicyDTO

    private enum CodingKeys: String, CodingKey {
        case consented
        case currentPolicyVersion
        case consentVersion
        case needsRenewal
        case previouslyConsentedToCurrentPolicy
        case consentedAt
        case revokedAt
        case policy
    }

    init(
        consented: Bool,
        currentPolicyVersion: String,
        consentVersion: String?,
        needsRenewal: Bool,
        previouslyConsentedToCurrentPolicy: Bool = false,
        consentedAt: String?,
        revokedAt: String?,
        policy: PolicyDTO
    ) {
        self.consented = consented
        self.currentPolicyVersion = currentPolicyVersion
        self.consentVersion = consentVersion
        self.needsRenewal = needsRenewal
        self.previouslyConsentedToCurrentPolicy = previouslyConsentedToCurrentPolicy
        self.consentedAt = consentedAt
        self.revokedAt = revokedAt
        self.policy = policy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        consented = try container.decode(Bool.self, forKey: .consented)
        currentPolicyVersion = try container.decode(String.self, forKey: .currentPolicyVersion)
        consentVersion = try container.decodeIfPresent(String.self, forKey: .consentVersion)
        needsRenewal = try container.decode(Bool.self, forKey: .needsRenewal)
        previouslyConsentedToCurrentPolicy = try container.decodeIfPresent(
            Bool.self,
            forKey: .previouslyConsentedToCurrentPolicy
        ) ?? false
        consentedAt = try container.decodeIfPresent(String.self, forKey: .consentedAt)
        revokedAt = try container.decodeIfPresent(String.self, forKey: .revokedAt)
        policy = try container.decode(PolicyDTO.self, forKey: .policy)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(consented, forKey: .consented)
        try container.encode(currentPolicyVersion, forKey: .currentPolicyVersion)
        try container.encodeIfPresent(consentVersion, forKey: .consentVersion)
        try container.encode(needsRenewal, forKey: .needsRenewal)
        try container.encode(
            previouslyConsentedToCurrentPolicy,
            forKey: .previouslyConsentedToCurrentPolicy
        )
        try container.encodeIfPresent(consentedAt, forKey: .consentedAt)
        try container.encodeIfPresent(revokedAt, forKey: .revokedAt)
        try container.encode(policy, forKey: .policy)
    }

    var hasCurrentConsent: Bool {
        consented && !needsRenewal
    }
}

nonisolated struct AIScheduleParsingConsentRequest: Codable, Equatable, Sendable {
    let consented: Bool
    let policyVersion: String?
}

nonisolated protocol AIScheduleParsingConsentServicing: Sendable {
    func status() async throws -> AIScheduleParsingConsentResponse
    func update(consented: Bool, policyVersion: String?) async throws -> AIScheduleParsingConsentResponse
}

nonisolated struct AIScheduleParsingConsentService: AIScheduleParsingConsentServicing, Sendable {
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func status() async throws -> AIScheduleParsingConsentResponse {
        try await client.request("consents/ai-schedule-parsing")
    }

    func update(
        consented: Bool,
        policyVersion: String?
    ) async throws -> AIScheduleParsingConsentResponse {
        let body = try JSONEncoder().encode(AIScheduleParsingConsentRequest(
            consented: consented,
            policyVersion: policyVersion
        ))
        let data = try await client.data(
            "consents/ai-schedule-parsing",
            method: .put,
            body: body,
            headers: ["Content-Type": "application/json"]
        )
        if !data.isEmpty {
            do {
                return try JSONDecoder().decode(AIScheduleParsingConsentResponse.self, from: data)
            } catch {
                throw APIError.decoding
            }
        }
        return try await status()
    }
}

nonisolated enum AIScheduleSaveConsentDecision: Equatable, Sendable {
    case save(aiTimeParsingRequested: Bool)
    case requestConsent(PolicyDTO)
}

nonisolated enum AIScheduleConsentDecisionPolicy {
    static func saveDecision(
        isAllDay: Bool,
        response: AIScheduleParsingConsentResponse?
    ) -> AIScheduleSaveConsentDecision {
        guard isAllDay else { return .save(aiTimeParsingRequested: true) }
        guard let response else { return .save(aiTimeParsingRequested: false) }
        if response.hasCurrentConsent {
            return .save(aiTimeParsingRequested: true)
        }
        if response.needsRenewal || response.revokedAt == nil {
            return .requestConsent(response.policy)
        }
        return .save(aiTimeParsingRequested: false)
    }

    static func isAllDay(start: Date, end: Date, calendar: Calendar) -> Bool {
        let startParts = calendar.dateComponents([.hour, .minute, .second], from: start)
        let endParts = calendar.dateComponents([.hour, .minute, .second], from: end)
        return [startParts.hour, startParts.minute, startParts.second, endParts.hour, endParts.minute, endParts.second]
            .allSatisfy { ($0 ?? 0) == 0 }
    }
}

nonisolated enum AIScheduleConsentFreshnessPolicy {
    static func shouldRefresh(
        hasResponse: Bool,
        lastSuccessfulRefreshAt: Date?,
        now: Date,
        minimumInterval: TimeInterval
    ) -> Bool {
        guard hasResponse,
              let lastSuccessfulRefreshAt,
              minimumInterval > 0
        else { return true }

        let elapsed = now.timeIntervalSince(lastSuccessfulRefreshAt)
        return elapsed < 0 || elapsed >= minimumInterval
    }
}

@MainActor
final class AIScheduleParsingConsentStore: ObservableObject {
    static let shared = AIScheduleParsingConsentStore()

    private let service: any AIScheduleParsingConsentServicing
    private let now: () -> Date
    private var refreshTask: Task<AIScheduleParsingConsentResponse?, Never>?
    private var refreshTaskMemberID: Int64?
    private var refreshTaskGeneration: UInt = 0
    private var scopeGeneration: UInt = 0
    private(set) var memberID: Int64?
    private(set) var lastSuccessfulRefreshAt: Date?

    @Published private(set) var response: AIScheduleParsingConsentResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdating = false
    @Published private(set) var errorKey: String?

    init(
        service: any AIScheduleParsingConsentServicing = AIScheduleParsingConsentService(),
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.now = now
    }

    var isEnabled: Bool {
        response?.hasCurrentConsent == true
    }

    func scope(to memberID: Int64?) {
        guard self.memberID != memberID else { return }
        scopeGeneration &+= 1
        self.memberID = memberID
        response = nil
        lastSuccessfulRefreshAt = nil
        errorKey = nil
        isLoading = false
        isUpdating = false
        refreshTask = nil
        refreshTaskMemberID = nil
    }

    func dismissError() {
        errorKey = nil
    }

    func reportLoadFailure() {
        errorKey = "settings.aiConsent.loadFailed"
    }

    func load(for memberID: Int64, force: Bool = false) async {
        scope(to: memberID)
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            errorKey = nil
            return
        }
#endif
        if !force {
            guard response == nil else { return }
        }
        _ = await refresh(for: memberID)
    }

    func refreshIfStale(
        for memberID: Int64,
        minimumInterval: TimeInterval = 30
    ) async {
        scope(to: memberID)
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            errorKey = nil
            return
        }
#endif
        guard AIScheduleConsentFreshnessPolicy.shouldRefresh(
            hasResponse: response != nil,
            lastSuccessfulRefreshAt: lastSuccessfulRefreshAt,
            now: now(),
            minimumInterval: minimumInterval
        ) else { return }

        _ = await refresh(for: memberID)
    }

    private func refresh(for memberID: Int64) async -> AIScheduleParsingConsentResponse? {
        let generation = scopeGeneration
        if let refreshTask,
           refreshTaskMemberID == memberID,
           refreshTaskGeneration == generation {
            return await refreshTask.value
        }

        isLoading = true
        errorKey = nil
        let task = Task { @MainActor [weak self] () -> AIScheduleParsingConsentResponse? in
            guard let self else { return nil }
            do {
                let loaded = try await self.service.status()
                guard self.memberID == memberID,
                      self.scopeGeneration == generation
                else { return nil }
                self.response = loaded
                self.lastSuccessfulRefreshAt = self.now()
                return loaded
            } catch {
                guard self.memberID == memberID,
                      self.scopeGeneration == generation
                else { return nil }
                self.errorKey = "settings.aiConsent.loadFailed"
                return nil
            }
        }
        refreshTask = task
        refreshTaskMemberID = memberID
        refreshTaskGeneration = generation

        let result = await task.value
        if self.memberID == memberID,
           scopeGeneration == generation,
           refreshTaskMemberID == memberID,
           refreshTaskGeneration == generation {
            refreshTask = nil
            refreshTaskMemberID = nil
            isLoading = false
        }
        return result
    }

    func saveDecision(
        for memberID: Int64,
        start: Date,
        end: Date,
        calendar: Calendar = CalendarDateSupport.calendar
    ) async -> AIScheduleSaveConsentDecision {
        scope(to: memberID)
        let isAllDay = AIScheduleConsentDecisionPolicy.isAllDay(
            start: start,
            end: end,
            calendar: calendar
        )
        guard isAllDay else { return .save(aiTimeParsingRequested: true) }
        let freshResponse = await refresh(for: memberID)
        return AIScheduleConsentDecisionPolicy.saveDecision(
            isAllDay: true,
            response: freshResponse
        )
    }

    @discardableResult
    func grant(for memberID: Int64, policyVersion: String) async -> Bool {
        await update(for: memberID, consented: true, policyVersion: policyVersion)
    }

    @discardableResult
    func revoke(for memberID: Int64) async -> Bool {
        await update(for: memberID, consented: false, policyVersion: nil)
    }

    private func update(
        for memberID: Int64,
        consented: Bool,
        policyVersion: String?
    ) async -> Bool {
        scope(to: memberID)
        guard !isUpdating else { return false }
        isUpdating = true
        errorKey = nil
        defer {
            if self.memberID == memberID { isUpdating = false }
        }
        do {
            let updated = try await service.update(
                consented: consented,
                policyVersion: policyVersion
            )
            guard self.memberID == memberID else { return false }
            response = updated
            lastSuccessfulRefreshAt = now()
            return consented ? updated.hasCurrentConsent : !updated.consented
        } catch {
            guard self.memberID == memberID else { return false }
            errorKey = consented
                ? "settings.aiConsent.enableFailed"
                : "settings.aiConsent.disableFailed"
            return false
        }
    }
}
