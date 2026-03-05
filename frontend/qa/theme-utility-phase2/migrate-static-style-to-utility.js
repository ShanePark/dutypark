#!/usr/bin/env node

import fs from 'fs'
import path from 'path'

const SRC_DIR = path.resolve(process.cwd(), 'frontend/src')

const RULES = [
  { styleAttr: ':style="{ color: \'var(--dp-text-primary)\' }"', classes: ['text-dp-text-primary'] },
  { styleAttr: ':style="{ color: \'var(--dp-text-secondary)\' }"', classes: ['text-dp-text-secondary'] },
  { styleAttr: ':style="{ color: \'var(--dp-text-muted)\' }"', classes: ['text-dp-text-muted'] },
  { styleAttr: ':style="{ color: \'var(--dp-border-secondary)\' }"', classes: ['text-dp-border-secondary'] },

  { styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-secondary)\' }"', classes: ['bg-dp-bg-secondary'] },
  { styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-tertiary)\' }"', classes: ['bg-dp-bg-tertiary'] },
  { styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-modal)\' }"', classes: ['bg-dp-bg-modal'] },
  { styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-card)\' }"', classes: ['bg-dp-bg-card'] },
  { styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-footer)\' }"', classes: ['bg-dp-bg-footer'] },
  { styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-hover)\' }"', classes: ['bg-dp-bg-hover'] },
  { styleAttr: ':style="{ backgroundColor: \'var(--dp-modal-header-bg)\' }"', classes: ['bg-dp-surface-strong'] },
  { styleAttr: ':style="{ backgroundColor: \'var(--dp-modal-header-bg-alt)\' }"', classes: ['bg-dp-surface-strong-alt'] },

  { styleAttr: ':style="{ borderColor: \'var(--dp-border-primary)\' }"', classes: ['border-dp-border-primary'] },
  { styleAttr: ':style="{ borderColor: \'var(--dp-border-secondary)\' }"', classes: ['border-dp-border-secondary'] },
  { styleAttr: ':style="{ borderColor: \'var(--dp-border-input)\' }"', classes: ['border-dp-border-input'] },

  { styleAttr: ':style="{ borderTop: \'1px solid var(--dp-border-primary)\' }"', classes: ['border-t', 'border-dp-border-primary'] },
  { styleAttr: ':style="{ borderBottom: \'1px solid var(--dp-border-primary)\' }"', classes: ['border-b', 'border-dp-border-primary'] },
  { styleAttr: ':style="{ borderTop: \'1px solid var(--dp-border-secondary)\' }"', classes: ['border-t', 'border-dp-border-secondary'] },
  { styleAttr: ':style="{ borderBottom: \'1px solid var(--dp-border-secondary)\' }"', classes: ['border-b', 'border-dp-border-secondary'] },

  {
    styleAttr: ':style="{ borderBottomWidth: \'1px\', borderBottomStyle: \'solid\', borderBottomColor: \'var(--dp-border-primary)\' }"',
    classes: ['border-b', 'border-dp-border-primary'],
  },
  {
    styleAttr: ':style="{ borderBottomWidth: \'1px\', borderColor: \'var(--dp-border-primary)\' }"',
    classes: ['border-b', 'border-dp-border-primary'],
  },
  {
    styleAttr: ':style="{ borderBottomWidth: \'1px\', borderColor: \'var(--dp-border-secondary)\' }"',
    classes: ['border-b', 'border-dp-border-secondary'],
  },
  {
    styleAttr: ':style="{ borderTopWidth: \'1px\', borderColor: \'var(--dp-border-primary)\' }"',
    classes: ['border-t', 'border-dp-border-primary'],
  },

  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-card)\', border: \'1px solid var(--dp-border-primary)\' }"',
    classes: ['bg-dp-bg-card', 'border', 'border-dp-border-primary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-card)\', borderColor: \'var(--dp-border-primary)\' }"',
    classes: ['bg-dp-bg-card', 'border-dp-border-primary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-card)\', borderWidth: \'1px\', borderColor: \'var(--dp-border-primary)\' }"',
    classes: ['bg-dp-bg-card', 'border', 'border-dp-border-primary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-card)\', borderColor: \'var(--dp-border-secondary)\' }"',
    classes: ['bg-dp-bg-card', 'border-dp-border-secondary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-card)\', borderBottom: \'1px solid var(--dp-border-primary)\' }"',
    classes: ['bg-dp-bg-card', 'border-b', 'border-dp-border-primary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-card)\', color: \'var(--dp-text-primary)\' }"',
    classes: ['bg-dp-bg-card', 'text-dp-text-primary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-card)\', color: \'var(--dp-text-secondary)\' }"',
    classes: ['bg-dp-bg-card', 'text-dp-text-secondary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-card)\', color: \'var(--dp-text-muted)\' }"',
    classes: ['bg-dp-bg-card', 'text-dp-text-muted'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-card)\', color: \'var(--dp-danger)\' }"',
    classes: ['bg-dp-bg-card', 'text-dp-danger'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-card)\', color: \'var(--dp-warning-hover)\' }"',
    classes: ['bg-dp-bg-card', 'text-dp-warning-hover'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-card)\', borderColor: \'var(--dp-border-secondary)\', color: \'var(--dp-text-secondary)\' }"',
    classes: ['bg-dp-bg-card', 'border-dp-border-secondary', 'text-dp-text-secondary'],
  },

  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-input)\', borderColor: \'var(--dp-border-input)\', color: \'var(--dp-text-primary)\' }"',
    classes: ['bg-dp-bg-input', 'border-dp-border-input', 'text-dp-text-primary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-input)\', border: \'1px solid var(--dp-border-input)\', color: \'var(--dp-text-primary)\' }"',
    classes: ['bg-dp-bg-input', 'border', 'border-dp-border-input', 'text-dp-text-primary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-input)\', color: \'var(--dp-text-primary)\' }"',
    classes: ['bg-dp-bg-input', 'text-dp-text-primary'],
  },

  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-secondary)\', color: \'var(--dp-text-secondary)\' }"',
    classes: ['bg-dp-bg-secondary', 'text-dp-text-secondary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-secondary)\', color: \'var(--dp-text-muted)\' }"',
    classes: ['bg-dp-bg-secondary', 'text-dp-text-muted'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-secondary)\', borderWidth: \'1px\', borderColor: \'var(--dp-border-primary)\' }"',
    classes: ['bg-dp-bg-secondary', 'border', 'border-dp-border-primary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-secondary)\', borderColor: \'var(--dp-border-primary)\' }"',
    classes: ['bg-dp-bg-secondary', 'border-dp-border-primary'],
  },
  {
    styleAttr: ':style="{ borderColor: \'var(--dp-border-primary)\', backgroundColor: \'var(--dp-bg-secondary)\' }"',
    classes: ['bg-dp-bg-secondary', 'border-dp-border-primary'],
  },

  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-tertiary)\', borderBottom: \'1px solid var(--dp-border-primary)\' }"',
    classes: ['bg-dp-bg-tertiary', 'border-b', 'border-dp-border-primary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-tertiary)\', color: \'var(--dp-text-secondary)\' }"',
    classes: ['bg-dp-bg-tertiary', 'text-dp-text-secondary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-tertiary)\', color: \'var(--dp-text-primary)\' }"',
    classes: ['bg-dp-bg-tertiary', 'text-dp-text-primary'],
  },
  {
    styleAttr: ':style="{ color: \'var(--dp-text-primary)\', backgroundColor: \'var(--dp-bg-tertiary)\' }"',
    classes: ['bg-dp-bg-tertiary', 'text-dp-text-primary'],
  },
  {
    styleAttr: ':style="{ backgroundColor: \'var(--dp-bg-tertiary)\', borderColor: \'var(--dp-border-secondary)\' }"',
    classes: ['bg-dp-bg-tertiary', 'border-dp-border-secondary'],
  },

  {
    styleAttr: ':style="{ borderColor: \'var(--dp-border-secondary)\', color: \'var(--dp-text-secondary)\' }"',
    classes: ['border-dp-border-secondary', 'text-dp-text-secondary'],
  },
  {
    styleAttr: ':style="{ borderColor: \'var(--dp-border-primary)\', color: \'var(--dp-text-primary)\' }"',
    classes: ['border-dp-border-primary', 'text-dp-text-primary'],
  },
  {
    styleAttr: ':style="{ borderColor: \'var(--dp-border-primary)\', color: \'var(--dp-text-muted)\' }"',
    classes: ['border-dp-border-primary', 'text-dp-text-muted'],
  },
]

function walkVueFiles(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true })
  const files = []
  for (const entry of entries) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      files.push(...walkVueFiles(full))
    } else if (entry.isFile() && full.endsWith('.vue')) {
      files.push(full)
    }
  }
  return files
}

function addClasses(tag, classesToAdd) {
  const classMatch = tag.match(/\bclass="([^"]*)"/)
  if (classMatch) {
    const original = classMatch[1]
    const tokens = original.split(/\s+/).filter(Boolean)
    for (const c of classesToAdd) {
      if (!tokens.includes(c)) tokens.push(c)
    }
    const merged = tokens.join(' ')
    return tag.replace(/\bclass="([^"]*)"/, `class="${merged}"`)
  }

  return tag.replace(/^<([A-Za-z][^\s/>]*)/, `<$1 class="${classesToAdd.join(' ')}"`)
}

