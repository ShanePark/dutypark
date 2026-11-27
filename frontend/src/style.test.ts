/// <reference types="node" />

import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'

const styles = readFileSync(resolve(process.cwd(), 'src/style.css'), 'utf8')

describe('SweetAlert2 container styles', () => {
  it('only applies the backdrop blur while a non-toast dialog is shown', () => {
    expect(styles).toContain('body:not(.swal2-toast-shown) .swal2-container {')
    expect(styles).not.toContain('.swal2-container:not(.swal2-toast-shown) {')
  })
})

describe('Calendar search highlight styles', () => {
  it('leaves the highlight flash to the calendar grid instead of a global cell glow', () => {
    expect(styles).not.toContain('highlight-pulse-glow')
    expect(styles).not.toContain('outline: 1px solid var(--dp-warning)')
    expect(styles).not.toContain('outline-offset: -1px')
    expect(styles).not.toContain('z-index: 10')
  })
})

describe('member tag chip gloss tokens', () => {
  function themeBlock(header: string) {
    const start = styles.indexOf(`\n${header} {`)
    expect(start, `${header} block`).toBeGreaterThan(-1)
    return styles.slice(start, styles.indexOf('\n}', start))
  }

  // The sheen is a translucent overlay, so each chip keeps its own
  // background-color (and its hover colour) underneath.
  it('defines a light sheen, inner highlight and faint drop shadow', () => {
    const light = themeBlock(':root')
    expect(light).toContain('--dp-tag-chip-sheen: linear-gradient(180deg, rgb(255 255 255 / 0) 0%, rgb(15 23 42 / 0.05) 100%);')
    expect(light).toContain('--dp-tag-chip-highlight: rgb(255 255 255 / 0.95);')
    expect(light).toContain('--dp-tag-chip-drop: 0 1px 2px rgb(15 23 42 / 0.08), 0 1px 1px rgb(15 23 42 / 0.04);')
    expect(light).toContain('--dp-tag-chip-drop-mini: 0 0.5px 1px rgb(15 23 42 / 0.14);')
  })

  it('lifts the top edge instead of sinking the bottom in dark mode', () => {
    const dark = themeBlock('.dark')
    expect(dark).toContain('--dp-tag-chip-sheen: linear-gradient(180deg, rgb(255 255 255 / 0.12) 0%, rgb(255 255 255 / 0) 100%);')
    expect(dark).toContain('--dp-tag-chip-highlight: rgb(255 255 255 / 0.1);')
    expect(dark).toContain('--dp-tag-chip-drop: 0 1px 2px rgb(0 0 0 / 0.45);')
    expect(dark).toContain('--dp-tag-chip-drop-mini: 0 0.5px 1px rgb(0 0 0 / 0.45);')
  })
})
