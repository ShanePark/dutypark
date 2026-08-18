import Combine
import Foundation

nonisolated enum ReportLocalization {
    static func text(_ key: String) -> String {
        AppLocalization.string(key, table: "Report")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalization.format(key, table: "Report", arguments: arguments)
    }
}

/// The one client-side rule of the report form: `OTHER` has no fixed meaning, so it
/// only says something once the reporter writes it down. The server enforces the same
/// rule with `report.detail.required`.
nonisolated enum ReportSubmissionPolicy {
    static let detailLimit = 500

    static func normalizedDetail(_ detail: String) -> String? {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func canSubmit(reason: ReportReason, detail: String) -> Bool {
        guard detail.count <= detailLimit else { return false }
        guard reason == .other else { return true }
        return normalizedDetail(detail) != nil
    }
}

@MainActor
final class ReportViewModel: ObservableObject {
    @Published var reason: ReportReason = .spam
    @Published var detail = ""
    @Published var alsoBlock = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var didSubmit = false
    @Published var errorMessage: String?

    let target: ReportTarget
    private let repository: any ReportRepository

    init(target: ReportTarget, repository: any ReportRepository = ReportAPIRepository()) {
        self.target = target
        self.repository = repository
    }

    var targetLabel: String {
        ReportLocalization.format(target.type.labelKey, target.name)
    }

    var requiresDetail: Bool {
        reason == .other
    }

    var isDetailTooLong: Bool {
        detail.count > ReportSubmissionPolicy.detailLimit
    }

    var canSubmit: Bool {
        !isSubmitting
            && !didSubmit
            && ReportSubmissionPolicy.canSubmit(reason: reason, detail: detail)
    }

    @discardableResult
    func submit() async -> Bool {
        guard canSubmit else { return false }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await repository.createReport(
                CreateReportRequest(
                    targetType: target.type,
                    targetId: target.targetID,
                    reason: reason,
                    detail: ReportSubmissionPolicy.normalizedDetail(detail),
                    alsoBlock: alsoBlock
                )
            )
            didSubmit = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

/// Blocking from the member calendar overflow menu. Kept apart from `ReportViewModel`
/// because it is bound to a member rather than to one report form.
@MainActor
final class MemberBlockViewModel: ObservableObject {
    @Published private(set) var isBlocking = false
    @Published var errorMessage: String?

    private let repository: any ReportRepository

    init(repository: any ReportRepository = ReportAPIRepository()) {
        self.repository = repository
    }

    @discardableResult
    func block(memberID: MemberID) async -> Bool {
        guard !isBlocking else { return false }
        isBlocking = true
        defer { isBlocking = false }
        do {
            try await repository.block(memberID: memberID)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
