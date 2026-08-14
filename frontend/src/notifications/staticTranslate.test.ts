import { describe, expect, it } from 'vitest'
import { createStaticNotificationTranslate } from './staticTranslate'

describe('createStaticNotificationTranslate', () => {
  it('renders Korean notification templates with interpolation', () => {
    const t = createStaticNotificationTranslate('ko-KR')

    expect(t('notifications.items.todoStatusDone.v1', {
      actorName: 'Shane',
      todoTitle: '보고서 정리',
    })).toBe('Shane님이 [보고서 정리] TODO를 완료 처리했습니다.')
  })

  it('renders English notification templates with interpolation', () => {
    const t = createStaticNotificationTranslate('en-US')

    expect(t('notifications.items.scheduleTagged.v1', {
      actorName: 'Shane',
      scheduleTitle: 'Team Sync',
    })).toBe('Shane tagged you in [Team Sync].')
  })

  it('falls back to English for an unsupported locale', () => {
    const t = createStaticNotificationTranslate('ja-JP')

    expect(t('notifications.items.generic')).toBe('You have a new notification.')
    expect(t('notifications.items.missingKey')).toBe('notifications.items.missingKey')
  })
})
