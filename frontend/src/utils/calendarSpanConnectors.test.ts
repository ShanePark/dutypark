import { describe, expect, it } from 'vitest'
import { buildCalendarSpanConnectors, type CalendarSpanAnchor } from './calendarSpanConnectors'
function anchor(day: number, key = 'schedule', y = 50): CalendarSpanAnchor {
  return { day, key, part: day + 1, left: day * 102, right: day * 102 + 100, y, color: '#123456', paddingLeft: 16, paddingRight: 16, thickness: 3 }
}
describe('calendar span connectors', () => {
  it('joins unequal baselines with horizontal tangents inside both tiles', () => {
    const [join] = buildCalendarSpanConnectors([anchor(0), anchor(1, 'schedule', 68)])
    expect(join).toMatchObject({ from: 0, to: 1, inset: 12 })
    expect(join?.path).toBe('M 88 50 C 101 50 101 68 114 68')
  })
  it.each([
    { padding: 3, thickness: 2.5, expected: 1.75 },
    { padding: 8, thickness: 3, expected: 6.5 },
  ])('keeps curves inside the empty cell edge strip ($padding px padding)', ({ padding, thickness, expected }) => {
    const left = { ...anchor(0), paddingLeft: padding, paddingRight: padding, thickness }
    const right = { ...anchor(1, 'schedule', 90), paddingLeft: padding, paddingRight: padding, thickness }
    expect(buildCalendarSpanConnectors([left, right])[0]?.inset).toBe(expected)
  })
  it('uses the smaller safe strip when adjacent cell padding differs', () => {
    const left = { ...anchor(0), paddingLeft: 8, paddingRight: 8, thickness: 3 }
    const right = { ...anchor(1), paddingLeft: 3, paddingRight: 8, thickness: 2.5 }
    expect(buildCalendarSpanConnectors([left, right])[0]?.inset).toBe(1.75)
  })
  it('keeps equal baselines straight', () => {
    expect(buildCalendarSpanConnectors([anchor(0), anchor(1)])[0]?.path).toBe('M 88 50 L 114 50')
  })
  it('does not connect week wraps, gaps, different schedules, or nonconsecutive parts', () => {
    expect(buildCalendarSpanConnectors([anchor(6), anchor(7)])).toEqual([])
    expect(buildCalendarSpanConnectors([anchor(0), anchor(2)])).toEqual([])
    expect(buildCalendarSpanConnectors([anchor(0), anchor(1, 'other-owner')])).toEqual([])
    expect(buildCalendarSpanConnectors([anchor(0), { ...anchor(1), part: 3 }])).toEqual([])
  })
  it('tracks overlapping schedules independently and preserves each endpoint color', () => {
    const joins = buildCalendarSpanConnectors([anchor(0), anchor(0, 'other', 80), { ...anchor(1), color: '#ffffff' }, anchor(1, 'other', 100)])
    expect(joins.map(join => [join.from, join.to])).toEqual([[0, 2], [1, 3]])
    expect(joins[0]).toMatchObject({ startColor: '#123456', endColor: '#ffffff' })
  })
})

import { buildCalendarSpanPaths } from './calendarSpanConnectors'
describe('continuous calendar span paths', () => {
  it('insets real rounded endpoints and clips continuation cuts flush without overlapping paint', () => {
    const rounded = buildCalendarSpanPaths([{ ...anchor(0), barLeft: 8, barRight: 92, starts: true, ends: true }])[0]!
    expect(rounded.path).toBe('M 9.5 50 L 90.5 50')
    expect(rounded).toMatchObject({ clipLeft: 8, clipRight: 92 })
    const cut = buildCalendarSpanPaths([{ ...anchor(6), barLeft: 612, barRight: 712 }])[0]!
    expect(cut.path).toBe('M 612 50 L 712 50')
    expect(cut).toMatchObject({ clipLeft: 612, clipRight: 712 })
  })

  it('draws a fractional same-height three-day underline as one uninterrupted path', () => {
    const anchors = [0, 1, 2].map(day => ({ ...anchor(day, 'schedule', 50.375), barLeft: day * 102 + 8, barRight: day * 102 + 92 }))
    const paths = buildCalendarSpanPaths(anchors)
    expect(paths).toHaveLength(1)
    expect(paths[0]?.path.match(/M /g)).toHaveLength(1)
    expect(paths[0]?.path).toBe('M 8 50.375 L 88 50.375 L 114 50.375 L 190 50.375 L 216 50.375 L 296 50.375')
  })
  it('keeps curved runs continuous, color transitions inside safe connectors, and week wraps separate', () => {
    const anchors = [
      { ...anchor(5), barLeft: 518, barRight: 602 },
      { ...anchor(6, 'schedule', 80), barLeft: 620, barRight: 704, color: '#ffffff' },
      { ...anchor(7, 'schedule', 80), barLeft: 722, barRight: 806 },
    ]
    const paths = buildCalendarSpanPaths(anchors)
    expect(paths).toHaveLength(2)
    expect(paths[0]?.path).toContain('C 611 50 611 80 624 80')
    expect(paths[0]?.stops.map(stop => stop.color)).toEqual(['#123456', '#123456', '#ffffff', '#ffffff'])
  })
})
