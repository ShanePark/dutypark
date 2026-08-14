import { marked, Renderer, type Tokens } from 'marked'

const LINK_SCHEMES = new Set(['http', 'https', 'mailto', 'tel'])

function hasAllowedUrl(href: string, schemes: ReadonlySet<string>): boolean {
  const normalized = href.trim().replace(/[\u0000-\u0020\u007f-\u009f]/g, '')

  if (!normalized || normalized.startsWith('//') || normalized.startsWith('\\')) {
    return false
  }

  const schemeBoundary = normalized.search(/[/?#]/)
  const schemeCandidate = normalized.slice(0, schemeBoundary === -1 ? undefined : schemeBoundary)

  // Character references are decoded by the browser after HTML rendering and can
  // otherwise hide a colon in the scheme candidate (for example, &colon;).
  if (/&(?:colon|#0*58|#x0*3a);?/i.test(schemeCandidate)) {
    return false
  }

  const scheme = /^([^/?#]*):/.exec(normalized)?.[1]
  return scheme === undefined || schemes.has(scheme.toLowerCase())
}

class PolicyMarkdownRenderer extends Renderer {
  override html(_token: Tokens.HTML | Tokens.Tag): string {
    return ''
  }

  override link(token: Tokens.Link): string {
    if (!hasAllowedUrl(token.href, LINK_SCHEMES)) {
      return this.parser.parseInline(token.tokens)
    }
    return super.link(token)
  }

  override image(_token: Tokens.Image): string {
    return ''
  }
}

const renderer = new PolicyMarkdownRenderer()

export function renderPolicyMarkdown(markdown: string): string {
  return String(marked(markdown, { breaks: true, renderer }))
}
