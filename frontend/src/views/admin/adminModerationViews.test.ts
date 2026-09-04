import { describe, expect, it } from 'vitest'
import reportListView from './AdminReportListView.vue?raw'
import inquiryListView from './AdminInquiryListView.vue?raw'
import inquiryUpdateRequest from './inquiryUpdateRequest.ts?raw'
import adminDashboardView from './AdminDashboardView.vue?raw'
import reportDetailModal from '@/components/admin/AdminReportDetailModal.vue?raw'
import inquiryDetailModal from '@/components/admin/AdminInquiryDetailModal.vue?raw'
import memberDetailModal from '@/components/admin/AdminMemberDetailModal.vue?raw'
import {
  INQUIRY_STATUS_LABEL_KEYS,
  MEMBER_STATUS_LABEL_KEYS,
  REPORT_REASON_LABEL_KEYS,
  REPORT_STATUS_LABEL_KEYS,
  REPORT_TARGET_TYPE_LABEL_KEYS,
  inquiryStatusToneClass,
  memberStatusToneClass,
  reportStatusToneClass,
} from '@/components/admin/adminModerationLabels'
import type { ReportResolutionStatus } from '@/types/adminModeration'

describe('AdminReportListView', () => {
  it('offers every report status filter and opens on the unhandled queue', () => {
    for (const value of ['OPEN', 'RESOLVED', 'DISMISSED', 'CANCELED', 'ALL']) {
      expect(reportListView).toContain(`value: '${value}'`)
    }
    expect(reportListView).toContain("ref<ReportStatusFilter>('OPEN')")
  })

  it('marks itself as the reports tab and mounts the detail modal', () => {
    expect(reportListView).toContain('<AdminNavTiles active="reports" />')
    expect(reportListView).toContain('<AdminReportDetailModal')
  })

  it('wires the moderation actions the detail modal emits', () => {
    expect(reportListView).toContain('@update-status="handleUpdateStatus"')
    expect(reportListView).toContain('@delete-target="handleDeleteTarget"')
    expect(reportListView).toContain('@suspend="handleSuspend"')
    expect(reportListView).toContain('@unsuspend="handleUnsuspend"')
  })

  it('confirms content deletion with the destructive confirmation dialog', () => {
    expect(reportListView).toContain('confirmDelete(t(\'admin.reports.messages.deleteTargetConfirm\'')
  })

  it('sends the admin to the reported member calendar', () => {
    expect(reportListView).toContain("router.push({ name: 'duty', params: { id: String(memberId) } })")
  })

  it('submits the memo box verbatim so emptying it clears the stored memo', () => {
    expect(reportListView).toContain('memo: memo.trim(),')
    expect(reportListView).not.toContain('memo.trim() || undefined')
  })

  it('refreshes only the shared report count after a successful status update', () => {
    expect(reportListView).toContain("import { useAdminModerationCounts } from '@/composables/useAdminModerationCounts'")
    expect(reportListView).toContain('const { loadReports } = useAdminModerationCounts()')

    const handlerStart = reportListView.indexOf('async function handleUpdateStatus')
    const handlerEnd = reportListView.indexOf('\n}\n\nasync function handleDeleteTarget', handlerStart)
    const handler = reportListView.slice(handlerStart, handlerEnd)

    expect(handler).toContain('await loadReports(true)')
    expect(handler.indexOf('await loadReports(true)')).toBeGreaterThan(handler.indexOf('await adminApi.updateReportStatus'))
    expect(handler).not.toContain('loadInquiries(true)')
  })

  it('ignores stale list responses and retries the last valid page', () => {
    expect(reportListView).toContain('reportRequestTracker.start()')
    expect(reportListView).toContain('reportRequestTracker.isLatest(requestId)')
    expect(reportListView).toContain('lastValidPage(requestedPage, res.data.totalPages)')
    expect(reportListView).toContain('await fetchReports()')
  })
})

describe('AdminReportDetailModal', () => {
  it('hides content deletion for member targets', () => {
    const labelIndex = reportDetailModal.indexOf('admin.reports.detail.actions.deleteTarget')
    const deleteButton = reportDetailModal.slice(
      reportDetailModal.lastIndexOf('<button', labelIndex),
      labelIndex,
    )
    expect(deleteButton).toContain('v-if="!isMemberTarget"')
  })

  it('disables content deletion once the target is gone', () => {
    expect(reportDetailModal).toContain('!isMemberTarget.value && props.report.targetExists')
    expect(reportDetailModal).toContain(':disabled="working || !canDeleteTarget"')
    expect(reportDetailModal).toContain('admin.reports.detail.targetDeleted')
  })

  it('exposes suspension and calendar actions for the reported member', () => {
    expect(reportDetailModal).toContain('@click="emit(\'suspend\')"')
    expect(reportDetailModal).toContain('@click="emit(\'unsuspend\')"')
    expect(reportDetailModal).toContain('@click="emit(\'goToCalendar\')"')
  })

  it('keys the memo box on the report id so refreshing one report keeps typed text', () => {
    expect(reportDetailModal).toContain('() => props.report?.id ?? null')
    expect(reportDetailModal).not.toContain('() => props.report,')
  })

  it('renders the snapshot verbatim with its line breaks', () => {
    expect(reportDetailModal).toContain('whitespace-pre-wrap break-words text-dp-text-primary">{{ report.contentSnapshot }}')
  })
})

