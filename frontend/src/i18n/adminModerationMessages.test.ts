import { describe, expect, it } from 'vitest'
import en from './messages/en'
import ko from './messages/ko'

const locales: [string, typeof ko | typeof en][] = [['ko', ko], ['en', en]]

function keyPaths(value: unknown, prefix = ''): string[] {
  if (typeof value !== 'object' || value === null) return [prefix]
  return Object.entries(value as Record<string, unknown>)
    .flatMap(([key, child]) => keyPaths(child, prefix ? `${prefix}.${key}` : key))
    .sort()
}

describe('admin moderation translations', () => {
  it.each(locales)('defines the report queue copy in %s', (_locale, messages) => {
    const reports = messages.admin.reports
    expect(reports.totalReports).toContain('{count}')
    expect(reports.pagination).toContain('{total}')
    expect(reports.row.reportedMember).toContain('{name}')
    expect(reports.row.reporter).toContain('{name}')
    expect(reports.messages.deleteTargetConfirm).toContain('{name}')
    expect(reports.detail.memberTargetNotDeletable).toBeTruthy()
    expect(reports.detail.targetDeleted).toBeTruthy()
    expect(reports.detail.actions.viewCalendar).toBeTruthy()
  })

  it.each(locales)('defines the inquiry queue copy in %s', (_locale, messages) => {
    const inquiries = messages.admin.inquiries
    expect(inquiries.totalInquiries).toContain('{count}')
    expect(inquiries.detail.replyHint).toBeTruthy()
    expect(inquiries.detail.actions.copyEmail).toBeTruthy()
    expect(inquiries.detail.actions.markClosed).toBeTruthy()
    expect(inquiries.detail.actions.reopen).toBeTruthy()
  })

  it.each(locales)('names the suspension action and its confirmations in %s', (_locale, messages) => {
    const suspension = messages.admin.memberDetail.suspension
    expect(suspension.statusBadge.suspended).toBeTruthy()
    expect(suspension.suspendConfirm).toContain('{name}')
    expect(suspension.unsuspendConfirm).toContain('{name}')
    expect(suspension.suspendSuccess).toContain('{name}')
    expect(suspension.unsuspendSuccess).toContain('{name}')
  })

  it('keeps the ko and en admin namespaces in sync', () => {
    expect(keyPaths(en.admin)).toEqual(keyPaths(ko.admin))
  })
})
