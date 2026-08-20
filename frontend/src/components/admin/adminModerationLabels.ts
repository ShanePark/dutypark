import type { MemberStatus } from '@/types'
import type {
  InquiryStatus,
  ReportReason,
  ReportStatus,
  ReportTargetType,
} from '@/types/adminModeration'

export const REPORT_STATUS_LABEL_KEYS: Record<ReportStatus, string> = {
  OPEN: 'admin.reports.status.open',
  RESOLVED: 'admin.reports.status.resolved',
  DISMISSED: 'admin.reports.status.dismissed',
  CANCELED: 'admin.reports.status.canceled',
}

export const REPORT_REASON_LABEL_KEYS: Record<ReportReason, string> = {
  SPAM: 'admin.reports.reason.spam',
  HARASSMENT: 'admin.reports.reason.harassment',
  INAPPROPRIATE_CONTENT: 'admin.reports.reason.inappropriateContent',
  IMPERSONATION: 'admin.reports.reason.impersonation',
  OTHER: 'admin.reports.reason.other',
}

export const REPORT_TARGET_TYPE_LABEL_KEYS: Record<ReportTargetType, string> = {
  MEMBER: 'admin.reports.targetType.member',
  SCHEDULE: 'admin.reports.targetType.schedule',
  TODO: 'admin.reports.targetType.todo',
}

export const INQUIRY_STATUS_LABEL_KEYS: Record<InquiryStatus, string> = {
  OPEN: 'admin.inquiries.status.open',
  CLOSED: 'admin.inquiries.status.closed',
}

export const MEMBER_STATUS_LABEL_KEYS: Record<MemberStatus, string> = {
  ACTIVE: 'admin.memberDetail.suspension.statusBadge.active',
  SUSPENDED: 'admin.memberDetail.suspension.statusBadge.suspended',
  DELETION_PENDING: 'admin.memberDetail.suspension.statusBadge.deletionPending',
}

const OPEN_TONE = 'bg-dp-warning-soft text-dp-warning'
const DONE_TONE = 'bg-dp-success-soft text-dp-success'
const MUTED_TONE = 'bg-dp-bg-tertiary text-dp-text-secondary'
const DANGER_TONE = 'bg-dp-danger-soft text-dp-danger'

export function reportStatusToneClass(status: ReportStatus): string {
  if (status === 'OPEN') return OPEN_TONE
  if (status === 'RESOLVED') return DONE_TONE
  return MUTED_TONE
}

export function inquiryStatusToneClass(status: InquiryStatus): string {
  return status === 'OPEN' ? OPEN_TONE : DONE_TONE
}

export function memberStatusToneClass(status: MemberStatus): string {
  if (status === 'SUSPENDED') return DANGER_TONE
  if (status === 'DELETION_PENDING') return OPEN_TONE
  return MUTED_TONE
}