function transformTemplate(template) {
  return template.replace(/<[^>]+>/gs, (tag) => {
    if (tag.startsWith('</') || tag.startsWith('<!') || tag.startsWith('<?')) return tag
    if (!tag.includes(':style="{')) return tag

    let next = tag
    for (const rule of RULES) {
      if (!next.includes(rule.styleAttr)) continue
      next = next.replace(new RegExp(`\\s*${escapeRegExp(rule.styleAttr)}`, 'g'), '')
      next = addClasses(next, rule.classes)
    }

    return next
  })
}

function escapeRegExp(input) {
  return input.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

const files = walkVueFiles(SRC_DIR)
let changedFiles = 0
let transformedTags = 0

for (const file of files) {
  const source = fs.readFileSync(file, 'utf8')

  const templateStart = source.indexOf('<template')
  const templateClose = source.lastIndexOf('</template>')
  if (templateStart < 0 || templateClose < 0 || templateClose <= templateStart) continue

  const templateEnd = templateClose + '</template>'.length
  const templateRegion = source.slice(templateStart, templateEnd)
  if (!templateRegion.includes(':style="{')) continue

  const transformedRegion = transformTemplate(templateRegion)
  if (templateRegion === transformedRegion) continue

  transformedTags += (templateRegion.match(/:style="\{/g) || []).length - (transformedRegion.match(/:style="\{/g) || []).length
  const updated = source.slice(0, templateStart) + transformedRegion + source.slice(templateEnd)
  fs.writeFileSync(file, updated)
  changedFiles++
}

console.log(`changed files: ${changedFiles}`)
console.log(`removed :style blocks (rough): ${transformedTags}`)
