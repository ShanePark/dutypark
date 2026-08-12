import { describe, expect, it } from 'vitest'
import en from './messages/en'
import es from './messages/es'
import ja from './messages/ja'
import ko from './messages/ko'
import zh from './messages/zh'

describe('social account link translations', () => {
  it.each([
    ['ko', ko],
    ['en', en],
    ['ja', ja],
    ['zh', zh],
    ['es', es],
  ])('defines provider-aware success copy in %s', (_locale, messages) => {
    expect(messages.member.sso.linkSuccess).toContain('{provider}')
  })
})
