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
