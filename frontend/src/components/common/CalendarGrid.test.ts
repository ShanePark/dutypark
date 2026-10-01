import { describe, expect, it, vi } from 'vitest'
import { h, nextTick } from 'vue'
import { createHostWrapper, findHostNodes, hostText, mountHost } from '@/test/hostRenderer'
import type { HolidayDto } from '@/types'

vi.mock('vue-i18n', () => ({ useI18n: () => ({ locale: { value: 'ko' } }) }))
const { default: CalendarGrid } = await import('./CalendarGrid.vue')

describe('CalendarGrid duty palette readability', () => {
  it.each([
    { color: '#F6D365', sunday: '#991B1B', saturday: '#1E40AF' },
    { color: '#123456', sunday: 'var(--dp-sunday)', saturday: 'var(--dp-saturday)' },
    { color: null, sunday: 'var(--dp-sunday)', saturday: 'var(--dp-saturday)' },
  ])('renders weekday dates and holidays for $color', async ({ color, sunday, saturday }) => {
    const days = Array.from({ length: 7 }, (_, index) => ({ year: 2026, month: 9, day: index + 20, isCurrentMonth: true }))
    const mounted = mountHost(createHostWrapper(() => h(CalendarGrid, {
      days, currentYear: 2026, currentMonth: 9, getDutyColor: () => color,
      holidays: [[{ localDate: '2026-09-20', dateName: '공휴일', isHoliday: true } as HolidayDto]],
    })))
    await nextTick()
    const spans = findHostNodes(mounted.root, node => node.type === 'span')
    expect(spans.find(node => hostText(node) === '20')?.props.style).toMatchObject({ color: sunday })
    expect(spans.find(node => hostText(node) === '26')?.props.style).toMatchObject({ color: saturday })
    const holiday = findHostNodes(mounted.root, node => node.type === 'div' && node.props.title === '공휴일')[0]
    expect(holiday?.props.style).toMatchObject({ color: sunday })
    const headers = findHostNodes(mounted.root, node => node.type === 'div' && String(node.props.class).includes('py-2 text-center'))
    expect(headers[0]?.props.style).toMatchObject({ color: 'var(--dp-sunday)' })
    expect(headers[6]?.props.style).toMatchObject({ color: 'var(--dp-saturday)' })
  })
})
