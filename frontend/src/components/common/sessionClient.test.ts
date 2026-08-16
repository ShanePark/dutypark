import { describe, expect, it } from 'vitest'
import { AppWindow, Globe } from 'lucide-vue-next'
import en from '@/i18n/messages/en'
import ko from '@/i18n/messages/ko'
import {
  isAppSession,
  sessionClientIcon,
  sessionClientLabelKey,
  sessionClientName,
} from './sessionClient'

const t = (key: string) => key

const browserSession = {
  userAgent: { os: 'Mac OS X', browser: 'Chrome', device: 'Other' },
  clientType: 'BROWSER',
}

const appSession = {
  userAgent: { os: 'iOS', browser: 'Dutypark', device: 'iPhone' },
  clientType: 'IOS_APP',
}

describe('session client presentation', () => {
  it('renders browser sessions with the browser name, icon and label', () => {
    expect(isAppSession(browserSession)).toBe(false)
    expect(sessionClientIcon(browserSession)).toBe(Globe)
    expect(sessionClientLabelKey(browserSession)).toBe('member.sessions.browserLabel')
    expect(sessionClientName(browserSession, t)).toBe('Chrome')
  })

  it('renders iOS app sessions with the app label instead of a browser name', () => {
    expect(isAppSession(appSession)).toBe(true)
    expect(sessionClientIcon(appSession)).toBe(AppWindow)
    expect(sessionClientLabelKey(appSession)).toBe('member.sessions.appLabel')
    expect(sessionClientName(appSession, t)).toBe('member.sessions.iosApp')
  })

  it('falls back to browser rendering when the client type is missing or unknown', () => {
    const legacySession = { userAgent: browserSession.userAgent }
    const unknownSession = { userAgent: browserSession.userAgent, clientType: 'ANDROID_APP' }

    expect(isAppSession(legacySession)).toBe(false)
    expect(sessionClientIcon(legacySession)).toBe(Globe)
    expect(sessionClientName(legacySession, t)).toBe('Chrome')

    expect(isAppSession(unknownSession)).toBe(false)
    expect(sessionClientIcon(unknownSession)).toBe(Globe)
    expect(sessionClientName(unknownSession, t)).toBe('Chrome')
  })

  it('keeps the placeholder for browser sessions without user agent details', () => {
    expect(sessionClientName({ userAgent: null, clientType: 'BROWSER' }, t)).toBe('-')
  })

  it.each([ko, en])('translates the app client labels', (messages) => {
    expect(messages.member.sessions.appLabel).toBeTruthy()
    expect(messages.member.sessions.iosApp).toBeTruthy()
  })
})
