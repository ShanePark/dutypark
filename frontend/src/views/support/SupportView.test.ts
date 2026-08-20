import { describe, expect, it } from 'vitest'
import supportView from './SupportView.vue?raw'
import myInquiryList from './MyInquiryList.vue?raw'
import myReportList from './MyReportList.vue?raw'
import { routes } from '@/router/routes'
import {
  MY_REPORT_REASON_LABEL_KEYS,
  MY_REPORT_STATUS_DESCRIPTION_KEYS,
  MY_REPORT_STATUS_LABEL_KEYS,
  MY_REPORT_TARGET_TYPE_LABEL_KEYS,
  myReportStatusToneClass,
} from './supportHistory'

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

  it('collects an optional subject and the message', () => {
    expect(supportView).toContain('v-model="subject"')
    expect(supportView).toContain('v-model="content"')
    expect(supportView).toContain('SUBJECT_MAX_LENGTH = 100')
    expect(supportView).toContain('CONTENT_MAX_LENGTH = 2000')
  })

  /**
   * A member reads the answer in the app, so asking for a reply address is noise — and a social
   * account has no e-mail to prefill anyway. Only a guest still has to name one.
   */
  it('asks a guest for a reply address and never asks a member', () => {
    const emailField = supportView.match(/<div v-if="!isSignedIn">\s*<label for="support-email"/)?.[0] ?? ''

    expect(emailField).not.toBe('')
    expect(supportView).toContain('v-model="email"')
    expect(supportView).toContain('const isEmailValid = computed(() => isSignedIn.value || EMAIL_PATTERN.test(email.value.trim()))')
    expect(supportView).toContain('email: isSignedIn.value ? undefined : email.value.trim()')
    expect(supportView).not.toContain("authStore.user?.email")
  })

  it('submits through the inquiry api and confirms receipt', () => {
    expect(supportView).toContain('inquiryApi.create')
    expect(supportView).toContain('verifyMemberSession: isSignedIn.value')
    expect(supportView).toContain('support.success.title')
  })

  it('tells the visitor to retry later when the rate limit rejects the inquiry', () => {
    expect(supportView).toContain('=== 429')
    expect(supportView).toContain('support.form.error.rateLimit')
  })
})

/**
 * Signed-in members read answers and report outcomes in the app, so the page grows two more
 * tabs for them. The signed-out layout is the published contact page and has to stay as it was.
 */
