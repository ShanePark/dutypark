import { describe, expect, it } from 'vitest'
import supportView from './SupportView.vue?raw'
import { routes } from '@/router/routes'

/**
 * The support page is the contact address published to the App Store, so it has to stay
 * reachable without a session and keep both halves App Review asks for: the explanation of
 * reporting and blocking, and a working inquiry form.
 */

describe('support page', () => {
  it('is reachable without signing in', () => {
    const support = routes.find((route) => route.path === '/support')

    expect(support?.name).toBe('support')
    expect(support?.meta?.requiresAuth).toBe(false)
  })

  it('returns to the more tab when opened directly', () => {
    const header = supportView.match(/<PageHeader\b[^>]*>/)?.[0] ?? ''

    expect(header).toContain('show-back')
    expect(header).toContain('back-fallback="/more"')
  })

  it('explains reporting, blocking, the handling standard and appeals', () => {
    for (const marker of [
      'support.guide.reportDescription',
      'support.guide.blockDescription',
      'support.guide.handlingDescription',
      'support.guide.appealDescription',
    ]) {
      expect(supportView, marker).toContain(marker)
    }
  })

  it('links to the terms of service', () => {
    expect(supportView).toContain('to="/terms"')
    expect(supportView).toContain('support.guide.termsLink')
  })

  it('collects a reply address, an optional subject and the message', () => {
    expect(supportView).toContain('v-model="email"')
    expect(supportView).toContain('v-model="subject"')
    expect(supportView).toContain('v-model="content"')
    expect(supportView).toContain('SUBJECT_MAX_LENGTH = 100')
    expect(supportView).toContain('CONTENT_MAX_LENGTH = 2000')
  })

  it('prefills the reply address from the signed-in account without locking it', () => {
    expect(supportView).toContain("authStore.user?.email ?? ''")
    expect(supportView).not.toContain('readonly')
  })

  it('submits through the inquiry api and confirms receipt', () => {
    expect(supportView).toContain('inquiryApi.create')
    expect(supportView).toContain('support.success.title')
  })

  it('tells the visitor to retry later when the rate limit rejects the inquiry', () => {
    expect(supportView).toContain('=== 429')
    expect(supportView).toContain('support.form.error.rateLimit')
  })
})
