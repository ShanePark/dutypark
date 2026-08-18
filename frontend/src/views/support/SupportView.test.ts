import { describe, expect, it } from 'vitest'
import supportView from './SupportView.vue?raw'
import myInquiryList from './MyInquiryList.vue?raw'
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

/**
 * Signed-in members read answers in the app, so the page grows a second tab for them.
 * The signed-out layout is the published contact page and has to stay exactly as it was.
 */
describe('support page tabs', () => {
  it('offers the tab strip only to signed-in members', () => {
    const tablist = supportView.match(/<div\b[^>]*role="tablist"[^>]*>/)?.[0] ?? ''

    expect(tablist).toContain('v-if="isSignedIn"')
    expect(supportView).toContain('support.tabs.form')
    expect(supportView).toContain('support.tabs.history')
  })

  it('opens on the history tab when a notification deep-links into it', () => {
    expect(supportView).toContain("resolveTab(route.query.tab)")
    expect(supportView).toContain("value === 'history' ? 'history' : 'form'")
    expect(supportView).toContain('watch(() => route.query.tab')
  })

  it('never shows the history list to a signed-out visitor', () => {
    expect(supportView).toContain("isSignedIn.value && activeTab.value === 'history'")
    expect(supportView).toContain('<section v-if="showHistory"')
    expect(supportView).toContain('<MyInquiryList @go-to-form="selectTab(\'form\')" />')
  })

  it('promises an in-app answer to members and an e-mail to guests', () => {
    expect(supportView).toContain('const formDescription = computed(() => isSignedIn.value')
    expect(supportView).toContain("t('support.form.descriptionSignedIn')")
    expect(supportView).toContain("t('support.form.description')")
    expect(supportView).toContain('const successDescription = computed(() => isSignedIn.value')
    expect(supportView).toContain("t('support.success.descriptionSignedIn')")
    expect(supportView).toContain("t('support.success.description')")
    expect(supportView).toContain('support.form.guestHint')
  })
})

describe('my inquiry list', () => {
  it('reads the signed-in member own inquiries ten at a time', () => {
    expect(myInquiryList).toContain('PAGE_SIZE = 10')
    expect(myInquiryList).toContain('inquiryApi.fetchMine(page, PAGE_SIZE)')
  })

  it('labels the handling status and whether an answer arrived', () => {
    expect(myInquiryList).toContain('support.history.status.open')
    expect(myInquiryList).toContain('support.history.status.closed')
    expect(myInquiryList).toContain('support.history.answered')
    expect(myInquiryList).toContain('support.history.awaiting')
    expect(myInquiryList).toContain('support.history.noSubject')
  })

  it('expands an entry into the full message and the answer', () => {
    expect(myInquiryList).toContain('toggleExpanded(inquiry.id)')
    expect(myInquiryList).toContain('whitespace-pre-wrap break-words">{{ inquiry.content }}')
    expect(myInquiryList).toContain('whitespace-pre-wrap break-words">{{ inquiry.answer }}')
    expect(myInquiryList).toContain('support.history.answeredAt')
  })

  it('tells the member an answer is still coming when there is none', () => {
    expect(myInquiryList).toContain('support.history.awaitingDescription')
  })

  it('pages with an explicit button rather than infinite scroll', () => {
    expect(myInquiryList).toContain('support.history.loadMore')
    expect(myInquiryList).toContain('hasMorePages')
    expect(myInquiryList).not.toContain('IntersectionObserver')
  })

  it('covers the empty, loading and failed states', () => {
    expect(myInquiryList).toContain('support.history.empty')
    expect(myInquiryList).toContain("emit('goToForm')")
    expect(myInquiryList).toContain('support.history.loading')
    expect(myInquiryList).toContain('support.history.loadFailed')
    expect(myInquiryList).toContain('support.history.retry')
  })
})
