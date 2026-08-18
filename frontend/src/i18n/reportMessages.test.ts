import { describe, expect, it } from 'vitest'
import en from './messages/en'
import ko from './messages/ko'
import { REPORT_REASONS, REPORT_TARGET_TYPES } from '@/types/report'

const locales = { ko, en }

// Every error code introduced by the report/block/inquiry contract must be translatable,
// otherwise `resolveApiErrorMessage` silently falls back to a generic message.
const requiredApiErrorCodes = [
  'block.self',
  'friend.request.blocked',
  'report.self',
  'report.detail.required',
  'report.target.notDeletable',
  'member.suspend.deletionPending',
  'auth.account.suspended',
  'inquiry.rateLimit.exceeded',
]

const requiredReportKeys = [
  'report.actions.menu',
  'report.actions.report',
  'report.actions.reportMember',
  'report.actions.blockMember',
  'report.modal.title',
  'report.modal.reasonLabel',
  'report.modal.reasonRequired',
  'report.modal.detailLabel',
  'report.modal.detailPlaceholder',
  'report.modal.detailRequired',
  'report.modal.alsoBlock',
  'report.modal.submit',
  'report.modal.submitting',
  'report.messages.submitted',
  'report.messages.submitFailed',
  'report.login.title',
  'report.login.message',
  'report.login.confirm',
  'report.block.title',
  'report.block.message',
  'report.block.confirm',
  'report.block.failed',
]

const reasonKeys: Record<(typeof REPORT_REASONS)[number], string> = {
  SPAM: 'report.reasons.spam',
  HARASSMENT: 'report.reasons.harassment',
  INAPPROPRIATE_CONTENT: 'report.reasons.inappropriateContent',
  IMPERSONATION: 'report.reasons.impersonation',
  OTHER: 'report.reasons.other',
}

const targetKeys: Record<(typeof REPORT_TARGET_TYPES)[number], string> = {
  MEMBER: 'report.targets.member',
  SCHEDULE: 'report.targets.schedule',
  TODO: 'report.targets.todo',
}

function readMessage(messages: object, path: string): unknown {
  return path.split('.').reduce<unknown>((current, segment) => {
    if (typeof current !== 'object' || current === null) return undefined
    return (current as Record<string, unknown>)[segment]
  }, messages)
}

describe('report translations', () => {
  it.each(Object.entries(locales))('%s translates every new API error code', (_locale, messages) => {
    for (const code of requiredApiErrorCodes) {
      const value = readMessage(messages, `apiErrors.${code}`)
      expect(value, `missing apiErrors.${code}`).toEqual(expect.any(String))
    }
  })

  it.each(Object.entries(locales))('%s translates the report UI', (_locale, messages) => {
    for (const key of [...requiredReportKeys, ...Object.values(reasonKeys)]) {
      expect(readMessage(messages, key), `missing ${key}`).toEqual(expect.any(String))
    }
  })

  it.each(Object.entries(locales))('%s names the report target and the blocked member', (_locale, messages) => {
    for (const key of Object.values(targetKeys)) {
      expect(String(readMessage(messages, key)), `${key} must include {name}`).toContain('{name}')
    }
    expect(String(readMessage(messages, 'report.block.success'))).toContain('{name}')
  })
})
