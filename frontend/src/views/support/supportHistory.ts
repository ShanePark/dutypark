import type { ReportReason, ReportStatus, ReportTargetType } from '@/types/report'

/** Member-facing labels. The admin namespace stays separate: its wording is internal. */
export const MY_REPORT_STATUS_LABEL_KEYS: Record<ReportStatus, string> = {
  OPEN: 'support.reports.status.open',
  RESOLVED: 'support.reports.status.resolved',
  DISMISSED: 'support.reports.status.dismissed',
  CANCELED: 'support.reports.status.canceled',
}

export const MY_REPORT_STATUS_DESCRIPTION_KEYS: Record<ReportStatus, string> = {
  OPEN: 'support.reports.statusDescription.open',
  RESOLVED: 'support.reports.statusDescription.resolved',
  DISMISSED: 'support.reports.statusDescription.dismissed',
  CANCELED: 'support.reports.statusDescription.canceled',
}

export const MY_REPORT_REASON_LABEL_KEYS: Record<ReportReason, string> = {
  SPAM: 'report.reasons.spam',
  HARASSMENT: 'report.reasons.harassment',
  INAPPROPRIATE_CONTENT: 'report.reasons.inappropriateContent',
  IMPERSONATION: 'report.reasons.impersonation',
  OTHER: 'report.reasons.other',
}

export const MY_REPORT_TARGET_TYPE_LABEL_KEYS: Record<ReportTargetType, string> = {
  MEMBER: 'support.reports.targetType.member',
  SCHEDULE: 'support.reports.targetType.schedule',
  TODO: 'support.reports.targetType.todo',
}

const OPEN_TONE = 'bg-dp-warning-soft text-dp-warning'
const DONE_TONE = 'bg-dp-success-soft text-dp-success'
const MUTED_TONE = 'bg-dp-bg-tertiary text-dp-text-secondary'

export function myReportStatusToneClass(status: ReportStatus): string {
  if (status === 'OPEN') return OPEN_TONE
  if (status === 'RESOLVED') return DONE_TONE
  return MUTED_TONE
}

/** The server sends a `LocalDateTime`, so it is read in the reader's own time zone. */
export function formatSupportDateTime(value: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(new Date(value))
}
