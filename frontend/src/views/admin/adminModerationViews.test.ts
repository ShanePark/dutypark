import { describe, expect, it } from 'vitest'
import reportListView from './AdminReportListView.vue?raw'
import inquiryListView from './AdminInquiryListView.vue?raw'
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

describe('AdminReportListView', () => {
  it('offers every report status filter and opens on the unhandled queue', () => {
    for (const value of ['OPEN', 'RESOLVED', 'DISMISSED', 'ALL']) {
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

  it('copies the reply address to the clipboard', () => {
    expect(inquiryListView).toContain('navigator.clipboard.writeText(email)')
  })
})

describe('AdminInquiryDetailModal', () => {
  it('supports replying by email rather than in-app answers', () => {
    expect(inquiryDetailModal).toContain('mailto:${props.inquiry.email}')
    expect(inquiryDetailModal).toContain("emit('copyEmail', inquiry.email)")
    expect(inquiryDetailModal).toContain('admin.inquiries.detail.replyHint')
  })

  it('toggles between closing and reopening an inquiry', () => {
    expect(inquiryDetailModal).toContain('@click="emit(\'updateStatus\', \'CLOSED\', memo)"')
    expect(inquiryDetailModal).toContain('@click="emit(\'updateStatus\', \'OPEN\', memo)"')
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
  it('reads the unhandled counts from a single-element page', () => {
    expect(adminDashboardView).toContain("adminApi.getReports('OPEN', 0, 1)")
    expect(adminDashboardView).toContain("adminApi.getInquiries('OPEN', 0, 1)")
    expect(adminDashboardView).toContain(':open-report-count="openReportCount"')
    expect(adminDashboardView).toContain(':open-inquiry-count="openInquiryCount"')
  })

  it('handles suspension from the member detail modal', () => {
    expect(adminDashboardView).toContain('@suspend="handleSuspendMember"')
    expect(adminDashboardView).toContain('@unsuspend="handleUnsuspendMember"')
  })
})

describe('admin moderation label maps', () => {
  it('maps every enum value to a translation key', () => {
    expect(Object.keys(REPORT_STATUS_LABEL_KEYS)).toEqual(['OPEN', 'RESOLVED', 'DISMISSED'])
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
    expect(inquiryStatusToneClass('OPEN')).not.toBe(inquiryStatusToneClass('CLOSED'))
    expect(memberStatusToneClass('SUSPENDED')).toContain('danger')
    expect(memberStatusToneClass('ACTIVE')).not.toContain('danger')
  })
})
