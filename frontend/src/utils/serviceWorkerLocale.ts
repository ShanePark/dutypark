import type { SupportedLocale } from '@/i18n'

const SET_LOCALE_MESSAGE_TYPE = 'DUTYPARK_SET_LOCALE'

function postLocaleMessage(target: ServiceWorker | null, locale: SupportedLocale) {
  if (!target) {
    return
  }

  target.postMessage({
    type: SET_LOCALE_MESSAGE_TYPE,
    locale,
  })
}

export async function syncServiceWorkerLocale(
  locale: SupportedLocale,
  registration?: ServiceWorkerRegistration | null,
) {
  if (typeof window === 'undefined' || !('serviceWorker' in navigator)) {
    return
  }

  const resolvedRegistration = registration
    ?? await navigator.serviceWorker.getRegistration()
    ?? await navigator.serviceWorker.ready.catch(() => null)

  if (!resolvedRegistration) {
    return
  }

  postLocaleMessage(resolvedRegistration.active, locale)
  postLocaleMessage(resolvedRegistration.waiting, locale)
  postLocaleMessage(resolvedRegistration.installing, locale)
  postLocaleMessage(navigator.serviceWorker.controller, locale)
}
