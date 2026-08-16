import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const locales = ['en', 'ko']
const __dirname = path.dirname(fileURLToPath(import.meta.url))
const repositoryRoot = path.resolve(__dirname, '..', '..')
const releaseNotesPath = path.join(repositoryRoot, 'src', 'main', 'resources', 'public-content', 'release-notes.json')

function fail(message) {
  console.error(message)
  process.exit(1)
}

function requirePrNumber() {
  const value = process.argv[2] || process.env.PR_NUMBER || ''
  if (!/^\d+$/.test(value)) fail('Usage: node .github/scripts/check-pr-release-note.mjs <pr-number>')
  return Number(value)
}

function readReleaseNotes() {
  try {
    return JSON.parse(fs.readFileSync(releaseNotesPath, 'utf8'))
  } catch (error) {
    fail(`Unable to read canonical release notes at ${releaseNotesPath}: ${error.message}`)
  }
}

const prNumber = requirePrNumber()
const releaseNotes = readReleaseNotes()
const matches = releaseNotes.items?.filter(item => item.pr === prNumber) || []

if (matches.length !== 1) fail(`Expected exactly one release note for PR #${prNumber} in ${releaseNotesPath}.`)

const note = matches[0]
if (note.id !== `pr-${prNumber}`) fail(`Release note for PR #${prNumber} must use id "pr-${prNumber}".`)
if (typeof note.version !== 'string' || !note.version.trim()) fail(`Release note for PR #${prNumber} must include a version.`)

for (const locale of locales) {
  const copy = releaseNotes.locales?.[locale]?.entries?.[note.id]
  if (!copy) fail(`Missing ${locale} release note copy for PR #${prNumber} in ${releaseNotesPath}.`)
  if (
    typeof copy.title !== 'string' || !copy.title.trim() ||
    typeof copy.summary !== 'string' || !copy.summary.trim() ||
    !Array.isArray(copy.changes) || copy.changes.length === 0 ||
    copy.changes.some(change => typeof change !== 'string' || !change.trim())
  ) {
    fail(`${locale} release note copy for PR #${prNumber} must include title, summary, and at least one change.`)
  }
}

console.log(`Release note entry found for PR #${prNumber} in canonical JSON and ${locales.length} locales.`)