describe('AdminInquiryListView', () => {
  it('offers every inquiry status filter and opens on the unhandled queue', () => {
    for (const value of ['OPEN', 'CLOSED', 'ALL']) {
      expect(inquiryListView).toContain(`value: '${value}'`)
    }
    expect(inquiryListView).toContain("ref<InquiryStatusFilter>('OPEN')")
  })

  it('marks itself as the inquiries tab and mounts the detail modal', () => {
    expect(inquiryListView).toContain('<AdminNavTiles active="inquiries" />')
    expect(inquiryListView).toContain('<AdminInquiryDetailModal')
  })

  it('submits the memo box verbatim so emptying it clears the stored memo', () => {
    expect(inquiryListView).toContain('buildInquiryUpdateRequest(status, memo, answer, selectedInquiry.value.answer)')
    expect(inquiryUpdateRequest).toContain('memo: memo.trim(),')
    expect(inquiryUpdateRequest).not.toContain('memo.trim() || undefined')
  })

  it('copies the reply address to the clipboard', () => {
    expect(inquiryListView).toContain('navigator.clipboard.writeText(email)')
  })

  it('sends the in-app answer along with the status change', () => {
    expect(inquiryListView).toContain('async function handleUpdateStatus(status: InquiryStatus, memo: string, answer: string)')
    expect(inquiryListView).toContain('buildInquiryUpdateRequest(status, memo, answer, selectedInquiry.value.answer)')
  })

  it('refreshes only the shared inquiry count when the status changes', () => {
    expect(inquiryListView).toContain("import { useAdminModerationCounts } from '@/composables/useAdminModerationCounts'")
    expect(inquiryListView).toContain('const { loadInquiries } = useAdminModerationCounts()')

    const handlerStart = inquiryListView.indexOf('async function handleUpdateStatus')
    const handlerEnd = inquiryListView.indexOf('\n}\n\nasync function handleCopyEmail', handlerStart)
    const handler = inquiryListView.slice(handlerStart, handlerEnd)

    expect(handler).toContain('if (statusChanged) await loadInquiries(true)')
    expect(handler.indexOf('if (statusChanged) await loadInquiries(true)')).toBeGreaterThan(handler.indexOf('await adminApi.updateInquiryStatus'))
    expect(handler).not.toContain('loadReports(true)')
  })

  it('ignores stale list responses and retries the last valid page', () => {
    expect(inquiryListView).toContain('inquiryRequestTracker.start()')
    expect(inquiryListView).toContain('inquiryRequestTracker.isLatest(requestId)')
    expect(inquiryListView).toContain('lastValidPage(requestedPage, res.data.totalPages)')
    expect(inquiryListView).toContain('await fetchInquiries()')
  })
})

describe('AdminInquiryDetailModal', () => {
  it('supports replying by email rather than in-app answers', () => {
    expect(inquiryDetailModal).toContain('mailto:${replyEmail.value}')
    expect(inquiryDetailModal).toContain("emit('copyEmail', inquiry.email)")
    expect(inquiryDetailModal).toContain('admin.inquiries.detail.replyHint')
  })

  // A signed-in member is answered in the app, so the inquiry can carry no reply address.
  it('hides the e-mail actions when the inquiry has no reply address', () => {
    expect(inquiryDetailModal).toContain("const replyEmail = computed(() => props.inquiry?.email ?? '')")
    expect(inquiryDetailModal).toContain('admin.inquiries.detail.values.inAppOnly')
    expect(inquiryDetailModal).toContain('v-if="replyEmail"')
    expect(inquiryDetailModal).toContain('v-if="inquiry.email"')
  })

  it('toggles between closing and reopening an inquiry', () => {
    expect(inquiryDetailModal).toContain('@click="emit(\'updateStatus\', \'CLOSED\', memo, answer)"')
    expect(inquiryDetailModal).toContain('@click="emit(\'updateStatus\', \'OPEN\', memo, answer)"')
  })

  it('saves memo and answer while preserving the current inquiry status', () => {
    expect(inquiryDetailModal).toContain('data-testid="save-inquiry"')
    expect(inquiryDetailModal).toContain('@click="emit(\'updateStatus\', inquiry.status, memo, answer)"')
    expect(inquiryDetailModal).toContain('admin.inquiries.detail.actions.saveChanges')
  })

  it('collects the answer the user will read, capped and counted', () => {
    expect(inquiryDetailModal).toContain('v-model="answer"')
    expect(inquiryDetailModal).toContain(':maxlength="ANSWER_MAX_LENGTH"')
    expect(inquiryDetailModal).toContain('ANSWER_MAX_LENGTH = 2000')
    expect(inquiryDetailModal).toContain('<CharacterCounter :current="answer.length" :max="ANSWER_MAX_LENGTH" />')
  })

  it('warns that the answer is published to the user verbatim', () => {
    expect(inquiryDetailModal).toContain('admin.inquiries.detail.answerWarning')
  })

  it('prefills the answer already sent to the user', () => {
    expect(inquiryDetailModal).toContain("answer.value = inquiry?.answer ?? ''")
  })
})

