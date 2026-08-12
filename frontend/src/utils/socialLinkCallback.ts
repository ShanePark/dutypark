export type SocialLinkProvider = 'kakao' | 'naver'

export type SocialLinkCallbackResult =
  | { type: 'success'; provider: SocialLinkProvider }
  | { type: 'alreadyLinked'; provider: SocialLinkProvider }

type Query = Record<string, unknown>
type SocialLinkMember = {
  kakaoId?: string | null
  naverId?: string | null
}

type SocialLinkStorage = Pick<Storage, 'getItem' | 'setItem' | 'removeItem'>

const callbackQueryKeys = ['socialLinkSuccess', 'socialLinkError', 'socialProvider'] as const
const pendingSocialLinkProviderKey = 'dutypark.pendingSocialLinkProvider'

function getSessionStorage(): SocialLinkStorage | null {
  try {
    return typeof window === 'undefined' ? null : window.sessionStorage
  } catch {
    return null
  }
}

function getFirstString(value: unknown): string | null {
  if (Array.isArray(value)) {
    return typeof value[0] === 'string' ? value[0] : null
  }
  return typeof value === 'string' ? value : null
}

function getProvider(value: unknown): SocialLinkProvider | null {
  const provider = getFirstString(value)
  return provider === 'kakao' || provider === 'naver' ? provider : null
}

export function storePendingSocialLinkProvider(
  provider: SocialLinkProvider,
  storage: SocialLinkStorage | null = getSessionStorage(),
): void {
  try {
    storage?.setItem(pendingSocialLinkProviderKey, provider)
  } catch {
    // Storage may be unavailable in private browsing or restricted webviews.
  }
}

export function clearPendingSocialLinkProvider(
  storage: SocialLinkStorage | null = getSessionStorage(),
): void {
  try {
    storage?.removeItem(pendingSocialLinkProviderKey)
  } catch {
    // Linking itself must keep working when storage is unavailable.
  }
}

export function consumeConnectedPendingSocialLinkProvider(
  member: SocialLinkMember,
  storage: SocialLinkStorage | null = getSessionStorage(),
): SocialLinkProvider | null {
  let provider: SocialLinkProvider | null = null

  try {
    provider = getProvider(storage?.getItem(pendingSocialLinkProviderKey))
    storage?.removeItem(pendingSocialLinkProviderKey)
  } catch {
    return null
  }

  if (provider === 'kakao' && member.kakaoId) return provider
  if (provider === 'naver' && member.naverId) return provider
  return null
}

export async function consumeSocialLinkCallback<TQuery extends Query>(
  query: TQuery,
  replaceQuery: (query: TQuery) => Promise<unknown>,
): Promise<SocialLinkCallbackResult | null> {
  if (!callbackQueryKeys.some((key) => key in query)) return null

  const nextQuery = { ...query }
  callbackQueryKeys.forEach((key) => delete nextQuery[key])

  const provider = getProvider(query.socialProvider)
  const success = getFirstString(query.socialLinkSuccess) === 'true'
  const error = getFirstString(query.socialLinkError)

  await replaceQuery(nextQuery)

  if (!provider) return null
  if (success) return { type: 'success', provider }
  if (error === 'already_linked') return { type: 'alreadyLinked', provider }
  return null
}
