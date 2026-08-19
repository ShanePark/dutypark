import Foundation

nonisolated enum ReportTargetType: String, Codable, Equatable, Sendable {
    case member = "MEMBER"
    case schedule = "SCHEDULE"
    case todo = "TODO"

    /// Printf label naming what is being reported, for example `일정: {제목}`.
    var labelKey: String {
        switch self {
        case .member: "report.target.member"
        case .schedule: "report.target.schedule"
        case .todo: "report.target.todo"
        }
    }
}

nonisolated enum ReportReason: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case spam = "SPAM"
    case harassment = "HARASSMENT"
    case inappropriateContent = "INAPPROPRIATE_CONTENT"
    case impersonation = "IMPERSONATION"
    case other = "OTHER"

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .spam: "report.reason.spam"
        case .harassment: "report.reason.harassment"
        case .inappropriateContent: "report.reason.inappropriateContent"
        case .impersonation: "report.reason.impersonation"
        case .other: "report.reason.other"
        }
    }
}

/// What a report sheet was opened for: the API target plus the name shown in the form.
nonisolated struct ReportTarget: Identifiable, Equatable, Sendable {
    let type: ReportTargetType
    let targetID: String
    let name: String

    var id: String { "\(type.rawValue)-\(targetID)" }
}

nonisolated struct CreateReportRequest: Codable, Equatable, Sendable {
    let targetType: ReportTargetType
    let targetId: String
    let reason: ReportReason
    let detail: String?
    let alsoBlock: Bool
}

/// How far a report has been handled. `open` is the intake state; the other two are the
/// outcomes an administrator can record.
nonisolated enum ReportStatus: String, Codable, Equatable, Sendable {
    case open = "OPEN"
    case resolved = "RESOLVED"
    case dismissed = "DISMISSED"
}

/// One row of `GET /api/reports/me`. The endpoint deliberately omits the
/// administrator-only fields (`adminMemo`, `resolvedBy`, `contentSnapshot`) and the target
/// identifier, so nothing here can leak them to the reporter. The reported name is a
/// snapshot taken when the report was filed, so it survives the member being deleted.
nonisolated struct MyReportDTO: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let targetType: ReportTargetType
    let reportedMemberName: String
    let reason: ReportReason
    let detail: String?
    let status: ReportStatus
    let createdAt: LocalDateTimeValue
    let resolvedAt: LocalDateTimeValue?
}
