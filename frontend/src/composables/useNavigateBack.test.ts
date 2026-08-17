import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

const mocks = vi.hoisted(() => ({
  back: vi.fn(),
  replace: vi.fn(),
}))

vi.mock('vue-router', () => ({
  useRouter: () => ({
    back: mocks.back,
    replace: mocks.replace,
  }),
}))

import { useNavigateBack } from './useNavigateBack'

const originalWindow = Object.getOwnPropertyDescriptor(globalThis, 'window')

function setHistoryState(state: unknown) {
  Object.defineProperty(globalThis, 'window', {
    value: { history: { state } },
    configurable: true,
    writable: true,
  })
}

describe('useNavigateBack', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  afterEach(() => {
    if (originalWindow) {
      Object.defineProperty(globalThis, 'window', originalWindow)
    } else {
      Reflect.deleteProperty(globalThis, 'window')
    }
  })

  it('goes back when vue-router recorded an in-app history entry', () => {
    setHistoryState({ back: '/team' })

    useNavigateBack().goBack('/')

    expect(mocks.back).toHaveBeenCalledTimes(1)
    expect(mocks.replace).not.toHaveBeenCalled()
  })

  it('replaces with the fallback when there is no in-app history', () => {
    setHistoryState({ back: null })

    useNavigateBack().goBack('/')

    expect(mocks.replace).toHaveBeenCalledWith('/')
    expect(mocks.back).not.toHaveBeenCalled()
  })

  it('replaces with a section fallback so a directly entered sub-page returns to its tab', () => {
    setHistoryState({ back: null })

    useNavigateBack().goBack('/more')

    expect(mocks.replace).toHaveBeenCalledWith('/more')
    expect(mocks.back).not.toHaveBeenCalled()
  })

  it('falls back to the home route by default', () => {
    setHistoryState(null)

    useNavigateBack().goBack()

    expect(mocks.replace).toHaveBeenCalledWith('/')
    expect(mocks.back).not.toHaveBeenCalled()
  })
})
