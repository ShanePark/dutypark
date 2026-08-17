import { useRouter } from 'vue-router'
import type { RouteLocationRaw } from 'vue-router'

export function useNavigateBack() {
  const router = useRouter()

  /**
   * vue-router records the previous entry in `history.state.back` only for its own
   * navigations, so its absence means the page was entered directly (deep link, push
   * notification landing, new tab). Going back then would leave the app entirely.
   */
  function goBack(fallback: RouteLocationRaw = '/') {
    if (window.history.state?.back) {
      router.back()
      return
    }
    router.replace(fallback)
  }

  return { goBack }
}
