import { describe, expect, it } from 'vitest'
import en from './messages/en'
import es from './messages/es'
import ja from './messages/ja'
import ko from './messages/ko'
import zh from './messages/zh'

const locales = { ko, en, ja, zh, es }

const requiredKeys = [
  'apiErrors.common.concurrentUpdate',
  'apiErrors.duty.pattern.team.required',
  'apiErrors.duty.pattern.weekdays.required',
  'apiErrors.duty.pattern.weekdays.duplicate',
  'apiErrors.duty.pattern.dutyType.invalid',
  'member.dutyPattern.sectionTitle',
  'member.dutyPattern.modalTitle',
  'member.dutyPattern.description',
  'member.dutyPattern.summary.edit',
  'member.dutyPattern.summary.offDay',
  'member.dutyPattern.summary.holidayOffBadge',
  'member.dutyPattern.summary.setupTitle',
  'member.dutyPattern.summary.setupDescription',
  'member.dutyPattern.summary.setupAction',
  'member.dutyPattern.dutyType',
  'member.dutyPattern.dutyTypeByDay',
  'member.dutyPattern.automatic',
  'member.dutyPattern.noDutyType',
  'member.dutyPattern.weekdaysLabel',
  'member.dutyPattern.holidayOff',
  'member.dutyPattern.holidayOffHint',
  'member.dutyPattern.effectiveFrom',
  'member.dutyPattern.unavailable.title',
  'member.dutyPattern.unavailable.team',
  'member.dutyPattern.unavailable.none',
  'member.dutyPattern.unavailable.multiple',
  'member.dutyPattern.unavailable.default',
  'member.dutyPattern.paused.title',
  'member.dutyPattern.paused.description',
  'member.dutyPattern.actions.save',
  'member.dutyPattern.actions.update',
  'member.dutyPattern.actions.delete',
  'member.dutyPattern.validation.weekdayRequired',
  'member.dutyPattern.validation.dutyTypeRequired',
  'member.dutyPattern.messages.loadFailed',
  'member.dutyPattern.messages.saveConfirm',
  'member.dutyPattern.messages.saveSuccess',
  'member.dutyPattern.messages.saveFailed',
  'member.dutyPattern.messages.deleteConfirm',
  'member.dutyPattern.messages.deleteSuccess',
  'member.dutyPattern.messages.deleteFailed',
  'team.manage.labels.visible',
  'team.manage.labels.hidden',
  'team.manage.actions.hideDutyType',
  'team.manage.actions.restoreDutyType',
  'team.manage.messages.hideDutyTypeConfirm',
  'team.manage.messages.restoreDutyTypeConfirm',
  'team.manage.messages.hideDutyTypeSuccess',
  'team.manage.messages.restoreDutyTypeSuccess',
  'team.manage.messages.updateDutyTypeVisibilityFailed',
] as const

function readMessage(messages: object, path: string): unknown {
  return path.split('.').reduce<unknown>((current, segment) => {
    if (typeof current !== 'object' || current === null) return undefined
    return (current as Record<string, unknown>)[segment]
  }, messages)
}

describe('weekly duty pattern translations', () => {
  it.each(Object.entries(locales))('%s has every user-facing pattern and visibility message', (_locale, messages) => {
    for (const key of requiredKeys) {
      const value = readMessage(messages, key)
      expect(value, `missing or empty translation: ${key}`).toEqual(expect.any(String))
      expect(String(value).trim(), `empty translation: ${key}`).not.toBe('')
    }
  })

  it.each(Object.entries(locales))('%s has all seven weekday labels', (_locale, messages) => {
    for (const day of ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']) {
      const value = readMessage(messages, `member.dutyPattern.weekdays.${day}`)
      expect(value, `missing weekday translation: ${day}`).toEqual(expect.any(String))
      expect(String(value).trim(), `empty weekday translation: ${day}`).not.toBe('')
    }
  })
})
