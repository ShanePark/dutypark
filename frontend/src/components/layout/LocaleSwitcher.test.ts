import { describe, expect, it } from 'vitest'
import localeSwitcher from './LocaleSwitcher.vue?raw'

const templateAt = localeSwitcher.indexOf('<template>')
const styleAt = localeSwitcher.indexOf('<style')
const script = localeSwitcher.slice(0, templateAt)
const template = localeSwitcher.slice(templateAt, styleAt)
const style = localeSwitcher.slice(styleAt)

// The switcher sits at different distances from the viewport edge in the header (logged in or
// out) and on the intro page, so a fixed CSS offset can't keep the suggestion on screen.
describe('LocaleSwitcher suggestion placement', () => {
  it('drops the fixed mobile offset that pushed the suggestion off screen', () => {
    expect(style).not.toMatch(/right:\s*-/)
  })

  it('leaves room for a 16px gutter on both sides', () => {
    expect(style).toMatch(/\.locale-suggestion \{[^}]*width: min\(18rem, calc\(100vw - 2rem\)\)/)
  })

  it('shifts the suggestion back inside the viewport gutter after it renders and on resize', () => {
    expect(script).toContain('const SUGGESTION_VIEWPORT_GUTTER = 16')
    expect(script).toMatch(/watch\(showSuggestion, keepSuggestionOnScreen, \{[^}]*flush: 'post'/)
    expect(script).toContain("window.addEventListener('resize', keepSuggestionOnScreen)\n  keepSuggestionOnScreen()")
    expect(script).toContain("window.removeEventListener('resize', keepSuggestionOnScreen)")
    expect(template).toContain('ref="suggestionRef"')
    expect(template).toContain(':style="suggestionStyle"')
  })
})
