import { describe, expect, it } from 'vitest'
import adminNavTiles from './AdminNavTiles.vue?raw'

describe('AdminNavTiles', () => {
  it('keeps only the four user-facing administration menu items', () => {
    expect(adminNavTiles).not.toContain('to="/admin/dev"')
    expect(adminNavTiles).not.toContain('href="/docs/index.html"')

    const menuLinks = adminNavTiles.match(/<router-link\n/g) ?? []
    expect(menuLinks).toHaveLength(4)
  })

  it('keeps all four administration menu items on one row at every breakpoint', () => {
    expect(adminNavTiles).toContain('grid grid-cols-4 gap-2 sm:gap-4 mb-4 sm:mb-6')
    expect(adminNavTiles).not.toContain('grid-cols-3')
  })
})
