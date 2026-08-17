import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { useSwal } from '@/composables/useSwal'

export function useLogout() {
  const router = useRouter()
  const authStore = useAuthStore()
  const { t } = useI18n()
  const { confirm, showWarning } = useSwal()

  async function logoutAndRedirect() {
    const serverSessionCleared = await authStore.logout()
    await router.push('/auth/login')
    if (!serverSessionCleared) {
      await showWarning(
        t('sessionRecovery.logoutUnconfirmed'),
        t('sessionRecovery.logoutUnconfirmedTitle')
      )
    }
    window.location.replace('/auth/login')
  }

  async function confirmAndLogout() {
    const confirmed = await confirm(
      t('member.logoutDialog.message'),
      t('member.logoutDialog.title')
    )
    if (!confirmed) {
      return
    }
    await logoutAndRedirect()
  }

  return { logoutAndRedirect, confirmAndLogout }
}
