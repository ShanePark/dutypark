import fs from 'node:fs'
import path from 'node:path'

const locales = ['en', 'ko', 'ja', 'zh', 'es']

function fail(message) {
  console.error(message)
  process.exit(1)
}

function read(filePath) {
  if (!fs.existsSync(filePath)) {
    fail(`Missing file: ${filePath}`)
  }

  return fs.readFileSync(filePath, 'utf8')
}

function decodeI18nLiteral(text) {
  return text
    .replaceAll("{'@'}", '@')
    .replaceAll("{'{'}", '{')
    .replaceAll("{'}'}", '}')
}

function parseJsonStringFromLine(line) {
  const match = line.match(/"((?:[^"\\]|\\.)*)"/)
  return match ? decodeI18nLiteral(JSON.parse(match[0])) : null
}

function getEntryBlock(lines, startIndex) {
  const block = []

  for (const line of lines.slice(startIndex + 1)) {
    const trimmed = line.trim()
    if (trimmed === '},' || trimmed === '}') {
      break
    }

    block.push(line)
  }

  return block
}

function readReleaseNoteMeta(prNumber) {
  const metaPath = path.join(process.cwd(), 'frontend', 'src', 'releaseNotes', 'meta.ts')
  const lines = read(metaPath).split('\n')
  const startIndex = lines.findIndex(line => line.includes(`id: "pr-${prNumber}"`))

  if (startIndex < 0) {
    return null
  }

  const note = {
    pr: null,
    version: '',
  }

  for (const line of getEntryBlock(lines, startIndex)) {
    const trimmed = line.trim()

    if (trimmed.startsWith('pr:')) {
      const match = trimmed.match(/pr:\s*(\d+)/)
      note.pr = match ? Number(match[1]) : null
      continue
    }

    if (trimmed.startsWith('version:')) {
      note.version = parseJsonStringFromLine(line) ?? ''
    }
  }

  return note
}

function readReleaseNoteCopy(prNumber, locale) {
  const messagePath = path.join(
    process.cwd(),
    'frontend',
    'src',
    'releaseNotes',
    'messages',
    `${locale}.ts`,
  )
  const lines = read(messagePath).split('\n')
  const startIndex = lines.findIndex(line => line.includes(`"pr-${prNumber}": {`))

  if (startIndex < 0) {
    return null
  }

  const note = {
    title: '',
    summary: '',
    changes: [],
  }
  let inChanges = false

  for (const line of getEntryBlock(lines, startIndex)) {
    const trimmed = line.trim()

    if (trimmed.startsWith('title:')) {
      note.title = parseJsonStringFromLine(line) ?? ''
      continue
    }

    if (trimmed.startsWith('summary:')) {
      note.summary = parseJsonStringFromLine(line) ?? ''
      continue
    }

    if (trimmed.startsWith('changes: [')) {
      inChanges = true
      continue
    }

    if (inChanges && trimmed.startsWith(']')) {
      inChanges = false
      continue
    }

    if (inChanges) {
      const change = parseJsonStringFromLine(line)
      if (change) {
        note.changes.push(change)
      }
    }
  }

  return note
}

function requirePrNumber() {
  const value = process.argv[2] || process.env.PR_NUMBER || ''
  if (!/^\d+$/.test(value)) {
    fail('Usage: node .github/scripts/check-pr-release-note.mjs <pr-number>')
  }

  return Number(value)
}

const prNumber = requirePrNumber()
const meta = readReleaseNoteMeta(prNumber)

if (!meta) {
  fail(`Missing in-app release note metadata for PR #${prNumber}. Add id "pr-${prNumber}" to frontend/src/releaseNotes/meta.ts.`)
}

if (meta.pr !== prNumber) {
  fail(`Release note metadata id "pr-${prNumber}" must include pr: ${prNumber}.`)
}

if (!meta.version) {
  fail(`Release note metadata for PR #${prNumber} must include a version.`)
}

for (const locale of locales) {
  const copy = readReleaseNoteCopy(prNumber, locale)
  if (!copy) {
    fail(`Missing ${locale} in-app release note copy for PR #${prNumber}. Add entry "pr-${prNumber}" to frontend/src/releaseNotes/messages/${locale}.ts.`)
  }

  if (!copy.title || !copy.summary || copy.changes.length === 0) {
    fail(`${locale} release note copy for PR #${prNumber} must include title, summary, and at least one change.`)
  }
}

console.log(`Release note entry found for PR #${prNumber} in metadata and ${locales.length} locales.`)
