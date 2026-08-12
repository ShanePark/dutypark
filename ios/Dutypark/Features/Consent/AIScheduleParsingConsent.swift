import Combine
import Foundation

nonisolated struct AIScheduleParsingConsentResponse: Codable, Equatable, Sendable {
    let consented: Bool
    let currentPolicyVersion: String
    let consentVersion: String?
    let needsRenewal: Bool
    let consentedAt: String?
    let revokedAt: String?
    let policy: PolicyDTO

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

@MainActor
final class AIScheduleParsingConsentStore: ObservableObject {
    static let shared = AIScheduleParsingConsentStore()

    private let service: any AIScheduleParsingConsentServicing
    private(set) var memberID: Int64?

    @Published private(set) var response: AIScheduleParsingConsentResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdating = false
    @Published private(set) var errorKey: String?

    init(service: any AIScheduleParsingConsentServicing = AIScheduleParsingConsentService()) {
        self.service = service
    }

    var isEnabled: Bool {
        response?.hasCurrentConsent == true
    }

    func scope(to memberID: Int64?) {
        guard self.memberID != memberID else { return }
        self.memberID = memberID
        response = nil
        errorKey = nil
        isLoading = false
        isUpdating = false
    }

    func dismissError() {
        errorKey = nil
    }

    func reportLoadFailure() {
        errorKey = "settings.aiConsent.loadFailed"
    }

    func load(for memberID: Int64, force: Bool = false) async {
        scope(to: memberID)
        if !force {
            guard response == nil, !isLoading else { return }
        }
        _ = await refresh(for: memberID)
    }

    private func refresh(for memberID: Int64) async -> AIScheduleParsingConsentResponse? {
        isLoading = true
        errorKey = nil
        defer {
            if self.memberID == memberID { isLoading = false }
        }
        do {
            let loaded = try await service.status()
            guard self.memberID == memberID else { return nil }
            response = loaded
            return loaded
        } catch {
            guard self.memberID == memberID else { return nil }
            errorKey = "settings.aiConsent.loadFailed"
            return nil
        }
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
