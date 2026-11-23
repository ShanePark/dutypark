import type { ScheduleChanges } from '@/types'
import type { NotificationTranslate } from './renderers/types'
import { descriptionChanges } from '@/utils/scheduleChanges'

export function displayValue(value: string, t: NotificationTranslate): string {
  const normalized = value.replace(/\s+/gu, ' ').trim()
  const characters = Array.from(normalized)
  return characters.length > 100
    ? `${characters.slice(0, 100).join('')}…`
    : normalized || t('notifications.changes.empty')
}

function timeRange(value: { startDateTime: string; endDateTime: string }, showDate: boolean, showYear: boolean): string {
  const date = (timestamp: string) => {
    const [year, month, day] = timestamp.slice(0, 10).split('-')
    return `${showYear ? `${year}/` : ''}${Number(month)}/${Number(day)}`
  }
  const start = value.startDateTime.slice(11, 16)
  const end = value.endDateTime.slice(11, 16)
  const crossesDate = value.startDateTime.slice(0, 10) !== value.endDateTime.slice(0, 10)
  return `${showDate ? `${date(value.startDateTime)} ` : ''}${start}–${showDate && crossesDate ? `${date(value.endDateTime)} ` : ''}${end}`
}

export function scheduleChangeMessage(changes: ScheduleChanges, t: NotificationTranslate): string {
  const parts: string[] = []
  const textChange = (before: string, after: string) => {
    parts.push(t('notifications.changes.inlineText', {
      before: displayValue(before, t),
      after: displayValue(after, t),
    }))
  }
  if (changes.description) {
    const portions = descriptionChanges(changes.description.before, changes.description.after)
    if (portions.length) {
      textChange(
        portions.map(change => change.before).filter(Boolean).join(' … '),
        portions.map(change => change.after).filter(Boolean).join(' … '))
    }
  }
  if (changes.time) {
    const timestamps = [changes.time.before.startDateTime, changes.time.before.endDateTime, changes.time.after.startDateTime, changes.time.after.endDateTime]
    const showDate = new Set(timestamps.map(value => value.slice(0, 10))).size > 1
    const showYear = new Set(timestamps.map(value => value.slice(0, 4))).size > 1
    parts.push(t('notifications.changes.inlineTime', {
      before: timeRange(changes.time.before, showDate, showYear),
      after: timeRange(changes.time.after, showDate, showYear),
    }))
  }
  return parts.join('\n')
}

export function koreanDirectionParticle(value: string): string {
  const finalCharacter = Array.from(value.replace(/[\p{P}\p{Z}\s]+$/gu, '')).at(-1) ?? ''
  if ('036'.includes(finalCharacter) && finalCharacter) return '으로'
  const codePoint = finalCharacter.codePointAt(0) ?? 0
  if (codePoint >= 0xac00 && codePoint <= 0xd7a3) {
    const finalConsonant = (codePoint - 0xac00) % 28
    if (finalConsonant !== 0 && finalConsonant !== 8) return '으로'
  }
  return '로'
}
