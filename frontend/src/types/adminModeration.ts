import type { MemberStatus } from '@/types'
import type { InquiryStatus } from './inquiry'

// Report moderation types (admin only)
export type ReportTargetType = 'MEMBER' | 'SCHEDULE' | 'TODO'

export type ReportReason =
  | 'SPAM'
  | 'HARASSMENT'
  | 'INAPPROPRIATE_CONTENT'
  | 'IMPERSONATION'
  | 'OTHER'

export type ReportStatus = 'OPEN' | 'RESOLVED' | 'DISMISSED'

/** Status query value accepted by the admin report list API. `ALL` means "no status filter". */
export type ReportStatusFilter = ReportStatus | 'ALL'

/** Resolution states an admin can move a report into. `OPEN` is the intake state only. */
export type ReportResolutionStatus = Exclude<ReportStatus, 'OPEN'>

export interface ReportPartyDto {
  id: number
  name: string
  status: MemberStatus
}

export interface AdminReportSummaryDto {
  id: string
  targetType: ReportTargetType
  targetId: string
  reason: ReportReason
  status: ReportStatus
  createdAt: string
  /** null when the member has been deleted; the snapshot name is kept for evidence. */
  reporter: ReportPartyDto | null
  reportedMember: ReportPartyDto | null
  reporterName: string
  reportedMemberName: string
  snapshotPreview: string
}

export interface AdminReportDetailDto extends AdminReportSummaryDto {
  detail: string | null
  contentSnapshot: string
  targetExists: boolean
  adminMemo: string | null
  resolvedAt: string | null
  resolvedByName: string | null
}

export interface UpdateReportStatusRequest {
  status: ReportResolutionStatus
  /** Omitted keeps the memo already recorded; an empty string clears it. */
  memo?: string
}

// Inquiry management types (admin only)
export type { InquiryStatus }

/** Status query value accepted by the admin inquiry list API. `ALL` means "no status filter". */
export type InquiryStatusFilter = InquiryStatus | 'ALL'

export interface AdminInquiryDto {
  id: string
  /** null when the inquiry was submitted without signing in. */
  memberId: number | null
  memberName: string | null
  /** null when a signed-in member sent the inquiry without an account e-mail to reply to. */
  email: string | null
  subject: string | null
  content: string
  status: InquiryStatus
  adminMemo: string | null
  createdAt: string
  closedAt: string | null
  /** Published to the member verbatim; null until an admin writes one. */
  answer: string | null
  answeredAt: string | null
  answeredBy: number | null
}

export interface UpdateInquiryStatusRequest {
  status: InquiryStatus
  /** Omitted keeps the memo already recorded; an empty string clears it. */
  memo?: string
  /** Blank or omitted keeps the current answer; answers are never cleared. */
  answer?: string
}
