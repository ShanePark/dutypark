import { describe, expect, it } from 'vitest'
import { syncCalendarScheduleTextFlow } from './calendarScheduleTextFlow'

function titleFixture(scrollHeight: number, clientHeight: number, hasTime = true) {
  const classes = new Set<string>()
  const title = {
    scrollHeight,
    clientHeight,
    nextElementSibling: hasTime ? { classList: { contains: (name: string) => name === 'calendar-item__time' } } : null,
    classList: {
      remove: (name: string) => { classes.delete(name) },
      toggle: (name: string, force: boolean) => {
        if (force) classes.add(name)
        else classes.delete(name)
      },
    },
  }
  return { title, classes }
}

function syncTitles(...titles: ReturnType<typeof titleFixture>[]) {
  syncCalendarScheduleTextFlow({ querySelectorAll: () => titles.map(({ title }) => title) } as unknown as HTMLElement)
}

describe('calendar schedule text flow', () => {
  it('allows one- and two-line titles to share their final line with the clock', () => {
    const short = titleFixture(13, 13)
    const wrapped = titleFixture(26, 26)
    syncTitles(short, wrapped)
    expect(short.classes.has('calendar-item__text--flow')).toBe(true)
    expect(wrapped.classes.has('calendar-item__text--flow')).toBe(true)
  })

  it('keeps overflowing titles clamped and waits for hidden cells to acquire a size', () => {
    const long = titleFixture(52, 26)
    const hidden = titleFixture(0, 0)
    syncTitles(long, hidden)
    expect(long.classes.size).toBe(0)
    expect(hidden.classes.size).toBe(0)
  })

  it('leaves untimed schedule titles in their existing clamped form', () => {
    const fixture = titleFixture(13, 13)
    syncTitles(fixture)
    expect(fixture.classes.size).toBe(1)
    fixture.title.nextElementSibling = null
    syncTitles(fixture)
    expect(fixture.classes.size).toBe(0)
  })

  it('remeasures flowing titles in their clamped form after their width or content changes', () => {
    const fixture = titleFixture(26, 26)
    syncTitles(fixture)
    Object.defineProperty(fixture.title, 'scrollHeight', {
      get: () => {
        expect(fixture.classes.has('calendar-item__text--flow')).toBe(false)
        return 52
      },
    })
    syncTitles(fixture)
    expect(fixture.classes.size).toBe(0)
  })
})