describe('AdminMemberDetailModal suspension controls', () => {
  it('shows the member status badge', () => {
    expect(memberDetailModal).toContain('MEMBER_STATUS_LABEL_KEYS[memberStatus]')
    expect(memberDetailModal).toContain('memberStatusToneClass(memberStatus)')
  })

  it('emits suspend or unsuspend from a single toggle', () => {
    expect(memberDetailModal).toContain('@click="toggleSuspension"')
    expect(memberDetailModal).toContain("emit('unsuspend', props.member)")
    expect(memberDetailModal).toContain("emit('suspend', props.member)")
  })
})

describe('AdminDashboardView moderation entry points', () => {
  it('delegates unhandled counts to the shared navigation state', () => {
    expect(adminDashboardView).not.toContain("adminApi.getReports('OPEN', 0, 1)")
    expect(adminDashboardView).not.toContain("adminApi.getInquiries('OPEN', 0, 1)")
    expect(adminDashboardView).not.toContain(':open-report-count=')
    expect(adminDashboardView).not.toContain(':open-inquiry-count=')
  })

  it('handles suspension from the member detail modal', () => {
    expect(adminDashboardView).toContain('@suspend="handleSuspendMember"')
    expect(adminDashboardView).toContain('@unsuspend="handleUnsuspendMember"')
  })
})

describe('admin report resolution', () => {
  it('never lets an admin withdraw a report on the reporter behalf', () => {
    const resolutions: ReportResolutionStatus[] = ['RESOLVED', 'DISMISSED']

    expect(resolutions).toEqual(['RESOLVED', 'DISMISSED'])
    // @ts-expect-error CANCELED is the reporter's own withdrawal, not an admin decision
    const adminChoice: ReportResolutionStatus = 'CANCELED'
    expect(adminChoice).toBe('CANCELED')
  })
})

describe('admin moderation label maps', () => {
  it('maps every enum value to a translation key', () => {
    expect(Object.keys(REPORT_STATUS_LABEL_KEYS)).toEqual(['OPEN', 'RESOLVED', 'DISMISSED', 'CANCELED'])
    expect(Object.keys(REPORT_REASON_LABEL_KEYS)).toEqual([
      'SPAM',
      'HARASSMENT',
      'INAPPROPRIATE_CONTENT',
      'IMPERSONATION',
      'OTHER',
    ])
    expect(Object.keys(REPORT_TARGET_TYPE_LABEL_KEYS)).toEqual(['MEMBER', 'SCHEDULE', 'TODO'])
    expect(Object.keys(INQUIRY_STATUS_LABEL_KEYS)).toEqual(['OPEN', 'CLOSED'])
    expect(Object.keys(MEMBER_STATUS_LABEL_KEYS)).toEqual(['ACTIVE', 'SUSPENDED', 'DELETION_PENDING'])
  })

  it('separates unhandled, handled and suspended tones', () => {
    expect(reportStatusToneClass('OPEN')).not.toBe(reportStatusToneClass('RESOLVED'))
    expect(reportStatusToneClass('DISMISSED')).not.toBe(reportStatusToneClass('RESOLVED'))
    expect(reportStatusToneClass('CANCELED')).not.toBe(reportStatusToneClass('OPEN'))
    expect(inquiryStatusToneClass('OPEN')).not.toBe(inquiryStatusToneClass('CLOSED'))
    expect(memberStatusToneClass('SUSPENDED')).toContain('danger')
    expect(memberStatusToneClass('ACTIVE')).not.toContain('danger')
  })
})
