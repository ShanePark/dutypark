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

    static func detailLength(_ detail: String) -> Int {
        normalizedDetail(detail)?.utf16.count ?? 0
    }

    static func canSubmit(reason: ReportReason, detail: String) -> Bool {
        guard detailLength(detail) <= detailLimit else { return false }
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
    /// Whether the accepted report also blocked the reported member. Snapshotting the
    /// toggle keeps the outcome true to what the server was actually asked to do.
    @Published private(set) var didBlock = false
    @Published var errorMessage: String?

    let target: ReportTarget
    private let repository: any ReportRepository
    private let hapticCenter: DPHapticCenter

    init(
        target: ReportTarget,
        repository: any ReportRepository = ReportAPIRepository(),
        hapticCenter: DPHapticCenter = .shared
    ) {
        self.target = target
        self.repository = repository
        self.hapticCenter = hapticCenter
    }

    var targetLabel: String {
        ReportLocalization.format(target.type.labelKey, target.name)
    }

    var requiresDetail: Bool {
        reason == .other
    }

    var isDetailTooLong: Bool {
        detailLength > ReportSubmissionPolicy.detailLimit
    }

    var detailLength: Int {
        ReportSubmissionPolicy.detailLength(detail)
    }

    var canSubmit: Bool {
        !isSubmitting
            && !didSubmit
            && ReportSubmissionPolicy.canSubmit(reason: reason, detail: detail)
    }

    /// Picker and toggle bindings call these methods so a repeated value assignment is
    /// silent while every committed choice still gets one selection tick.
    func selectReason(_ reason: ReportReason) {
        guard self.reason != reason else { return }
        self.reason = reason
        hapticCenter.emit(.selection)
    }

    func setAlsoBlock(_ isEnabled: Bool) {
        guard alsoBlock != isEnabled else { return }
        alsoBlock = isEnabled
        hapticCenter.emit(.selection)
    }

    @discardableResult
    func submit() async -> Bool {
        guard !isSubmitting, !didSubmit else { return false }
        guard ReportSubmissionPolicy.canSubmit(reason: reason, detail: detail) else {
            hapticCenter.emit(.warning)
            return false
        }
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil
        let request = CreateReportRequest(
            targetType: target.type,
            targetId: target.targetID,
            reason: reason,
            detail: ReportSubmissionPolicy.normalizedDetail(detail),
            alsoBlock: alsoBlock
        )
        do {
            try await repository.createReport(request)
            didSubmit = true
            didBlock = request.alsoBlock
            hapticCenter.emit(.success)
            return true
        } catch {
            errorMessage = error.localizedDescription
            hapticCenter.emit(.error)
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
    private let hapticCenter: DPHapticCenter

    init(
        repository: any ReportRepository = ReportAPIRepository(),
        hapticCenter: DPHapticCenter = .shared
    ) {
        self.repository = repository
        self.hapticCenter = hapticCenter
    }

    @discardableResult
    func block(memberID: MemberID) async -> Bool {
        guard !isBlocking else { return false }
        isBlocking = true
        defer { isBlocking = false }
        do {
            try await repository.block(memberID: memberID)
            hapticCenter.emit(.success)
            return true
        } catch {
            errorMessage = error.localizedDescription
            hapticCenter.emit(.error)
            return false
        }
    }
}
