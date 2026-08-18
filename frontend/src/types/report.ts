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
