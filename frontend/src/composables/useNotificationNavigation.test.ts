import { describe, expect, it, vi } from 'vitest'
import type { NotificationDto, NotificationReferenceType } from '@/types'

const routerStub = vi.hoisted(() => ({
  push: vi.fn(),
  currentRoute: { value: { path: '/' } },
}))

vi.mock('vue-router', () => ({
  useRouter: () => routerStub,
}))

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ user: { id: 1 } }),
}))

import { useNotificationNavigation } from './useNotificationNavigation'

function notificationWith(
  referenceType: NotificationReferenceType,
  referenceId: string | null,
): NotificationDto {
  return {
    id: 'notification-id',
    type: 'INQUIRY_ANSWERED',
    referenceType,
    referenceId,
    actorId: null,
    payload: { version: 1, subject: null },
    isRead: false,
    createdAt: '2026-08-18T00:00:00',
  } as NotificationDto
}

describe('useNotificationNavigation', () => {
  it('opens the answered inquiry on the support history tab', () => {
    const { getNavigationPath } = useNotificationNavigation()

    expect(getNavigationPath(notificationWith('INQUIRY', 'a7d0f1c2-1111-2222-3333-444455556666')))
      .toBe('/support?tab=history')
  })

  it('keeps routing the existing reference types', () => {
    const { getNavigationPath } = useNotificationNavigation()

    expect(getNavigationPath(notificationWith('FRIEND_REQUEST', '1'))).toBe('/friends')
    expect(getNavigationPath(notificationWith('TODO', '1'))).toBe('/todo')
    expect(getNavigationPath(notificationWith('MEMBER', '7'))).toBe('/duty/7')
    expect(getNavigationPath(notificationWith('SCHEDULE', '1'))).toBeNull()
  })
})
