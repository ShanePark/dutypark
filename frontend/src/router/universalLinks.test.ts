import { describe, expect, it } from 'vitest'
import association from '../../public/apple-app-site-association?raw'
import { routes } from './routes'

/**
 * A malformed association file silently disables every universal link at once, so parse the
 * real file instead of matching on its text.
 */
const applinks = JSON.parse(association) as {
  applinks: { details: Array<{ appIDs: string[]; components: Array<{ '/': string }> }> }
}

const details = applinks.applinks.details
const componentPaths = details.flatMap((detail) => detail.components.map((component) => component['/']))

describe('apple app site association', () => {
  it('keeps a single detail entry for the iOS app', () => {
    expect(details.map((detail) => detail.appIDs)).toEqual([
      ['2V47G42CDS.io.github.shanepark.dutypark'],
    ])
  })

  it('registers every deep linked path, including the support form', () => {
    expect(componentPaths).toEqual(['/guide', '/terms', '/privacy', '/support', '/duty/*'])
  })

  it('points every registered path at a real route', () => {
    const routePaths = routes.map((route) => route.path)

    for (const path of componentPaths) {
      const prefix = path.replace(/\/\*$/, '')
      expect(
        routePaths.some((routePath) => routePath === prefix || routePath.startsWith(`${prefix}/`)),
        path
      ).toBe(true)
    }
  })
})
