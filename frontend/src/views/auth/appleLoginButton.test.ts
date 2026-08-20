import { describe, expect, it } from 'vitest'
import loginView from './LoginView.vue?raw'

/**
 * Apple's SDK only auto-renders `#appleid-signin` at page load, and we inject its script after
 * mount, so that slot stays empty and our own layer is what users actually see. It therefore has
 * to carry the Apple mark itself, the way the Kakao and Naver buttons carry theirs.
 */
describe('apple login button', () => {
  it('shows the Apple mark beside the label', () => {
    const label = loginView.match(/<span\s+aria-hidden="true"[\s\S]*?<\/span>/)?.[0] ?? ''

    expect(label).toContain('/img/apple.svg')
    expect(label).toContain('auth.login.social.apple')
  })

  it('ships the Apple mark asset', () => {
    const assets = import.meta.glob('/public/img/*.svg', {
      query: '?raw',
      import: 'default',
      eager: true,
    })

    expect(assets['/public/img/apple.svg']).toContain('<svg')
  })
})
