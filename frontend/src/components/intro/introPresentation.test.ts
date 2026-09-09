import { strict as assert } from 'node:assert'
import { readFileSync } from 'node:fs'
import { describe, it } from 'vitest'

const showcase = readFileSync(new URL('./IntroShowcase.vue', import.meta.url), 'utf8')
const section = readFileSync(new URL('./IntroSection.vue', import.meta.url), 'utf8')
const cta = readFileSync(new URL('./IntroCTA.vue', import.meta.url), 'utf8')
const styles = readFileSync(new URL('../../styles/intro.css', import.meta.url), 'utf8')
const template = showcase.slice(showcase.indexOf('<template>'), showcase.indexOf('<style'))

function ruleFor(source: string, selector: string) {
  const start = source.indexOf(`${selector} {`)
  assert.notEqual(start, -1, `Missing rule for ${selector}`)
  return source.slice(start, source.indexOf('}', start))
}

describe('landing presentation', () => {
  it('keeps one phone frame outside the animated text loop', () => {
    assert.match(template, /class="intro-showcase-text-stack"/)
    assert.match(template, /class="intro-mockup-frame">\s*<div\s+v-for=/)
    assert.equal(template.match(/class="intro-mockup-frame"/g)?.length, 1)
    assert.doesNotMatch(template, /mockupOpacity/)
    assert.doesNotMatch(ruleFor(showcase, '.intro-showcase-mockup'), /transform|opacity/)
  })

  it('reserves complete translated text before typing so wrapping cannot move the phone', () => {
    assert.match(template, /\{\{ feature\.title \}\}/)
    assert.match(template, /class="description-line-size" aria-hidden="true"/)
    assert.match(ruleFor(showcase, '.intro-showcase-text'), /grid-area: 1 \/ 1/)
    assert.match(ruleFor(showcase, '.description-line-size'), /visibility: hidden/)
  })

  it('uses the natural sticky entrance with a stable mobile viewport', () => {
    assert.match(ruleFor(showcase, '.intro-showcase-viewport'), /position: sticky/)
    assert.match(ruleFor(showcase, '.intro-showcase-viewport'), /height: 100svh/)
    assert.match(ruleFor(section, '.intro-container'), /height: 100svh/)
  })

  it('exposes the existing persisted locale switcher without scrolling it away', () => {
    assert.match(section, /import LocaleSwitcher from '@\/components\/layout\/LocaleSwitcher.vue'/)
    assert.match(section, /<LocaleSwitcher \/>/)
    assert.match(ruleFor(section, '.intro-locale-control'), /position: absolute/)
    assert.match(ruleFor(section, '.intro-locale-control :deep(.locale-suggestion)'), /right: 0/)
  })

  it('animates both CTA links as a group and keeps their destinations', () => {
    assert.match(cta, /class="intro-cta-actions" :style="buttonStyle"/)
    assert.equal(cta.match(/:style="buttonStyle"/g)?.length, 1)
    assert.doesNotMatch(cta, /guideLinkStyle/)
    assert.match(cta, /to="\/auth\/login"/)
    assert.match(cta, /to="\/guide"/)
  })

  it('gives both actions equal tracks, height, spacing and visible keyboard focus', () => {
    assert.match(ruleFor(styles, '.intro-cta-actions'), /display: grid/)
    assert.match(ruleFor(styles, '.intro-cta-actions'), /gap: 1rem/)
    assert.match(styles, /grid-template-columns: repeat\(2, minmax\(0, 1fr\)\)/)
    assert.match(styles, /\.intro-cta-button,\s*\.intro-guide-link \{[^}]*min-height: 3\.5rem/s)
    assert.doesNotMatch(ruleFor(styles, '.intro-guide-link'), /margin-top/)
    assert.match(styles, /\.intro-guide-link:focus-visible/)
  })
})
