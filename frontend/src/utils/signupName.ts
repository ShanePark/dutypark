export const MEMBER_NAME_MAX_LENGTH = 10

export interface AppleUserName {
  firstName?: string | null
  lastName?: string | null
}

const EAST_ASIAN_NAME_PATTERN = /[\p{Script=Hangul}\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]/u

export function generateDefaultSignupName(prefix: string, random: () => number = Math.random): string {
  const digits = Math.min(9999, Math.floor(random() * 10000)).toString().padStart(4, '0')
  return `${prefix}${digits}`
}

// Length follows the same UTF-16 `.length` rule as the 10-character counter, without
// splitting a surrogate pair.
function truncateName(name: string): string {
  let result = ''
  for (const char of name) {
    if (result.length + char.length > MEMBER_NAME_MAX_LENGTH) break
    result += char
  }
  return result.trim()
}

/** Builds a member name from the Apple name parts, or '' when none were shared. */
export function formatAppleDisplayName(name: AppleUserName | null | undefined): string {
  const firstName = name?.firstName?.trim() ?? ''
  const lastName = name?.lastName?.trim() ?? ''
  const fullName = EAST_ASIAN_NAME_PATTERN.test(firstName + lastName)
    ? `${lastName}${firstName}`
    : [firstName, lastName].filter(Boolean).join(' ')

  if (fullName.length <= MEMBER_NAME_MAX_LENGTH) return fullName
  return truncateName(firstName || fullName)
}

/** History-state key carrying a provider-supplied name to the social signup form. */
export const SSO_SIGNUP_NAME_STATE_KEY = 'ssoSignupName'

export function buildSsoSignupNameState(name: string): Record<string, string> | undefined {
  const trimmed = name.trim()
  return trimmed ? { [SSO_SIGNUP_NAME_STATE_KEY]: trimmed } : undefined
}

export function readSsoSignupNameState(state: unknown): string {
  if (!state || typeof state !== 'object') return ''
  const value = (state as Record<string, unknown>)[SSO_SIGNUP_NAME_STATE_KEY]
  return typeof value === 'string' ? truncateName(value.trim()) : ''
}
