import { describe, expect, it } from 'vitest'
import { renderPolicyMarkdown } from './policyMarkdown'

describe('renderPolicyMarkdown', () => {
  it('preserves policy Markdown formatting', () => {
    const rendered = renderPolicyMarkdown([
      '# Policy',
      '',
      '**Important** and [details](/policy/details).',
      '',
      '- first',
      '- second',
    ].join('\n'))

    expect(rendered).toContain('<h1>Policy</h1>')
    expect(rendered).toContain('<strong>Important</strong>')
    expect(rendered).toContain('<a href="/policy/details">details</a>')
    expect(rendered).toContain('<li>first</li>')
  })

  it('removes executable HTML and unsafe URLs', () => {
    const rendered = renderPolicyMarkdown([
      '<script>alert(1)</script>',
      '',
      '<style>body { display: none }</style>',
      '',
      '<img src="x" onerror="alert(1)">',
      '',
      '<a href="javascript:alert(1)" onclick="alert(1)">bad link</a>',
      '',
      '<iframe src="https://attacker.example"></iframe>',
      '',
      '<object data="https://attacker.example"></object>',
      '',
      '<embed src="https://attacker.example">',
      '',
      '<svg><a href="javascript:alert(1)">svg link</a></svg>',
      '',
      '<math><mtext onclick="alert(1)">math</mtext></math>',
      '',
      '![data image](data:image/svg+xml;base64,PHN2Zy8+)',
    ].join('\n'))

    expect(rendered).not.toMatch(/<\/?(?:script|style|iframe|object|embed|svg|math)\b/i)
    expect(rendered).not.toMatch(/\son\w+\s*=/i)
    expect(rendered).not.toMatch(/(?:javascript|data)\s*:/i)
    expect(rendered).not.toContain('attacker.example')
  })

  it('keeps safe URLs and unwraps obfuscated unsafe links', () => {
    const rendered = renderPolicyMarkdown([
      '[relative](/policy)',
      '[secure](https://dutypark.example/policy)',
      '[email](mailto:privacy@dutypark.example)',
      '[unsafe](javascript&colon;alert(1))',
      '[encoded](java%73cript:alert(1))',
      '![unsafe image](data:image/png;base64,AAAA)',
    ].join('\n'))

    expect(rendered).toContain('href="/policy"')
    expect(rendered).toContain('href="https://dutypark.example/policy"')
    expect(rendered).toContain('href="mailto:privacy@dutypark.example"')
    expect(rendered).toContain('unsafe')
    expect(rendered).toContain('encoded')
    expect(rendered).not.toMatch(/(?:javascript|data)\s*(?:&colon;|:)/i)
    expect(rendered).not.toContain('java%73cript')
  })

  it('allows colon character references outside the URL scheme', () => {
    const rendered = renderPolicyMarkdown([
      '[query](https://dutypark.example/policy?separator=&colon;)',
      '[fragment](/policy#separator=&#58;)',
    ].join('\n'))

    expect(rendered).toContain(
      '<a href="https://dutypark.example/policy?separator=&colon;">query</a>',
    )
    expect(rendered).toContain('<a href="/policy#separator=&#58;">fragment</a>')
  })

  it('does not allow Markdown labels or titles to inject attributes', () => {
    const rendered = renderPolicyMarkdown([
      '![" onerror="alert(1)](https://invalid.example/image.png)',
      '[" onclick="alert(1)](https://dutypark.example)',
      '[link](https://dutypark.example \'" onclick="alert(1)\')',
    ].join('\n'))

    expect(rendered).not.toContain('<img')
    expect(rendered).toContain(
      '<a href="https://dutypark.example">&quot; onclick=&quot;alert(1)</a>',
    )
    expect(rendered).toContain(
      '<a href="https://dutypark.example" title="&quot; onclick=&quot;alert(1)">link</a>',
    )
  })
})
