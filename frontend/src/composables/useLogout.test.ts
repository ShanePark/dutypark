import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const mocks = vi.hoisted(() => ({
  push: vi.fn(),
  logout: vi.fn(),
  confirm: vi.fn(),
  showWarning: vi.fn(),
  replace: vi.fn(),
}))

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mocks.push }),
}))

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: (key: string) => key }),
}))

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ logout: mocks.logout }),
}))

vi.mock('@/composables/useSwal', () => ({
  useSwal: () => ({ confirm: mocks.confirm, showWarning: mocks.showWarning }),
}))

import { useLogout } from './useLogout'

const originalWindow = Object.getOwnPropertyDescriptor(globalThis, 'window')

describe('useLogout', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mocks.logout.mockResolvedValue(true)
    Object.defineProperty(globalThis, 'window', {
      value: { location: { replace: mocks.replace } },
      configurable: true,
      writable: true,
    })
  })

  afterEach(() => {
    if (originalWindow) {
      Object.defineProperty(globalThis, 'window', originalWindow)
    } else {
      Reflect.deleteProperty(globalThis, 'window')
    }
  })

  it('does nothing when the confirmation is dismissed', async () => {
    mocks.confirm.mockResolvedValue(false)

    await useLogout().confirmAndLogout()

    expect(mocks.logout).not.toHaveBeenCalled()
    expect(mocks.push).not.toHaveBeenCalled()
    expect(mocks.replace).not.toHaveBeenCalled()
  })

  it('logs out and redirects to the login page once confirmed', async () => {
    mocks.confirm.mockResolvedValue(true)

    await useLogout().confirmAndLogout()

    expect(mocks.logout).toHaveBeenCalledTimes(1)
    expect(mocks.push).toHaveBeenCalledWith('/auth/login')
    expect(mocks.showWarning).not.toHaveBeenCalled()
    expect(mocks.replace).toHaveBeenCalledWith('/auth/login')
  })

  it('warns when the server session could not be confirmed as cleared', async () => {
    mocks.confirm.mockResolvedValue(true)
    mocks.logout.mockResolvedValue(false)

    await useLogout().confirmAndLogout()

    expect(mocks.showWarning).toHaveBeenCalledWith(
      'sessionRecovery.logoutUnconfirmed',
      'sessionRecovery.logoutUnconfirmedTitle'
    )
    expect(mocks.replace).toHaveBeenCalledWith('/auth/login')
  })

  it('skips the confirmation when logging out directly', async () => {
    await useLogout().logoutAndRedirect()

    expect(mocks.confirm).not.toHaveBeenCalled()
    expect(mocks.logout).toHaveBeenCalledTimes(1)
    expect(mocks.replace).toHaveBeenCalledWith('/auth/login')
  })
})
