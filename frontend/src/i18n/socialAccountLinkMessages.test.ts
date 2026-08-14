import { describe, expect, it } from 'vitest'
import en from './messages/en'
import ko from './messages/ko'

describe('social account link translations', () => {
  it.each([
    ['ko', ko],
    ['en', en],
  ])('defines provider-aware success copy in %s', (_locale, messages) => {
    expect(messages.member.sso.linkSuccess).toContain('{provider}')
  })
})
