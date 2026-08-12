import { beforeEach, describe, expect, it, vi } from 'vitest'

const mocks = vi.hoisted(() => ({
  fire: vi.fn(),
  toastFire: vi.fn(),
  translateGlobal: vi.fn((key: string) => `translated:${key}`),
}))

vi.mock('sweetalert2', () => ({
  default: {
    fire: mocks.fire,
    mixin: vi.fn(() => ({ fire: mocks.toastFire })),
  },
}))

vi.mock('@/i18n', () => ({
  translateGlobal: mocks.translateGlobal,
}))

import { useSwal } from './useSwal'

describe('useSwal', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    mocks.fire.mockResolvedValue({ isConfirmed: true })
  })

  it('keeps the shared delete label when no custom label is provided', async () => {
    const { confirmDelete } = useSwal()

    await expect(confirmDelete('Delete this item?')).resolves.toBe(true)

    expect(mocks.fire).toHaveBeenCalledWith(expect.objectContaining({
      title: 'translated:common.swal.confirmDelete',
      confirmButtonText: 'translated:common.actions.delete',
    }))
  })

  it('uses a caller-provided destructive action label', async () => {
    const { confirmDelete } = useSwal()

    await expect(confirmDelete(
      'Disconnect this account?',
      'Disconnect account',
      'Disconnect',
    )).resolves.toBe(true)

    expect(mocks.fire).toHaveBeenCalledWith(expect.objectContaining({
      title: 'Disconnect account',
      confirmButtonText: 'Disconnect',
    }))
  })

  it('returns the selected three-way choice with custom labels', async () => {
    mocks.fire.mockResolvedValue({ isDenied: true })
    const { choose } = useSwal()

    await expect(choose(
      'Disclosure',
      'Use AI?',
      'Consent and use AI',
      'Save without AI',
    )).resolves.toBe('deny')

    expect(mocks.fire).toHaveBeenCalledWith(expect.objectContaining({
      showDenyButton: true,
      confirmButtonText: 'Consent and use AI',
      denyButtonText: 'Save without AI',
    }))
  })
})
