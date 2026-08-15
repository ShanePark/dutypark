import { describe, expect, it } from 'vitest'

import { formatPublicContentLabel } from './publicContentLabel'

describe('formatPublicContentLabel', () => {
  it('replaces a count placeholder', () => {
    expect(formatPublicContentLabel('{count} items', { count: 12 })).toBe('12 items')
  })

  it('replaces a pull request number placeholder', () => {
    expect(formatPublicContentLabel('PR #{number}', { number: 345 })).toBe('PR #345')
  })

  it('preserves unknown placeholders', () => {
    expect(formatPublicContentLabel('{known} and {unknown}', { known: 'resolved' })).toBe(
      'resolved and {unknown}',
    )
  })
})
