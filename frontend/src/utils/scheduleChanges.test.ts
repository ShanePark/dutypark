import { describe, expect, it } from 'vitest'
import { descriptionChanges } from './scheduleChanges'

describe('schedule description changes', () => {
  it('shows the changed passage without repeating the shared beginning and end', () => {
    expect(descriptionChanges('회의 장소는 서울입니다.', '회의 장소는 부산입니다.')).toEqual([{ before: '서울', after: '부산' }])
  })
  it('omits unchanged text between separate edits', () => {
    expect(descriptionChanges('서울에서 회의 후 점심', '부산에서 회의 후 저녁')).toEqual([{ before: '서울', after: '부산' }, { before: '점심', after: '저녁' }])
  })
  it('handles long rewrites with a shared character using bounded comparison', () => {
    const before = `공통${'가'.repeat(32000)}`
    const after = `공통${'나'.repeat(32000)}`
    expect(descriptionChanges(before, after)).toEqual([{ before: '가'.repeat(32000), after: '나'.repeat(32000) }])
  })
  it('preserves emoji and additions or removals', () => {
    expect(descriptionChanges('회의', '회의 👋')).toEqual([{ before: '', after: ' 👋' }])
    expect(descriptionChanges('👋회의', '회의')).toEqual([{ before: '👋', after: '' }])
  })
})