describe('support page tabs', () => {
  it('offers the tab strip only to signed-in members', () => {
    const tablist = supportView.match(/<div\b[^>]*role="tablist"[^>]*>/s)?.[0] ?? ''

    expect(tablist).toContain('v-if="isSignedIn"')
    expect(supportView).toContain('support.tabs.form')
    expect(supportView).toContain('support.tabs.history')
    expect(supportView).toContain('support.tabs.reports')
  })

  /** #374151 is both the dark tab track and the dark strong surface, so the selected tab is tinted. */
  it('marks the selected tab with the accent tint so dark mode can show it', () => {
    expect(supportView).toContain("'bg-dp-accent-soft text-dp-accent font-bold shadow-sm ring-1 ring-dp-accent-border'")
    expect(supportView).toContain(':aria-selected="activeTab === tab.value"')
  })

  it('opens on the tab a notification deep-links into', () => {
    expect(supportView).toContain('resolveTab(route.query.tab)')
    expect(supportView).toContain("if (value === 'history') return 'history'")
    expect(supportView).toContain("if (value === 'reports') return 'reports'")
    expect(supportView).toContain('watch(() => route.query.tab')
  })

  it('never shows a history list to a signed-out visitor', () => {
    expect(supportView).toContain("const activeSection = computed<SupportTab>(() => (isSignedIn.value ? activeTab.value : 'form'))")
    expect(supportView).toContain('<MyInquiryList v-if="activeSection === \'history\'" @go-to-form="selectTab(\'form\')" />')
    expect(supportView).toContain('<MyReportList v-else-if="activeSection === \'reports\'" />')
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

  it('leads with whether an answer arrived rather than the internal status', () => {
    expect(myInquiryList).toContain('support.history.answered')
    expect(myInquiryList).toContain('support.history.awaiting')
    expect(myInquiryList).toContain('support.history.status.closed')
    expect(myInquiryList).toContain('support.history.noSubject')
    expect(myInquiryList).toContain('support.history.countSummary')
  })

  it('expands an entry into the full message and the answer', () => {
    expect(myInquiryList).toContain('toggleExpanded(inquiry.id)')
    expect(myInquiryList).toContain(':aria-expanded="expandedId === inquiry.id"')
    expect(myInquiryList).toContain('whitespace-pre-wrap break-words text-dp-text-primary">{{ inquiry.content }}')
    expect(myInquiryList).toContain('whitespace-pre-wrap break-words text-dp-text-primary">{{ inquiry.answer }}')
    expect(myInquiryList).toContain('support.history.answeredAt')
  })

  it('tells the member an answer is still coming and how it will arrive', () => {
    expect(myInquiryList).toContain('support.history.awaitingDescription')
    expect(myInquiryList).toContain('support.history.answeredNotice')
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

/**
 * A reporter never hears back today, so the third tab is the only place the outcome shows up.
 * It must stay the reporter's own view: the admin memo and the moderator are internal.
 */
describe('my report list', () => {
  it('reads the signed-in member own reports ten at a time', () => {
    expect(myReportList).toContain('PAGE_SIZE = 10')
    expect(myReportList).toContain('reportApi.fetchMine(page, PAGE_SIZE)')
  })

  it('shows every handling state with its own tone', () => {
    expect(MY_REPORT_STATUS_LABEL_KEYS).toEqual({
      OPEN: 'support.reports.status.open',
      RESOLVED: 'support.reports.status.resolved',
      DISMISSED: 'support.reports.status.dismissed',
      CANCELED: 'support.reports.status.canceled',
    })
    expect(myReportStatusToneClass('OPEN')).toContain('warning')
    expect(myReportStatusToneClass('RESOLVED')).toContain('success')
    expect(myReportStatusToneClass('DISMISSED')).not.toContain('danger')
    expect(myReportStatusToneClass('CANCELED')).toBe(myReportStatusToneClass('DISMISSED'))
    expect(myReportList).toContain('myReportStatusToneClass(report.status)')
  })

  it('explains what each state means and what stays private', () => {
    expect(MY_REPORT_STATUS_DESCRIPTION_KEYS.OPEN).toBe('support.reports.statusDescription.open')
    expect(myReportList).toContain('MY_REPORT_STATUS_DESCRIPTION_KEYS[report.status]')
    expect(myReportList).toContain('support.reports.privacyNotice')
  })

  it('reuses the report reason wording the member already saw when reporting', () => {
    expect(MY_REPORT_REASON_LABEL_KEYS.SPAM).toBe('report.reasons.spam')
    expect(MY_REPORT_REASON_LABEL_KEYS.OTHER).toBe('report.reasons.other')
    expect(MY_REPORT_TARGET_TYPE_LABEL_KEYS.MEMBER).toBe('support.reports.targetType.member')
  })

  it('never leaks the moderation internals to the reporter', () => {
    for (const internal of ['adminMemo', 'resolvedBy', 'contentSnapshot', 'snapshotPreview', 'targetId']) {
      expect(myReportList, internal).not.toContain(internal)
    }
  })

  it('shows who was reported, why, and when it was handled', () => {
    expect(myReportList).toContain('report.reportedMemberName')
    expect(myReportList).toContain('support.reports.reportedAt')
    expect(myReportList).toContain('support.reports.handledAt')
    expect(myReportList).toContain('formatDate(report.resolvedAt)')
  })

  it('covers the empty, loading and failed states', () => {
    expect(myReportList).toContain('support.reports.empty')
    expect(myReportList).toContain('support.reports.emptyDescription')
    expect(myReportList).toContain('support.reports.loading')
    expect(myReportList).toContain('support.reports.loadFailed')
    expect(myReportList).toContain('support.reports.retry')
    expect(myReportList).toContain('support.reports.loadMore')
  })
})

/**
 * Withdrawing is not a delete: the row stays as evidence with a muted badge, and the block the
 * member may have set alongside the report is untouched.
 */
describe('withdrawing my own report', () => {
  it('offers the withdrawal only on a report still waiting for review', () => {
    expect(myReportList).toContain('v-if="report.status === \'OPEN\'"')
    expect(myReportList).toContain('support.reports.cancel.action')
    expect(myReportList).toContain('min-h-11')
  })

  it('asks for confirmation before withdrawing', () => {
    expect(myReportList).toContain('useSwal')
    expect(myReportList).toContain("t('support.reports.cancel.confirmMessage')")
    expect(myReportList).toContain("t('support.reports.cancel.confirmTitle')")
    expect(myReportList).toContain('if (!confirmed) return')
  })

  it('marks only the row being withdrawn as pending', () => {
    expect(myReportList).toContain('cancelingId')
    expect(myReportList).toContain(':disabled="cancelingId === report.id"')
    expect(myReportList).toContain('support.reports.cancel.pending')
  })

  it('swaps the withdrawn row in place instead of reloading the list', () => {
    expect(myReportList).toContain('reportApi.cancelMine(report.id)')
    expect(myReportList).toContain('reports.value = reports.value.map((item) => (item.id === updated.id ? updated : item))')
    expect(myReportList).not.toContain('await loadReports(currentPage.value)')
  })

  it('reports a failed withdrawal inline without emptying the list', () => {
    expect(myReportList).toContain('role="alert"')
    expect(myReportList).toContain("fallbackKey: 'support.reports.cancel.failed'")
    expect(myReportList).toContain('cancelErrorId === report.id')
  })

  it('dates a withdrawn report as withdrawn rather than handled', () => {
    expect(myReportList).toContain('support.reports.canceledAt')
    expect(myReportList).toContain('support.reports.handledAt')
  })
})
