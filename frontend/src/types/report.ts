export const REPORT_TARGET_TYPES = ['MEMBER', 'SCHEDULE', 'TODO'] as const
export type ReportTargetType = (typeof REPORT_TARGET_TYPES)[number]

export const REPORT_REASONS = [
  'SPAM',
  'HARASSMENT',
  'INAPPROPRIATE_CONTENT',
  'IMPERSONATION',
  'OTHER',
] as const
export type ReportReason = (typeof REPORT_REASONS)[number]

export const REPORT_STATUS = ['OPEN', 'RESOLVED', 'DISMISSED'] as const
export type ReportStatus = (typeof REPORT_STATUS)[number]

export const REPORT_DETAIL_MAX_LENGTH = 500

export interface CreateReportRequest {
  targetType: ReportTargetType
  targetId: string
  reason: ReportReason
  detail?: string
  alsoBlock: boolean
}

export interface CreateReportResponse {
  id: string
}

/** What the report modal is currently pointed at. */
export interface ReportTarget {
  targetType: ReportTargetType
  targetId: string
  targetName: string
}

export interface ReportSubmission {
  reason: ReportReason
  detail: string
  alsoBlock: boolean
}

/**
 * The reporter's own view of a report. Deliberately narrower than the admin DTOs: the
 * moderation memo, the evidence snapshot and the target identifier never reach the reporter.
 */
export interface MyReport {
  id: string
  targetType: ReportTargetType
  reportedMemberName: string
  reason: ReportReason
  detail: string | null
  status: ReportStatus
  createdAt: string
  resolvedAt: string | null
}
