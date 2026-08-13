import { describe, expect, it } from 'vitest'
import en from './messages/en'
import es from './messages/es'
import ja from './messages/ja'
import ko from './messages/ko'
import zh from './messages/zh'

const locales = { ko, en, ja, zh, es }

const requiredPlaceholders = {
  'notifications.list.deleteConfirmMessage': ['message'],
  'todoBoard.messages.deleteConfirm': ['title'],
  'todoBoard.messages.untagConfirm': ['title'],
  'member.sessions.signOutCurrentConfirm': ['device', 'browser', 'ip'],
  'duty.schedule.messages.deleteConfirm': ['title'],
  'duty.untagConfirm.message': ['title'],
  'duty.todo.messages.deleteConfirm': ['title'],
  'duty.todo.messages.untagConfirm': ['title'],
  'team.view.schedule.deleteConfirm': ['title'],
  'team.manage.messages.resetAdminConfirm': ['name'],
  'team.manage.messages.deleteTeamConfirm': ['name'],
  'friendTagSelector.clearConfirm': ['count'],
  'admin.dashboard.messages.revokeSessionConfirm': ['name', 'device', 'browser', 'ip'],
} as const

function readMessage(messages: object, path: string): unknown {
  return path.split('.').reduce<unknown>((current, segment) => {
    if (typeof current !== 'object' || current === null) return undefined
    return (current as Record<string, unknown>)[segment]
  }, messages)
}

describe('destructive confirmation translations', () => {
  it.each(Object.entries(locales))('%s identifies every destructive action target', (_locale, messages) => {
    for (const [key, placeholders] of Object.entries(requiredPlaceholders)) {
      const value = readMessage(messages, key)
      expect(value, `missing destructive confirmation: ${key}`).toEqual(expect.any(String))

      for (const placeholder of placeholders) {
        expect(String(value), `${key} must identify its target with {${placeholder}}`).toContain(`{${placeholder}}`)
      }
    }
  })
})
