import { AppWindow, Globe } from 'lucide-vue-next'
import type { RefreshTokenDto } from '@/types'

/**
 * Sessions may arrive from a backend that does not send `clientType` yet, so the
 * client type is read loosely and anything other than a known app value renders
 * as a browser session.
 */
type SessionClientSource = Pick<RefreshTokenDto, 'userAgent'> & { clientType?: string }

export function isAppSession(token: SessionClientSource): boolean {
  return token.clientType === 'IOS_APP'
}

export function sessionClientIcon(token: SessionClientSource) {
  return isAppSession(token) ? AppWindow : Globe
}

export function sessionClientLabelKey(token: SessionClientSource): string {
  return isAppSession(token) ? 'member.sessions.appLabel' : 'member.sessions.browserLabel'
}

export function sessionClientName(token: SessionClientSource, t: (key: string) => string): string {
  if (isAppSession(token)) return t('member.sessions.iosApp')
  return token.userAgent?.browser || '-'
}
