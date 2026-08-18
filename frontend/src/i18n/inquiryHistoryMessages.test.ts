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

describe('my inquiry history translations', () => {
  it.each(locales)('names every state of the history list in %s', (_locale, messages) => {
    const history = messages.support.history
    for (const value of [
      history.loading,
      history.loadFailed,
      history.retry,
      history.empty,
      history.emptyAction,
      history.loadMore,
      history.noSubject,
      history.submittedAt,
      history.status.open,
      history.status.closed,
      history.answered,
      history.awaiting,
      history.contentTitle,
      history.answerTitle,
      history.answeredAt,
      history.awaitingDescription,
    ]) {
      expect(value).toEqual(expect.any(String))
    }
    expect(messages.support.tabs.form).toEqual(expect.any(String))
    expect(messages.support.tabs.history).toEqual(expect.any(String))
  })

  it.each(locales)('promises an in-app answer to signed-in members in %s', (_locale, messages) => {
    expect(messages.support.form.descriptionSignedIn).toEqual(expect.any(String))
    expect(messages.support.form.guestHint).toEqual(expect.any(String))
    expect(messages.support.success.descriptionSignedIn).toEqual(expect.any(String))
  })

  it.each(locales)('interpolates the inquiry subject in the answered notification in %s', (_locale, messages) => {
    expect(messages.notifications.items.inquiryAnswered.v1).toContain('{subject}')
    expect(messages.notifications.items.inquiryAnsweredFallback.v1).not.toContain('{subject}')
  })

  it.each(locales)('warns that the admin answer reaches the user verbatim in %s', (_locale, messages) => {
    expect(messages.admin.inquiries.detail.answerWarning).toEqual(expect.any(String))
    expect(messages.admin.inquiries.detail.answerPlaceholder).toEqual(expect.any(String))
    expect(messages.admin.inquiries.detail.fields.answer).toEqual(expect.any(String))
  })

  it('keeps the ko and en support namespaces in sync', () => {
    expect(keyPaths(en.support)).toEqual(keyPaths(ko.support))
    expect(keyPaths(en.notifications)).toEqual(keyPaths(ko.notifications))
  })
})
